// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import "src/diamond/interfaces/IAlpManager.sol";
import "src/diamond/interfaces/IApxReward.sol";
import "src/diamond/interfaces/IBook.sol";
import "src/diamond/interfaces/IBrokerManager.sol";
import "src/diamond/interfaces/IChainlinkPrice.sol";
import "src/diamond/interfaces/IDiamondCut.sol";
import "src/diamond/interfaces/IDiamondLoupe.sol";
import "src/diamond/interfaces/IFeeManager.sol";
import "src/diamond/interfaces/IHookManager.sol";
import "src/diamond/interfaces/ILimitOrder.sol";
import "src/diamond/interfaces/IOraclePrice.sol";
import "src/diamond/interfaces/IOrderAndTradeHistory.sol";
import "src/diamond/interfaces/IPairsManager.sol";
import "src/diamond/interfaces/IPausable.sol";
import "src/diamond/interfaces/IPredictUpDown.sol";
import "src/diamond/interfaces/IPredictionManager.sol";
import "src/diamond/interfaces/IPriceFacade.sol";
import "src/diamond/interfaces/ISlippageManager.sol";
import "src/diamond/interfaces/IStakeReward.sol";
import "src/diamond/interfaces/ITimeLock.sol";
import "src/diamond/interfaces/ITrading.sol";
import "src/diamond/interfaces/ITradingChecker.sol";
import "src/diamond/interfaces/ITradingClose.sol";
import "src/diamond/interfaces/ITradingConfig.sol";
import "src/diamond/interfaces/ITradingCore.sol";
import "src/diamond/interfaces/ITradingOpen.sol";
import "src/diamond/interfaces/ITradingPortal.sol";
import "src/diamond/interfaces/ITradingReader.sol";
import "src/diamond/interfaces/IVault.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract BaseTest is Test {
    address apolloX = 0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0;
    IERC20 alp = IERC20(0x4E47057f45adF24ba41375a175dA0357cB3480E5);
    IERC20 BUSD = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IAlpManager alpManager;
    IApxReward apxReward;
    IBook book;
    IBrokerManager brokerManager;
    IChainlinkPrice chainlinkPrice;
    IDiamondCut diamondCut;
    IDiamondLoupe diamondLoupe;
    IFeeManager feeManager;
    IHookManager hookManager;
    ILimitOrder limitOrder;
    IOraclePrice oraclePrice;
    IOrderAndTradeHistory orderAndTradeHistory;
    IPairsManager pairsManager;
    IPausable pausable;
    IPredictUpDown predictUpDown;
    IPredictionManager predictionManager;
    IPriceFacade priceFacade;
    ISlippageManager slippageManager;
    IStakeReward stakeReward;
    ITimeLock timeLock;
    ITrading trading;
    ITradingChecker tradingChecker;
    ITradingClose tradingClose;
    ITradingConfig tradingConfig;
    ITradingCore tradingCore;
    ITradingOpen tradingOpen;
    ITradingPortal tradingPortal;
    ITradingReader tradingReader;
    IVault vault;


    function setUp() public {
        console.log("setUp");
        // node https://bsc-rpc.publicnode.com
        alpManager = IAlpManager(apolloX);
        apxReward = IApxReward(apolloX);
        book = IBook(apolloX);
        brokerManager = IBrokerManager(apolloX);
        chainlinkPrice = IChainlinkPrice(apolloX);
        diamondCut = IDiamondCut(apolloX);
        diamondLoupe = IDiamondLoupe(apolloX);
        feeManager = IFeeManager(apolloX);
        hookManager = IHookManager(apolloX);
        limitOrder = ILimitOrder(apolloX);
        oraclePrice = IOraclePrice(apolloX);
        orderAndTradeHistory = IOrderAndTradeHistory(apolloX);
        pairsManager = IPairsManager(apolloX);
        pausable = IPausable(apolloX);
        predictUpDown = IPredictUpDown(apolloX);
        predictionManager = IPredictionManager(apolloX);
        priceFacade = IPriceFacade(apolloX);
        slippageManager = ISlippageManager(apolloX);
        stakeReward = IStakeReward(apolloX);
        timeLock = ITimeLock(apolloX);
        trading = ITrading(apolloX);
        tradingChecker = ITradingChecker(apolloX);
        tradingClose = ITradingClose(apolloX);
        tradingConfig = ITradingConfig(apolloX);
        tradingCore = ITradingCore(apolloX);
        tradingOpen = ITradingOpen(apolloX);
        tradingPortal = ITradingPortal(apolloX);
        tradingReader = ITradingReader(apolloX);
        vault = IVault(apolloX);

        //set label to other address
        vm.label(0x55d398326f99059fF775485246999027B3197955, "BUSD");


        // set label to address
        vm.label(0x1b6F2d3844C6ae7D56ceb3C3643b9060ba28FEb0, "ApolloProxy");
        vm.label(0x4E47057f45adF24ba41375a175dA0357cB3480E5, "ALP");

        vm.label(0xc370Ae142b4444BEA0F7bC5D638B23B3302f4477, "NewAlpManagerFacet");
        vm.label(0x61595c597fB5b00067507d8850E5c9161406Ae9c, "DiamondCutFacet");
        vm.label(0x903441522f439304Ec39DD34DA67074aa32A17a5, "DiamondLoupeFacet");
        vm.label(0x01cfD0d1F556AC279Da0924602883b2D6973F51c, "AccessControlEnumerableFacet");
        vm.label(0x9bB035B78c9037bDde0c4246611A3b2c45F69D66, "ApxRewardFacet");
        vm.label(0x99f360bE1Ff828266F5Bf20ded3aD209D3d62920, "PausableFacet");
        vm.label(0xF93F04eefDe067C56800df6F685A76168F777220, "ChainlinkPriceFacet");
        vm.label(0x967B50407B58fB963929Bbfae63c454C8D194F73, "VaultFacet");
        vm.label(0x6Caa8FE103243CD25306adBe4C5d8a14963a57c9, "PriceFacadeFacet");
        vm.label(0xEC050cfDF99002b6A5cea9c4b1602B241c11e5F5, "StakeRewardFacet");
        vm.label(0x9Ea7616CDADcCb488b0cdFaB424576f7A6cE1ABA, "FeeManagerFacet");
        vm.label(0x009230B8e92D1a798FF98126F664aAf5c63C2De9, "PairsManagerFacet");
        vm.label(0x41a5814536cDB3cd096802C0fd610a2158577044, "BrokerManagerFacet");
        vm.label(0x010D2fA0A62F2243819724992d8BCaA4582fC021, "LimitOrderFacet");
        vm.label(0x69DE8A24bC698307b92867776aCE8A8B45175553, "TradingCheckerFacet");
        vm.label(0x52AE9016f29763cF5ED6985771F04e1cF694d94B, "TradingConfigFacet");
        vm.label(0xb3f48DE72155e866dfdc301f55B435D1Ee805ef4, "TradingCoreFacet");
        vm.label(0x58341Fc230A58a87642672c8799Fc98B3Df4Aa69, "TradingPortalFacet");
        vm.label(0x3a868944a5C78fD1C76F6437064E50ff3F75423A, "TradingReaderFacet");
        vm.label(0xdbe2b7e92f00dBd70478199577393bE5BBe37201, "TradingOpenFacet");
        vm.label(0xb203d3b25d8C5d5E9d1f266E32eCd205F0449c68, "TradingCloseFacet");
        vm.label(0xb8860d150dDcb1F3f71EEa00D005d787D124Da33, "PredictionManagerFacet");
        vm.label(0xc2DA30e062E7E78e7E2E1a3Ffc40734D5d258D81, "SlippageManagerFacet");
        vm.label(0x73293578681cFcf72C8C2d9b9eF526A7454445a4, "TimeLockFacet");
        vm.label(0xAcb897fCB7E21aB392C5794b29E2FF4aF34a098A, "PredictUpDownFacet");
        vm.label(0xaD2548773Ef7C880DE96Acba1eF02215Df7611f6, "TransitionFacet");
        vm.label(0xee5Be604B964222Db9f8d4e11F77eA189476DBD6, "HookManagerFacet");
    }
}
