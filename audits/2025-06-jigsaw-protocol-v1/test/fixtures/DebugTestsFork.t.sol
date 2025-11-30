// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { stdJson as StdJson } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { DeployGenesisOracle } from "../../script/deployment/01_DeployGenesisOracle.s.sol";
import { DeployManager } from "../../script/deployment/02_DeployManager.s.sol";
import { DeployJUSD } from "../../script/deployment/03_DeployJUSD.s.sol";
import { DeployManagers } from "../../script/deployment/04_DeployManagers.s.sol";
import { DeployReceiptToken } from "../../script/deployment/05_DeployReceiptToken.s.sol";
import { DeployChronicleOracleFactory } from "../../script/deployment/06_DeployChronicleOracleFactory.s.sol";
import { DeployRegistries } from "../../script/deployment/07_DeployRegistries.s.sol";
import { DeployUniswapV3Oracle } from "../../script/deployment/08_DeployUniswapV3Oracle.s.sol";
import { DeployMocks } from "../../script/mocks/00_DeployMocks.s.sol";

import { Holding, HoldingManager } from "../../src/HoldingManager.sol";
import { JigsawUSD } from "../../src/JigsawUSD.sol";
import { LiquidationManager } from "../../src/LiquidationManager.sol";
import { Manager } from "../../src/Manager.sol";

import { ReceiptToken } from "../../src/ReceiptToken.sol";
import { ReceiptTokenFactory } from "../../src/ReceiptTokenFactory.sol";
import { ISharesRegistry, SharesRegistry } from "../../src/SharesRegistry.sol";
import { StablesManager } from "../../src/StablesManager.sol";
import { StrategyManager } from "../../src/StrategyManager.sol";
import { SwapManager } from "../../src/SwapManager.sol";

import { ChronicleOracle } from "../../src/oracles/chronicle/ChronicleOracle.sol";
import { ChronicleOracleFactory } from "../../src/oracles/chronicle/ChronicleOracleFactory.sol";

import { UniswapV3Oracle } from "src/oracles/uniswap/UniswapV3Oracle.sol";

