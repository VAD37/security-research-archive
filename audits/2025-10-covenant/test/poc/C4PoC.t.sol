// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

// Test setup dependencies
import "forge-std/Test.sol";
import {CovenantCurator} from "../../src/curators/CovenantCurator.sol";
import {StubPriceOracle} from "../mocks/StubPriceOracle.sol";
import {MockChainlinkAggregator} from "./mocks/MockChainlinkAggregator.sol";
import {ChainlinkOracle} from "../../src/curators/oracles/chainlink/ChainlinkOracle.sol";
import {MockPyth} from "./mocks/MockPyth.sol";
import {PythOracle} from "../../src/curators/oracles/pyth/PythOracle.sol";

// Several project dependencies that might be useful in PoCs
import {SynthToken} from "../../src/synths/SynthToken.sol";
import {Covenant, MarketId, MarketParams, MarketState, SynthTokens} from "../../src/Covenant.sol";
import {LatentSwapLEX} from "../../src/lex/latentswap/LatentSwapLEX.sol";
import {LSErrors} from "../../src/lex/latentswap/libraries/LSErrors.sol";
import {FixedPoint} from "../../src/lex/latentswap/libraries/FixedPoint.sol";
import {DebtMath} from "../../src/lex/latentswap/libraries/DebtMath.sol";
import {ICovenant, IERC20, AssetType, SwapParams, RedeemParams, MintParams} from "../../src/interfaces/ICovenant.sol";
import {ISynthToken} from "../../src/interfaces/ISynthToken.sol";
import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";
import {ILiquidExchangeModel} from "../../src/interfaces/ILiquidExchangeModel.sol";
import {ILatentSwapLEX, LexState, LexParams, LexConfig} from "../../src/lex/latentswap/interfaces/ILatentSwapLEX.sol";
import {MockOracle} from "../mocks/MockOracle.sol";
import {MockERC20, ERC20} from "../mocks/MockERC20.sol";
import {WadRayMath} from "@aave/libraries/math/WadRayMath.sol";
import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {UtilsLib} from "../../src/libraries/Utils.sol";
import {TestMath} from "../utils/TestMath.sol";
import {Events} from "../../src/libraries/Events.sol";
import {Errors} from "../../src/libraries/Errors.sol";
import {LatentSwapLib} from "../../src/periphery/libraries/LatentSwapLib.sol";
import {PercentageMath} from "@aave/libraries/math/PercentageMath.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {StubERC4626} from "../mocks/StubERC4626.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Math} from "@openzeppelin/utils/math/Math.sol";

