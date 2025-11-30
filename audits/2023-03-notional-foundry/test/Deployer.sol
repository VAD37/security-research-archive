// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.7.6;
pragma abicoder v2;
import "forge-std/Test.sol";
import "../src/global/Types.sol";
import "../src/external/governance/NoteERC20.sol";
import "../src/proxy/nProxy.sol";
import "../src/mocks/MockWETH.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockAggregator.sol";
// import libraries
import "../src/external/SettleAssetsExternal.sol";
import "../src/external/actions/GovernanceAction.sol";
import "../src/external/Views.sol";
import "../src/external/actions/InitializeMarketsAction.sol";
import "../src/external/actions/nTokenAction.sol";
import "../src/external/actions/BatchAction.sol";
import "../src/external/actions/AccountAction.sol";
import "../src/external/actions/ERC1155Action.sol";
import "../src/external/actions/LiquidateCurrencyAction.sol";
import "../src/external/CalculationViews.sol";
import "../src/external/actions/LiquidatefCashAction.sol";
import "../src/external/actions/TreasuryAction.sol";
import "../src/external/actions/VaultAction.sol";
import "../src/external/actions/VaultAccountAction.sol";
import "../src/external/actions/VaultLiquidationAction.sol";
import "../src/external/actions/VaultAccountHealth.sol";

//import router and proxy
import "../src/external/Router.sol";
import "../src/external/PauseRouter.sol";
import "../src/external/governance/GovernorAlpha.sol";