import { SampleOracle } from "../utils/mocks/SampleOracle.sol";
import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";
import { wETHMock } from "../utils/mocks/wETHMock.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DebugTestsFork is Test {
    using StdJson for string;

    address user = makeAddr("user"); //0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D

    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC mainnet address
    address internal WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH mainnet address
    address internal JUSD_Oracle = 0x4DFdF3F4dFaa93747a08D344c2f12cDcDa25c2e0; // genesis oracle

    address internal UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal UNISWAP_SWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    address internal USDT_USDC_POOL = 0xAd0883325adE2994fF7aFd1eeB1Ec8cf9a3f40e6; // UniswapV3 jUSD/USDC pool fee 3000
    //Curve JUSD/USDC: 0x6A0c68Bc96658A2B97201d94986Bf7753000f2cF
    Manager internal manager = Manager(0x0000000E44A948Ab0c83F2C65D3a2C4A06B05228);
    JigsawUSD internal jUSD = JigsawUSD(0x000000096CB3D4007fC2b79b935C4540C5c2d745); // jUSD mainnet address

    HoldingManager internal holdingManager = HoldingManager(payable(0x0000000A9FaCf0Be270c02DdfeCabD01CC194698));
    LiquidationManager internal liquidationManager = LiquidationManager(0x0000000Bb034315Bf08CE000C5F43c1AF2609421);
    StablesManager internal stablesManager = StablesManager(0x00000000Fb1d443a8D2aAAEE72ce4c55b8dB04B7); // stables
        // manager mainnet address
    StrategyManager internal strategyManager = StrategyManager(0x0000000b6bcCbd238329A55F83582EFd3b5D2Ed2); // strategy
        // manager mainnet address
    SwapManager internal swapManager = SwapManager(0x0000000d64A5f3b2DD2F7D617431f9a8C7577a26); // swap manager mainnet
        // address
    ReceiptToken internal receiptToken = ReceiptToken(0x2783D7156b2f4462a2B6585D3F88bc5F4CB0F884); // receipt token
        // mainnet address
    ReceiptTokenFactory internal receiptTokenFactory = ReceiptTokenFactory(0xc953dF62A03E002b6212175c2ebAdA829183f827); // receipt
        // token factory mainnet address
    ChronicleOracle internal chronicleOracle = ChronicleOracle(0x7cBAEfA03Db00b4aa4d88F566d704c2CDF238d56); // chronicle
        // oracle mainnet address
    ChronicleOracleFactory internal chronicleOracleFactory =
        ChronicleOracleFactory(0x9551ab399489316501D1a9820cc0e854D3ADcA27); // chronicle oracle factory mainnet address
    UniswapV3Oracle internal jUsdUniswapV3Oracle = UniswapV3Oracle(0x3aFC9691842B2648E344025e5192853d2EB7DA92); // jUSD
        // UniswapV3 oracle

    address[] internal registries;
    //tokens list
    //Withdraw and //whitelist
    // 0xaD55aebc9b8c03FC43cd9f62260391c13c23e7c0 // cUSD0 ERC4626 vault 0x7a3e55e2c23ab6adc12accf1075b91c174ee0102
    // 0x8238884Ec9668Ef77B90C6dfF4D1a9F4F4823BFe // USDO Token  0x87e3ba929c71c0e28fc1c817d107a888a59c523e
    // 0x7C1156E515aA1A2E851674120074968C905aAF37 //lvlUSD LevelMoney and morpho
    // 0x04C154b66CB340F3Ae24111CC767e0184Ed00Cc6 pxETH Pirex ETH, slightly worth less than eth
    // 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee weETH = ETH value * 1.064
    // 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0 wstETH  index 1.1977
    // 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 // WETH
    // 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 // WBTC
    // 0x35D8949372D46B7a3D5A56006AE77B215fc69bC0 USD0 Liquid Bond ~0.96 USD // UUPS got recently updated
    // 0x09D4214C03D01F49544C0448DBE3A27f768F2b34 rUSD LevelMoney and morpho. Pegged to USDC
    // 0xdAC17F958D2ee523a2206206994597C13D831ec7 // USDT
    // 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 // USDC

    function setUp() public {
        vm.createSelectFork(
            "https://rpc.ankr.com/eth/95e6b7b3769824dfa420ef460b5fd940bff206ca48caea572c3a9198f245bbb5", 22_580_300
        );
        registries.push(0x80dE34B817902fc05E44030fdd5CD8043fCD439e); //0 cUSD0
        registries.push(0x2Dd0306EE3657aCdCfBcD490137a27C5D304297a); //1 USDO
        registries.push(0xE4751F5FdF5c229b0E165eaD49d47A09Ae0c2f32); //2 lvlUSD
        registries.push(0x73387e934Cd66A973745eA450525BB49cA9be249); //3 pxETH 70%
        registries.push(0x6593942CDC8d3a1D75f2EdA63d7549A45bd162fF); //4 weETH 70%
        registries.push(0x524662D01457Bf73B92ab43492FD5509772D6f42); //5 wstETH 75%
        registries.push(0x1C9BE4B3423d61190282aA1F08948B3085340EA0); //6 WETH 75%
        registries.push(0xB7F07BF68c88E713C43Adc384BA94Fe3a6828d4C); //7 WBTC 70%
        registries.push(0x00321F409528f3D718d19C1ae5698AE32ac4782e); //8 USD0
        registries.push(0xFcf40c8a08551FeD5dE341C9248E8dA6B258CaA4); //9 rUSD
        registries.push(0x7e1a6588c1d0Bd9E17fF39D45f2873aB28DeB4e8); //10 USDT
        registries.push(0x1533dfaA4dBeE7506B956dF41bF85b00226c6fe6); //11 USDC

        // all USD have 85% collateralizationRate by default
        // CUSD0, USD0, lvlUSD use genesis oracle. 1:1 exchange rate with USD
        // hard assets like ETH have 70% collateralRate

        //oracles from chroniclelabs. 1% deviation is really high. sandwich attacks are possible

        // label user & tokens
        vm.label(user, "User");
        vm.label(USDC, "USDC");
        vm.label(WETH, "WETH");

        // label Oracles, Factories & Pools
        vm.label(JUSD_Oracle, "JUSD_Oracle");
        vm.label(UNISWAP_FACTORY, "UniswapV3Factory");
        vm.label(UNISWAP_SWAP_ROUTER, "UniswapV3Router");
        vm.label(USDT_USDC_POOL, "USDT_USDC_Pool");

        // label core Manager contracts
        vm.label(address(manager), "Manager");
        vm.label(address(jUSD), "JigsawUSD");
        vm.label(address(holdingManager), "HoldingManager");
        vm.label(address(liquidationManager), "LiquidationManager");
        vm.label(address(stablesManager), "StablesManager");
        vm.label(address(strategyManager), "StrategyManager");
        vm.label(address(swapManager), "SwapManager");

        // label ReceiptToken & Factory
        vm.label(address(receiptToken), "ReceiptToken");
        vm.label(address(receiptTokenFactory), "ReceiptTokenFactory");

        // label Chronicle Oracles
        vm.label(address(chronicleOracle), "ChronicleOracle");
        vm.label(address(chronicleOracleFactory), "ChronicleOracleFactory");
        vm.label(address(jUsdUniswapV3Oracle), "JUSD_UniswapV3Oracle");
        // Registries
        vm.label(registries[0], "Registry_cUSD0");
        vm.label(registries[1], "Registry_USDO");
        vm.label(registries[2], "Registry_lvlUSD");
        vm.label(registries[3], "Registry_pxETH");
        vm.label(registries[4], "Registry_weETH");
        vm.label(registries[5], "Registry_wstETH");
        vm.label(registries[6], "Registry_WETH");
        vm.label(registries[7], "Registry_WBTC");
        vm.label(registries[8], "Registry_USD0");
        vm.label(registries[9], "Registry_rUSD");
        vm.label(registries[10], "Registry_USDT");
        vm.label(registries[11], "Registry_USDC");

        // _debugConfigView();
    }

    function testDebug() public {
        //deposit USDC into holding and borrow jUSD

        vm.startPrank(user, user); //0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D
        deal(USDC, user, 100_000e6); // 100k USDC
        ERC20(USDC).approve(address(holdingManager), type(uint256).max);
        holdingManager.createHolding();
        Holding holding = Holding(holdingManager.userHolding(user));

        holdingManager.deposit(USDC, 100_000e6); //85% collateral for USDC. oracle push price down a little bit
        viewUser(user);
        console.log("USDC exchangeRate: %e", getRegistry(USDC).getExchangeRate());
        uint256 maxBorrow =
            stablesManager.getRatio(address(holding), ISharesRegistry(getRegistry(USDC)), getCollateralRate(USDC));
        console.log("max Borrow Amount: %e", maxBorrow);
        //convert maxBorrow from e18 to USDC decimals. because _amount here is collateral amount not JUSD amount to
        // borrow
        uint256 collateralUsedForBorrowing = 100_000e6 * getCollateralRate(USDC) / manager.PRECISION();
        holdingManager.borrow(USDC, collateralUsedForBorrowing, 0, true); //borrow max amount of jUSD
        viewUser(user);

        console.log("isLiquidatable:", stablesManager.isLiquidatable(USDC, address(holding)));
    }

    function viewUser(
        address usr
    ) public view {
        Holding holding = Holding(holdingManager.userHolding(usr));
        address _h = address(holding);
        console.log("User:", usr);
        console.log("  USDC Balance_holding: %e", ERC20(USDC).balanceOf(_h));
        console.log("  jUSD Balance_holding: %e", ERC20(jUSD).balanceOf(_h));
        console.log("  jUSD Balance_user: %e", ERC20(jUSD).balanceOf(user));
    }

    function getCollateralRate(
        address token
    ) public view returns (uint256) {
        (SharesRegistry.RegistryConfig memory config) = getConfig(token);
        return config.collateralizationRate;
    }

    function getConfig(
        address token
    ) public view returns (SharesRegistry.RegistryConfig memory config) {
        SharesRegistry registry = getRegistry(token);
        config = registry.getConfig();
    }

    function getRegistry(
        address token
    ) public view returns (SharesRegistry registry) {
        (bool active, address deployedAt) = stablesManager.shareRegistryInfo(token);
        require(active, "Registry is not active");
        registry = SharesRegistry(deployedAt);
    }

    function _debugConfigView() public {
        //reading all contracts view from Manager
        console.log("WETH:", address(manager.WETH()));
        console.log("jUsdOracle:", address(manager.jUsdOracle()));
        console.log("HoldingManager:", address(manager.holdingManager()));
        console.log("LiquidationManager:", address(manager.liquidationManager()));
        console.log("StablesManager:", address(manager.stablesManager()));
        console.log("StrategyManager:", address(manager.strategyManager()));
        console.log("SwapManager:", address(manager.swapManager()));
        console.log("ReceiptTokenFactory:", address(manager.receiptTokenFactory()));
        console.log("FeeAddress:", address(manager.feeAddress()));
        console.log("PerformanceFee: %e", manager.performanceFee());
        console.log("WithdrawalFee: %e", manager.withdrawalFee());
        console.log("MinDebtAmount: %e", manager.minDebtAmount());
        console.log("TimelockAmount:", manager.timelockAmount());

        for (uint256 i = 0; i < registries.length; i++) {
            (bool active, address deployedAt) = stablesManager.shareRegistryInfo(SharesRegistry(registries[i]).token());
            console.log("Registry %s: %s ", Strings.toString(i), registries[i]);
            console.log("  Token: %s", SharesRegistry(registries[i]).token());
            console.log("  Active: %s", active);
            console.log("  DeployedRegistry: %s", deployedAt);
            console.log("  Exchange Rate: %e", SharesRegistry(registries[i]).getExchangeRate());
            console.log("  Oracle: %s", address(SharesRegistry(registries[i]).oracle()));
            // console.logBytes(SharesRegistry(registries[i]).oracleData()); all bytes are empty
            (SharesRegistry.RegistryConfig memory a) = SharesRegistry(registries[i]).getConfig();
            console.log("  Config:");
            console.log("    collateralizationRate: %s", a.collateralizationRate);
            console.log("    liquidationBuffer: %s", a.liquidationBuffer); // 5% default for all
            console.log("    liquidatorBonus: %s", a.liquidatorBonus); // 8% default for all
        }
    }
}
