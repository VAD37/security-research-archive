// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {PRBProxy} from "prb-proxy/PRBProxy.sol";

import {WAD} from "../utils/Math.sol";

import {IntegrationTestBase} from "./integration/IntegrationTestBase.sol";
import {LinearInterestRateModelV3} from "@gearbox-protocol/core-v3/contracts/pool/LinearInterestRateModelV3.sol";
import {PermitParams} from "../proxy/TransferAction.sol";
import {PoolAction, PoolActionParams, Protocol} from "../proxy/PoolAction.sol";

import {ApprovalType, PermitParams} from "../proxy/TransferAction.sol";
import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";
import {PermitMaker} from "./utils/PermitMaker.sol";
import {PositionAction4626} from "../proxy/PositionAction4626.sol";

import {PoolV3, IPoolV3} from "../PoolV3.sol";
import {Flashlender} from "../Flashlender.sol";
import {VaultRegistry} from "../VaultRegistry.sol";

import {IVault, JoinKind, JoinPoolRequest} from "../vendor/IBalancerVault.sol";
import {Test, console} from "forge-std/Test.sol";
import {CDPVault} from "../CDPVault.sol";
import {PositionAction20} from "../proxy/PositionAction20.sol";
import {Flashlender} from "../Flashlender.sol";
import {VaultRegistry} from "../VaultRegistry.sol";
import {PendleMarket} from "lib/pendle-core-v2-public/contracts/core/Market/PendleMarket.sol";
//only test mainvault without proxy action and stuff.

