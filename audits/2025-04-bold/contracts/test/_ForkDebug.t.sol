// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";

import "src/AddressesRegistry.sol";
import "src/BorrowerOperations.sol";
import "src/ActivePool.sol";
import "src/BoldToken.sol";
import "src/CollSurplusPool.sol";
import "src/DefaultPool.sol";
import "src/PriceFeeds/WETHPriceFeed.sol";
import "src/SortedTroves.sol";
import "src/StabilityPool.sol";
import "src/CollateralRegistry.sol";
import "src/TroveManager.sol";
import "src/TroveNFT.sol";
import "src/NFTMetadata/MetadataNFT.sol";
// import "src/InterestRouter.sol";
import "src/GasPool.sol";
import "src/HintHelpers.sol";
import "src/Zappers/WETHZapper.sol";
// import "src/Zappers/GasCompZapper.sol";
// import "src/Zappers/LeverageLSTZapper.sol";

import "src/Interfaces/IMainnetPriceFeed.sol";
import "src/Interfaces/IWETH.sol";

contract ForkDebugTest is Test {

    // Core contracts for WETH. Reading from deployments json file
    address governance = 0x636dEb767Cd7D0f15ca4aB8eA9a9b26E98B426AC;
    CollateralRegistry collateralRegistry = CollateralRegistry(0xd99dE73b95236F69A559117ECD6F519Af780F3f7);
    BoldToken boldToken = BoldToken(0xb01dd87B29d187F3E3a4Bf6cdAebfb97F3D9aB98);
    // HintHelpers hintHelpers;

    //Branches contracts
    AddressesRegistry addressesRegistry;
    ActivePool activePool;
    BorrowerOperations borrowerOperations;
    CollSurplusPool collSurplusPool;
    DefaultPool defaultPool;
    SortedTroves sortedTroves;
    StabilityPool stabilityPool;
    TroveManager troveManager;
    TroveNFT troveNFT;
    MetadataNFT metadataNFT;
    IMainnetPriceFeed priceFeed;
    GasPool gasPool;
    // address interestRouter = 0x636dEb767Cd7D0f15ca4aB8eA9a9b26E98B426AC;//same as Gov
    WETHZapper wethZapper = WETHZapper(payable(0xD929C1927988625f834B9A39b562018CF6DAEDa5));
    // GasCompZapper gasCompZapper;
    // ILeverageZapper leverageZapperCurve;
    // ILeverageZapper leverageZapperUniV3;

    //Others
    IERC20 collToken = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IWETH WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setup() public {
        // some contracts have been changed from previous deployments so we need to etch them. Reusing previous users as data.
        //forking mainnet
        uint256 forkBlock = 22143000;
        string memory rpcURL =
            "https://rpc.ankr.com/eth/9f6e5db150bd7716e21a60eb9acc6f3909c10e43797deb81c8f8d9cc60dcaecc";
        uint256 forkId = vm.createSelectFork(rpcURL, forkBlock);

        //WETH branch have possible exploit
        _switchBranch(1);

        console.log("----------");
        vm.label(address(governance), "governance");
        vm.label(address(collateralRegistry), "collateralRegistry");
        vm.label(address(boldToken), "BOLD");
        vm.label(address(addressesRegistry), "addressesRegistry");
        vm.label(address(activePool), "activePool");
        vm.label(address(borrowerOperations), "borrowerOperations");
        vm.label(address(collSurplusPool), "collSurplusPool");
        vm.label(address(defaultPool), "defaultPool");
        vm.label(address(sortedTroves), "sortedTroves");
        vm.label(address(stabilityPool), "stabilityPool");
        vm.label(address(troveManager), "troveManager");
        vm.label(address(troveNFT), "troveNFT");
        vm.label(address(metadataNFT), "metadataNFT");
        vm.label(address(priceFeed), "priceFeed");
        vm.label(address(gasPool), "gasPool");
        // vm.label(address(interestRouter), "InterestRouter");
        vm.label(address(wethZapper), "wethZapper");
        vm.label(address(WETH), "WETH");
        vm.label(0xaDb6851875B7496E3D565B754d8a79508480a203, "curveUsdcBoldPool");
        vm.label(0xA8bB51606dB8e81F0ac964f0855C20D9e474Ab63, "curveUsdcBoldGauge");
        vm.label(0xa76434D58cCC9b8277180a691148A598Fd073035, "curveUsdcBoldInitiative");
        vm.label(0x29A760138FA530d51a100171cB5CE4DDf506aF2E, "curveLusdBoldPool");
        vm.label(0x3Ac4b6da715E7963BBcfb31dE39A1B139F426223, "curveLusdBoldGauge");
        vm.label(0x4347d2D28A3428dDF1B7cfC7f097b2128a1A0059, "curveLusdBoldInitiative");
        vm.label(0xDc6f869d2D34E4aee3E89A51f2Af6D54F0F7f690, "defiCollectiveInitiative");
        vm.label(0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d, "stakingV1");
        vm.label(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D, "LQTYToken");
        vm.label(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0, "LUSDToken");
    }

    function _switchBranch(uint256 index) internal {
        //1: WETH
        if (index == 1) {
            console.log("Switching to branch WETH");
            addressesRegistry = AddressesRegistry(0x38e1F07b954cFaB7239D7acab49997FBaAD96476);
        } else if (index == 2) {
            console.log("Switching to branch wstETH");
            addressesRegistry = AddressesRegistry(0x2D4ef56cb626E9a4C90c156018BA9CE269573c61);
        } else if (index == 3) {
            console.log("Switching to branch rETH");
            addressesRegistry = AddressesRegistry(0x3b48169809DD827F22C9e0F2d71ff12Ea7A94a2F);
        } else {
            revert("Invalid branch index");
        }
        collToken = IERC20(address(addressesRegistry.collToken()));
        borrowerOperations = BorrowerOperations(address(addressesRegistry.borrowerOperations()));
        troveManager = TroveManager(address(addressesRegistry.troveManager()));
        troveNFT = TroveNFT(address(addressesRegistry.troveNFT()));
        metadataNFT = MetadataNFT(address(addressesRegistry.metadataNFT()));
        stabilityPool = StabilityPool(address(addressesRegistry.stabilityPool()));
        priceFeed = IMainnetPriceFeed(address(addressesRegistry.priceFeed()));
        activePool = ActivePool(address(addressesRegistry.activePool()));
        defaultPool = DefaultPool(address(addressesRegistry.defaultPool()));
        gasPool = GasPool(address(addressesRegistry.gasPoolAddress()));
        collSurplusPool = CollSurplusPool(address(addressesRegistry.collSurplusPool()));
        sortedTroves = SortedTroves(address(addressesRegistry.sortedTroves()));
        // IInterestRouter public interestRouter;
        // IHintHelpers public hintHelpers;
        // IMultiTroveGetter public multiTroveGetter;
        // ICollateralRegistry public collateralRegistry;

        WETH = IWETH(addressesRegistry.WETH());
    }
    function testDebugWETH() public {
        _switchBranch(1);
        _debugPrint();
    }
    // function testDebugWstETH() public {
    //     _switchBranch(2);
    //     _debugPrint();
    // }
    // function testDebugRETH() public {
    //     _switchBranch(3);
    //     _debugPrint();
    // }

    function _debugPrint() public {
        console.log("----- AddressRegistry -----");
        console.log("CCR: %e CriticalSystemCollateral Ratio", addressesRegistry.CCR());
        console.log("MCR: %e MinimumCollateral Ratio", addressesRegistry.MCR());
        console.log("SCR: %e Shutdown system collateral ratio", addressesRegistry.SCR());
        //BCR is not set
        console.log(
            "LIQUIDATION_PENALTY_SP: %e Liquidation penalty Stability Pool", addressesRegistry.LIQUIDATION_PENALTY_SP()
        );
        console.log(
            "LIQUIDATION_PENALTY_REDISTRIBUTION: %e Liquidation penalty Redistribution",
            addressesRegistry.LIQUIDATION_PENALTY_REDISTRIBUTION()
        );
        console.log("collToken: %s", address(addressesRegistry.collToken())); //WETH

        console.log("----- ActivePool -----");
        console.log("collBalance: %e", activePool.getCollBalance());
        console.log("WETHBalance: %e", WETH.balanceOf(address(activePool)));
        console.log("aggRecordedDebt: %e", activePool.aggRecordedDebt());
        console.log("aggWeightedDebtSum: %e", activePool.aggWeightedDebtSum());
        console.log("lastAggUpdateTime: %s", activePool.lastAggUpdateTime());
        console.log("shutdownTime: %s second", activePool.shutdownTime());
        console.log("aggBatchManagementFees: %e", activePool.aggBatchManagementFees());
        console.log("aggWeightedBatchManagementFeeSum: %e", activePool.aggWeightedBatchManagementFeeSum());
        console.log("lastAggBatchManagementFeesUpdateTime: %e", activePool.lastAggBatchManagementFeesUpdateTime());

        console.log("BoldDebt: %e", activePool.getBoldDebt());
        console.log("PendingAggInterest: %e", activePool.calcPendingAggInterest());
        console.log("PendingSPYield: %e", activePool.calcPendingSPYield());
        console.log("PendingAggBatchManagementFee: %e", activePool.calcPendingAggBatchManagementFee());
        TroveChange memory change;
        console.log("AvgInterest: %e", activePool.getNewApproxAvgInterestRateFromTroveChange(change));
        change.debtIncrease = 100000e18;
        change.newWeightedRecordedDebt = 100000e18 * 0.01e18;
        console.log("AvgInterest after 1% debt 100,000 BOLD : %e", activePool.getNewApproxAvgInterestRateFromTroveChange(change));
        //250% debt
        change.debtIncrease = 250000e18;
        change.newWeightedRecordedDebt = 250000e18 * 0.01e18;
        console.log("AvgInterest after 250% debt 100,000 BOLD : %e", activePool.getNewApproxAvgInterestRateFromTroveChange(change));        
        // 1M debt with 0.5% interest
        change.debtIncrease = 1000000e18;
        change.newWeightedRecordedDebt = 1000000e18 * 0.005e18;
        console.log("AvgInterest after 0.5% debt 1,000,000 BOLD : %e", activePool.getNewApproxAvgInterestRateFromTroveChange(change));

        // 1M debt with 250% interest
        change.debtIncrease = 1000000e18;
        change.newWeightedRecordedDebt = 1000000e18 * 2.5e18;
        console.log("AvgInterest after 250% debt 1,000,000 BOLD : %e", activePool.getNewApproxAvgInterestRateFromTroveChange(change));

        console.log("----- BOLD -----");
        console.log("totalSupply: %e", boldToken.totalSupply());
        console.log("balanceOf curve USDC/BOLD: %e", boldToken.balanceOf(0xaDb6851875B7496E3D565B754d8a79508480a203));
        console.log("balanceOf curve LUSD/BOLD: %e", boldToken.balanceOf(0x29A760138FA530d51a100171cB5CE4DDf506aF2E));
        //700K at uniswap pool 0xa77d08b8b586f96fdace020190b694367d43ea3b
        //600K at DAO voter/Bounties. 0xF06016D822943C42e3Cb7FC3a6A3B1889C1045f8 . Old version of Safe Proxy Factory 1.1.1
        //300K at chainlink CCIP crosschain pool: 0x6f580a9bc9e95273a65f73356f9caf92caa1f193
        //200K at balancerV3 0xbA1333333333a1BA1108E8412f11850A5C319bA9
        //curve gauge reward have tiny amount of BOLD < 6k. Hold by only few people

        console.log("----- BorrowerOperations -----");
        console.log("hasBeenShutDown: %s", borrowerOperations.hasBeenShutDown());
        //troveId got from event only. SortedTrove is used to query on chain.
        console.log("----- Collateral -----");
        console.log("totalCollaterals: %s", collateralRegistry.totalCollaterals());
        console.log("baseRate: %e", collateralRegistry.baseRate());
        console.log("getRedemptionRate: %e", collateralRegistry.getRedemptionRate());
        console.log("getRedemptionRateWithDecay: %e", collateralRegistry.getRedemptionRateWithDecay());

        console.log(
            "getRedemptionRateForRedeemedAmount: 500,000 BOLD = %e",
            collateralRegistry.getRedemptionRateForRedeemedAmount(500000e18)
        );
        console.log(
            "getRedemptionRateForRedeemedAmount: 100,000 BOLD = %e",
            collateralRegistry.getRedemptionRateForRedeemedAmount(100000e18)
        );
        console.log(
            "getRedemptionRateForRedeemedAmount: 10000 BOLD = %e",
            collateralRegistry.getRedemptionRateForRedeemedAmount(10000e18)
        );
        console.log("getRedemptionFeeWithDecay: 100ETH = %e", collateralRegistry.getRedemptionFeeWithDecay(100e18));
        console.log("getRedemptionFeeWithDecay: 10ETH = %e", collateralRegistry.getRedemptionFeeWithDecay(10e18));
        console.log("getRedemptionFeeWithDecay: 5ETH = %e", collateralRegistry.getRedemptionFeeWithDecay(5e18));

        console.log(
            "getEffectiveRedemptionFeeInBold: 500,000 BOLD = %e",
            collateralRegistry.getEffectiveRedemptionFeeInBold(500000e18)
        );
        console.log(
            "getEffectiveRedemptionFeeInBold: 100,000 BOLD = %e",
            collateralRegistry.getEffectiveRedemptionFeeInBold(100000e18)
        );
        console.log(
            "getEffectiveRedemptionFeeInBold: 10000 BOLD = %e",
            collateralRegistry.getEffectiveRedemptionFeeInBold(10000e18)
        );

        console.log("----- CollSurplusPool -----");
        console.log("collBalance: %e", collSurplusPool.getCollBalance());
        console.log("collToken balance: %e", collToken.balanceOf(address(collSurplusPool)));

        console.log("----- DefaultPool -----");
        console.log("collBalance: %e", defaultPool.getCollBalance());
        console.log("collToken balance: %e", collToken.balanceOf(address(defaultPool)));

        console.log("----- GasPool -----");
        console.log("gas WETH balance: %e", WETH.balanceOf(address(gasPool)));

        console.log("----- StabilityPool -----");
        console.log("collBalance: %e", stabilityPool.getCollBalance());
        console.log("totalBoldDeposits: %e", stabilityPool.getTotalBoldDeposits());
        console.log("yieldGainsOwed: %e", stabilityPool.getYieldGainsOwed());
        console.log("yieldGainsPending: %e", stabilityPool.getYieldGainsPending());

        console.log("currentScale: %e", stabilityPool.currentScale());
        console.log("currentEpoch: %e", stabilityPool.currentEpoch());
        console.log("lastCollError_Offset: %e", stabilityPool.lastCollError_Offset());
        console.log("lastBoldLossErrorByP_Offset: %e", stabilityPool.lastBoldLossErrorByP_Offset());
        console.log("lastBoldLossError_TotalDeposits: %e", stabilityPool.lastBoldLossError_TotalDeposits());
        console.log("lastYieldError: %e", stabilityPool.lastYieldError());

        console.log("----- TroveManager -----");
        console.log("totalStakes: %e",  uint(vm.load(address(troveManager), bytes32(uint256(13)))));//slot 13
        console.log("totalStakesSnapshot: %e",  uint(vm.load(address(troveManager), bytes32(uint256(14)))));
        console.log("totalCollateralSnapshot: %e",  uint(vm.load(address(troveManager), bytes32(uint256(15)))));
        console.log("L_coll: %e",  uint(vm.load(address(troveManager), bytes32(uint256(16)))));
        console.log("L_boldDebt: %e",  uint(vm.load(address(troveManager), bytes32(uint256(17)))));

        console.log("totalActiveTrove TroveIds.length: %e", uint(vm.load(address(troveManager), bytes32(uint256(20)))));
        console.log("getTroveIdsCount: %e", troveManager.getTroveIdsCount());
        console.log("totalBatchManager batchIds.length: %e", uint(vm.load(address(troveManager), bytes32(uint256(21)))));

        console.log("lastCollError_Redistribution: %e", uint(vm.load(address(troveManager), bytes32(uint256(22)))));
        console.log("lastBoldDebtError_Redistribution: %e", uint(vm.load(address(troveManager), bytes32(uint256(23)))));

        console.log("lastZombieTroveId: %e", troveManager.lastZombieTroveId());
        console.log("shutdownTime: %e", troveManager.shutdownTime());
    }
}