contract POC_CovenantTest is Test {
    using WadRayMath for uint256;

    // LatentSwapLEX init pricing constants
    uint160 internal constant P_MAX = uint160((1095445 * FixedPoint.Q96) / 1000000); //uint160(Math.sqrt((FixedPoint.Q192 * 12) / 10)); // Edge price of 1.2
    uint160 internal constant P_MIN = uint160(FixedPoint.Q192 / P_MAX);
    uint32 internal constant DURATION = 30 * 24 * 60 * 60;
    uint8 internal constant SWAP_FEE = 0;
    int64 internal constant LN_RATE_BIAS = 5012540000000000; // WAD

    address private _mockOracle;
    address private _mockBaseAsset;
    address private _mockQuoteAsset;
    uint160 private P_LIM_H = LatentSwapLib.getSqrtPriceFromLTVX96(P_MIN, P_MAX, 9500);
    uint160 private P_LIM_MAX = LatentSwapLib.getSqrtPriceFromLTVX96(P_MIN, P_MAX, 9999);

    // PoC Contract Deployments
    Covenant public covenant;
    LatentSwapLEX public lex;
    CovenantCurator public covenantCurator;
    StubPriceOracle public covenantCuratorOracle;
    MarketId internal _marketId;
    MockChainlinkAggregator public chainlinkAggregator;
    ChainlinkOracle public chainlinkOracle;
    MockPyth public pyth;
    PythOracle public pythOracle;

    ////////////////////////////////////////////////////////////////////////////

    function setUp() public {
        // Deploy mock Oracle
        _mockOracle = address(new MockOracle(address(this)));

        // Deploy mock Base Asset w/ pre-mint
        _mockBaseAsset = address(new MockERC20(address(this), "MockBaseAsset", "MBA", 18));
        MockERC20(_mockBaseAsset).mint(address(this), 100e18);

        // Deploy mock Quote Asset
        _mockQuoteAsset = address(new MockERC20(address(this), "MockQaseAsset", "MQA", 18));

        // Deploy Covenant
        covenant = new Covenant(address(this));

        // Deploy LEX implementation
        lex = new LatentSwapLEX(
            address(this), address(covenant), P_MAX, P_MIN, P_LIM_H, P_LIM_MAX, LN_RATE_BIAS, DURATION, SWAP_FEE
        );

        // Connect LEX w/ Covenant
        covenant.setEnabledLEX(address(lex), true);

        // Connect mock oracle w/ Covenant
        covenant.setEnabledCurator(_mockOracle, true);

        // Create a mock market
        MarketParams memory marketParams = MarketParams({
            baseToken: _mockBaseAsset, quoteToken: _mockQuoteAsset, curator: _mockOracle, lex: address(lex)
        });
        _marketId = covenant.createMarket(marketParams, hex"");

        // Deploy the Covenant Curator (Oracle Router)
        covenantCurator = new CovenantCurator(address(this));

        // Deploy a *stub* oracle for the Covenant Curator
        covenantCuratorOracle = new StubPriceOracle(); //@oracle include payment fee

        // Link *stub* oracle with mock base and quote assets
        covenantCurator.govSetConfig(_mockBaseAsset, _mockQuoteAsset, address(covenantCuratorOracle)); //@oracle is sorted

        // Deploy mock Chainlink Aggregator
        chainlinkAggregator = new MockChainlinkAggregator(8);

        // Deploy Chainlink Oracle
        chainlinkOracle = new ChainlinkOracle(_mockBaseAsset, _mockQuoteAsset, address(chainlinkAggregator), 1 hours);

        // Deploy mock Pyth
        pyth = new MockPyth();

        // Deploy Pyth Oracle
        pythOracle =
            new PythOracle(address(pyth), _mockBaseAsset, _mockQuoteAsset, bytes32(uint256(196)), 10 minutes, 250);
    }

    function test_submissionValidity() public {
        console.log("-- POC: Covenant Curator Submission Validity Test--");
        //set oracle price to 2000$
        uint256 price = 2000e18;
        covenantCuratorOracle.setPrice(_mockBaseAsset, _mockQuoteAsset, price);

        MarketParams memory marketParams = covenant.getIdToMarketParams(_marketId);
        MarketId marketId = _marketId;

        //lex config and Synth token sanity check
        LexParams memory lexParams = lex.getLexParams();
        LexState memory lexState = lex.getLexState(marketId);
        LexConfig memory lexConfig = lex.getLexConfig(marketId);

        // LOGGING SETUP

        console.log("P_MAX: %e %e", toPrice(P_MAX), P_MAX); //8.6790094485438297295159752675e28
        console.log("P_MIN: %e %e", toPrice(P_MIN), P_MIN); // 7.2325093924628199127791856584e28
        console.log("P_LIM_H: %e %e", toPrice(P_LIM_H), P_LIM_H); //8.6061026241832566201911310611e28
        console.log("P_LIM_MAX: %e %e", toPrice(P_LIM_MAX), P_LIM_MAX); //8.6788647961275514677250667266e28
        console.log("DURATION: %s", uint256(DURATION));
        console.log("SWAP_FEE: %e", uint256(SWAP_FEE));

        console.log("lexParams.targetXvsL: %e %e", toPrice(lexParams.targetXvsL), lexParams.targetXvsL);
        console.log(
            "lexParams.edgeSqrtPriceX96_A: %e %e", toPrice(lexParams.edgeSqrtPriceX96_A), lexParams.edgeSqrtPriceX96_A
        );
        console.log(
            "lexParams.edgeSqrtPriceX96_B: %e %e", toPrice(lexParams.edgeSqrtPriceX96_B), lexParams.edgeSqrtPriceX96_B
        );
        console.log(
            "lexParams.limHighSqrtPriceX96: %e %e",
            toPrice(lexParams.limHighSqrtPriceX96),
            lexParams.limHighSqrtPriceX96
        );
        console.log(
            "lexParams.limMaxSqrtPriceX96: %e %e", toPrice(lexParams.limMaxSqrtPriceX96), lexParams.limMaxSqrtPriceX96
        );
        emit log_named_int("lexParams.initLnRateBias: ", lexParams.initLnRateBias);

        console.log("lexState.lastDebtNotionalPrice: %e", uint256(lexState.lastDebtNotionalPrice));
        console.log("lexState.lastBaseTokenPrice: %e", uint256(lexState.lastBaseTokenPrice));
        console.log("lexState.lastETWAPBaseSupply: %e", uint256(lexState.lastETWAPBaseSupply));
        console.log("lexState.lastSqrtPriceX96: %e %e", toPrice(lexState.lastSqrtPriceX96), lexState.lastSqrtPriceX96);
        emit log_named_int("lexState.lastLnRateBias: ", lexState.lastLnRateBias);

        console.log("lexConfig.protocolFee: %s", uint256(lexConfig.protocolFee));
        console.log(
            "lexConfig.aToken: %s", IERC20Metadata(lexConfig.aToken).name(), IERC20Metadata(lexConfig.aToken).symbol()
        );
        console.log(
            "lexConfig.zToken: %s", IERC20Metadata(lexConfig.zToken).name(), IERC20Metadata(lexConfig.zToken).symbol()
        );
        console.log("lexConfig.noCapLimit: %s", uint256(lexConfig.noCapLimit));
        console.log("lexConfig.scaleDecimals: %s", int256(lexConfig.scaleDecimals));
        console.log("lexConfig.adaptive: %s", lexConfig.adaptive);

        address user = makeAddr("user");
        vm.startPrank(user);
        IERC20(_mockBaseAsset).approve(address(covenant), type(uint256).max);

        uint256 baseAmountIn = 10e18;
        deal(_mockBaseAsset, user, baseAmountIn);
        console.log("- Mint -");
        (uint256 aTokenAmount, uint256 zTokenAmount) = covenant.mint(
            MintParams({
                marketId: marketId,
                marketParams: marketParams,
                baseAmountIn: baseAmountIn,
                to: user,
                minATokenAmountOut: 0,
                minZTokenAmountOut: 0,
                data: hex"",
                msgValue: 0
            })
        );

        console.log("aTokenAmount: %e", aTokenAmount);
        console.log("zTokenAmount: %e", zTokenAmount);

        vm.warp(block.timestamp + 1 days);
        covenant.updateState(marketId, marketParams, hex"", 0);

        console.log("- Swap -");
        covenant.swap(
            SwapParams({
                marketId: marketId,
                marketParams: marketParams,
                assetIn: AssetType.LEVERAGE,
                assetOut: AssetType.DEBT,
                to: address(user),
                amountSpecified: 10 ** 16,
                amountLimit: 0,
                isExactIn: true,
                data: "",
                msgValue: 0
            })
        );
        console.log("- Redeem -");

        covenant.redeem(
            RedeemParams({
                marketId: marketId,
                marketParams: marketParams,
                aTokenAmountIn: aTokenAmount / 4,
                zTokenAmountIn: zTokenAmount / 4,
                to: address(this),
                minAmountOut: 0,
                data: "",
                msgValue: 0
            })
        );
    }
    //scale to e18 decimal
    function toPrice(uint256 sqrtRatioX96) internal returns (uint256 price) {
        price = Math.mulDiv(uint256(sqrtRatioX96) *1e18, uint256(sqrtRatioX96), 2 ** 192, Math.Rounding.Ceil);
    }
}