contract DebugTest is IntegrationTestBase {
    using SafeERC20 for ERC20;

    // user
    PRBProxy userProxy;
    address user;
    uint256 constant userPk = 0x12341234;

    // cdp vaults
    CDPVault pendleVault_STETH;
    ERC20 PENDLE = ERC20(0x808507121B80c02388fAd14726482e061B8da827);
    // actions
    PositionAction20 positionAction;

    PendleMarket market = PendleMarket(address(PENDLE_LP_STETH));
    address pendleOwner = 0x1FcCC097db89A86Bfc474A1028F93958295b1Fb7;
    address weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

    function setUp() public override {
        usePatchedDeal = true;
        super.setUp();

        // configure permissions and system settings
        setGlobalDebtCeiling(15_000_000 ether);

        // deploy vaults
        pendleVault_STETH = createCDPVault(
            PENDLE_LP_STETH, // token
            5_000_000 ether, // debt ceiling
            0, // debt floor
            1.25 ether, // liquidation ratio
            1.0 ether, // liquidation penalty
            1.05 ether // liquidation discount
        );

        createGaugeAndSetGauge(address(pendleVault_STETH), address(PENDLE_LP_STETH));

        // configure oracle spot prices
        oracle.updateSpot(address(PENDLE_LP_STETH), 3500 ether);

        // setup user and userProxy
        user = vm.addr(0x12341234);
        userProxy = PRBProxy(payable(address(prbProxyRegistry.deployFor(user))));

        // deploy position actions
        positionAction =
            new PositionAction20(address(flashlender), address(swapAction), address(poolAction), address(vaultRegistry));

        vm.label(user, "user");
        vm.label(address(userProxy), "userProxy");
        vm.label(address(PENDLE_LP_STETH), "PENDLE_LP_STETH");
        vm.label(address(pendleVault_STETH), "pendleVault_STETH");
        vm.label(address(positionAction), "positionAction");
    }
    //override setup
    //overide: change to manual deposit first

    function createCore() internal override {
        LinearInterestRateModelV3 irm = new LinearInterestRateModelV3({
            U_1: 85_00,
            U_2: 95_00,
            R_base: 10_00,
            R_slope1: 20_00,
            R_slope2: 30_00,
            R_slope3: 40_00,
            _isBorrowingMoreU2Forbidden: false
        });
        createAddressProvider();

        liquidityPool = new PoolV3({
            addressProvider_: address(addressProvider),
            underlyingToken_: address(mockWETH),
            interestRateModel_: address(irm),
            totalDebtLimit_: initialGlobalDebtCeiling,
            name_: "Loop Liquidity Pool",
            symbol_: "lpETH "
        });

        underlyingToken = mockWETH;

        // uint256 availableLiquidity = 1_000_000 ether;
        // mockWETH.mint(address(this), availableLiquidity);
        // mockWETH.approve(address(liquidityPool), availableLiquidity);
        // liquidityPool.deposit(availableLiquidity, address(this));

        flashlender = new Flashlender(IPoolV3(address(liquidityPool)), 0); // no fee
        liquidityPool.setCreditManagerDebtLimit(address(flashlender), type(uint256).max);
        vaultRegistry = new VaultRegistry();
    }

    function getForkBlockNumber() internal pure virtual override(IntegrationTestBase) returns (uint256) {
        return 20451703;
    }

    function testDebug3() public {
        
    }

    // function testDebug2() public {
    //     //@proof show that CDPvault receive rewards token which is PENDLE token.
    //     // when rewarder transfer PENDLE token to PendleMarket. which is Pendle LP token.
    //     // accrued rewards automatically transfer to CDPVault everytime time user transfer LP token to vault.
    //     // all rewards receive automatically without any further action from user.
    //     //Pendle token now stuck inside vault.
    //     console.log("--- Start Debug ---");
    //     console.log("poolToken: %s", address(pendleVault_STETH.token()));
    //     user = 0xfF43C5727FbFC31Cb96e605dFD7546eb8862064C; //have 200 stETH LP
    //     liquidityPool.setWithdrawFee(99);
    //     // liquidityPool.setLock(false);

    //     vm.prank(0xF977814e90dA44bFA03b6295A0616a897441aceC);
    //     PENDLE.transfer(address(this), 1_000_000e18);

    //     PENDLE.transfer(address(user), 10_000e18); //acrrued rewards
    //     PENDLE.transfer(address(market), 10_000e18); //acrrued rewards

    //     uint256 availableLiquidity = 100 ether;
    //     mockWETH.mint(user, 10000 ether);

    //     vm.startPrank(user);
    //     mockWETH.approve(address(liquidityPool), type(uint256).max);
    //     liquidityPool.deposit(availableLiquidity, address(user));

    //     (uint128 index, uint128 lastBalance) = market.rewardState(address(PENDLE));
    //     console.log("index: %e", index);
    //     console.log("lastBalance: %e", lastBalance);

    //     // printPool();
    //     console.log("-skip 30 days");
    //     skip(30 days);
    //     vm.roll(block.number + 1);

    //     // printPool();
    //     // working with CDP Vault
    //     // 1WETH = 0.88 stETH =1 LP stETH
    //     //assume we have 10 stETH

    //     (index, lastBalance) = market.rewardState(address(PENDLE));
    //     console.log("index2: %e", index);
    //     console.log("lastBalance2: %e", lastBalance);
    //     console.log("PENDLE balanceOf Vault _ before deposit: %e", PENDLE.balanceOf(address(pendleVault_STETH)));
    //     market.approve(address(pendleVault_STETH), type(uint256).max);
    //     //deposit to Vault_STETH
    //     pendleVault_STETH.deposit(user, 100 ether);
    //     pendleVault_STETH.deposit(user, 300 ether);
    //     PENDLE.transfer(address(market), 10_000e18); //give acrrued rewards
    //     (index, lastBalance) = market.rewardState(address(PENDLE));
    //     console.log("index3: %e", index);
    //     console.log("lastBalance3: %e", lastBalance);
    //     skip(90 days);
    //     vm.roll(block.number + 1);
    //     (index, lastBalance) = market.rewardState(address(PENDLE));
    //     console.log("index4: %e", index);
    //     console.log("lastBalance4: %e", lastBalance);
    //     console.log("PENDLE balanceOf Vault _ after deposit: %e", PENDLE.balanceOf(address(pendleVault_STETH)));
    //     address[] memory rewardsToken = market.getRewardTokens();
    //     for (uint256 i = 0; i < rewardsToken.length; i++) {
    //         console.log("rewardsToken: %s", rewardsToken[i]);
    //     }
    //     uint256[] memory rewardsOut1 = market.redeemRewards(user);
    //     uint256[] memory rewardsOut2 = market.redeemRewards(address(pendleVault_STETH));
    //     rewardsOut2 = market.redeemRewards(address(pendleVault_STETH));
    //     (index, lastBalance) = market.rewardState(address(PENDLE));
    //     console.log("index5: %e", index);
    //     console.log("lastBalance5: %e", lastBalance);
    //     console.log("PENDLE balanceOf User: %e", PENDLE.balanceOf(user));
    //     console.log("PENDLE balanceOf Vault _ After claim rewards: %e", PENDLE.balanceOf(address(pendleVault_STETH)));
    //     console.log("rewardsOut1: %e", rewardsOut1[0]);
    //     console.log("rewardsOut2: %e", rewardsOut2[0]);
    //     //we have 100 ETH in pool,
    //     // 400 ETH in vault.
    //     printPool();

    //     vm.stopPrank();
    // }
    // function _testDebug1() public {
    //     console.log("--- Start Debug ---");
    //     console.log("poolToken: %s",address( pendleVault_STETH.token()));
    //     user = 0xfF43C5727FbFC31Cb96e605dFD7546eb8862064C; //have 200 stETH LP
    //     liquidityPool.setWithdrawFee(99);
    //     // liquidityPool.setLock(false);

    //     uint256 availableLiquidity = 100 ether;
    //     mockWETH.mint(user, 10000 ether);

    //     //pendle LP ETH have hidden rewards mechanism. Does it affect pool who hold these token too?
    //     // vm.prank(0xfF43C5727FbFC31Cb96e605dFD7546eb8862064C);
    //     // // PENDLE_LP_STETH.transfer(user, 0 ether);
    //     // PENDLE_LP_STETH.transfer(user, 10 ether);

    //     vm.startPrank(user);
    //     mockWETH.approve(address(liquidityPool), type(uint256).max);
    //     liquidityPool.deposit(availableLiquidity, address(user));

    //     // printPool();
    //     console.log("-skip 30 days");
    //     skip(30 days);

    //     // printPool();
    //     // working with CDP Vault
    //     // 1WETH = 0.88 stETH =1 LP stETH
    //     //assume we have 10 stETH

    //     PENDLE_LP_STETH.approve(address(pendleVault_STETH), type(uint256).max);
    //     //deposit to Vault_STETH
    //     pendleVault_STETH.deposit(user, 100 ether);
    //     pendleVault_STETH.deposit(user, 300 ether);
    //     skip(30 days);

    //     address[] memory rewardsToken = market.getRewardTokens();
    //     for (uint256 i = 0; i < rewardsToken.length; i++) {
    //         console.log("rewardsToken: %s", rewardsToken[i]);
    //     }
    //     uint256[] memory rewardsOut1 =  market.redeemRewards(user);
    //     uint256[] memory rewardsOut2 = market.redeemRewards(address(pendleVault_STETH));
    //     rewardsOut2 = market.redeemRewards(address(pendleVault_STETH));

    //     console.log("rewardsOut1: %e", rewardsOut1[0]);
    //     console.log("rewardsOut2: %e", rewardsOut2[0]);
    //     //we have 100 ETH in pool,
    //     // 400 ETH in vault.
    //     printPool();

    //     vm.stopPrank();
    // }

    function printPool() internal view {
        console.log("--- Pool Info ---");
        //print all view function from pool
        // PoolV3 pool = PoolV3(address(liquidityPool));
        // console.log("acl: ", liquidityPool.acl());
        // console.log("addressProvider: ", liquidityPool.addressProvider());
        // console.log("asset: ", liquidityPool.asset());
        console.log("availableLiquidity: %e", liquidityPool.availableLiquidity());
        console.log("baseInterestIndex: %e", liquidityPool.baseInterestIndex());
        console.log("baseInterestIndexLU: %e", liquidityPool.baseInterestIndexLU());
        console.log("baseInterestRate: %e", liquidityPool.baseInterestRate());
        console.log("calcAccruedQuotaInterest: %e", liquidityPool.calcAccruedQuotaInterest());
        // console.log("contractsRegister: ", liquidityPool.contractsRegister());
        // console.log("controller: ", liquidityPool.controller());
        // console.log("creditManager length: ", liquidityPool.creditManagers().length);
        // console.log("creditManager length: ", liquidityPool.creditManagers()[0]);
        // console.log("decimals: ", liquidityPool.decimals());
        console.log("locked: ", liquidityPool.locked());
        // console.log("maxDeposit: ", liquidityPool.maxDeposit(address(this)));
        // console.log("maxMint: ", liquidityPool.maxMint(address(this)));
        // console.log("maxRedeem: ", liquidityPool.maxRedeem(address(this)));
        // console.log("maxWithdraw: ", liquidityPool.maxWithdraw(address(this)));
        // console.log("name: ", liquidityPool.name());
        // console.log("paused: ", liquidityPool.paused());
        // console.log("poolQuotaKeeper: ", liquidityPool.poolQuotaKeeper());
        console.log("quotaRevenue: %e", liquidityPool.quotaRevenue());
        console.log("supplyRate: %e", liquidityPool.supplyRate());
        // console.log("symbol: ", liquidityPool.symbol());
        console.log("totalAssets: %e", liquidityPool.totalAssets());
        console.log("totalSupply: %e", liquidityPool.totalSupply());
        console.log("totalBorrowed: %e", liquidityPool.totalBorrowed());
        console.log("totalDebtLimit: %e", liquidityPool.totalDebtLimit());
        // console.log("treasury: ", liquidityPool.treasury());
        // console.log("underlyingToken: ", liquidityPool.underlyingToken());
        console.log("withdrawFee: %e", uint(liquidityPool.withdrawFee()));
        console.log("--- Vault Info ---");
        console.log("token Supply: %e", market.balanceOf(address(pendleVault_STETH)));
        console.log("activeBalance: %e", market.activeBalance(address(pendleVault_STETH)));
        console.log("totalDebt: %e", pendleVault_STETH.totalDebt());
        console.log("spotPrice: %e", pendleVault_STETH.spotPrice());
        console.log("--- End Pool Info ---");

        //           --- Pool Info ---
        //   acl:  0xaE79994bE4fDfd2816b951a2392ba6acDE3e9A61
        //   addressProvider:  0x9e8e0510dc2e80751e4E5894095a162e62d940b6
        //   asset:  0x825e0655358b0627957a2B8640E1D51aC36e35Ef
        //   availableLiquidity:  0
        //   baseInterestIndex:  1000000000000000000000000000
        //   baseInterestIndexLU:  1000000000000000000000000000
        //   baseInterestRate:  0
        //   calcAccruedQuotaInterest:  0
        //   contractsRegister:  0x0B01F6613f1b7c5bd1a9cB24908E6c383778C25C
        //   controller:  0xC15d2bA57D126E6603240E89437efD419cE329D2
        //   creditManager length:  1
        //   decimals:  18
        //   locked:  true
        //   maxDeposit:  115792089237316195423570985008687907853269984665640564039457584007913129639935
        //   maxMint:  115792089237316195423570985008687907853269984665640564039457584007913129639935
        //   maxRedeem:  0
        //   maxWithdraw:  0
        //   name:  Loop Liquidity Pool
        //   paused:  false
        //   poolQuotaKeeper:  0xBf26C01490F8b07eD6C168ff425192e3fD3d9473
        //   quotaRevenue:  0
        //   supplyRate:  0
        //   symbol:  lpETH
        //   totalAssets:  0
        //   totalSupply:  0
        //   totalBorrowed:  0
        //   totalDebtLimit:  100000000000000000000000000000
        //   treasury:  0xf43Bca55E8091977223Fa5b776E23528D205dcA8
        //   underlyingToken:  0x825e0655358b0627957a2B8640E1D51aC36e35Ef
        //   withdrawFee:  0
    }
}
