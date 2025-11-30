// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../reward/interfaces/IWETH.sol";

//ACL
import {LinearInterestRateModelV3} from "@gearbox-protocol/core-v3/contracts/pool/LinearInterestRateModelV3.sol";
import {ACL} from "@gearbox-protocol/core-v2/contracts/core/ACL.sol";
import {AddressProviderV3} from "@gearbox-protocol/core-v3/contracts/core/AddressProviderV3.sol";
import {ContractsRegister} from "@gearbox-protocol/core-v2/contracts/core/ContractsRegister.sol";
import "@gearbox-protocol/core-v3/contracts/interfaces/IAddressProviderV3.sol";

import {CDPVault} from "../CDPVault.sol";
import {SwapAction} from "../proxy/SwapAction.sol";
import {PoolAction} from "../proxy/PoolAction.sol";
import {PositionAction20} from "../proxy/PositionAction20.sol";
import {PositionAction4626} from "../proxy/PositionAction4626.sol";
import {PoolV3, IPoolV3} from "../PoolV3.sol";
import {Flashlender} from "../Flashlender.sol";
import {VaultRegistry} from "../VaultRegistry.sol";

import {IVault, JoinKind, JoinPoolRequest} from "../vendor/IBalancerVault.sol";
import {Test, console} from "forge-std/Test.sol";

