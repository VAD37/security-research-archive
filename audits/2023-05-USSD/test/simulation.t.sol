// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/USSDRebalancer.sol";
import "../src/USSD.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "lib/v3-periphery/contracts/SwapRouter.sol";
import "lib/v3-periphery/contracts/libraries/PoolAddress.sol";
import "lib/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import "../src/oracles/MockERC20.sol";
import "../src/oracles/WETH9.sol";
import "../src/oracles/SimOracle.sol";
import "lib/v3-periphery/contracts/NonfungiblePositionManager.sol";

contract SimulationTest is Test {
    USSD ussd;
    USSDRebalancer rebalancer;

    MockERC20 DAI = MockERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    MockERC20 USDC = MockERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    MockERC20 WBTC = MockERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    MockERC20 WBGL = MockERC20(0x2bA64EFB7A4Ec8983E22A49c81fa216AC33f383A);
    WETH9 WETH = WETH9(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

    SimOracle btcOracle;
    SimOracle ethOracle;
    SimOracle daiOracle;
    SimOracle wbglOracle;

    SwapRouter router =
        SwapRouter(payable(0xE592427A0AEce92De3Edee1F18E0157C05861564));
    IUniswapV3Factory factory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    NonfungiblePositionManager positionManager =
        NonfungiblePositionManager(
            payable(0xC36442b4a4522E871399CD717aBDD847Ab11FE88)
        );
    uint24 fee0 = 100;
    uint24 fee1 = 500;
    uint24 fee2 = 3000;
    uint24 fee3 = 10000;
    IUniswapV3Pool pool_dai_ussd;
    IQuoterV2 quoter = IQuoterV2(0x61fFE014bA17989E743c5F6cB21bF9697530B21e);

    function setUp() public {
        routerSetup();
        balancerSetup();
        ussd.approve(address(positionManager), type(uint256).max);
        DAI.approve(address(positionManager), type(uint256).max);

        //check token balance of this address
        console.log("DAI balance: ", DAI.balanceOf(address(this)));
        console.log("WBTC balance: ", WBTC.balanceOf(address(this)));
        console.log("WBGL balance: ", WBGL.balanceOf(address(this)));
        console.log("WETH balance: ", WETH.balanceOf(address(this)));
        console.log("USDC balance: ", USDC.balanceOf(address(this)));
        console.log("USSD balance: ", ussd.balanceOf(address(this)));
        // decodebytes 0000000000000000000000000000000000000000000010C6F7A0B5ED8D36B4C7 to uint

        pool_dai_ussd = IUniswapV3Pool(
            positionManager.createAndInitializePoolIfNecessary(
                address(ussd),
                address(DAI),
                fee1,
                uint160(1000000 * (2 ** 96)) //(( 1000000000000000000/1000000 ) ^0.5)*2^96 | >> (96 * 2)
            )
        ); //79228162514264337593543
        //79228162514264300000000
        rebalancer.setPoolAddress(address(pool_dai_ussd));
        console.log("token0 ussd: ", pool_dai_ussd.token0());
        console.log("token1 dai: ", pool_dai_ussd.token1());
        console.log("init mint NFT positions");
        INonfungiblePositionManager.MintParams memory mintParam = INonfungiblePositionManager
            .MintParams({
                token0: address(ussd),
                token1: address(DAI),
                fee: fee1,
                tickLower: int24(-880000), // -880000
                tickUpper: int24(880000), // 880000
                amount0Desired: 10000000000, //10k
                amount1Desired: 10000000000000000000000, // 10k
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 100
            });
        (, uint liquidity, , ) = positionManager.mint(mintParam);
        //vm skip block
        vm.warp(block.timestamp + 150);

        //log pool balance
        console.log(
            "pool token0 USSD balance: ",
            ussd.balanceOf(address(pool_dai_ussd))
        );
        console.log(
            "pool token1 DAI  balance: ",
            DAI.balanceOf(address(pool_dai_ussd))
        );

        console.log("DAI balance: ", DAI.balanceOf(address(this)));
        console.log("USSD balance: ", ussd.balanceOf(address(this)));
        console.log("NFT liquidity :", liquidity);
        console.log("pool liquidity:", pool_dai_ussd.liquidity());

        console.log("mint token for collateral");
        DAI.approve(address(ussd), type(uint256).max);
        ussd.mintForToken(address(DAI), 10000e18, address(this));

        console.log("DAI balance: ", DAI.balanceOf(address(this)));
        console.log("USSD balance: ", ussd.balanceOf(address(this)));
        // print pool slot0
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool_dai_ussd.slot0();
        console.log("pool slot0 sqrtPriceX96: ", sqrtPriceX96);
        console.logInt(int(tick));
    }

    function test_addLiquidity() public {
        // add 10000k DAI to liquidity
        console.log("DAI balance: ", DAI.balanceOf(address(this)));
        console.log("USSD balance: ", ussd.balanceOf(address(this)));
        console.log(
            "pool token0 USSD balance: ",
            ussd.balanceOf(address(pool_dai_ussd))
        );
        console.log(
            "pool token1 DAI  balance: ",
            DAI.balanceOf(address(pool_dai_ussd))
        );
        console.log("pool liquidity:", pool_dai_ussd.liquidity());

        int24 lowerTick = TickMath.getTickAtSqrtRatio(
            uint160(900000 * (2 ** 96))
        );
        int24 upperTick = TickMath.getTickAtSqrtRatio(
            uint160((1000000 - 1) * (2 ** 96))
        );
        console.log("ticks");
        console.logInt(lowerTick);
        console.logInt(upperTick);
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool_dai_ussd.slot0();
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(lowerTick);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(upperTick);
        uint128 expectLiquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            0,
            5000e18
        );//499846744662011893 10000000000000000
        console.log(expectLiquidity);
        pool_dai_ussd.mint(
            address(this),
            lowerTick,
            upperTick,
            expectLiquidity,
            abi.encode(address(this))
        );
        console.log("DAI balance: ", DAI.balanceOf(address(this)));
        console.log("USSD balance: ", ussd.balanceOf(address(this)));
        console.log(
            "pool token0 USSD balance: ",
            ussd.balanceOf(address(pool_dai_ussd))
        );
        console.log(
            "pool token1 DAI  balance: ",
            DAI.balanceOf(address(pool_dai_ussd))
        );
        console.log("pool liquidity:", pool_dai_ussd.liquidity());
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        console.log("uniswapCallback");
        console.log("amount0Owed:", amount0Owed);
        console.log("amount1Owed:", amount1Owed);
        if (amount0Owed > 0) ussd.transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) DAI.transfer(msg.sender, amount1Owed);
    }

    function balancerSetup() internal {
        ussd = new USSD();
        ussd.initialize("US Secured Dollar", "USSD");

        rebalancer = new USSDRebalancer();
        rebalancer.initialize(address(ussd));
        rebalancer.grantRole(keccak256("STABLECONTROL"), address(this));
        rebalancer.setPoolAddress(address(pool_dai_ussd));
        rebalancer.setBaseAsset(address(DAI));
        // 14.25, 28.35, 61, 112.8 according to whitepaper
        // this.rebalancer.setFlutterRatios([web3.utils.toBN('14250000000000000000'), web3.utils.toBN('28350000000000000000'), web3.utils.toBN('61000000000000000000'), web3.utils.toBN('112800000000000000000')], { from: accounts[0] });
        uint256[] memory ratios = new uint256[](4);
        ratios[0] = 14.25e18;
        ratios[1] = 28.35e18;
        ratios[2] = 61e18;
        ratios[3] = 112.8e18;
        rebalancer.setFlutterRatios(ratios);

        ussd.grantRole(keccak256("STABLECONTROL"), address(this));
        ussd.setUniswapRouter(address(router));
        ussd.setRebalancer(address(rebalancer));

        ussd.approveToRouter(address(WBTC));
        ussd.approveToRouter(address(WETH));
        ussd.approveToRouter(address(ussd));
        ussd.approveToRouter(address(DAI));
        ussd.approveToRouter(address(WBGL));

        btcOracle = new SimOracle(32000e18);
        ethOracle = new SimOracle(2000e18);
        daiOracle = new SimOracle(1e18);
        wbglOracle = new SimOracle(0.3e18);
        // ussd.addCollateral(address(DAI), daiOracle, true,true, );
        // ussd.addCollateral(address(WBTC));
        // ussd.addCollateral(address(WETH));
        //         path_DAI_USSD = "0x" + "6b175474e89094c44da98b954eedeac495271d0f" //DAI
        //   + "0001f4" // 0.05% tier (medium-risk)
        //   + this.USSD.address.substring(2)

        // path_USSD_DAI = "0x" + this.USSD.address.substring(2)
        //   + "0001f4" // 0.05% tier (medium-risk)
        //   + "6b175474e89094c44da98b954eedeac495271d0f" //DAI

        // path_DAI_USDC = "0x" + "6b175474e89094c44da98b954eedeac495271d0f" //DAI
        //   + "0001f4" // 0.05% tier (medium-risk)
        //   + "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" //USDC

        // path_WETH_USDC_DAI = "0x" + "c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" //WETH
        //   + "0001f4" // 0.05% tier (medium-risk)
        //   + "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" //USDC
        //   + "000064" // 0.01% tier (low-risk)
        //   + "6b175474e89094c44da98b954eedeac495271d0f" //DAI

        // path_DAI_USDC_WETH = "0x" + "6b175474e89094c44da98b954eedeac495271d0f" //DAI
        //   + "000064" // 0.05% tier (medium-risk)
        //   + "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" //USDC
        //   + "0001f4" // 0.01% tier (low-risk)
        //   + "c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" //WETH

        // path_WBTC_WETH_USDC_DAI = "0x" + "2260fac5e5542a773aa44fbcfedf7c193bc2c599" //WBTC
        //   + "000bb8" // 0.3% tier
        //   + "c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" //WETH
        //   + "0001f4" // 0.05% tier (medium-risk)
        //   + "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" //USDC
        //   + "000064" // 0.01% tier (low-risk)
        //   + "6b175474e89094c44da98b954eedeac495271d0f" //DAI

        // path_DAI_USDC_WETH_WBTC = "0x" + "6b175474e89094c44da98b954eedeac495271d0f" //DAI
        //   + "000064" // 0.01% tier (low-risk)
        //   + "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" //USDC
        //   + "0001f4" // 0.05% tier (medium-risk)
        //   + "c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" //WETH
        //   + "000bb8" // 0.3% tier
        //   + "2260fac5e5542a773aa44fbcfedf7c193bc2c599" //WBTC

        // path_WBGL_WETH_USDC_DAI = "0x" + "2ba64efb7a4ec8983e22a49c81fa216ac33f383a" //WBGL
        //   + "000064" // 0.01% tier
        //   + "c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" //WETH
        //   + "0001f4" // 0.05% tier
        //   + "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" //USDC
        //   + "000064" // 0.01% tier
        //   + "6b175474e89094c44da98b954eedeac495271d0f" //DAI

        // path_DAI_USDC_WETH_WBGL = "0x" + "6b175474e89094c44da98b954eedeac495271d0f" //DAI
        //   + "000064" // 0.01% tier
        //   + "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" //USDC
        //   + "0001f4" // 0.05% tier
        //   + "c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" //WETH
        //   + "000064" // 0.01% tier
        //   + "2ba64efb7a4ec8983e22a49c81fa216ac33f383a" //WBGL
        bytes memory path_DAI_USSD = abi.encodePacked(
            address(DAI),
            fee1,
            address(ussd)
        );
        bytes memory path_DAI_USDC = abi.encodePacked(
            address(DAI),
            fee1,
            address(USDC)
        );
        bytes memory path_WETH_USDC_DAI = abi.encodePacked(
            address(WETH),
            fee1,
            address(USDC),
            fee0,
            address(DAI)
        );
        bytes memory path_DAI_USDC_WETH = abi.encodePacked(
            address(DAI),
            fee1,
            address(USDC),
            fee0,
            address(WETH)
        );
        bytes memory path_WBTC_WETH_USDC_DAI = abi.encodePacked(
            address(WBTC),
            fee2,
            address(WETH),
            fee1,
            address(USDC),
            fee0,
            address(DAI)
        );
        bytes memory path_DAI_USDC_WETH_WBTC = abi.encodePacked(
            address(DAI),
            fee0,
            address(USDC),
            fee1,
            address(WETH),
            fee1,
            address(WBTC)
        );
        bytes memory path_WBGL_WETH_USDC_DAI = abi.encodePacked(
            address(WBGL),
            fee0,
            address(WETH),
            fee1,
            address(USDC),
            fee0,
            address(DAI)
        );
        bytes memory path_DAI_USDC_WETH_WBGL = abi.encodePacked(
            address(DAI),
            fee0,
            address(USDC),
            fee1,
            address(WETH),
            fee0,
            address(WBGL)
        );
        // await this.USSD.addCollateral(DAI, this.oracleDAI.address, true, true,
        //   [web3.utils.toBN('250000000000000000'), web3.utils.toBN('350000000000000000'), web3.utils.toBN('1000000000000000000'), web3.utils.toBN('800000000000000000')],
        //   '0x', '0x', 100);
        // await this.USSD.addCollateral(WETH, this.oracleWETH.address, false, false,
        //   [web3.utils.toBN('2000000000000000000'), web3.utils.toBN('4000000000000000000'), web3.utils.toBN('5000000000000000000'), web3.utils.toBN('6000000000000000000')],
        //   path_DAI_USDC_WETH, path_WETH_USDC_DAI, 100);
        // await this.USSD.addCollateral(WBTC, this.oracleWBTC.address, false, false,
        //   [web3.utils.toBN('2000000000000000000'), web3.utils.toBN('4000000000000000000'), web3.utils.toBN('5000000000000000000'), web3.utils.toBN('6000000000000000000')],
        //   path_DAI_USDC_WETH_WBTC, path_WBTC_WETH_USDC_DAI, 100);
        // await this.USSD.addCollateral(WBGL, this.oracleWBGL.address, false, false,
        //   [web3.utils.toBN('10000000000000000000'), web3.utils.toBN('20000000000000000000'), web3.utils.toBN('50000000000000000000'), web3.utils.toBN('100000000000000000000')],
        //   path_DAI_USDC_WETH_WBGL, path_WBGL_WETH_USDC_DAI, 100);
        uint[] memory ratio = new uint[](4);
        ratio[0] = 250000000000000000;
        ratio[1] = 350000000000000000;
        ratio[2] = 1000000000000000000;
        ratio[3] = 800000000000000000;
        ussd.addCollateral(
            address(DAI),
            address(daiOracle),
            true,
            true,
            ratio,
            bytes(""),
            bytes(""),
            100
        );

        ratio[0] = 2000000000000000000;
        ratio[1] = 4000000000000000000;
        ratio[2] = 5000000000000000000;
        ratio[3] = 6000000000000000000;

        ussd.addCollateral(
            address(WETH),
            address(ethOracle),
            false,
            false,
            ratio,
            path_DAI_USDC_WETH,
            path_WETH_USDC_DAI,
            100
        );

        ussd.addCollateral(
            address(WBTC),
            address(btcOracle),
            false,
            false,
            ratio,
            path_DAI_USDC_WETH_WBTC,
            path_WBTC_WETH_USDC_DAI,
            100
        );

        ratio[0] = 10000000000000000000;
        ratio[1] = 20000000000000000000;
        ratio[2] = 50000000000000000000;
        ratio[3] = 100000000000000000000;

        ussd.addCollateral(
            address(WBGL),
            address(wbglOracle),
            false,
            false,
            ratio,
            path_DAI_USDC_WETH_WBGL,
            path_WBGL_WETH_USDC_DAI,
            100
        );
    }

    function routerSetup() internal {
        WETH.deposit{value: 1000000 ether}();
        WETH.approve(address(router), 1000000 ether);
        console.log("swap for 50000e18 dai");
        swapGetToken(address(DAI), 50000e18);
        console.log("swap for 10e8 wbtc");
        swapGetToken(address(WBTC), 10e8);
        // swapGetToken(address(WBGL), 1000e18);
    }

    function swapGetToken(address token, uint amountOut) internal {
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = token;
        ISwapRouter.ExactOutputSingleParams memory swapParam = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: address(WETH),
                tokenOut: token,
                fee: fee1,
                recipient: address(this),
                deadline: block.timestamp + 100,
                amountOut: amountOut,
                amountInMaximum: 1e30,
                sqrtPriceLimitX96: 0
            });
        uint amountIn = router.exactOutputSingle(swapParam);
        console.log();
    }

    function testSucceed() public {}
}