contract Deployer is Test {
    // struct primeCashScalars {
    //     uint16 ETH = 50;
    //     uint16 DAI = 49;
    //     uint16 USDC = 48;
    //     uint16 WBTC = 47;
    // }

    // Notional child contracts
    GovernanceAction public governanceAction;
    Views public views;
    InitializeMarketsAction public initializeMarketsAction; // library converted to contract
    nTokenAction public ntokenAction;
    BatchAction public batchAction;
    AccountAction public accountAction;
    ERC1155Action public eRC1155Action;
    LiquidateCurrencyAction public liquidateCurrencyAction;
    CalculationViews public calculationViews;
    LiquidatefCashAction public liquidatefCashAction;
    TreasuryAction public treasuryAction;
    VaultAction public vaultAction;
    VaultAccountAction public vaultAccountAction;
    VaultLiquidationAction public vaultLiquidationAction;
    VaultAccountHealth public vaultAccountHealth;

    // 3rd party contracts
    address public comptroller;
    address public nPriceOracle;
    IRebalancingStrategy public REBALANCING_STRATEGY;

    // main proxy contract
    PauseRouter public pauseRouter;
    Router public router;
    nProxy public proxy;

    // stuff
    address payable public noteERC20; // nProxy
    address payable public governance; // normal contract

    MockERC20 public DAI;
    MockAggregator public DAI_AGGREGATOR;
    MockERC20 public USDC;
    MockAggregator public USDC_AGGREGATOR;
    MockERC20 public WBTC;
    MockAggregator public WBTC_AGGREGATOR;
    MockERC20 public NOMINT;
    MockAggregator public NOMINT_AGGREGATOR;
    MockERC20 public USDT;
    MockAggregator public USDT_AGGREGATOR;

    function initTestEnvironment() public {
        deployMockCurrencies();
        // deploy from artifacts json failed. So manually deploy code from original source instead
        deployComp();
        deployNoteERC20();
        // deployGovernance();

        deployNotional();
    }

    function deployComp() private {
        // use cheat to deploy artifacts json
        nPriceOracle = deployCode("nPriceOracle.sol");
        comptroller = deployCode("nComptroller.sol");
        // COMPTROLLER._setMaxAssets(20);
        // COMPTROLLER._setPriceOracle(nPriceOracle);
        emit log_named_address("nPriceOracle", nPriceOracle);
        emit log_named_address("comptroller", comptroller);
        comptroller.call(abi.encodeWithSignature("_setMaxAssets(uint256)", 20));
        comptroller.call(
            abi.encodeWithSignature("_setPriceOracle(address)", nPriceOracle)
        );
    }

    function deployGovernance() private {
        uint96 quorumVotes_ = 4_000_000e8;
        uint96 proposalThreshold_ = 1_000_000e8;
        uint32 votingDelayBlocks_ = 0;
        uint32 votingPeriodBlocks_ = 0;
        INoteERC20 note_ = INoteERC20(noteERC20);
        address guardian_ = address(this);
        uint256 minDelay_ = 0;
        uint256 proposalCount_ = 0;
        governance = address(
            new GovernorAlpha(
                quorumVotes_,
                proposalThreshold_,
                votingDelayBlocks_,
                votingPeriodBlocks_,
                note_,
                guardian_,
                minDelay_,
                proposalCount_
            )
        );
    }

    function deployNoteERC20() private {
        address[1] memory receivers = [address(this)];
        uint96[1] memory amounts = [uint96(100000000e8)];
        address owner = address(this);
        bytes memory data = abi.encodeWithSignature(
            "initialize(address[],uint96[],address)",
            receivers,
            amounts,
            owner
        );
        address logic = address(new NoteERC20());
        noteERC20 = address(new nProxy(logic, data));
    }

    function deployMockCurrencies() private {
        // "DAI": {"name": "Dai Stablecoin", "decimals": 18, "fee": 0, "rate": 0.01e18},
        // "USDC": {"name": "USD Coin", "decimals": 6, "fee": 0, "rate": 0.01e18},
        // "WBTC": {"name": "Wrapped Bitcoin", "decimals": 8, "fee": 0, "rate": 100e18},
        // "COMP": {"name": "Compound COMP", "decimals": 18, "fee": 0, "rate": 0.01e18},
        // "NOMINT": {"name": "nonMintable", "decimals": 18, "fee": 0, "rate": 1e18},
        // "USDT": {"name": "Tether", "decimals": 8, "fee": 0.01e18, "rate": 0.01e18},
        DAI = new MockERC20("Dai Stablecoin", "DAI", 18, 0);
        DAI_AGGREGATOR = new MockAggregator(18);
        DAI_AGGREGATOR.setAnswer(0.01e18);

        USDC = new MockERC20("USD Coin", "USDC", 6, 0);
        USDC_AGGREGATOR = new MockAggregator(6);
        USDC_AGGREGATOR.setAnswer(0.01e18);

        WBTC = new MockERC20("Wrapped Bitcoin", "WBTC", 8, 0);
        WBTC_AGGREGATOR = new MockAggregator(8);
        WBTC_AGGREGATOR.setAnswer(100e18);

        USDT = new MockERC20("Tether", "USDT", 8, 0);
        USDT_AGGREGATOR = new MockAggregator(8);
        USDT_AGGREGATOR.setAnswer(0.01e18);

        NOMINT = new MockERC20("nonMintable", "NOMINT", 18, 0);
        NOMINT_AGGREGATOR = new MockAggregator(18);
        NOMINT_AGGREGATOR.setAnswer(1e18);
    }

    function deployNotional() private {
        // deploy a proxy contract link to  router. Then deploy router with all child contracts
        governanceAction = new GovernanceAction(); //admin

        views = new Views();
        initializeMarketsAction = new InitializeMarketsAction();
        ntokenAction = new nTokenAction();
        batchAction = new BatchAction();
        accountAction = new AccountAction();
        eRC1155Action = new ERC1155Action();
        liquidateCurrencyAction = new LiquidateCurrencyAction();
        calculationViews = new CalculationViews();
        liquidatefCashAction = new LiquidatefCashAction();
        treasuryAction = new TreasuryAction(
            Comptroller(comptroller),
            REBALANCING_STRATEGY
        ); //both zero address
        vaultAction = new VaultAction();
        vaultAccountAction = new VaultAccountAction();
        vaultLiquidationAction = new VaultLiquidationAction();
        vaultAccountHealth = new VaultAccountHealth();

        pauseRouter = new PauseRouter(
            address(views),
            address(liquidateCurrencyAction),
            address(liquidatefCashAction),
            address(calculationViews),
            address(vaultAccountHealth)
        );
        Router.DeployedContracts memory deployedContracts = Router
            .DeployedContracts(
                address(governanceAction),
                address(views),
                address(initializeMarketsAction),
                address(ntokenAction),
                address(batchAction),
                address(accountAction),
                address(eRC1155Action),
                address(liquidateCurrencyAction),
                address(liquidatefCashAction),
                address(treasuryAction),
                address(calculationViews),
                address(vaultAccountAction),
                address(vaultAction),
                address(vaultLiquidationAction),
                address(vaultAccountHealth)
            );
        router = new Router(deployedContracts);
        // deploy nProxy
        bytes memory data = abi.encodeWithSignature(
            "initialize(address owner_, address pauseRouter_, address pauseGuardian_)",
            address(this),
            address(pauseRouter),
            address(this)
        );
        address logic = address(router);
        proxy = new nProxy(logic, data);
    }
}