contract ForkTest is Test {
    using SafeERC20 for ERC20;

    // address wstETH_bb_a_WETH_BPTl = 0x41503C9D499ddbd1dCdf818a1b05e9774203Bf46;
    // bytes32 poolId = 0x41503c9d499ddbd1dcdf818a1b05e9774203bf46000000000000000000000594;

    // address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    // address constant bbaweth = 0xbB6881874825E60e1160416D6C426eae65f2459E; //balancerV3 aave-WETH
    // IWETH WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // //deploy
    // LinearInterestRateModelV3 irm;
    // ACL acl;
    // AddressProviderV3 addressProvider;
    // ContractsRegister contractsRegister;

    // PoolV3 pool;
    // Flashlender flashlender;
    // VaultRegistry vaultRegistry;
    // SwapAction swapAction;
    // PoolAction poolAction;

    // PositionAction20 positionAction20;
    // PositionAction4626 positionAction4626;

    // function setUp() public {
    //     vm.createSelectFork(vm.rpcUrl("mainnet"), 17055414);
    //     //replicated from Deployment script. similar to TestBase.sol

    //     _deployGearBox();
    //     _deployFlashLender();
    //     _deployActions();
    //     //there is PRB Proxy 0x584009E9eDe26e212182c9745F5c000191296a78
    //     // seem like used to craft user signing message for testing purpose. not needed here
    //     // ERC165 plugins attached to proxy PRB.

    //     // vm.label(BALANCER_VAULT, "balancer");
    //     // vm.label(wstETH, "wstETH");
    //     // vm.label(bbaweth, "bbaweth");
    //     // vm.label(wstETH_bb_a_WETH_BPTl, "wstETH-bb-a-WETH-BPTl");

    //     // vm.label(address(irm), "interestRateModelV3");
    //     // vm.label(address(acl), "acl");
    //     // vm.label(address(addressProvider), "addressProvider");
    //     // vm.label(address(contractsRegister), "contractsRegister");
    //     // vm.label(address(pool), "PoolV3");
    //     // vm.label(address(flashlender), "flashlender");
    //     // vm.label(address(vaultRegistry), "vaultRegistry");
    // }

    // function _deployGearBox() internal {
    //     irm = new LinearInterestRateModelV3({
    //         U_1: 85_00, // U_1
    //         U_2: 95_00, // U_2
    //         R_base: 10_00, // R_base
    //         R_slope1: 20_00, // R_slope1
    //         R_slope2: 30_00, // R_slope2
    //         R_slope3: 40_00, // R_slope3
    //         _isBorrowingMoreU2Forbidden: false
    //     });
    //     //ACL singleton contracts address provider. based on gearbox. unnecessary complicated
    //     acl = new ACL();
    //     addressProvider = new AddressProviderV3(address(acl));
    //     addressProvider.setAddress(AP_WETH_TOKEN, address(WETH), false);
    //     addressProvider.setAddress(AP_TREASURY, treasury, false);
    //     contractsRegister = new ContractsRegister(address(addressProvider));
    //     addressProvider.setAddress(AP_CONTRACTS_REGISTER, address(contractsRegister), false);

    //     // Pool V3
    //     uint initialGlobalDebtCeiling = 100_000_000e18;
    //     pool = new PoolV3({
    //         addressProvider_: address(addressProvider),
    //         underlyingToken_: address(WETH),
    //         interestRateModel_: address(irm),
    //         totalDebtLimit_: initialGlobalDebtCeiling,
    //         name_: "Loop Liquidity Pool",
    //         symbol_: "lpETH "
    //     });
    // }

    // function _deployFlashLender() internal {
    //     flashlender = new Flashlender(IPoolV3(address(pool)), 0); // no fee
    //     pool.setCreditManagerDebtLimit(address(flashlender), type(uint256).max);
    //     vaultRegistry = new VaultRegistry();
    // }

    // function _deployActions() internal {
    //     // deploy position actions
    //     swapAction = new SwapAction(balancerVault, univ3Router);
    //     poolAction = new PoolAction(BALANCER_VAULT);
    //     positionAction20 =
    //         new PositionAction20(address(flashlender), address(swapAction), address(poolAction), address(vaultRegistry));
    //     positionAction4626 = new PositionAction4626(
    //         address(flashlender), address(swapAction), address(poolAction), address(vaultRegistry)
    //     );
    // }

    // function printPool() internal {
    //     console.log("--- Pool Info ---");
    //     //print all view function from pool
    //     PoolV3 liquidityPool = PoolV3(address(pool));
    //     // console.log("acl: ", liquidityPool.acl());
    //     // console.log("addressProvider: ", liquidityPool.addressProvider());
    //     // console.log("asset: ", liquidityPool.asset());
    //     console.log("availableLiquidity: %e", liquidityPool.availableLiquidity());
    //     console.log("baseInterestIndex: %e", liquidityPool.baseInterestIndex());
    //     console.log("baseInterestIndexLU: %e", liquidityPool.baseInterestIndexLU());
    //     console.log("baseInterestRate: %e", liquidityPool.baseInterestRate());
    //     console.log("calcAccruedQuotaInterest: %e", liquidityPool.calcAccruedQuotaInterest());
    //     // console.log("contractsRegister: ", liquidityPool.contractsRegister());
    //     // console.log("controller: ", liquidityPool.controller());
    //     // console.log("creditManager length: ", liquidityPool.creditManagers().length);
    //     // console.log("creditManager length: ", liquidityPool.creditManagers()[0]);
    //     // console.log("decimals: ", liquidityPool.decimals());
    //     console.log("locked: ", liquidityPool.locked());
    //     // console.log("maxDeposit: ", liquidityPool.maxDeposit(address(this)));
    //     // console.log("maxMint: ", liquidityPool.maxMint(address(this)));
    //     // console.log("maxRedeem: ", liquidityPool.maxRedeem(address(this)));
    //     // console.log("maxWithdraw: ", liquidityPool.maxWithdraw(address(this)));
    //     // console.log("name: ", liquidityPool.name());
    //     // console.log("paused: ", liquidityPool.paused());
    //     // console.log("poolQuotaKeeper: ", liquidityPool.poolQuotaKeeper());
    //     console.log("quotaRevenue: %e", liquidityPool.quotaRevenue());
    //     console.log("supplyRate: %e", liquidityPool.supplyRate());
    //     // console.log("symbol: ", liquidityPool.symbol());
    //     console.log("totalAssets: %e", liquidityPool.totalAssets());
    //     console.log("totalSupply: %e", liquidityPool.totalSupply());
    //     console.log("totalBorrowed: %e", liquidityPool.totalBorrowed());
    //     console.log("totalDebtLimit: %e", liquidityPool.totalDebtLimit());
    //     // console.log("treasury: ", liquidityPool.treasury());
    //     // console.log("underlyingToken: ", liquidityPool.underlyingToken());
    //     console.log("withdrawFee: %e", uint(liquidityPool.withdrawFee()));

    //     //           --- Pool Info ---
    //     //   acl:  0xaE79994bE4fDfd2816b951a2392ba6acDE3e9A61
    //     //   addressProvider:  0x9e8e0510dc2e80751e4E5894095a162e62d940b6
    //     //   asset:  0x825e0655358b0627957a2B8640E1D51aC36e35Ef
    //     //   availableLiquidity:  0
    //     //   baseInterestIndex:  1000000000000000000000000000
    //     //   baseInterestIndexLU:  1000000000000000000000000000
    //     //   baseInterestRate:  0
    //     //   calcAccruedQuotaInterest:  0
    //     //   contractsRegister:  0x0B01F6613f1b7c5bd1a9cB24908E6c383778C25C
    //     //   controller:  0xC15d2bA57D126E6603240E89437efD419cE329D2
    //     //   creditManager length:  1
    //     //   decimals:  18
    //     //   locked:  true
    //     //   maxDeposit:  115792089237316195423570985008687907853269984665640564039457584007913129639935
    //     //   maxMint:  115792089237316195423570985008687907853269984665640564039457584007913129639935
    //     //   maxRedeem:  0
    //     //   maxWithdraw:  0
    //     //   name:  Loop Liquidity Pool
    //     //   paused:  false
    //     //   poolQuotaKeeper:  0xBf26C01490F8b07eD6C168ff425192e3fD3d9473
    //     //   quotaRevenue:  0
    //     //   supplyRate:  0
    //     //   symbol:  lpETH
    //     //   totalAssets:  0
    //     //   totalSupply:  0
    //     //   totalBorrowed:  0
    //     //   totalDebtLimit:  100000000000000000000000000000
    //     //   treasury:  0xf43Bca55E8091977223Fa5b776E23528D205dcA8
    //     //   underlyingToken:  0x825e0655358b0627957a2B8640E1D51aC36e35Ef
    //     //   withdrawFee:  0
    // }
}
