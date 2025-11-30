// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../src/USSDRebalancer.sol";
import "../src/USSD.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "lib/v3-periphery/contracts/SwapRouter.sol";
import "lib/v3-periphery/contracts/libraries/PoolAddress.sol";
import "lib/v3-periphery/contracts/interfaces/IQuoterV2.sol";

contract ContractBTest is Test {
    USSD ussd;
    USSDRebalancer rebalancer;

    IERC20Upgradeable usdc =
        IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Upgradeable dai =
        IERC20Upgradeable(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20Upgradeable rUSD =
        IERC20Upgradeable(0xF9A2D7E60a3297E513317AD1d7Ce101CC4C6C8F6);
    SwapRouter router =
        SwapRouter(payable(0xE592427A0AEce92De3Edee1F18E0157C05861564));
    IUniswapV3Factory factory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    uint24 fee0 = 100;
    uint24 fee1 = 500;
    uint24 fee2 = 3000;
    uint24 fee3 = 10000;

    IUniswapV3Pool pool_dai_usdc =
        IUniswapV3Pool(0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168);
    IUniswapV3Pool pool_usdc_rUSD =//rUSD token
        IUniswapV3Pool(0x1d2E8efAE9fAb4731028d4A90f0cCA27e1A57C9F);
    IQuoterV2 quoter = IQuoterV2(0x61fFE014bA17989E743c5F6cB21bF9697530B21e);

    function setUp() public {
        ussd = new USSD();

        ussd.initialize("US Secured Dollar", "USSD");

        rebalancer = new USSDRebalancer();
        rebalancer.initialize(address(usdc));
        rebalancer.grantRole(keccak256("STABLECONTROL"), address(this));
        rebalancer.setPoolAddress(address(pool_dai_usdc));
        rebalancer.setBaseAsset(address(dai));
        // 14.25, 28.35, 61, 112.8 according to whitepaper
        // this.rebalancer.setFlutterRatios([web3.utils.toBN('14250000000000000000'), web3.utils.toBN('28350000000000000000'), web3.utils.toBN('61000000000000000000'), web3.utils.toBN('112800000000000000000')], { from: accounts[0] });
        uint256[] memory ratios = new uint256[](4);
        ratios[0] = 14.25e18;
        ratios[1] = 28.35e18;
        ratios[2] = 61e18;
        ratios[3] = 112.8e18;
        rebalancer.setFlutterRatios(ratios);
    }

    // function test_getOwnValuation() public {
    //     console.log("pool DAI/USDC");
    //     rebalancer.setPoolAddress(address(pool_dai_usdc));
    //     console.log("Valuation price:", rebalancer.getOwnValuation());
    //     test_quote_USDC_DAI();
    //     test_quote_DAI_USDC();

    //     console.log("---------------------");
    //     console.log("pool USDC/rUSD");
    //     rebalancer.setPoolAddress(address(pool_usdc_rUSD));
    //     console.log("Valuation price:", rebalancer.getOwnValuation());
    //     test_quote_USDC_rUSD();
    //     test_quote_rUSD_USDC();

    //     rebalancer.setPoolAddress(address(pool_dai_usdc));
    // }

    // function test_quote_USDC_DAI() internal {
    //     console.log("quote 1e6 USDC -> DAI");
    //     IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2
    //         .QuoteExactInputSingleParams({
    //             tokenIn: address(usdc),
    //             tokenOut: address(dai),
    //             amountIn: 1e6,
    //             fee: fee0,
    //             sqrtPriceLimitX96: 0
    //         });
    //     (
    //         uint256 amountOut,
    //         uint160 sqrtPriceX96After,
    //         uint32 initializedTicksCrossed,
    //         uint256 gasEstimate
    //     ) = quoter.quoteExactInputSingle(params);
    //     console.log("amountOut:", amountOut);
    // }

    // function test_quote_DAI_USDC() internal {
    //     console.log("quote 1e18 DAI -> USDC");
    //     IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2
    //         .QuoteExactInputSingleParams({
    //             tokenIn: address(dai),
    //             tokenOut: address(usdc),
    //             amountIn: 1e18,
    //             fee: fee0,
    //             sqrtPriceLimitX96: 0
    //         });
    //     (
    //         uint256 amountOut,
    //         uint160 sqrtPriceX96After,
    //         uint32 initializedTicksCrossed,
    //         uint256 gasEstimate
    //     ) = quoter.quoteExactInputSingle(params);
    //     console.log("amountOut:", amountOut);
    // }

    // function test_quote_USDC_rUSD() internal {
    //     console.log("quote 1e6 USDC -> rUSD");
    //     IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2
    //         .QuoteExactInputSingleParams({
    //             tokenIn: address(usdc),
    //             tokenOut: address(rUSD),
    //             amountIn: 1e6,
    //             fee: fee3,
    //             sqrtPriceLimitX96: 0
    //         });
    //     (
    //         uint256 amountOut,
    //         uint160 sqrtPriceX96After,
    //         uint32 initializedTicksCrossed,
    //         uint256 gasEstimate
    //     ) = quoter.quoteExactInputSingle(params);
    //     console.log("amountOut:", amountOut);
    // }

    // function test_quote_rUSD_USDC() internal {
    //     console.log("quote 1e18 USDC -> rUSD");
    //     IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2
    //         .QuoteExactInputSingleParams({
    //             tokenIn: address(rUSD),
    //             tokenOut: address(usdc),
    //             amountIn: 1e18,
    //             fee: fee3,
    //             sqrtPriceLimitX96: 0
    //         });
    //     (
    //         uint256 amountOut,
    //         uint160 sqrtPriceX96After,
    //         uint32 initializedTicksCrossed,
    //         uint256 gasEstimate
    //     ) = quoter.quoteExactInputSingle(params);
    //     console.log("amountOut:", amountOut);
    // }
}
