// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@src/Size.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {UserView} from "@src/SizeView.sol";
import {DataView, UserView} from "@src/SizeViewData.sol";
import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary,
    LoanStatus,
    RESERVED_ID
} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {Deposit, DepositParams} from "@src/libraries/actions/Deposit.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {PriceFeed} from "@src/oracle/PriceFeed.sol";
import {NonTransferrableScaledToken} from "@src/token/NonTransferrableScaledToken.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";
import {SizeMock} from "@test/mocks/SizeMock.sol";
import "lib/aave-v3-core/contracts/dependencies/weth/WETH9.sol";
import "lib/aave-v3-core/contracts/protocol/pool/Pool.sol";
import {AToken} from "lib/aave-v3-core/contracts/protocol/tokenization/AToken.sol";

contract DebugForkTest is Test {
    address internal alice = address(0x10000);
    address internal bob = address(0x20000);
    address internal candy = address(0x30000);
    address internal james = address(0x40000);
    address internal liquidator = address(0x50000);
    address internal feeRecipient = address(0x70000);

    SizeMock internal size;
    PriceFeed internal priceFeed;
    WETH9 WETH = WETH9(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    Pool aavePool = Pool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    AToken aUSDC;

    //USDC/ETH price feed. On Sepolia it is ETH / USD return 351315226152
    // address internal _wethAggregator = address(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4);
    //ETH/USD price feed. on mainnet it return 3514.07812383
    address internal _wethAggregator = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    //USDC/USD price feed . return .99990171 on mainnet. .99999156 on Sepolia
    address internal _usdcAggregator = address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);

    InitializeFeeConfigParams internal f;
    InitializeRiskConfigParams internal r;
    InitializeOracleParams internal o;
    InitializeDataParams internal d;

    address implementation;
    ERC1967Proxy proxy;
    uint256 constant RESERVED_ID = type(uint256).max;
    address owner = address(this);

    NonTransferrableToken collateralToken; //@ wrap WETH . Size contract can mint this
    // Size deposit underlying borrow aToken
    NonTransferrableScaledToken borrowAToken; //@warp USDC scaled. @note only Size Contract can move nonTransferrable Token.
    // Size tokenized debt
    NonTransferrableToken debtToken; //@ warp USDC as debt token.same 1e6 decimals

    function setUp() public {
        // uint256 mainnetFork = vm.createFork("https://eth-mainnet.alchemyapi.io/v2/");
        uint256 mainnetFork = vm.createFork("https://rpc.ankr.com/eth");
        vm.selectFork(mainnetFork);
        vm.rollFork(20060000);

        _setupFork();
        _labels();
    }

    function _setupFork() internal {
        //copy from Deploy.setupProduction()
        //stale time to infinity to allow cheats
        priceFeed =
        // new PriceFeed(_wethAggregator, _usdcAggregator, address(0), 3600 * 1.1e18 / 1e18, 86400 * 1.1e18 / 1e18);
         new PriceFeed(_wethAggregator, _usdcAggregator, address(0), type(uint256).max, type(uint256).max);

        f = InitializeFeeConfigParams({
            swapFeeAPR: 0.005e18,
            // swapFeeAPR: 0,
            fragmentationFee: 5e6,
            liquidationRewardPercent: 0.05e18,
            overdueCollateralProtocolPercent: 0.01e18,
            collateralProtocolPercent: 0.1e18,
            feeRecipient: feeRecipient
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            minimumCreditBorrowAToken: 50e6,
            borrowATokenCap: 1_000_000e6,
            minTenor: 1 hours,
            maxTenor: 5 * 365 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), variablePoolBorrowRateStaleRateInterval: 0});
        d = InitializeDataParams({
            weth: address(WETH),
            underlyingCollateralToken: address(WETH),
            underlyingBorrowToken: address(USDC),
            variablePool: address(aavePool) // Aave v3
        });

        implementation = address(new SizeMock());
        proxy = new ERC1967Proxy(implementation, abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        size = SizeMock(payable(proxy));

        aUSDC = AToken(aavePool.getReserveData(address(USDC)).aTokenAddress);

        DataView memory _view = size.data();
        collateralToken = NonTransferrableToken(_view.collateralToken);
        borrowAToken = NonTransferrableScaledToken(_view.borrowAToken);
        debtToken = NonTransferrableToken(_view.debtToken);

        // console.log("Size address: %s", address(size));
    }

    function _labels() internal {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(candy, "candy");
        vm.label(james, "james");
        vm.label(liquidator, "liquidator");
        vm.label(feeRecipient, "feeRecipient");

        vm.label(address(proxy), "size-proxy");
        vm.label(address(implementation), "size-implementation");
        vm.label(address(size), "size");
        vm.label(address(priceFeed), "priceFeed");
        vm.label(address(USDC), "usdc");
        vm.label(address(WETH), "weth");
        vm.label(address(aavePool), "variablePool");
        vm.label(_wethAggregator, "wethAggregator");
        vm.label(_usdcAggregator, "usdcAggregator");
        vm.label(address(aUSDC), "aUSDC");

        vm.label(address(0), "address(0)");
    }

    // function testCompensate() public {
    //     _getFund(alice);
    //     vm.startPrank(alice);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     size.deposit{value: 3 ether}(DepositParams({token: address(WETH), amount: 3 ether, to: alice}));
    //     size.deposit(DepositParams({token: address(USDC), amount: 10000e6, to: alice}));
    //     // make borrower offer 10%
    //     uint256[] memory tenors = new uint256[](1);
    //     int256[] memory aprs = new int256[](1);
    //     uint256[] memory marketRateMultipliers = new uint256[](1);
    //     tenors[0] = 365 days;
    //     aprs[0] = 0.1e18; //10% year
    //     size.sellCreditLimit(
    //         SellCreditLimitParams({
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );
    //     // lend 1000$ to alice
        
    //     size.buyCreditMarket(
    //         BuyCreditMarketParams({
    //             borrower: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 365 days,
    //             amount: 1000e6,
    //             deadline: block.timestamp,
    //             minAPR: 0,
    //             exactAmountIn: true
    //         })
    //     );
    //     printBalance(alice);
    //     // alice now owned 1000$ to her self.
    //     //now make 0% lending offer, with 2 years
    //     aprs[0] = 0e18; //0% year
    //     tenors[0] = 100 days;
    //     size.buyCreditLimit(
    //         BuyCreditLimitParams({
    //             maxDueDate: type(uint256).max,
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );
    //     // borrow 3000$ from herself with 2 years tenor
    //     size.sellCreditMarket(
    //         SellCreditMarketParams({
    //             lender: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 100 days,
    //             amount: 3000e6,
    //             deadline: block.timestamp,
    //             maxAPR: 0,
    //             exactAmountIn: true
    //         })
    //     );

    //     printBalance(alice);
    //     console.log("credit: %e", size.getCreditPosition(CREDIT_POSITION_ID_START).credit);
    //     console.log("credit: %e", size.getCreditPosition(CREDIT_POSITION_ID_START + 1).credit);
    //     //now we can compensate first credit loan with 2nd credit loan that is much longer
    //     size.compensate(
    //         CompensateParams({
    //             creditPositionWithDebtToRepayId: CREDIT_POSITION_ID_START,
    //             creditPositionToCompensateId: CREDIT_POSITION_ID_START + 1,
    //             amount: 1100e6
    //         })
    //     );

    //     printBalance(alice);
    //     console.log("credit: %e", size.getCreditPosition(CREDIT_POSITION_ID_START).credit);
    //     console.log("credit: %e", size.getCreditPosition(CREDIT_POSITION_ID_START + 1).credit);
    //     console.log("credit: %e", size.getCreditPosition(CREDIT_POSITION_ID_START + 2).credit);
    // }

    function _setupForCreditTest(address user) internal {

        // //set swapfee to 10% 
        // size.updateConfig(UpdateConfigParams({key:"swapFeeAPR",value: 0.1e18}));

        _getFund(user);
        vm.startPrank(user);
        USDC.approve(address(size), type(uint256).max);
        WETH.approve(address(size), type(uint256).max);
        size.deposit{value: 3 ether}(DepositParams({token: address(WETH), amount: 3 ether, to: user}));
        size.deposit(DepositParams({token: address(USDC), amount: 10000e6, to: user}));

        uint256[] memory tenors = new uint256[](1);
        int256[] memory aprs = new int256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);
        tenors[0] = 365 days;
        aprs[0] = 0.1e18; // 10% year

        size.sellCreditLimit(
            SellCreditLimitParams({
                curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
            })
        );

        size.buyCreditLimit(
            BuyCreditLimitParams({
                maxDueDate: type(uint256).max,
                curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
            })
        );

        vm.stopPrank();
    }

    function testSellCreditMarket_ExactAmountIn() public {
        _setupForCreditTest(alice);
        vm.startPrank(alice);

        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                tenor: 365 days,
                amount: 1100e6,
                deadline: block.timestamp,
                maxAPR: 1e18,
                exactAmountIn: true
            })
        );
        console.log("---borrower Sell $1100 credit, exactAmountIn==true");
        printBalance(alice);
        console.log("fee: %e", borrowAToken.balanceOf(feeRecipient));
        console.log("lender credit: %e", size.getCreditPosition(size.data().nextCreditPositionId - 1).credit);
        vm.stopPrank();
        // debt 1100$
        // fee 5$
        // receive: 1100$ - 5$ = 1095$
        // credit: 1100$
    }

    function testSellCreditMarket_NonExactAmountIn() public {
        _setupForCreditTest(alice);
        vm.startPrank(alice);

        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                tenor: 365 days,
                amount: 1000e6,
                deadline: block.timestamp,
                maxAPR: 1e18,
                exactAmountIn: false
            })
        );
        console.log("---borrower sell $1000 cash, exactAmountIn==false");
        printBalance(alice);
        console.log("fee: %e", borrowAToken.balanceOf(feeRecipient));
        console.log("lender credit: %e", size.getCreditPosition(size.data().nextCreditPositionId - 1).credit);
        vm.stopPrank();
        // with 10% fee, 10% APR loan
        // debt 1222.22$?
        // fee 99.99$ 
        // receive: 1000$ - 99.99$ = 900$
        //credit: 1222.22$?
    }

    function testBuyCreditMarket_ExactAmountIn() public {
        _setupForCreditTest(alice);
        vm.startPrank(alice);

        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                tenor: 365 days,
                amount: 1000e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true
            })
        );
        console.log("---lender buy $1000 cash, exactAmountIn==true");
        printBalance(alice);
        console.log("fee: %e", borrowAToken.balanceOf(feeRecipient));
        console.log("lender credit: %e", size.getCreditPosition(size.data().nextCreditPositionId - 1).credit);
        vm.stopPrank();
        //debt 1100$
        //fee5$
        //receive:1000$ - 5$ = 995$
        //credit: 1100$
    }

    function testBuyCreditMarket_NonExactAmountIn() public {
        _setupForCreditTest(alice);
        vm.startPrank(alice);

        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                tenor: 365 days,
                amount: 1100e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
        console.log("---lender buy $1100 credit, exactAmountIn==false");
        printBalance(alice);
        console.log("fee: %e USDC", borrowAToken.balanceOf(feeRecipient));
        console.log("lender credit: %e USDC", size.getCreditPosition(size.data().nextCreditPositionId - 1).credit);
        vm.stopPrank();
        //debt 1100$
        //fee 5$
        //receive: 1100$ - 5$ = 1095$
        //credit: 1100$
    }

    //*****  ARCHIVE   ******/

    // function _testLiquidationReplacement() public {
    //     _getFund(alice); // alice borrower
    //     _getFund(candy); //liquidator
    //     _getFund(bob); //lender
    //     size.grantRole(KEEPER_ROLE, candy);
    //     // alice borrower got lots of collateral. but only want to borrow 5000$
    //     vm.startPrank(alice);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     size.deposit{value: 3 ether}(DepositParams({token: address(WETH), amount: 3 ether, to: alice}));
    //     int256[] memory aprs = new int256[](2);
    //     uint256[] memory tenors = new uint256[](2);
    //     uint256[] memory marketRateMultipliers = new uint256[](2);
    //     tenors[0] = 1 days;
    //     tenors[1] = 365 days;
    //     aprs[0] = 0.1e18; //10% year
    //     aprs[1] = 0.1e18; //10% year
    //     //offer borrow
    //     size.sellCreditLimit(
    //         SellCreditLimitParams({
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );

    //     //bob lender provide 5000$ loan to alice
    //     vm.startPrank(bob);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     uint256 loanAmount = 5000e6;
    //     size.deposit(DepositParams({token: address(USDC), amount: loanAmount, to: bob}));
    //     size.buyCreditMarket(
    //         BuyCreditMarketParams({
    //             borrower: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 365 days,
    //             amount: loanAmount,
    //             deadline: block.timestamp,
    //             minAPR: 0,
    //             exactAmountIn: true
    //         })
    //     );
    //     //alice withdraw all USDC
    //     vm.startPrank(alice);
    //     size.withdraw(WithdrawParams({token: address(USDC), amount: type(uint256).max, to: alice}));

    //     //candy liquidator got 5500$ to repay full debt to alice
    //     //want to replace alice loan with candy borrow offer which have much lower APR.
    //     vm.startPrank(candy);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     //deposit USDC for liquidator repay debt
    //     size.deposit(DepositParams({token: address(USDC), amount: 5500e6, to: candy}));
    //     //deposit ETH as collateral
    //     size.deposit{value: 3 ether}(DepositParams({token: address(WETH), amount: 3 ether, to: candy}));
    //     //make same borrow offer with 0% APR
    //     aprs[0] = 0e18; //0% year
    //     aprs[1] = 0e18; //0% year
    //     size.sellCreditLimit(
    //         SellCreditLimitParams({
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );

    //     // drop ETH price 40%
    //     mockPriceFeed(_wethAggregator, -4000); // new price: 2203.33

    //     printBalance(alice);
    //     printBalance(bob);
    //     printBalance(candy);

    //     //collateral now ready to be liquidated and replace with new borrow
    //     size.liquidateWithReplacement(
    //         LiquidateWithReplacementParams({
    //             debtPositionId: size.data().nextDebtPositionId - 1,
    //             borrower: candy,
    //             minimumCollateralProfit: 0,
    //             deadline: block.timestamp,
    //             minAPR: 0
    //         })
    //     );
    //     //candy receive some ETH collateral, all USDC transfered to Size
    //     // some collateral taken as fee

    //     // //@recipient taking all fees out of system
    //     // vm.startPrank(feeRecipient);
    //     // size.withdraw(WithdrawParams({token: address(USDC), amount: type(uint256).max, to: feeRecipient}));
    //     // size.withdraw(WithdrawParams({token: address(WETH), amount: type(uint256).max, to: feeRecipient}));

    //     console.log("---- Liquidated");
    //     printBalance(alice); // 6758$ and 0.58 ETH ~= 1810.43$. total asset: 8568$ . drop from original 3ETH ~=9363$
    //     printBalance(bob); // got 20557$
    //     printBalance(candy); // candy got 2.35 ETH ~= 7344.5$, 12655$ . Total Asset = 19999$
    //     printBalance(feeRecipient);
    // }

    //     function testLiquidation() public {
    //     _getFund(alice); // alice borrower
    //     _getFund(candy); //liquidator
    //     _getFund(bob); //lender
    //     vm.startPrank(alice);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     size.deposit{value: 3 ether}(DepositParams({token: address(WETH), amount: 3 ether, to: alice}));
    //     int256[] memory aprs = new int256[](1);
    //     uint256[] memory tenors = new uint256[](1);
    //     uint256[] memory marketRateMultipliers = new uint256[](1);
    //     tenors[0] = 300 days;
    //     aprs[0] = 0.1e18; //10% year
    //     size.sellCreditLimit(
    //         SellCreditLimitParams({
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );
    //     vm.startPrank(bob);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     //deposit 20000 USDC for lending
    //     size.deposit(DepositParams({token: address(USDC), amount: 20000e6, to: bob}));
    //     //provide a maximum loan offer to alice
    //     uint256 maxDebt = _howMuchUSDCDebtCanUserTake(alice);
    //     size.buyCreditMarket(
    //         BuyCreditMarketParams({
    //             borrower: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 300 days,
    //             amount: maxDebt,
    //             deadline: block.timestamp,
    //             minAPR: 0,
    //             exactAmountIn: false
    //         })
    //     );

    //     vm.startPrank(candy);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     //deposit USDC for liquidator repay debt
    //     size.deposit(DepositParams({token: address(USDC), amount: 20000e6, to: candy}));

    //     // drop ETH price 15%
    //     mockPriceFeed(_wethAggregator, -1500);// new price: 3121.435

    //     printBalance(alice);
    //     printBalance(bob);
    //     printBalance(candy);

    //     //collateral now ready to be liquidated
    //     size.liquidate(
    //         LiquidateParams({debtPositionId: size.data().nextDebtPositionId - 1, minimumCollateralProfit: 0})
    //     );
    //     vm.startPrank(bob);
    //     size.claim(ClaimParams({creditPositionId: size.data().nextCreditPositionId - 1}));

    //     console.log("---- Liquidated");
    //     printBalance(alice);// 6758$ and 0.58 ETH ~= 1810.43$. total asset: 8568$ . drop from original 3ETH ~=9363$
    //     printBalance(bob);// got 20557$
    //     printBalance(candy);// candy got 2.35 ETH ~= 7344.5$, 12655$ . Total Asset = 19999$
    //     printBalance(feeRecipient);
    // }
    // function _testStoleBorrowerLoan() public {
    //     vm.startPrank(alice);
    //     WETH.approve(address(size), type(uint256).max);
    //     //deposit 3 ETH as collateral ~= 11016$ as borrower
    //     //ETH price 3672$
    //     deal(alice, 3 ether);
    //     size.deposit{value: 3 ether}(DepositParams({token: address(WETH), amount: 3 ether, to: alice}));
    //     //create borrower offer with 10% apr a year
    //     int256[] memory aprs = new int256[](1);
    //     uint256[] memory tenors = new uint256[](1);
    //     uint256[] memory marketRateMultipliers = new uint256[](1);
    //     tenors[0] = 365 days;
    //     aprs[0] = 0.1e18; //10% year

    //     // make borrow offer of 10% year
    //     size.sellCreditLimit(
    //         SellCreditLimitParams({
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );
    //     //create lending offer with 5% apr a year
    //     aprs[0] = 0.05e18; //5% year
    //     size.buyCreditLimit(
    //         BuyCreditLimitParams({
    //             maxDueDate: type(uint256).max,
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );
    //     vm.stopPrank();

    //     // fund bob with 10000 USDC
    //     vm.prank(0x28C6c06298d514Db089934071355E5743bf21d60);
    //     USDC.transfer(bob, 100_000e6);
    //     deal(bob, 5e18);
    //     //bob give loan and borrow that money back from alice
    //     vm.startPrank(bob);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     size.deposit{value: 3 ether}(DepositParams({token: address(WETH), amount: 3 ether, to: bob}));
    //     size.deposit(DepositParams({token: address(USDC), amount: 10000e6, to: bob}));
    //     //give 5000$ credit to alice
    //     size.buyCreditMarket(
    //         BuyCreditMarketParams({
    //             borrower: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 365 days,
    //             amount: 5000e6,
    //             deadline: block.timestamp,
    //             minAPR: 0,
    //             exactAmountIn: true
    //         })
    //     );
    //     console.log("--- Sell 5500$ credit to Alice");
    //     printBalance(alice);
    //     //take back 5000$ credit from alice
    //     size.sellCreditMarket(
    //         SellCreditMarketParams({
    //             lender: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 365 days,
    //             amount: 5220e6, // replace with lower maturity 5250$ subtract ~0.05% fee yearly.
    //             deadline: block.timestamp,
    //             maxAPR: 1e18,
    //             exactAmountIn: true
    //         })
    //     );
    //     console.log("--- Buy 5200$ credit back from Alice at much lower APR");
    //     printBalance(alice);
    //     printBalance(bob);
    //     //Result:
    //     //alice got 5500$ debt. 3 ETH collateral. and no cash from borrowing.
    //     //bob own 5220$ debt to alice. Credit mature same time as original alice debt.
    // }
    // function _testNewLoan2() public {
    //     _getFund(alice);
    //     vm.startPrank(alice);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     //deposit 10000$ USDC as lender
    //     //deposit 3 ETH as collateral ~= 11016$ as borrower
    //     //ETH price 3672$
    //     size.deposit(DepositParams({token: address(USDC), amount: 11111.234567e6, to: alice}));
    //     size.deposit{value: 3 ether}(DepositParams({token: address(WETH), amount: 3 ether, to: alice}));
    //     //Test buy/sell credit as lender and borrower. to see if fee transfer correctly.
    //     int256[] memory aprs = new int256[](2);
    //     uint256[] memory tenors = new uint256[](2);
    //     uint256[] memory marketRateMultipliers = new uint256[](2);
    //     tenors[0] = 1 hours;
    //     tenors[1] = 365 days * 2;
    //     aprs[0] = 0.1e18; //10% year
    //     aprs[1] = 0.15e18; //15% year

    //     //create borrower offer with 10% apr a year

    //     size.sellCreditLimit(
    //         SellCreditLimitParams({
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );
    //     //create lending offer with 15% apr a year
    //     aprs[0] = 0.15e18; //15% year
    //     size.buyCreditLimit(
    //         BuyCreditLimitParams({
    //             maxDueDate: type(uint256).max,
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );
    //     // borrow 1000 USDC
    //     size.sellCreditMarket(
    //         SellCreditMarketParams({
    //             lender: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 1 hours,
    //             amount: 1_000e6,
    //             deadline: block.timestamp,
    //             maxAPR: 1e18,
    //             exactAmountIn: true
    //         })
    //     );
    //     size.sellCreditMarket(
    //         SellCreditMarketParams({
    //             lender: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 3 days,
    //             amount: 2_000e6,
    //             deadline: block.timestamp,
    //             maxAPR: 1e18,
    //             exactAmountIn: true
    //         })
    //     );
    //     size.sellCreditMarket(
    //         SellCreditMarketParams({
    //             lender: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 365 days,
    //             amount: 3_000e6,
    //             deadline: block.timestamp,
    //             maxAPR: 1e18,
    //             exactAmountIn: true
    //         })
    //     );

    //     printLoanStatus();
    //     console.log("---skip 2 hours");
    //     skip(2 hours);
    //     printLoanStatus();
    //     console.log("---skip 1 days and repaid 3rd loan");
    //     size.repay(RepayParams({debtPositionId: size.data().nextDebtPositionId - 1}));
    //     printLoanStatus();
    // }

    // function printLoanStatus() internal {
    //     (uint256 debtCount, uint256 creditCount) = size.getPositionsCount();
    //     console.log("-debt-");
    //     for (uint256 i = DEBT_POSITION_ID_START; i < debtCount; i++) {
    //         LoanStatus status = size.getLoanStatus(i);
    //         if (status == LoanStatus.REPAID) console.log("Debt %s status repaid", i);
    //         else if (status == LoanStatus.OVERDUE) console.log("Debt %s status overdue", i);
    //         else console.log("Debt %s status Active", i);
    //     }
    //     console.log("-credit-");
    //     for (uint256 i = CREDIT_POSITION_ID_START; i < CREDIT_POSITION_ID_START + creditCount; i++) {
    //         LoanStatus status = size.getLoanStatus(i);
    //         if (status == LoanStatus.REPAID) console.log("Credit %s status repaid", i);
    //         else if (status == LoanStatus.OVERDUE) console.log("Credit %s status overdue", i);
    //         else console.log("Credit %s status Active", i);
    //     }
    // }

    // function _testWeirdError() public {
    //     vm.prank(0x28C6c06298d514Db089934071355E5743bf21d60);
    //     USDC.transfer(alice, 2_000_000e6);
    //     deal(alice, 100e18);
    //     vm.startPrank(alice);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     console.log("max aBorrowToken: %e", size.riskConfig().borrowATokenCap);
    //     bytes[] memory _data = new bytes[](5);
    //     //deposit collateral
    //     _data[0] = abi.encodeWithSelector(
    //         Size.deposit.selector, DepositParams({token: address(WETH), amount: 100e18, to: alice})
    //     );
    //     //deposit 1M USDC
    //     _data[1] = abi.encodeWithSelector(
    //         Size.withdraw.selector, WithdrawParams({token: address(WETH), amount: 1_000_000e18, to: alice})
    //     );
    //     //make borrow offer 0% apr
    //     int256[] memory aprs = new int256[](1);
    //     uint256[] memory tenors = new uint256[](1);
    //     uint256[] memory marketRateMultipliers = new uint256[](1);
    //     tenors[0] = 1 hours; //minimum time for minimum fee
    //     _data[2] = abi.encodeWithSelector(
    //         Size.sellCreditLimit.selector,
    //         SellCreditLimitParams({
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );
    //     //buy loan offer
    //     _data[3] = abi.encodeWithSelector(
    //         Size.buyCreditMarket.selector,
    //         BuyCreditMarketParams({
    //             borrower: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 1 hours,
    //             amount: 1_000_000e6,
    //             deadline: block.timestamp,
    //             minAPR: 0,
    //             exactAmountIn: true
    //         })
    //     );
    //     size.multicall{value: 100e18}(_data);
    //     printBalance(alice);
    //     // Maximum borrowATokenCap is 1M USDC already reached.
    //     // So now deposit another 1M and repay. now total deposit USDC is 2M. over 1M limit
    // }

    // function _testBypassMax1MillionCap() public {
    //     vm.prank(0x28C6c06298d514Db089934071355E5743bf21d60);
    //     USDC.transfer(alice, 20_000_000e6);
    //     deal(alice, 10000e18);
    //     vm.startPrank(alice);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     console.log("max aBorrowToken: %e", size.riskConfig().borrowATokenCap);

    //     //deposit collateral
    //     size.deposit{value: 10000e18}(DepositParams({token: address(WETH), amount: 10000e18, to: alice}));
    //     //deposit 1M USDC
    //     size.deposit(DepositParams({token: address(USDC), amount: 1_000_000e6, to: alice}));

    //     // repeat exploit actions 4 times to reach 16M USDC deposit. 16x times over 1M limit
    //     for (uint256 i = 0; i < 4; i++) {
    //         uint256 buyCreditAmount = size.getUserView(alice).borrowATokenBalance;
    //         //make borrow offer 0% apr
    //         int256[] memory aprs = new int256[](1);
    //         uint256[] memory tenors = new uint256[](1);
    //         uint256[] memory marketRateMultipliers = new uint256[](1);
    //         tenors[0] = 1 hours; //minimum time for minimum fee
    //         size.sellCreditLimit(
    //             SellCreditLimitParams({
    //                 curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //             })
    //         );
    //         //buy loan offer with all
    //         size.buyCreditMarket(
    //             BuyCreditMarketParams({
    //                 borrower: alice,
    //                 creditPositionId: RESERVED_ID,
    //                 tenor: 1 hours,
    //                 amount: buyCreditAmount,
    //                 deadline: block.timestamp,
    //                 minAPR: 0,
    //                 exactAmountIn: true
    //             })
    //         );

    //         // Maximum borrowATokenCap is 1M USDC already reached.
    //         // So now deposit another 1M and repay. now total deposit USDC is 2M. over 1M limit
    //         bytes[] memory _data = new bytes[](3);
    //         //deposit another 1M USDC
    //         _data[0] = abi.encodeWithSelector(
    //             Size.deposit.selector, DepositParams({token: address(USDC), amount: buyCreditAmount, to: alice})
    //         );
    //         //repay debt 1M
    //         _data[1] = abi.encodeWithSelector(
    //             Size.repay.selector, RepayParams({debtPositionId: size.data().nextDebtPositionId - 1})
    //         );
    //         //claim debt
    //         _data[2] = abi.encodeWithSelector(
    //             Size.claim.selector, ClaimParams({creditPositionId: size.data().nextCreditPositionId - 1})
    //         );
    //         size.multicall(_data);
    //     }

    //     printBalance(alice);
    //     console.log("total aBorrowToken: %e USDC", borrowAToken.totalSupply());
    //     console.log("overlimit amount: %e USDC", borrowAToken.totalSupply() - size.riskConfig().borrowATokenCap);
    //     //   total aBorrowToken: 1.5999990296787e13 USDC
    //     //   overlimit amount: 1.4999990296787e13 USDC
    // }

    // function _testNewLoan1() public {
    //     _getFund(alice);
    //     vm.startPrank(alice);
    //     USDC.approve(address(size), type(uint256).max);
    //     WETH.approve(address(size), type(uint256).max);
    //     //deposit 10000$ USDC as lender
    //     size.deposit(DepositParams({token: address(USDC), amount: 11111.234567e6, to: alice}));
    //     //deposit 3 ETH as collateral
    //     size.deposit{value: 3 ether}(DepositParams({token: address(WETH), amount: 3 ether, to: alice}));
    //     //balance of Alice
    //     //   collateralToken: 3e18
    //     //   borrowAToken: 1.1111234567e10
    //     // no debt
    //     //ETH price 3672$

    //     //can make borrowOffer loan to self
    //     int256[] memory aprs = new int256[](1);
    //     uint256[] memory tenors = new uint256[](1);
    //     uint256[] memory marketRateMultipliers = new uint256[](1);
    //     tenors[0] = 300 days;
    //     aprs[0] = 0.1e18; //10% year
    //     //provide borrower offer with 10% apr a year
    //     size.sellCreditLimit(
    //         SellCreditLimitParams({
    //             curveRelativeTime: YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers})
    //         })
    //     );
    //     printBalance(alice);
    //     console.log("--Create new loan--");
    //     uint256 maxDebt = _howMuchUSDCDebtCanUserTake(alice);
    //     console.log("Alice can borrow: %e USDC", maxDebt);
    //     //now try to borrow max 150% of collateral.It default try to borrow max credit limit
    //     size.buyCreditMarket(
    //         BuyCreditMarketParams({
    //             borrower: alice,
    //             creditPositionId: RESERVED_ID,
    //             tenor: 300 days,
    //             amount: maxDebt,
    //             deadline: block.timestamp,
    //             minAPR: 0,
    //             exactAmountIn: false
    //         })
    //     );
    //     console.log("debtPositionId: %s", size.data().nextDebtPositionId);
    //     console.log("creditPositionId: %s", size.data().nextCreditPositionId);
    //     printBalance(alice);
    //     console.log("--repay loan--");
    //     console.log("total Fee to Size: %e", borrowAToken.balanceOf(feeRecipient));
    //     console.log("Size aUSDC balance: %e", aUSDC.balanceOf(address(size)));
    //     console.log("Size aUSDC ScaledBalance: %e", aUSDC.scaledBalanceOf(address(size)));
    //     // now we test repay and claim new loan.
    //     uint256 timeSkip = 298 days;
    //     skip(timeSkip);
    //     console.log("-time skip %s", timeSkip);
    //     console.log("aave liquidity index: %e", aavePool.getReserveNormalizedIncome(address(USDC)));
    //     console.log("Size aUSDC balance: %e", aUSDC.balanceOf(address(size)));
    //     console.log("Size aUSDC ScaledBalance: %e", aUSDC.scaledBalanceOf(address(size)));
    //     //check how many debt that borrower need to repaid.
    //     // uint256 debt = size.getUserView(alice).debtBalance;
    //     uint256 debtFutureValue = size.getDebtPosition(size.data().nextDebtPositionId - 1).futureValue;
    //     // console.log("borrower have debt: %e", debt);
    //     console.log("borrower need to repay: %e USDC", debtFutureValue);
    //     size.repay(RepayParams({debtPositionId: size.data().nextDebtPositionId - 1}));

    //     printBalance(address(size));
    //     printBalance(alice);

    //     console.log("--claim borrower payment--");
    //     console.log("pending scaled borrowAToken from Size: %e", borrowAToken.scaledBalanceOf(address(size)));
    //     //after regardless of time. alice must receive same amount of USDC
    //     skip(365 days * 10);
    //     size.claim(ClaimParams({creditPositionId: size.data().nextCreditPositionId - 1}));

    //     printBalance(address(size));
    //     printBalance(alice);
    //     console.log("Size aUSDC balance: %e", aUSDC.balanceOf(address(size)));
    //     console.log("Size aUSDC ScaledBalance: %e", aUSDC.scaledBalanceOf(address(size)));
    // }

    // function _testDebugWithdraw() public {
    //     _getFund(alice);
    //     vm.startPrank(alice);
    //     //try deposit some collateral. This do nothing special
    //     // try deposit some USDC. scaled balance will be affected by aave pool.
    //     // skip some time and block will also update aave balance but borrowAToken was not affected.
    //     USDC.approve(address(size), type(uint256).max);

    //     //deposit ETH as collateral
    //     uint256 depositETHAmount = (5.38 ether / uint256(3)); //~1.7933
    //     size.deposit{value: depositETHAmount}(
    //         DepositParams({token: address(WETH), amount: depositETHAmount, to: alice})
    //     );

    //     //deposit USDC
    //     console.log("aave liquidity index: %e", aavePool.getReserveNormalizedIncome(address(USDC)));
    //     size.deposit(DepositParams({token: address(USDC), amount: 1000e6, to: alice}));
    //     printBalance(alice);
    //     //skip 4 days
    //     skip(4 days);
    //     //deposit again
    //     console.log("aave liquidity index: %e", aavePool.getReserveNormalizedIncome(address(USDC)));
    //     size.deposit(DepositParams({token: address(USDC), amount: 1000e6, to: bob}));
    //     size.deposit(DepositParams({token: address(USDC), amount: 1000e6, to: candy}));
    //     skip(4 days);
    //     // printBalance(bob);
    //     // printBalance(candy);
    //     // printBalance(alice);

    //     skip(365 days * 10);
    //     // we need to check aToken of size same as borrowAToken of user
    //     UserView memory aliceView = size.getUserView(alice);
    //     UserView memory bobView = size.getUserView(bob);
    //     UserView memory candyView = size.getUserView(candy);
    //     uint256 totalATokenBalance =
    //         aliceView.borrowATokenBalance + bobView.borrowATokenBalance + candyView.borrowATokenBalance;
    //     console.log("total aToken: %e", totalATokenBalance);
    //     //compare this to aave scaled balance and real balance
    //     uint256 scaledaUSDC = aUSDC.scaledBalanceOf(address(size));
    //     uint256 aUSDCBalance = aUSDC.balanceOf(address(size));
    //     console.log("aUSDC scaled balance: %e", scaledaUSDC);
    //     console.log("aUSDC balance: %e", aUSDCBalance);

    //     // now the question is when we withdraw what does it use.
    //     // it use USDC, current value included accrued rewards
    //     size.withdraw(WithdrawParams({token: address(USDC), amount: 1000000e6, to: alice}));
    //     printBalance(alice);
    //     vm.stopPrank();

    //     vm.prank(bob);
    //     size.withdraw(WithdrawParams({token: address(USDC), amount: 1000000e6, to: bob}));
    //     printBalance(bob);

    //     vm.prank(candy);
    //     size.withdraw(WithdrawParams({token: address(USDC), amount: 1000000e6, to: candy}));
    //     printBalance(candy);

    //     scaledaUSDC = aUSDC.scaledBalanceOf(address(size));
    //     aUSDCBalance = aUSDC.balanceOf(address(size));
    //     console.log("aUSDC scaled balance: %e", scaledaUSDC);
    //     console.log("aUSDC balance: %e", aUSDCBalance);
    // }

    // function _testMulticallBypass() public {
    //     _getFund(alice);
    //     vm.startPrank(alice);
    //     USDC.approve(address(size), type(uint256).max);
    //     bytes[] memory _data = new bytes[](3);
    //     //first multicall into itself doing nothing
    //     _data[0] = abi.encodeWithSelector(Size.multicall.selector, new bytes[](0));
    //     //second just deposit normally
    //     _data[1] = abi.encodeWithSelector(
    //         Size.deposit.selector, DepositParams({token: address(WETH), amount: 1e18, to: alice})
    //     );
    //     //withdraw 500 USDC
    //     _data[2] = abi.encodeWithSelector(
    //         Size.withdraw.selector, WithdrawParams({token: address(WETH), amount: 0.5e18, to: alice})
    //     );

    //     size.multicall{value: 1e18}(_data);

    //     printBalance(alice);
    // }

    // function _testMathBinarySearch() public {
    //     uint256[] memory array = new uint256[](10);
    //     for (uint256 i = 0; i < 10; i++) {
    //         array[i] = i * 100; // 0,100,200,300,400
    //     }
    //     uint256 value = 499;
    //     (uint256 low, uint256 high) = Math.binarySearch(array, value);
    //     console.log("low: %s, high: %s, value: %s", low, high, value);
    // }

    // function _testAcceptRandomTransfer() public {
    //     vm.startPrank(alice);
    //     (bool ss,) = payable(address(size)).call{value: 1e18}("");
    //     console.log("random transfer success?: %s", ss);
    //     printBalance(alice);
    //     printBalance(address(size));
    // }
    function mockPriceFeed(address feed, int256 bps_change) public {
        vm.clearMockedCalls();
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(feed).latestRoundData();
        int256 newPrice = answer + answer * bps_change / 10000;
        bytes memory newPriceCallback = abi.encode(roundId, newPrice, startedAt, updatedAt, answeredInRound);

        console.log("Mock %s price from %e to %e", feed, uint256(answer), uint256(newPrice));
        // mock call pricefeed call to change price
        vm.mockCall(feed, abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), newPriceCallback);
    }

    // function printBalance(address account) public {
    //     console.log("-Account %s Balance", account);
    //     console.log("USDC balance: %e", USDC.balanceOf(account));
    //     console.log("ETH balance: %e", account.balance);
    //     console.log("WETH balance: %e", WETH.balanceOf(account));
    //     //Size User View
    //     UserView memory user = size.getUserView(account);
    //     console.log("collateralToken: %e", user.collateralTokenBalance);
    //     console.log("borrowAToken_unscaled_USDC: %e", user.borrowATokenBalance);
    //     console.log("borrowAToken_scaled: %e", borrowAToken.scaledBalanceOf(account));
    //     console.log("debtToken: %e", user.debtBalance);
    //     console.log("collateralRatio: %e", size.collateralRatio(account));
    //     console.log("-");
    // }
    function printBalance(address account) public {
        console.log("-Account %s Balance", account);
        //Size User View
        UserView memory user = size.getUserView(account);
        console.log("collateralToken balance: %e WETH", user.collateralTokenBalance);
        console.log("borrowAToken balance: %e USDC", user.borrowATokenBalance);
        console.log("debtToken balance: %e USDC", user.debtBalance);
        // console.log("collateralRatio: %e", size.collateralRatio(account));
        console.log("-");
    }

    // function _getFund(address account) internal {
    //     console.log("Debug Test");
    //     //get some WETH, USDC
    //     // USDC deal does not work. so get it from binance
    //     vm.prank(0x28C6c06298d514Db089934071355E5743bf21d60);
    //     USDC.transfer(account, 100_000e6);
    //     console.log("start USDC: %e", USDC.balanceOf(account));
    //     deal(account, 5e18);
    //     console.log("start ETH: %e", account.balance);
    //     deal(address(WETH), account, 8e18);
    //     console.log("start WETH: %e", WETH.balanceOf(account));
    //     console.log("start aave liquidityIndex: %e", aavePool.getReserveNormalizedIncome(address(USDC)));
    //     console.log("--Funding %s--", account);
    // }

    function _getFund(address account) internal {
        //get some WETH, USDC
        // USDC deal does not work. so get it from binance
        vm.prank(0x28C6c06298d514Db089934071355E5743bf21d60);
        USDC.transfer(account, 100_000e6);
        deal(account, 5e18);
        deal(address(WETH), account, 8e18);
    }

    function _howMuchUSDCDebtCanUserTake(address account) internal returns (uint256) {
        UserView memory user = size.getUserView(account);
        uint256 collateral = user.collateralTokenBalance; //wrap WETH .total deposit balance
        uint256 debt = user.debtBalance; //@ debtWad = debt * 1e6 = USDC debt * 1e6 .//@debt token just minted after buyCreditMarket. Lender provide fund to borrower
        uint256 debtWad = Math.amountToWad(debt, 6); //convert USDC debt to 1e18.
        uint256 price = IPriceFeed(size.oracle().priceFeed).getPrice(); //WETH/USDC 1e18 or 3540e18
        console.log("oracle price: %e", price);
        //(collateral USDC value - debt USDC value) / 150%
        uint256 maxDebt_e18 = ((collateral * price - debtWad) / 1.5e18);
        return maxDebt_e18 / 1e12; // To USDC
    }
}
