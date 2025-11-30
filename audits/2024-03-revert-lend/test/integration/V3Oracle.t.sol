// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// base contracts
import "../../src/V3Oracle.sol";
import "v3-core/interfaces/pool/IUniswapV3PoolDerivedState.sol";

import "../../src/interfaces/IErrors.sol";

contract TestChainLinkOracle {
    int256 USDC_PRICE = 0.9999e8;

    function setUSDCPrice(uint256 price) external {
        USDC_PRICE = int256(price);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (10000, USDC_PRICE, block.timestamp, block.timestamp, 10000);
    }

    function decimals() external view returns (uint8) {
        return 8;
    }
}

contract V3OracleIntegrationTest is Test {
    uint256 constant Q32 = 2 ** 32;
    uint256 constant Q96 = 2 ** 96;

    address constant WHALE_ACCOUNT = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

    INonfungiblePositionManager constant NPM = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address constant CHAINLINK_USDC_USD = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant CHAINLINK_DAI_USD = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
    address constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant CHAINLINK_USDT_USD = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;

    address constant UNISWAP_DAI_USDC = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168; // 0.01% pool
    address constant UNISWAP_ETH_USDC = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // 0.05% pool
    address constant UNISWAP_USDT_USDC = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6; // 0.05% pool

    uint256 constant TEST_NFT = 126; // DAI/USDC 0.05% - in range (-276330/-276320)

    uint256 constant TEST_NFT_UNI = 1; // WETH/UNI 0.3%

    uint256 mainnetFork;
    V3Oracle oracle;
    TestChainLinkOracle testUsdcOracle;

    function setUp() external {
        mainnetFork = vm.createFork("https://rpc.ankr.com/eth", 18521658);
        vm.selectFork(mainnetFork);

        // use tolerant oracles (so timewarp for until 30 days works in tests - also allow divergence from price for mocked price results)
        oracle = new V3Oracle(NPM, address(USDC), address(0));
        testUsdcOracle = new TestChainLinkOracle();
        oracle.setTokenConfig(
            address(USDC),
            AggregatorV3Interface(address(CHAINLINK_USDC_USD)), // AggregatorV3Interface(CHAINLINK_USDC_USD), AggregatorV3Interface(address(testUsdcOracle)),
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
            200
        );
        oracle.setTokenConfig(
            address(WETH),
            AggregatorV3Interface(CHAINLINK_ETH_USD),
            3600 * 24 * 30,
            IUniswapV3Pool(UNISWAP_ETH_USDC),
            60,
            V3Oracle.Mode.CHAINLINK_TWAP_VERIFY,
            200
        );
        oracle.setTokenConfig(
            address(USDT),
            AggregatorV3Interface(CHAINLINK_USDT_USD),
            3600 * 24 * 30,
            IUniswapV3Pool(UNISWAP_USDT_USDC),
            60,
            V3Oracle.Mode.CHAINLINK_TWAP_VERIFY,
            200
        );
    }

    function testWithDrawNFT() external {
        // withdraw NFT liquidity and collect fee to see how many token we receive and compare that with other stuff
        address nft_owner = NPM.ownerOf(TEST_NFT);
        vm.startPrank(nft_owner);

        (,, address token0, address token1,,,, uint128 liquidity,,,,) = NPM.positions(TEST_NFT);

        uint256 old0Balance = IERC20(token0).balanceOf(nft_owner);
        uint256 old1Balance = IERC20(token1).balanceOf(nft_owner);
        //foundry emit event log

        NPM.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: TEST_NFT,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
        (uint256 amount0, uint256 amount1) = NPM.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: TEST_NFT,
                recipient: nft_owner,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        console.log("NFT amount0: %e", amount0);
        console.log("NFT amount1: %e", amount1);
        uint256 new0Balance = IERC20(token0).balanceOf(nft_owner);
        uint256 new1Balance = IERC20(token1).balanceOf(nft_owner);
        console.log("token0 Balance change: %e", new0Balance - old0Balance); //3.93607068547774684e17  0.393 DAI
        console.log("token1 Balance change: %e", new1Balance - old1Balance); //9.436666e6              9.436 USDC
    }

    function testPrintModifiedChainLinkPrice() external {
        oracle.setMaxPoolPriceDifference(65000);
        oracle.setOracleMode(address(USDC), V3Oracle.Mode.CHAINLINK);
        oracle.setOracleMode(address(DAI), V3Oracle.Mode.CHAINLINK);
        oracle.setOracleMode(address(WETH), V3Oracle.Mode.CHAINLINK);

        uint256 oraclePrice = 9.01e8; //1 USD = 10.92 USDC
        vm.mockCall(
            CHAINLINK_DAI_USD,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(0), int256(oraclePrice), block.timestamp, block.timestamp, uint80(0))
        );
        //@ NFT 123 holding 0.393 DAi and 9.436USDC
        (uint256 valueUSDC,,,) = oracle.getValue(300, address(USDC));
        console.log("USDC Price: %e", valueUSDC);

        
    }

    function testDebug1() external {
        (uint256 valueUSDC,,,) = oracle.getValue(TEST_NFT, address(USDC));
        console.log("USDC Price: %e", valueUSDC);
        (uint256 valueDAI,,,) = oracle.getValue(TEST_NFT, address(DAI));
        console.log("DAI Price: %e", valueDAI);
        (uint256 valueWETH,,,) = oracle.getValue(TEST_NFT, address(WETH));
        console.log("WETH Price: %e", valueWETH);
        (uint256 valueUSDT,,,) = oracle.getValue(TEST_NFT, address(USDT));
        console.log("USDT Price: %e", valueUSDT);
    }

    function testConversionChainlink() external {
        (uint256 valueUSDC,,,) = oracle.getValue(TEST_NFT, address(USDC));
        assertEq(valueUSDC, 9830229); // 9.830229 e6 USDC

        (uint256 valueDAI,,,) = oracle.getValue(TEST_NFT, address(DAI));
        assertEq(valueDAI, 9831304996928906441); // 9.831304996928906441 e18 DAI

        (uint256 valueWETH,,,) = oracle.getValue(TEST_NFT, address(WETH));
        assertEq(valueWETH, 5265311333743718); // 0.005265311333743718 e18 ETH

        console.log("USDC Price: %e", valueUSDC);
        console.log("DAI Price: %e", valueDAI);
        console.log("WETH Price: %e", valueWETH);
    }

    function testConversionTWAP() external {
        oracle.setOracleMode(address(USDC), V3Oracle.Mode.TWAP_CHAINLINK_VERIFY);
        oracle.setOracleMode(address(DAI), V3Oracle.Mode.TWAP_CHAINLINK_VERIFY);
        oracle.setOracleMode(address(WETH), V3Oracle.Mode.TWAP_CHAINLINK_VERIFY);

        (uint256 valueUSDC,,,) = oracle.getValue(TEST_NFT, address(USDC));
        assertEq(valueUSDC, 9830274);

        (uint256 valueDAI,,,) = oracle.getValue(TEST_NFT, address(DAI));
        assertEq(valueDAI, 9830248010486057179);

        (uint256 valueWETH,,,) = oracle.getValue(TEST_NFT, address(WETH));
        assertEq(valueWETH, 5254033922056302);
    }

    function testNonExistingToken() external {
        vm.expectRevert(IErrors.NotConfigured.selector);
        oracle.getValue(TEST_NFT, address(WBTC));

        vm.expectRevert(IErrors.NotConfigured.selector);
        oracle.getValue(TEST_NFT_UNI, address(WETH));
    }

    function testInvalidPoolConfig() external {
        vm.expectRevert(IErrors.InvalidPool.selector);
        oracle.setTokenConfig(
            address(WETH),
            AggregatorV3Interface(CHAINLINK_ETH_USD),
            3600,
            IUniswapV3Pool(UNISWAP_DAI_USDC),
            60,
            V3Oracle.Mode.CHAINLINK_TWAP_VERIFY,
            500
        );
    }

    function testEmergencyAdmin() external {
        vm.expectRevert(IErrors.Unauthorized.selector);
        vm.prank(WHALE_ACCOUNT);
        oracle.setOracleMode(address(WETH), V3Oracle.Mode.TWAP_CHAINLINK_VERIFY);

        oracle.setEmergencyAdmin(WHALE_ACCOUNT);
        vm.prank(WHALE_ACCOUNT);
        oracle.setOracleMode(address(WETH), V3Oracle.Mode.TWAP_CHAINLINK_VERIFY);
    }

    function testChainlinkError() external {
        vm.mockCall(
            CHAINLINK_DAI_USD,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(0), int256(-1), block.timestamp, block.timestamp, uint80(0))
        );
        vm.expectRevert(IErrors.ChainlinkPriceError.selector);
        oracle.getValue(TEST_NFT, address(WETH));

        vm.mockCall(
            CHAINLINK_DAI_USD,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(0), int256(0), uint256(0), uint256(0), uint80(0))
        );
        vm.expectRevert(IErrors.ChainlinkPriceError.selector);
        oracle.getValue(TEST_NFT, address(WETH));
    }

    function testPriceDivergence() external {
        // change call to simulate oracle difference in chainlink
        vm.mockCall(
            CHAINLINK_DAI_USD,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(0), int256(0), block.timestamp, block.timestamp, uint80(0))
        );

        vm.expectRevert(IErrors.PriceDifferenceExceeded.selector);
        oracle.getValue(TEST_NFT, address(WETH));

        // works with normal prices
        vm.clearMockedCalls();
        (uint256 valueWETH,,,) = oracle.getValue(TEST_NFT, address(WETH));
        assertEq(valueWETH, 5265311333743718);

        // change call to simulate oracle difference in univ3 twap
        int56[] memory tickCumulatives = new int56[](2);
        uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](2);
        vm.mockCall(
            UNISWAP_DAI_USDC,
            abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector),
            abi.encode(tickCumulatives, secondsPerLiquidityCumulativeX128s)
        );
        vm.expectRevert(IErrors.PriceDifferenceExceeded.selector);
        oracle.getValue(TEST_NFT, address(WETH));
    }
}
