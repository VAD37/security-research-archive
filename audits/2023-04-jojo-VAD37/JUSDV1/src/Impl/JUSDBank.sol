/*
    Copyright 2022 JOJO Exchange
    SPDX-License-Identifier: BUSL-1.1*/
pragma solidity 0.8.9;

import "../Interface/IJUSDBank.sol";
import "../Interface/IFlashLoanReceive.sol";
import "./JUSDBankStorage.sol";
import "./JUSDOperation.sol";
import "./JUSDView.sol";
import "./JUSDMulticall.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../lib/smart-contract-EVM/contracts/intf/IDealer.sol";
import {IPriceChainLink} from "../Interface/IPriceChainLink.sol";

contract JUSDBank is IJUSDBank, JUSDOperation, JUSDView, JUSDMulticall {
    using DecimalMath for uint256;
    using SafeERC20 for IERC20;

    constructor(
        uint256 _maxReservesNum,//10
        address _insurance,//user account
        address _JUSD,//JUSD
        address _JOJODealer,//dealer contract MockJOJODealer
        uint256 _maxPerAccountBorrowAmount,//1000e8 , 100e9 , 100000e6
        uint256 _maxTotalBorrowAmount,//_maxPerAccountBorrowAmount + 1
        uint256 _borrowFeeRate,//2e16 , 0.02e18
        address _primaryAsset//USDC
    ) {
        maxReservesNum = _maxReservesNum;
        JUSD = _JUSD;
        JOJODealer = _JOJODealer;
        insurance = _insurance;
        maxPerAccountBorrowAmount = _maxPerAccountBorrowAmount;
        maxTotalBorrowAmount = _maxTotalBorrowAmount;
        borrowFeeRate = _borrowFeeRate;
        t0Rate = JOJOConstant.ONE;
        primaryAsset = _primaryAsset;
        lastUpdateTimestamp = uint32(block.timestamp);
    }

    // --------------------------event-----------------------

    event HandleBadDebt(address indexed liquidatedTrader, uint256 borrowJUSDT0);
    event Deposit(
        address indexed collateral,
        address indexed from,
        address indexed to,
        address operator,
        uint256 amount
    );
    event Borrow(
        address indexed from,
        address indexed to,
        uint256 amount,
        bool isDepositToJOJO
    );
    event Repay(address indexed from, address indexed to, uint256 amount);
    event Withdraw(
        address indexed collateral,
        address indexed from,
        address indexed to,
        uint256 amount,
        bool ifInternal
    );
    event Liquidate(
        address indexed collateral,
        address indexed liquidator,
        address indexed liquidated,
        address operator,
        uint256 collateralAmount,
        uint256 liquidatedAmount,
        uint256 insuranceFee
    );
    event FlashLoan(address indexed collateral, uint256 amount);

    /// @notice to ensure msg.sender is from account or msg.sender is the sub account of from
    /// so that msg.sender can send the transaction
    modifier isValidOperator(address operator, address client) {
        require(
            msg.sender == client || operatorRegistry[client][operator],
            JUSDErrors.CAN_NOT_OPERATE_ACCOUNT
        );
        _;
    }
    modifier isLiquidator(address liquidator) {
        if(isLiquidatorWhitelistOpen){
            require(isLiquidatorWhiteList[liquidator], "liquidator is not in the liquidator white list");
        }
        _;
    }

    function deposit(
        address from,
        address collateral,
        uint256 amount,
        address to
    ) external override nonReentrant isValidOperator(msg.sender, from) {
        DataTypes.ReserveInfo storage reserve = reserveInfo[collateral];
        DataTypes.UserInfo storage user = userInfo[to];
        //        deposit
        _deposit(reserve, user, amount, collateral, to, from);
    }

    function borrow(//@ok deposit 101 BTC. can borrow 1428
        uint256 amount,//borrow amount in USD
        address to,
        bool isDepositToJOJO
    ) external override nonReentrant nonFlashLoanReentrant{
        //     t0BorrowedAmount = borrowedAmount /  getT0Rate
        DataTypes.UserInfo storage user = userInfo[msg.sender];
        _borrow(user, isDepositToJOJO, to, amount, msg.sender);
        require(//t0BorrowBalance= deposit * 1e18 /old_tRate * new_tRate/1e18
            _isAccountSafeAfterBorrow(user, getTRate()),// < maxmint = price * original_deposit * 80%
            JUSDErrors.AFTER_BORROW_ACCOUNT_IS_NOT_SAFE
        );
    }

    function repay(
        uint256 amount,
        address to
    ) external override nonReentrant returns (uint256) {
        DataTypes.UserInfo storage user = userInfo[to];
        uint256 tRate = getTRate();
        return _repay(user, msg.sender, to, amount, tRate);
    }

    function withdraw(
        address collateral,
        uint256 amount,
        address to,
        bool isInternal
    ) external override nonReentrant nonFlashLoanReentrant{
        DataTypes.UserInfo storage user = userInfo[msg.sender];
        _withdraw(amount, collateral, to, msg.sender, isInternal);
        uint256 tRate = getTRate();
        require(//check deposit_borrow < deposit * price * 80% 
            _isAccountSafe(user, tRate),//@audit-ok cannot withdraw if borrow disabled
            JUSDErrors.AFTER_WITHDRAW_ACCOUNT_IS_NOT_SAFE
        );
    }
    // Liquidation allow partial and full. partial require repay debt but not transfer leftover. full liquid force repay some leftover USDC after debt send to original user.
    function liquidate(
        address liquidated,//target. liquidated 10e18 WETH borrow 7426e6 JUSD. 
        address collateral,//WBTC, WETH
        address liquidator,//msg.sender.
        uint256 amount,// collateral amount. 10e18 WETH or 1e8 BTC. max user deposit balance
        bytes memory afterOperationParam,// JUSD, 10e18// swap
        uint256 expectPrice// 900e6. WETH price in JUSD
    )//jusdExchange have 50000e6 JUSD
        public
        override
        isValidOperator(msg.sender, liquidator)//unsafe user can set allow any random address to be liquidator
        nonFlashLoanReentrant//@audit liquidation can have callback call deposit repay
        returns (DataTypes.LiquidateData memory liquidateData)
    {//@audit-ok t0borrow is smaller deposit amount. liquidation does not update to new interest rate
        uint256 JUSDBorrowedT0 = userInfo[liquidated].t0BorrowBalance;
        uint256 primaryLiquidatedAmount = IERC20(primaryAsset).balanceOf(//USDC
            liquidated  //@audit-ok why the fuck check USDC current balanceOf instead deposit balance
        ); // is all account here is contract or subcontract controlled by EVM  
        uint256 primaryInsuranceAmount = IERC20(primaryAsset).balanceOf(//USDC
            insurance//protocol account?
        );//valid operator check msg.sender == liquidator
        isValidLiquidator(liquidated, liquidator);//liquidator!= liquidated. if whitelist enable, only valid liquidator
        // 1. calculate the liquidate amount//@ok L self validLiquidator can be bypass by another address approved by user
        liquidateData = _calculateLiquidateAmount(
            liquidated,
            collateral,
            amount
        );//actualLiquidatedT0 = 0.855 * amount/newRate || borrowUSD /oldRate == t0BorrowBalance
        require(                                                //insuranceFee = amount * 0.095 || 0.09* amount
        // condition: actual liquidate price < max buy price,   //actualLiquidated = 0.855 * amount || borrowUSD * new/oldRate
        // price lower, better                                  //actualCollateral= amount || borrowUSD * new/oldtRate
            (liquidateData.insuranceFee + liquidateData.actualLiquidated).decimalDiv(liquidateData.actualCollateral)
                <= expectPrice,//unsafe as expectPrice can be anything //@audit M BTC expect price wrong decimal multiplication. actual in JUSD e6 * 1e18/ actual collateral in e18
            JUSDErrors.LIQUIDATION_PRICE_PROTECTION// expectPrice = 1e18   = amount_e18 *1e18 / amount_e18 
        );                                         // expectPrice ~= (  0.09* amount + borrow_e6 ) *1e18 / borrow_e6 ~= 1.09* amount_e6_e18 // if amount_e6 then convert to e18 * 1.09
        // 2. after liquidation flashloan operation
        _afterLiquidateOperation(//@note force user withdrawal then call flashloan
            afterOperationParam,// withdraw collateral to flashloan address inside afterOperationParam
            amount,// there is no bought discount with USDC yet
            collateral,// just send collateral away without asking back
            liquidated,
            liquidateData
        );//@ok callback cannot affect require check below as it cannot access borrow function
        // 3. price protect.//@audit H JUSD borrow delta e6 compare with partial collateral amount e8 or e18
        require(//repay check. callback must repay user debt using JUSD
            JUSDBorrowedT0 - userInfo[liquidated].t0BorrowBalance >=// borrow delta after callback
                liquidateData.actualLiquidatedT0,//actualLiquidatedT0 = 0.855 * amount/newRate || borrowUSD /oldRate == t0BorrowBalance
            JUSDErrors.REPAY_AMOUNT_NOT_ENOUGH//borrowUSD /oldRate == t0BorrowBalance
        );//@audit partial liquidation pay less 15% than full liquidation. actualLiquidatedT0 here should be actualLiquidated. or the actualLiquidatedT0 inside if case is wrong.
        require(
            IERC20(primaryAsset).balanceOf(insurance) - //insuranceFee = 0.095 * amount || 0.09* amount
                primaryInsuranceAmount >=
                liquidateData.insuranceFee,//check if callback transfer USDC insuranceFee to insurance account.
            JUSDErrors.INSURANCE_AMOUNT_NOT_ENOUGH
        );
        require(
            IERC20(primaryAsset).balanceOf(liquidated) - //actualCollateral= amount || borrowUSD * new/oldtRate
                primaryLiquidatedAmount >=//primaryLiquidatedAmount = before flashloan balanceOf(liquidated)
                liquidateData.liquidatedRemainUSDC,//liquidatedRemainUSDC = (amount - actualCollateral) * priceUSD
            JUSDErrors.LIQUIDATED_AMOUNT_NOT_ENOUGH //liquidatedRemainUSDC = 0 * priceUSD || (amount - borrow*interest) * priceUSD
        );//@note liquidated have check if target receive USDC discount of collateral.
        emit Liquidate(//@note the balanace sheet look like this.
            collateral,// liquidated: collateral 1ETH + borrow 800e6 JUSD 
            liquidator,// liquidator: 1000 USDC. call full liquidation 1ETH at price 600e6 JUSD
            liquidated,// repay 800 JUSD debt. or 0.855 * 799 JUSD. 0.095
            msg.sender,// 5% discount for partial liquidation.  full liquidation does not have to pay?
            liquidateData.actualCollateral,
            liquidateData.actualLiquidated,
            liquidateData.insuranceFee
        );
    }
    function handleDebt(
        address[] calldata liquidatedTraders
    ) external onlyOwner {
        for (uint256 i; i < liquidatedTraders.length; i = i + 1) {
            _handleBadDebt(liquidatedTraders[i]);
        }
    }

    function flashLoan(//@audit deposit and repay does not have nonFlashLoanReentrant modifier
        address receiver,
        address collateral,
        uint256 amount,
        address to,
        bytes memory param
    ) external nonFlashLoanReentrant {//flashloan can still allow user deposit more.
        DataTypes.UserInfo storage user = userInfo[msg.sender];
        _withdraw(amount, collateral, receiver, msg.sender, false);//@audit flashloan limit withdraw based on deposit of user.
        // repay
        IFlashLoanReceive(receiver).JOJOFlashLoan(//@audit flashloan can deposit again-> double counting?
            collateral,
            amount,//@audit disable borrow does not prevent flashloan. can this be exploited?
            to,
            param
        );
        require(
            _isAccountSafe(user, getTRate()),//@audit borrow possible disable flashloan
            JUSDErrors.AFTER_FLASHLOAN_ACCOUNT_IS_NOT_SAFE
        );//deposit *newRate / oldRate < deposit * price * 80%
        emit FlashLoan(collateral, amount);
    }

    function _deposit(
        DataTypes.ReserveInfo storage reserve,
        DataTypes.UserInfo storage user,// [to] userInfo
        uint256 amount,//unsafe
        address collateral,//BTC or ETH
        address to,//unsafe
        address from
    ) internal {//@audit deposit allow flashloan. Is this exploitable?
        require(reserve.isDepositAllowed, JUSDErrors.RESERVE_NOT_ALLOW_DEPOSIT);
        require(amount != 0, JUSDErrors.DEPOSIT_AMOUNT_IS_ZERO);
        IERC20(collateral).safeTransferFrom(from, address(this), amount);// operator[from][msg.sender] == true
        _addCollateralIfNotExists(user, collateral);
        user.depositBalance[collateral] += amount;
        reserve.totalDepositAmount += amount;
        require(
            user.depositBalance[collateral] <=
                reserve.maxDepositAmountPerAccount,//210e8 or 21k BTC. 2030e18 ETH
            JUSDErrors.EXCEED_THE_MAX_DEPOSIT_AMOUNT_PER_ACCOUNT
        );
        require(
            reserve.totalDepositAmount <= reserve.maxTotalDepositAmount,//30,000e6 BTC. 4000e18 ETH
            JUSDErrors.EXCEED_THE_MAX_DEPOSIT_AMOUNT_TOTAL
        );
        emit Deposit(collateral, from, to, msg.sender, amount);
    }

    //    Pass parameter checking, excluding checking legality
    function _borrow(
        DataTypes.UserInfo storage user,//[msg.sender]  userInfo
        bool isDepositToJOJO,//unsafe
        address to,//unsafe
        uint256 tAmount,//unsafe
        address from//msg.sender
    ) internal {
        uint256 tRate = getTRate();//~1.0000001e18
        //        tAmount % tRate ？ tAmount / tRate + 1 ： tAmount % tRate
        uint256 t0Amount = tAmount.decimalRemainder(tRate)//@audit the code here does not follow the comment logic.
            ? tAmount.decimalDiv(tRate)// tAmount < 1e18
            : tAmount.decimalDiv(tRate) + 1;// tAmount > 1e18 //@note why perfect rounding with tRate need +1 ?
        user.t0BorrowBalance += t0Amount;//t0BorrowBalance= deposit * 1e18 /tRate    .JUSD 6 decimal cannot make profit with L2 gas
        t0TotalBorrowAmount += t0Amount;//gas price: 1M ~= 0.0001e18 ETH or 0.2$ . borrow gas 50k
        if (isDepositToJOJO) {//multicall 100 times. 2621017 gas ~= 0.5$
            IERC20(JUSD).approve(address(JOJODealer), tAmount);//@audit H deposit wrong amount? should be t0 value in storage
            IDealer(JOJODealer).deposit(0, tAmount, to);//@note check dealer deposit any address can be issue?
        } else {
            IERC20(JUSD).safeTransfer(to, tAmount);
        }
        // Personal account hard cap
        require(
            user.t0BorrowBalance.decimalMul(tRate) <= maxPerAccountBorrowAmount,
            JUSDErrors.EXCEED_THE_MAX_BORROW_AMOUNT_PER_ACCOUNT
        );
        // Global account hard cap
        require(
            t0TotalBorrowAmount.decimalMul(tRate) <= maxTotalBorrowAmount,
            JUSDErrors.EXCEED_THE_MAX_BORROW_AMOUNT_TOTAL
        );//require( t0BorrowBalance *tRate/1e18 <=  )
        emit Borrow(from, to, tAmount, isDepositToJOJO);
    }

    function _repay(
        DataTypes.UserInfo storage user,//to user
        address payer,//msg.sender
        address to,//unsafe
        uint256 amount,//unsafe
        uint256 tRate// getTRate()
    ) internal returns (uint256) {
        require(amount != 0, JUSDErrors.REPAY_AMOUNT_IS_ZERO);
        uint256 JUSDBorrowed = user.t0BorrowBalance.decimalMul(tRate);//@audit H. borrow amount got reduced repay got tax twice. It revert tax amount stored from borrow.
        uint256 tBorrowAmount;//@note is it possible for tRate to reset every 8 hours?
        uint256 t0Amount;
        if (JUSDBorrowed <= amount) {// JUSDBorrowed = tAmount * 1e18 / oldtRate * newtRate / 1e18
            tBorrowAmount = JUSDBorrowed;// JUSDBorrowed = borrow / oldRate * newRate
            t0Amount = user.t0BorrowBalance;//@audit-ok H repay amount is not taxed correctly. Suppose to get 2% fee
        } else {
            tBorrowAmount = amount;
            t0Amount = amount.decimalDiv(tRate);//@audit-ok H. repay remove more debt than required. this is inversed. t0Amount here is more than borrow. repay got freebie benefit
        }//t0BorrowAmount >= t0Amount in all case.
        
        IERC20(JUSD).safeTransferFrom(payer, address(this), tBorrowAmount);//@audit payer approve this address. then anyone can call this function to repay for any user
        user.t0BorrowBalance -= t0Amount;//t0BorrowBalance= deposit * 1e18 /old_tRate
        t0TotalBorrowAmount -= t0Amount;//t0Amount = amount * 1e18 / new_tRate
        emit Repay(payer, to, tBorrowAmount);
        return tBorrowAmount;
    }

    function _withdraw(
        uint256 amount,//unsafe
        address collateral,//unsafe
        address to,//unsafe || user flashloanAddress 
        address from,//msg.sender || liquidated
        bool isInternal//unsafe
    ) internal {
        DataTypes.ReserveInfo storage reserve = reserveInfo[collateral];
        DataTypes.UserInfo storage fromAccount = userInfo[from];
        require(amount != 0, JUSDErrors.WITHDRAW_AMOUNT_IS_ZERO);
        require(
            amount <= fromAccount.depositBalance[collateral],
            JUSDErrors.WITHDRAW_AMOUNT_IS_TOO_BIG
        );

        fromAccount.depositBalance[collateral] -= amount;
        if (isInternal) {//@audit toAccount withdraw give collateral to anyone. What happen if it was this contract.
            DataTypes.UserInfo storage toAccount = userInfo[to];
            _addCollateralIfNotExists(toAccount, collateral);
            toAccount.depositBalance[collateral] += amount;
            require(
                toAccount.depositBalance[collateral] <=
                    reserve.maxDepositAmountPerAccount,
                JUSDErrors.EXCEED_THE_MAX_DEPOSIT_AMOUNT_PER_ACCOUNT
            );
        } else {
            reserve.totalDepositAmount -= amount;
            IERC20(collateral).safeTransfer(to, amount);
        }
        emit Withdraw(collateral, from, to, amount, isInternal);
        _removeEmptyCollateral(fromAccount, collateral);
    }

    function isValidLiquidator(address liquidated, address liquidator) internal view {
        require(
            liquidator != liquidated,
            JUSDErrors.SELF_LIQUIDATION_NOT_ALLOWED
        );
        if(isLiquidatorWhitelistOpen){
            require(isLiquidatorWhiteList[liquidator], JUSDErrors.LIQUIDATOR_NOT_IN_THE_WHITELIST);
        }
    }

    /// @notice liquidate is divided into three steps,
    // 1. determine whether liquidatedTrader is safe
    // 2. calculate the collateral amount actually liquidated
    // 3. transfer the insurance fee
    function _calculateLiquidateAmount(
        address liquidated,//target
        address collateral,//WBTC, WETH
        uint256 amount// collateral amount e6 or e18
    ) internal view returns (DataTypes.LiquidateData memory liquidateData) {
        DataTypes.UserInfo storage liquidatedInfo = userInfo[liquidated];
        require(amount != 0, JUSDErrors.LIQUIDATE_AMOUNT_IS_ZERO);
        require(
            amount <= liquidatedInfo.depositBalance[collateral],
            JUSDErrors.LIQUIDATE_AMOUNT_IS_TOO_BIG
        );//@audit liquidation does not have logic maxMintBorrow like repay, borrow.
        uint256 tRate = getTRate();
        require(
            _isStartLiquidation(liquidatedInfo, tRate),
            JUSDErrors.ACCOUNT_IS_SAFE
        );//@audit when delist collateral. maxMint reduce to 0. this check always pass if borrow
        DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
        uint256 price = IPriceChainLink(reserve.oracle).getAssetPrice();//jojo adapter oracle price converted 1e6 JUSD
        uint256 priceOff = price.decimalMul(//collateral USD price * 95% = 500e6 * 0.95e18 /1e18 = 475000000
            DecimalMath.ONE - reserve.liquidationPriceOff//0.05e18
        );
        uint256 liquidateAmount = amount.decimalMul(priceOff).decimalMul(// 10e18 * 475e6 / 1e18 * 0.9e18/1e18 = 4275000000
            JOJOConstant.ONE - reserve.insuranceFeeRate//0.1e18
        );//liquidate = amount * 95% * 90%
        uint256 JUSDBorrowed = liquidatedInfo.t0BorrowBalance.decimalMul(tRate);//t0BorrowBalance= deposit * 1e18 /tRate
        /*//t0BorrowBalance= deposit * 1e18 /tRate * newtRate /1e18
        liquidateAmount <= JUSDBorrowed //JUSDBorrowed = deposit* newtRate/oldtRate 
        liquidateAmount = amount * priceOff * (1-insuranceFee)
        actualJUSD = actualCollateral * priceOff
        insuranceFee = actualCollateral * priceOff * insuranceFeeRate
        *///liquidateAmount = 85% * input_collateral_amount
        if (liquidateAmount <= JUSDBorrowed) {//liquidateAmount in JUSD converted. 
            liquidateData.actualCollateral = amount;
            liquidateData.insuranceFee = amount.decimalMul(priceOff).decimalMul(
                reserve.insuranceFeeRate
            );//insuranceFee =amount * 0.95e18/1e18 * 0.1e18 / 1e18 = 0.095 * amount
            liquidateData.actualLiquidatedT0 = liquidateAmount.decimalDiv(
                tRate
            );//actualT0 = amount * 0.855 / tRate 
            liquidateData.actualLiquidated = liquidateAmount;//actualLiquidated = 0.855
        } else {
            //            actualJUSD = actualCollateral * priceOff
            //            = JUSDBorrowed * priceOff / priceOff * (1-insuranceFeeRate)
            //            = JUSDBorrowed / (1-insuranceFeeRate)
            //            insuranceFee = actualJUSD * insuranceFeeRate
            //            = actualCollateral * priceOff * insuranceFeeRate
            //            = JUSDBorrowed * insuranceFeeRate / (1- insuranceFeeRate)
            liquidateData.actualCollateral = JUSDBorrowed//JUSDBorrowed = deposit* new/oldtRate 
                .decimalDiv(priceOff) //@ok JUSDBorrowed == liquidateAmount
                .decimalDiv(JOJOConstant.ONE - reserve.insuranceFeeRate);
            liquidateData.insuranceFee = JUSDBorrowed//insuranceFee = 0.1 *0.9 * amount
                .decimalMul(reserve.insuranceFeeRate)//insuranceFee = 0.09* amount
                .decimalDiv(JOJOConstant.ONE - reserve.insuranceFeeRate);//@audit insuranceFee different between 2 logic if-else
            liquidateData.actualLiquidatedT0 = liquidatedInfo.t0BorrowBalance;//@audit actual0 missing fee 0.855 like above if
            liquidateData.actualLiquidated = JUSDBorrowed;//actualT0 =deposit /tRate
        }//@audit H actualCollateral give user more than suppose. this include interest that user not repay yet.
        
        liquidateData.liquidatedRemainUSDC = (amount -//
            liquidateData.actualCollateral).decimalMul(price);
        
        
    }//liquidatedRemainUSDC = (amount - actualCollateral) * priceUSD

    function _addCollateralIfNotExists(
        DataTypes.UserInfo storage user,
        address collateral
    ) internal {
        if (!user.hasCollateral[collateral]) {
            user.hasCollateral[collateral] = true;
            user.collateralList.push(collateral);
        }
    }

    function _removeEmptyCollateral(
        DataTypes.UserInfo storage user,
        address collateral
    ) internal {
        if (user.depositBalance[collateral] == 0) {
            user.hasCollateral[collateral] = false;
            address[] storage collaterals = user.collateralList;
            for (uint256 i; i < collaterals.length; i = i + 1) {
                if (collaterals[i] == collateral) {
                    collaterals[i] = collaterals[collaterals.length - 1];
                    collaterals.pop();
                    break;
                }
            }
        }
    }

    function _afterLiquidateOperation(
        bytes memory afterOperationParam,//unsafe callback
        uint256 flashloanAmount,//unsafe collateral amount 10e18 WETH
        address collateral,// WBTC, WETH
        address liquidated,// target
        DataTypes.LiquidateData memory liquidateData //safe
    ) internal {
        (address flashloanAddress, bytes memory param) = abi.decode(
            afterOperationParam,
            (address, bytes)
        );
        _withdraw(//@audit-ok liquidate withdraw does not check if account is safe
            flashloanAmount,
            collateral,
            flashloanAddress,
            liquidated,
            false
        );
        param = abi.encode(liquidateData, param);//@audit liquidate param cannot be empty. This force user to use flashloan contract or their own contract
        IFlashLoanReceive(flashloanAddress).JOJOFlashLoan(
            collateral,
            flashloanAmount,
            liquidated,
            param
        );
    }

    /// @notice handle the bad debt
    /// @param liquidatedTrader need to be liquidated
    function _handleBadDebt(address liquidatedTrader) internal {
        DataTypes.UserInfo storage liquidatedTraderInfo = userInfo[
            liquidatedTrader
        ];
        uint256 tRate = getTRate();
        if (//@audit when collateral list length == 0 yet still have t0BorrowBalance.
            liquidatedTraderInfo.collateralList.length == 0 &&
            _isStartLiquidation(liquidatedTraderInfo, tRate)
        ) {
            DataTypes.UserInfo storage insuranceInfo = userInfo[insurance];//@audit insurance account have borrow balance. So user can liquidate insurance account?
            uint256 borrowJUSDT0 = liquidatedTraderInfo.t0BorrowBalance;//insurance have no depositBalance. so it cannot borrow more. But can it be liquidated.
            insuranceInfo.t0BorrowBalance += borrowJUSDT0;
            liquidatedTraderInfo.t0BorrowBalance = 0;
            emit HandleBadDebt(liquidatedTrader, borrowJUSDT0);
        }
    }
}
