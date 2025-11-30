#[test_only]
module suitrump_dex::router_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin, mint_for_testing};  // Add Coin type here
    use sui::test_utils::assert_eq;
    use std::string::utf8;
    use suitrump_dex::router::{Self, Router};
    use suitrump_dex::library::{Self};
    use suitrump_dex::factory::{Self, Factory};
    use suitrump_dex::pair::{Self, AdminCap, Pair, LPCoin};  // Updated
    use suitrump_dex::fixed_point_math::{Self};  // Updated
    use suitrump_dex::test_coins::{Self, USDC, USDT,STK1,STK5, STK10};
    use std::debug;


    const ADMIN: address = @0x1;
    const USER: address = @0x2;
    const TEAM_1: address = @0x44;  // 40% of team fee
    const TEAM_2: address = @0x45;  // 50% of team fee
    const DEV: address = @0x46;     // 10% of team fee
    const LOCKER: address = @0x47;
    const BUYBACK: address = @0x48;

    // Test amounts for different scales
    const MILLION: u64 = 1_000_000;                    // 1M tokens
    const HUNDRED_MILLION: u64 = 100_000_000;      // 100B tokens
    const BILLION: u64 = 1_000_000_000;                // 1B tokens
    const TEN_BILLION: u64 = 10_000_000_000;           // 10B tokens
    const FIFTY_BILLION: u64 = 50_000_000_000;         // 50B tokens
    const HUNDRED_BILLION: u64 = 100_000_000_000;      // 100B tokens

    // Large amounts for testing
    const INITIAL_LIQUIDITY_A: u64 = 100_000_000_000;  // 100B tokens
    const INITIAL_LIQUIDITY_B: u64 = 100_000_000_000;  // 100B tokens
    const ADD_LIQUIDITY_A: u64 = 50_000_000_000;       // 50B tokens
    const ADD_LIQUIDITY_B: u64 = 50_000_000_000;       // 50B tokens

    const TRILLION: u64 = 1_000_000_000_000;           // 1T tokens
    const TEN_TRILLION: u64 = 10_000_000_000_000;      // 10T tokens
    const HUNDRED_TRILLION: u64 = 100_000_000_000_000;  // 100T tokens
    const FIFTY_TRILLION: u64 = 50_000_000_000_000;     // 50T tokens

    const TRILLION_BN: u256 = 1_000_000_000_000;           // 1T tokens
    const TEN_TRILLION_BN: u256 = 10_000_000_000_000;      // 10T tokens
    const HUNDRED_TRILLION_BN: u256 = 100_000_000_000_000;  // 100T tokens
    const FIFTY_TRILLION_BN: u256 = 50_000_000_000_000;     // 50T tokens

    const TOKEN_DECIMALS: u8 = 6;  // Both USDC and USDT typically use 6 decimals
    const INITIAL_PRICE_USDC: u64 = 1_000_000;  // $1.00 with 6 decimals
    const INITIAL_PRICE_USDT: u64 = 1_000_000;  // $1.00 with 6 decimals

    fun setup(scenario: &mut Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            debug::print(&b"Setting up test environment...");
            factory::init_for_testing(ts::ctx(scenario));
            pair::init_for_testing(ts::ctx(scenario));
            router::init_for_testing(ts::ctx(scenario));
            debug::print(&b"Setup completed.");
        };
    }

    #[test]
    fun test_large_scale_liquidity() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting large scale liquidity test...");

        // Create initial pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            debug::print(&b"Taking shared objects...");
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            debug::print(&b"Creating pair...");
            let pair_addr = factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );
            debug::print(&b"Pair created with address:");
            debug::print(&pair_addr);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial large liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            debug::print(&b"Taking objects for large liquidity addition...");
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            
            debug::print(&b"Taking pair object...");
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            debug::print(&b"Pair object taken successfully");

            debug::print(&b"Minting large scale test coins...");
            let coin_a = mint_for_testing<sui::sui::SUI>(INITIAL_LIQUIDITY_A, ts::ctx(&mut scenario));
            let coin_b = mint_for_testing<USDC>(INITIAL_LIQUIDITY_B, ts::ctx(&mut scenario));
            debug::print(&b"Large scale test coins minted");

            debug::print(&b"Adding large scale liquidity...");
            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_a,
                coin_b,
                (INITIAL_LIQUIDITY_A as u256),
                (INITIAL_LIQUIDITY_B as u256),
                (INITIAL_LIQUIDITY_A as u256),
                (INITIAL_LIQUIDITY_B as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            debug::print(&b"Checking large scale reserves...");
            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserve0 (Large Scale):");
            debug::print(&reserve0);
            debug::print(&b"Reserve1 (Large Scale):");
            debug::print(&reserve1);

            assert_eq(reserve0, (INITIAL_LIQUIDITY_A as u256));
            assert_eq(reserve1, (INITIAL_LIQUIDITY_B as u256));

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Add more large scale liquidity
        debug::print(&b"Testing additional large scale liquidity...");
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            debug::print(&b"Minting additional large scale test coins...");
            let coin_a = mint_for_testing<sui::sui::SUI>(ADD_LIQUIDITY_A, ts::ctx(&mut scenario));
            let coin_b = mint_for_testing<USDC>(ADD_LIQUIDITY_B, ts::ctx(&mut scenario));

            debug::print(&b"Adding more large scale liquidity...");
            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_a,
                coin_b,
                (ADD_LIQUIDITY_A as u256),
                (ADD_LIQUIDITY_B as u256),
                (ADD_LIQUIDITY_A as u256),
                (ADD_LIQUIDITY_B as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            debug::print(&b"Verifying final large scale reserves...");
            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final Reserve0 (Large Scale):");
            debug::print(&reserve0);
            debug::print(&b"Final Reserve1 (Large Scale):");
            debug::print(&reserve1);

            assert_eq(reserve0, ((INITIAL_LIQUIDITY_A + ADD_LIQUIDITY_A) as u256));
            assert_eq(reserve1, ((INITIAL_LIQUIDITY_B + ADD_LIQUIDITY_B) as u256));

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        debug::print(&b"Large scale test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_huge_scale_liquidity() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting huge scale liquidity test...");

        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            let pair_addr = factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );
            debug::print(&b"Pair created with address:");
            debug::print(&pair_addr);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            // Using 100 billion initial liquidity
            let initial_amount = HUNDRED_BILLION;
            let add_amount = FIFTY_BILLION;

            let coin_a = mint_for_testing<sui::sui::SUI>(initial_amount, ts::ctx(&mut scenario));
            let coin_b = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));

            debug::print(&b"Adding huge scale liquidity...");
            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_a,
                coin_b,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial huge reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            // Add more liquidity
            let coin_a = mint_for_testing<sui::sui::SUI>(add_amount, ts::ctx(&mut scenario));
            let coin_b = mint_for_testing<USDC>(add_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_a,
                coin_b,
                (add_amount as u256),
                (add_amount as u256),
                (add_amount as u256),
                (add_amount as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (final_reserve0, final_reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final huge reserves:");
            debug::print(&final_reserve0);
            debug::print(&final_reserve1);

            assert_eq(final_reserve0, ((initial_amount + add_amount) as u256));
            assert_eq(final_reserve1, ((initial_amount + add_amount) as u256));

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        debug::print(&b"Huge scale test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_uneven_large_liquidity() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"=== Starting Uneven Large Liquidity Test ===");
        
        // Check token ordering
        let is_sui_token0 = factory::is_token0<sui::sui::SUI>(&factory::sort_tokens<sui::sui::SUI, USDC>());
        debug::print(&b"Token ordering check:");
        debug::print(&b"Is SUI token0?");
        debug::print(&is_sui_token0); 

        // Create pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, sui::sui::SUI>(  // Create with USDC as token0
                &mut factory,
                utf8(b"USDC"),
                utf8(b"SUI"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add uneven liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);  // USDC as token0

            // Test with uneven amounts (2:1 ratio)
            let amount_usdc = FIFTY_BILLION;   // 50B USDC
            let amount_sui = HUNDRED_BILLION;  // 100B SUI

            debug::print(&b"=== Adding Uneven Large Scale Liquidity ===");
            debug::print(&b"Initial amounts:");
            debug::print(&b"- USDC amount (token0):");
            debug::print(&amount_usdc);
            debug::print(&b"- SUI amount (token1):");
            debug::print(&amount_sui);

            let coin_usdc = mint_for_testing<USDC>(amount_usdc, ts::ctx(&mut scenario));
            let coin_sui = mint_for_testing<sui::sui::SUI>(amount_sui, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,        // token0 (USDC) first
                coin_sui,         // token1 (SUI) second
                (amount_usdc as u256),
                (amount_sui as u256),
                (amount_usdc as u256),
                (amount_sui as u256),
                utf8(b"USDC"),
                utf8(b"SUI"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves:");
            debug::print(&b"- Reserve0 (USDC):");
            debug::print(&reserve0);
            debug::print(&b"- Reserve1 (SUI):");
            debug::print(&reserve1);
            debug::print(&b"Ratio (SUI/USDC):");
            debug::print(&(reserve1 / reserve0));

            // Check that reserves match inputs - USDC is token0, SUI is token1
            assert!(reserve0 == (amount_usdc as u256), 1);
            assert!(reserve1 == (amount_sui as u256), 2);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"=== Uneven Large Liquidity Test Completed Successfully ===");
        ts::end(scenario);
    }

    #[test]
    fun test_hundred_trillion_liquidity() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting hundred trillion scale liquidity test...");

        ts::next_tx(&mut scenario, ADMIN);
        {
            debug::print(&b"Taking shared objects...");
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            debug::print(&b"Creating pair...");
            let pair_addr = factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );
            debug::print(&b"Pair created with address:");
            debug::print(&pair_addr);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial hundred trillion liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            debug::print(&b"Taking objects for hundred trillion liquidity addition...");
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            
            debug::print(&b"Taking pair object...");
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            debug::print(&b"Pair object taken successfully");

            let initial_amount = HUNDRED_TRILLION;
            
            debug::print(&b"Minting hundred trillion test coins...");
            let coin_a = mint_for_testing<sui::sui::SUI>(initial_amount, ts::ctx(&mut scenario));
            let coin_b = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            debug::print(&b"Hundred trillion test coins minted");

            debug::print(&b"Adding hundred trillion liquidity...");
            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_a,
                coin_b,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial hundred trillion reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            assert_eq(reserve0, (initial_amount as u256));
            assert_eq(reserve1, (initial_amount as u256));

            // Add more liquidity (50 trillion)
            let add_amount = FIFTY_TRILLION;
            
            debug::print(&b"Minting additional fifty trillion test coins...");
            let coin_a = mint_for_testing<sui::sui::SUI>(add_amount, ts::ctx(&mut scenario));
            let coin_b = mint_for_testing<USDC>(add_amount, ts::ctx(&mut scenario));

            debug::print(&b"Adding fifty trillion more liquidity...");
            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_a,
                coin_b,
                (add_amount as u256),
                (add_amount as u256),
                (add_amount as u256),
                (add_amount as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (final_reserve0, final_reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves after adding fifty trillion more:");
            debug::print(&final_reserve0);
            debug::print(&final_reserve1);

            // Verify final amounts (150T total)
            assert_eq(final_reserve0, ((initial_amount + add_amount) as u256));
            assert_eq(final_reserve1, ((initial_amount + add_amount) as u256));

            // Print human-readable amounts in trillions
            debug::print(&b"Final amounts in trillions:");
            debug::print(&(final_reserve0 / (TRILLION as u256)));
            debug::print(&(final_reserve1 / (TRILLION as u256)));

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        debug::print(&b"Hundred trillion scale test completed successfully");
        ts::end(scenario);
    }
    
    #[test]
    fun test_hundred_trillion_remove_liquidity() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting hundred trillion remove liquidity test...");

        // First create and setup pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let initial_amount = HUNDRED_TRILLION;
            debug::print(&b"Adding initial hundred trillion liquidity...");
            let coin_a = mint_for_testing<sui::sui::SUI>(initial_amount, ts::ctx(&mut scenario));
            let coin_b = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_a,
                coin_b,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial hundred trillion reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Remove half the liquidity (50T)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<sui::sui::SUI, USDC>>>(&scenario, ADMIN);
            
            let total_lp = coin::value(&lp_coin);
            debug::print(&b"Total LP tokens:");
            debug::print(&total_lp);

            let burn_amount = total_lp / 2;
            debug::print(&b"Removing half of liquidity...");
            debug::print(&b"Burn amount:");
            debug::print(&burn_amount);

            let lp_burn = coin::split(&mut lp_coin, burn_amount, ts::ctx(&mut scenario));
            let (token0_out, token1_out) = pair::burn(&mut pair, lp_burn, ts::ctx(&mut scenario));

            let removed_amount0 = coin::value(&token0_out);
            let removed_amount1 = coin::value(&token1_out);
            debug::print(&b"Removed amounts:");
            debug::print(&removed_amount0);
            debug::print(&removed_amount1);

            // Verify approximately 50T tokens were removed
            assert!(removed_amount0 >= FIFTY_TRILLION - TRILLION, 0);
            assert!(removed_amount1 >= FIFTY_TRILLION - TRILLION, 0);

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after removing half:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            // Keep remaining LP tokens
            transfer::public_transfer(lp_coin, ADMIN);
            coin::burn_for_testing(token0_out);
            coin::burn_for_testing(token1_out);
            
            ts::return_shared(pair);
        };

        // Remove remaining liquidity (except minimum)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<sui::sui::SUI, USDC>>>(&scenario, ADMIN);
            
            let burn_amount = coin::value(&lp_coin) - 1000; // Leave minimum liquidity
            debug::print(&b"Removing remaining liquidity minus minimum...");
            debug::print(&b"Final burn amount:");
            debug::print(&burn_amount);

            let lp_burn = coin::split(&mut lp_coin, burn_amount, ts::ctx(&mut scenario));
            let (token0_out, token1_out) = pair::burn(&mut pair, lp_burn, ts::ctx(&mut scenario));

            let removed_amount0 = coin::value(&token0_out);
            let removed_amount1 = coin::value(&token1_out);
            debug::print(&b"Final removed amounts:");
            debug::print(&removed_amount0);
            debug::print(&removed_amount1);

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves (should be near minimum):");
            debug::print(&reserve0);
            debug::print(&reserve1);

            // Keep minimum LP tokens
            transfer::public_transfer(lp_coin, ADMIN);
            coin::burn_for_testing(token0_out);
            coin::burn_for_testing(token1_out);
            
            ts::return_shared(pair);
        };

        debug::print(&b"Hundred trillion remove liquidity test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_stablecoin_pair_liquidity() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting USDC-USDT pair liquidity test...");

        // Create pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity (1M of each token)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = 1_000_000_000_000; // 1M tokens with 6 decimals
            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            // Check initial reserves and price
            let (reserve_usdc, reserve_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial USDC-USDT reserves:");
            debug::print(&reserve_usdc);
            debug::print(&reserve_usdt);

            // Calculate and check price (should be ~1.0)
            let price = (reserve_usdt * 1_000_000) / reserve_usdc;
            debug::print(&b"Initial USDC/USDT price:");
            debug::print(&price);
            
            // Price should be very close to 1.00
            assert!(price >= 999_000 && price <= 1_001_000, 1); // Allow 0.1% deviation

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        ts::end(scenario);
    }
 
    #[test]
    fun test_stablecoin_pair_price_impact() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting stablecoin pair price impact test...");

        // First create and setup pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = 1_000_000_000_000; // 1M tokens with 6 decimals
            debug::print(&b"Adding initial liquidity...");
            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Test large swap impact
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);
            
            // Get initial price
            let (reserve_usdc, reserve_usdt, _) = pair::get_reserves(&pair);
            let initial_price = (reserve_usdt * 1_000_000) / reserve_usdc;
            debug::print(&b"Initial price:");
            debug::print(&initial_price);

            // Simulate adding significant USDC 
            let large_amount = 100_000_000_000; // Reduced amount to 100K USDC
            let coin_usdc = mint_for_testing<USDC>(large_amount, ts::ctx(&mut scenario));
            
            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                mint_for_testing<USDT>(large_amount, ts::ctx(&mut scenario)), // Add matching USDT amount
                (large_amount as u256),
                (large_amount as u256),
                0,
                0,
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            // Check new price
            let (new_reserve_usdc, new_reserve_usdt, _) = pair::get_reserves(&pair);
            let new_price = (new_reserve_usdt * 1_000_000) / new_reserve_usdc;
            debug::print(&b"Reserves after USDC/USDT addition:");
            debug::print(&new_reserve_usdc);
            debug::print(&new_reserve_usdt);
            debug::print(&b"New price after liquidity addition:");
            debug::print(&new_price);

            // Price should have remained stable since we added equal amounts
            assert!(new_price == initial_price, 2);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        debug::print(&b"Stablecoin pair price impact test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_router_remove_liquidity() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting router remove liquidity test...");

        // First create and setup pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = BILLION; // 1B tokens
            debug::print(&b"Adding initial liquidity...");
            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves after adding liquidity:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Test remove liquidity through router
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<USDC, USDT>>>(&scenario, ADMIN);
            
            let total_lp = coin::value(&lp_coin);
            debug::print(&b"Total LP tokens before removal:");
            debug::print(&total_lp);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before removal:");
            debug::print(&reserve0_before);
            debug::print(&reserve1_before);

            // Remove 50% of liquidity
            let burn_amount = total_lp / 2;
            debug::print(&b"Removing 50% of liquidity...");
            let lp_burn = coin::split(&mut lp_coin, burn_amount, ts::ctx(&mut scenario));
            
            // Calculate minimum expected amounts (95% of ideal amounts to account for potential slippage)
            let min_amount_0 = ((reserve0_before * (burn_amount as u256)) / (total_lp as u256)) * 95 / 100;
            let min_amount_1 = ((reserve1_before * (burn_amount as u256)) / (total_lp as u256)) * 95 / 100;

            // Create vector of LP coins and add the burn coin to it
            let mut lp_coins = vector::empty<Coin<LPCoin<USDC, USDT>>>();
            vector::push_back(&mut lp_coins, lp_burn);

            router::remove_liquidity(
                &router,
                &factory,
                &mut pair,
                lp_coins,          // Pass vector of LP coins
                burn_amount as u256,       // Amount to burn
                min_amount_0,
                min_amount_1,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after removal:");
            debug::print(&reserve0_after);
            debug::print(&reserve1_after);

            // Verify reserves were reduced by approximately half
            assert!(reserve0_after >= reserve0_before * 45 / 100, 0); // Allow some variance
            assert!(reserve0_after <= reserve0_before * 55 / 100, 0);
            assert!(reserve1_after >= reserve1_before * 45 / 100, 0);
            assert!(reserve1_after <= reserve1_before * 55 / 100, 0);

            // Keep remaining LP tokens
            transfer::public_transfer(lp_coin, ADMIN);
            
            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"Router remove liquidity test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_extreme_remove_liquidity_scenarios() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting extreme remove liquidity scenarios test...");

        // Create pair first
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add very large initial liquidity (100T tokens)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = HUNDRED_TRILLION;
            debug::print(&b"Adding massive initial liquidity of 100T tokens...");
            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial massive reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Test Scenario 1: Remove a tiny amount (test precision handling)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<USDC, USDT>>>(&scenario, ADMIN);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before tiny removal:");
            debug::print(&reserve0_before);
            debug::print(&reserve1_before);

            // Remove just 0.001% of liquidity
            let total_lp = (coin::value(&lp_coin) as u256);
            let tiny_amount = total_lp / 100000; // 0.001%
            let lp_burn = coin::split(&mut lp_coin, (tiny_amount as u64), ts::ctx(&mut scenario));

            // Calculate minimum expected amounts with higher precision
            let expected_amount0 = (reserve0_before * tiny_amount) / total_lp;
            let expected_amount1 = (reserve1_before * tiny_amount) / total_lp;

            // Create vector for LP coins
            let mut lp_coins = vector::empty<Coin<LPCoin<USDC,USDT>>>();
            vector::push_back(&mut lp_coins, lp_burn);
            
            router::remove_liquidity(
                &router,
                &factory,
                &mut pair,
                lp_coins,
                tiny_amount,
                expected_amount0 * 95 / 100, // 5% slippage tolerance
                expected_amount1 * 95 / 100,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after tiny removal:");
            debug::print(&reserve0_after);
            debug::print(&reserve1_after);

            // Calculate actual changes
            let removed_amount0 = reserve0_before - reserve0_after;
            let removed_amount1 = reserve1_before - reserve1_after;

            // Verify precision of tiny removal with percentage-based tolerance
            assert!(removed_amount0 >= expected_amount0 * 95 / 100, 0); // Allow 5% deviation
            assert!(removed_amount0 <= expected_amount0 * 105 / 100, 1);
            assert!(removed_amount1 >= expected_amount1 * 95 / 100, 2);
            assert!(removed_amount1 <= expected_amount1 * 105 / 100, 3);

            transfer::public_transfer(lp_coin, ADMIN);
            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Test Scenario 2: Remove 99.9% of remaining liquidity (test large removals)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<USDC, USDT>>>(&scenario, ADMIN);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            let total_lp = (coin::value(&lp_coin) as u256);
            
            // Calculate 99.9% of remaining LP tokens
            let large_removal = total_lp * 999 / 1000;
            debug::print(&b"Removing 99.9% of remaining liquidity");
            debug::print(&b"LP tokens to burn:");
            debug::print(&large_removal);

            let lp_burn = coin::split(&mut lp_coin, (large_removal as u64), ts::ctx(&mut scenario));

            // Calculate expected amounts
            let expected_amount0 = (reserve0_before * large_removal) / total_lp;
            let expected_amount1 = (reserve1_before * large_removal) / total_lp;

            // Create vector for LP coins
            let mut lp_coins = vector::empty<Coin<LPCoin<USDC,USDT>>>();
            vector::push_back(&mut lp_coins, lp_burn);

            router::remove_liquidity(
                &router,
                &factory,
                &mut pair,
                lp_coins,
                large_removal,
                expected_amount0 * 95 / 100, // 5% slippage tolerance
                expected_amount1 * 95 / 100,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after massive removal:");
            debug::print(&reserve0_after);
            debug::print(&reserve1_after);

            // Calculate actual changes
            let removed_amount0 = reserve0_before - reserve0_after;
            let removed_amount1 = reserve1_before - reserve1_after;

            // Verify the removed amounts
            assert!(removed_amount0 >= expected_amount0 * 95 / 100, 4);
            assert!(removed_amount0 <= expected_amount0 * 105 / 100, 5);
            assert!(removed_amount1 >= expected_amount1 * 95 / 100, 6);
            assert!(removed_amount1 <= expected_amount1 * 105 / 100, 7);

            transfer::public_transfer(lp_coin, ADMIN);
            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Test Scenario 3: Try to remove remaining liquidity (test minimum liquidity lock)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<USDC, USDT>>>(&scenario, ADMIN);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves before attempting complete removal:");
            debug::print(&reserve0_before);
            debug::print(&reserve1_before);

            let total_remaining_lp = (coin::value(&lp_coin) as u256);
            debug::print(&b"Remaining LP tokens:");
            debug::print(&total_remaining_lp);

            // Leave MINIMUM_LIQUIDITY (1000) tokens
            let burn_amount = ((total_remaining_lp - 1000) as u64);
            let lp_burn = coin::split(&mut lp_coin, burn_amount, ts::ctx(&mut scenario));

            // Calculate expected amounts
            let expected_amount0 = (reserve0_before * (burn_amount as u256)) / total_remaining_lp;
            let expected_amount1 = (reserve1_before * (burn_amount as u256)) / total_remaining_lp;

            // Create vector for LP coins
            let mut lp_coins = vector::empty<Coin<LPCoin<USDC,USDT>>>();
            vector::push_back(&mut lp_coins, lp_burn);

            // Try to remove almost all remaining liquidity except minimum
            router::remove_liquidity(
                &router,
                &factory,
                &mut pair,
                lp_coins,
                burn_amount as u256,
                expected_amount0 * 95 / 100,
                expected_amount1 * 95 / 100,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves after near-complete removal:");
            debug::print(&reserve0_after);
            debug::print(&reserve1_after);

            // Verify minimum liquidity is maintained
            assert!(reserve0_after > 0 && reserve1_after > 0, 8);
            assert!(reserve0_after >= 1000 && reserve1_after >= 1000, 9); // MINIMUM_LIQUIDITY check

            // Check that actual remaining reserves are within reasonable bounds
            // Minimum is 1000, but protocol mechanics might keep slightly more
            // Using 1% of initial reserves as a reasonable upper bound for remaining liquidity
            let max_remaining = reserve0_before / 100; // 1% of initial reserves
            assert!(reserve0_after <= max_remaining, 10);
            assert!(reserve1_after <= max_remaining, 11);
            assert!(reserve0_after >= 1000, 12); // Still ensure minimum liquidity
            assert!(reserve1_after >= 1000, 13);

            // Return remaining LP tokens to maintain state
            transfer::public_transfer(lp_coin, ADMIN);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"Extreme remove liquidity scenarios test completed successfully");
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = router::ERR_INSUFFICIENT_A_AMOUNT)]
    fun test_remove_liquidity_minimum_amount_failure() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        // Setup pair and add liquidity first
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = BILLION;
            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Test removing liquidity with too high minimum amount (should fail)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<USDC, USDT>>>(&scenario, ADMIN);

            let burn_amount = coin::value(&lp_coin) / 2;
            let lp_burn = coin::split(&mut lp_coin, burn_amount, ts::ctx(&mut scenario));

            // Set minimum amount higher than possible
            let impossible_min_amount = (BILLION as u256) * 2;

            // Create vector for LP coins
            let mut lp_coins = vector::empty<Coin<LPCoin<USDC,USDT>>>();
            vector::push_back(&mut lp_coins, lp_burn);

            router::remove_liquidity(
                &router,
                &factory,
                &mut pair,
                lp_coins,
                burn_amount as u256,
                impossible_min_amount, // This should cause failure
                0,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            transfer::public_transfer(lp_coin, ADMIN);
            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        ts::end(scenario);
    }


    #[test]
    fun test_sui_token_large_scale_remove_liquidity() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting large scale SUI-Token remove liquidity test...");

        // Create SUI-USDC pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add massive initial liquidity with different ratios
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            // Use 100T SUI and 10T USDC to simulate a realistic price ratio
            let sui_amount = HUNDRED_TRILLION;  // 100T SUI
            let usdc_amount = TEN_TRILLION;     // 10T USDC 

            debug::print(&b"Adding massive initial SUI-USDC liquidity...");
            debug::print(&b"Initial SUI amount:");
            debug::print(&sui_amount);
            debug::print(&b"Initial USDC amount:");
            debug::print(&usdc_amount);

            let coin_sui = mint_for_testing<sui::sui::SUI>(sui_amount, ts::ctx(&mut scenario));
            let coin_usdc = mint_for_testing<USDC>(usdc_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_sui,
                coin_usdc,
                (sui_amount as u256),
                (usdc_amount as u256),
                (sui_amount as u256),
                (usdc_amount as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial massive reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Remove large portions of liquidity in steps
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<sui::sui::SUI, USDC>>>(&scenario, ADMIN);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before massive removal:");
            debug::print(&reserve0_before);
            debug::print(&reserve1_before);

            let total_lp = (coin::value(&lp_coin) as u256);
            debug::print(&b"Total LP tokens:");
            debug::print(&total_lp);

            // First remove 40% (40T SUI and 4T USDC)
            let mut burn_amount = (total_lp * 40) / 100;
            debug::print(&b"Removing 40% of liquidity:");
            debug::print(&burn_amount);
            
            let lp_burn = coin::split(&mut lp_coin, (burn_amount as u64), ts::ctx(&mut scenario));

            let min_amount_0 = (reserve0_before * burn_amount / total_lp) * 95 / 100;
            let min_amount_1 = (reserve1_before * burn_amount / total_lp) * 95 / 100;

            // Create vector for LP coins
            let mut lp_coins = vector::empty<Coin<LPCoin<sui::sui::SUI,USDC>>>();
            vector::push_back(&mut lp_coins, lp_burn);

            router::remove_liquidity(
                &router,
                &factory,
                &mut pair,
                lp_coins,
                burn_amount,
                min_amount_0,
                min_amount_1,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_mid, reserve1_mid, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after 40% removal:");
            debug::print(&reserve0_mid);
            debug::print(&reserve1_mid);

            // Verify 60% of original massive amounts remain
            assert!(reserve0_mid >= reserve0_before * 59 / 100 && reserve0_mid <= reserve0_before * 61 / 100, 0);
            assert!(reserve1_mid >= reserve1_before * 59 / 100 && reserve1_mid <= reserve1_before * 61 / 100, 1);

            // Now remove 59% of remaining (leaving ~1% + minimum liquidity)
            burn_amount = (total_lp * 59) / 100;
            debug::print(&b"Removing another 59% of liquidity:");
            debug::print(&burn_amount);

            let lp_burn = coin::split(&mut lp_coin, (burn_amount as u64), ts::ctx(&mut scenario));

            let min_amount_0 = (reserve0_before * burn_amount / total_lp) * 95 / 100;
            let min_amount_1 = (reserve1_before * burn_amount / total_lp) * 95 / 100;

            // Create vector for LP coins
            let mut lp_coins = vector::empty<Coin<LPCoin<sui::sui::SUI,USDC>>>();
            vector::push_back(&mut lp_coins, lp_burn);

            router::remove_liquidity(
                &router,
                &factory,
                &mut pair,
                lp_coins,
                burn_amount,
                min_amount_0,
                min_amount_1,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves after 99% total removal:");
            debug::print(&reserve0_after);
            debug::print(&reserve1_after);

            // Verify approximately 1% of original massive amounts remain
            assert!(reserve0_after >= reserve0_before / 100 && reserve0_after <= reserve0_before * 2 / 100, 2);
            assert!(reserve1_after >= reserve1_before / 100 && reserve1_after <= reserve1_before * 2 / 100, 3);

            debug::print(&b"Final reserves in trillions:");
            debug::print(&(reserve0_after / (TRILLION as u256)));
            debug::print(&(reserve1_after / (TRILLION as u256)));

            // Keep remaining LP tokens
            transfer::public_transfer(lp_coin, ADMIN);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"Large scale SUI-Token remove liquidity test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_swap_exact_tokens() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting basic swap exact tokens test...");

        // Create pair first
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );
            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity with larger amounts
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = TEN_BILLION; // Increased initial liquidity
            debug::print(&b"Adding initial liquidity...");
            debug::print(&b"Initial amount:");
            debug::print(&initial_amount);

            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Test swap exact tokens
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let swap_amount = BILLION; // 1B tokens
            debug::print(&b"Swapping exact tokens...");
            debug::print(&b"Swap amount:");
            debug::print(&swap_amount);

            let coin_in = mint_for_testing<USDC>(swap_amount, ts::ctx(&mut scenario));
            // Calculate minimum output with more lenient slippage
            let min_amount_out = (swap_amount * 90) / 100; // 10% slippage allowance

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                (min_amount_out as u256),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after swap:");
            debug::print(&reserve0_after);
            debug::print(&reserve1_after);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_swap_large_amounts() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting large amount swap test...");

        // Setup with larger initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );
            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add massive liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = HUNDRED_TRILLION;
            debug::print(&b"Adding massive liquidity...");
            debug::print(&b"Initial amount:");
            debug::print(&initial_amount);

            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Test large swap
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let swap_amount = TEN_TRILLION;
            let min_amount_out = (swap_amount * 90) / 100; // 10% slippage allowance

            debug::print(&b"Attempting large swap...");
            debug::print(&b"Swap amount:");
            debug::print(&swap_amount);

            let coin_in = mint_for_testing<USDC>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                (min_amount_out as u256),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = router::ERR_INSUFFICIENT_OUTPUT_AMOUNT)]
    fun test_swap_slippage_protection() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        
        // Setup pair first
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );
            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = TEN_BILLION;
            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Test with unrealistic minimum output
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let swap_amount = BILLION;
            let unrealistic_min_out = swap_amount * 2; // Expecting more out than possible
            
            let coin_in = mint_for_testing<USDC>(swap_amount, ts::ctx(&mut scenario));

            // This should fail with ERR_INSUFFICIENT_OUTPUT_AMOUNT
            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                (unrealistic_min_out as u256),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_swap_fee_distribution() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting swap fee distribution test...");

        // Create pair with specific fee addresses
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let pair_addr = factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );
            debug::print(&b"Pair created at address:");
            debug::print(&pair_addr);
            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            // Update fee addresses
            pair::update_fee_addresses(
                &mut pair,
                TEAM_1,  // 40% of team fee
                TEAM_2,  // 50% of team fee
                DEV,     // 10% of team fee
                LOCKER,
                BUYBACK,
                &cap
            );

            let initial_amount = HUNDRED_BILLION;
            debug::print(&b"Adding initial liquidity of 100B tokens...");
            
            let coin_sui = mint_for_testing<sui::sui::SUI>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_sui,
                coin_usdc,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Perform swap to generate fees
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let swap_amount = TEN_BILLION;
            debug::print(&b"Performing swap of 10B tokens to generate fees...");
            debug::print(&b"Swap amount:");
            debug::print(&swap_amount);
            
            let coin_in = mint_for_testing<sui::sui::SUI>(swap_amount, ts::ctx(&mut scenario));
            let min_amount_out = (swap_amount * 90) / 100; // 10% slippage

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                (min_amount_out as u256),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Calculate expected fees
        let swap_amount = TEN_BILLION;
        let total_fee = (swap_amount * 30) / 10000; // 0.3% of swap amount
        let total_team_fee = (total_fee * 6) / 30;    // 0.06% total team fee
        
        // Calculate individual team member fees
        let expected_team1_fee = (total_team_fee * 40) / 100; // 40% of team fee
        let expected_team2_fee = (total_team_fee * 50) / 100; // 50% of team fee
        let expected_dev_fee = total_team_fee - expected_team1_fee - expected_team2_fee; // 10% remainder
        
        let expected_locker_fee = (total_fee * 3) / 30;  // 0.03%
        let expected_buyback_fee = (total_fee * 3) / 30; // 0.03%

        debug::print(&b"Expected fee distribution:");
        debug::print(&b"Total fee amount:");
        debug::print(&total_fee);
        debug::print(&b"Team 1 fee (40%):");
        debug::print(&expected_team1_fee);
        debug::print(&b"Team 2 fee (50%):");
        debug::print(&expected_team2_fee);
        debug::print(&b"Dev fee (10%):");
        debug::print(&expected_dev_fee);
        debug::print(&b"Locker fee:");
        debug::print(&expected_locker_fee);
        debug::print(&b"Buyback fee:");
        debug::print(&expected_buyback_fee);

        // Verify TEAM_1's received fees (40% of team fee)
        ts::next_tx(&mut scenario, TEAM_1);
        {
            let team1_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, TEAM_1);
            let team1_fee = coin::value(&team1_coins);
            debug::print(&b"Team 1 fee received:");
            debug::print(&team1_fee);
            assert!(team1_fee >= expected_team1_fee, 0);
            assert!(team1_fee <= expected_team1_fee + 1, 1); // Allow for rounding
            coin::burn_for_testing(team1_coins);
        };

        // Verify TEAM_2's received fees (50% of team fee)
        ts::next_tx(&mut scenario, TEAM_2);
        {
            let team2_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, TEAM_2);
            let team2_fee = coin::value(&team2_coins);
            debug::print(&b"Team 2 fee received:");
            debug::print(&team2_fee);
            assert!(team2_fee >= expected_team2_fee, 2);
            assert!(team2_fee <= expected_team2_fee + 1, 3); // Allow for rounding
            coin::burn_for_testing(team2_coins);
        };

        // Verify DEV's received fees (10% of team fee)
        ts::next_tx(&mut scenario, DEV);
        {
            let dev_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, DEV);
            let dev_fee = coin::value(&dev_coins);
            debug::print(&b"Dev fee received:");
            debug::print(&dev_fee);
            assert!(dev_fee >= expected_dev_fee, 4);
            assert!(dev_fee <= expected_dev_fee + 1, 5); // Allow for rounding
            coin::burn_for_testing(dev_coins);
        };

        // Verify locker fee
        ts::next_tx(&mut scenario, LOCKER);
        {
            let locker_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, LOCKER);
            let locker_fee = coin::value(&locker_coins);
            debug::print(&b"Locker fee received:");
            debug::print(&locker_fee);
            assert!(locker_fee >= expected_locker_fee, 6);
            assert!(locker_fee <= expected_locker_fee + 1, 7);
            coin::burn_for_testing(locker_coins);
        };

        // Verify buyback fee
        ts::next_tx(&mut scenario, BUYBACK);
        {
            let buyback_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, BUYBACK);
            let buyback_fee = coin::value(&buyback_coins);
            debug::print(&b"Buyback fee received:");
            debug::print(&buyback_fee);
            assert!(buyback_fee >= expected_buyback_fee, 8);
            assert!(buyback_fee <= expected_buyback_fee + 1, 9);
            coin::burn_for_testing(buyback_coins);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_price_impact() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting price impact test...");

        // Create pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );
            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = HUNDRED_BILLION;
            debug::print(&b"Adding initial liquidity...");
            debug::print(&b"Initial amount:");
            debug::print(&initial_amount);

            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Test different swap sizes
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            // Small swap (0.1% of pool)
            let small_amount = HUNDRED_MILLION;
            let mut coin_in = mint_for_testing<USDC>(small_amount, ts::ctx(&mut scenario));
            let min_out_small = (small_amount * 90) / 100;

            debug::print(&b"Performing small swap (0.1% of pool)");
            debug::print(&b"Amount:");
            debug::print(&small_amount);

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                (min_out_small as u256),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after_small, reserve1_after_small, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after small swap:");
            debug::print(&reserve0_after_small);
            debug::print(&reserve1_after_small);

            // Large swap (10% of pool)
            let large_amount = TEN_BILLION;
            coin_in = mint_for_testing<USDC>(large_amount, ts::ctx(&mut scenario));
            let min_out_large = (large_amount * 85) / 100; // Higher slippage for larger amount

            debug::print(&b"Performing large swap (10% of pool)");
            debug::print(&b"Amount:");
            debug::print(&large_amount);

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                (min_out_large as u256),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after_large, reserve1_after_large, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after large swap:");
            debug::print(&reserve0_after_large);
            debug::print(&reserve1_after_large);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_swap_price_impact() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"=== Starting Swap Price Impact Test ===");

        // Create USDC-SUI pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            // Check token ordering
            let is_usdc_token0 = factory::is_token0<USDC>(&factory::sort_tokens<USDC, sui::sui::SUI>());
            debug::print(&b"Token ordering check:");
            debug::print(&b"Is USDC token0?");
            debug::print(&is_usdc_token0);

            factory::create_pair<USDC, sui::sui::SUI>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"SUI"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity with 10:1 ratio
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

            let usdc_amount = TRILLION;        // 1T USDC
            let sui_amount = HUNDRED_BILLION;  // 100B SUI (10:1 ratio)
            
            debug::print(&b"=== Adding Initial Liquidity ===");
            debug::print(&b"Initial amounts (10:1 ratio):");
            debug::print(&b"- USDC amount (token0):");
            debug::print(&usdc_amount);
            debug::print(&b"- SUI amount (token1):");
            debug::print(&sui_amount);

            let coin_usdc = mint_for_testing<USDC>(usdc_amount, ts::ctx(&mut scenario));
            let coin_sui = mint_for_testing<sui::sui::SUI>(sui_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_sui,
                (usdc_amount as u256),
                (sui_amount as u256),
                (usdc_amount as u256),
                (sui_amount as u256),
                utf8(b"USDC"),
                utf8(b"SUI"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            let initial_price = (reserve0 * 100) / reserve1;
            debug::print(&b"Initial reserves:");
            debug::print(&b"- USDC reserve (token0):");
            debug::print(&reserve0);
            debug::print(&b"- SUI reserve (token1):");
            debug::print(&reserve1);
            debug::print(&b"Initial price (USDC/SUI * 100):");
            debug::print(&initial_price);
            assert!(initial_price == 1000, 0); // Should be 10.00 USDC per SUI

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Test small swap impact (0.1% of pool)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            let price_before = (reserve0_before * 100) / reserve1_before;
            
            debug::print(&b"=== Testing Small Swap Impact (0.1%) ===");
            debug::print(&b"Pre-swap state:");
            debug::print(&b"- USDC reserve:");
            debug::print(&reserve0_before);
            debug::print(&b"- SUI reserve:");
            debug::print(&reserve1_before);
            debug::print(&b"- Initial price (USDC/SUI * 100):");
            debug::print(&price_before);

            // Swap 0.1% of USDC pool
            let swap_amount = TRILLION / 1000;
            let expected_output = library::get_amounts_out(
                &factory,
                (swap_amount as u256),
                &pair,
                true  // USDC is token0
            );
            let min_amount_out = (expected_output * 950) / 1000; // 5% slippage

            debug::print(&b"Swap details:");
            debug::print(&b"- USDC input (0.1% of pool):");
            debug::print(&swap_amount);
            debug::print(&b"- Expected SUI output:");
            debug::print(&expected_output);

            let coin_in = mint_for_testing<USDC>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
            let price_after = (reserve0_after * 100) / reserve1_after;
            
            debug::print(&b"Post-swap state:");
            debug::print(&b"- USDC reserve:");
            debug::print(&reserve0_after);
            debug::print(&b"- SUI reserve:");
            debug::print(&reserve1_after);
            debug::print(&b"- Final price (USDC/SUI * 100):");
            debug::print(&price_after);

            let price_impact = if (price_after > price_before) {
                price_after - price_before
            } else {
                price_before - price_after
            };
            debug::print(&b"Price impact (basis points):");
            debug::print(&price_impact);
            assert!(price_impact < 10, 1); // Impact should be less than 0.1%

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Test large swap impact (10% of pool)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            let price_before = (reserve0_before * 100) / reserve1_before;

            debug::print(&b"=== Testing Large Swap Impact (10%) ===");
            debug::print(&b"Pre-swap state:");
            debug::print(&b"- USDC reserve:");
            debug::print(&reserve0_before);
            debug::print(&b"- SUI reserve:");
            debug::print(&reserve1_before);
            debug::print(&b"- Initial price (USDC/SUI * 100):");
            debug::print(&price_before);

            // Swap 10% of USDC pool
            let swap_amount = TRILLION / 10;
            let expected_output = library::get_amounts_out(
                &factory,
                (swap_amount as u256),
                &pair,
                true  // USDC is token0
            );
            let min_amount_out = (expected_output * 900) / 1000; // 10% slippage for large swap

            debug::print(&b"Swap details:");
            debug::print(&b"- USDC input (10% of pool):");
            debug::print(&swap_amount);
            debug::print(&b"- Expected SUI output:");
            debug::print(&expected_output);

            let coin_in = mint_for_testing<USDC>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
            let price_after = (reserve0_after * 100) / reserve1_after;
            
            debug::print(&b"Post-swap state:");
            debug::print(&b"- USDC reserve:");
            debug::print(&reserve0_after);
            debug::print(&b"- SUI reserve:");
            debug::print(&reserve1_after);
            debug::print(&b"- Final price (USDC/SUI * 100):");
            debug::print(&price_after);

            let price_impact = if (price_after > price_before) {
                price_after - price_before
            } else {
                price_before - price_after
            };
            debug::print(&b"Price impact (basis points):");
            debug::print(&price_impact);
            assert!(price_impact > 100, 2); // Impact should be more than 1%

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"=== Swap Price Impact Test Completed Successfully ===");
        ts::end(scenario);
    }

    #[test]
    fun test_trillion_scale_swap() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting trillion scale swap test...");

        // Create pair first
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );
            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity of 100T each
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = HUNDRED_TRILLION;
            debug::print(&b"Adding initial liquidity of 100T tokens...");
            debug::print(&b"Initial amount:");
            debug::print(&initial_amount);
            
            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves after adding liquidity:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Perform large swap (10T)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before swap:");
            debug::print(&reserve0_before);
            debug::print(&reserve1_before);

            let swap_amount = TEN_TRILLION;
            debug::print(&b"Performing 10T token swap...");
            debug::print(&b"Swap amount:");
            debug::print(&swap_amount);
            
            let coin_in = mint_for_testing<USDC>(swap_amount, ts::ctx(&mut scenario));
            // Increase slippage tolerance to 15% for very large swaps
            let min_amount_out = (swap_amount * 85) / 100; 
            debug::print(&b"Minimum output amount:");
            debug::print(&min_amount_out);

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                (min_amount_out as u256),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after swap:");
            debug::print(&reserve0_after);
            debug::print(&reserve1_after);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"Trillion scale swap test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_large_swap_with_price_verification() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"=== Starting Large Swap Price Verification Test ===");

        // Create pair same as before
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity (same as before)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let usdc_amount = FIFTY_TRILLION;
            let usdt_amount = HUNDRED_TRILLION;
            
            debug::print(&b"=== Adding Initial Liquidity ===");
            debug::print(&b"Initial amounts (1:2 ratio):");
            debug::print(&b"- USDC amount:");
            debug::print(&usdc_amount);
            debug::print(&b"- USDT amount:");
            debug::print(&usdt_amount);

            let coin_usdc = mint_for_testing<USDC>(usdc_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(usdt_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (usdc_amount as u256),
                (usdt_amount as u256),
                (usdc_amount as u256),
                (usdt_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&b"- USDC reserve:");
            debug::print(&reserve0);
            debug::print(&b"- USDT reserve:");
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Perform large swap with adjusted expectations
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            let swap_amount = TEN_TRILLION;
            let swap_amount_u256 = (swap_amount as u256);
            
            debug::print(&b"=== Performing Large Swap ===");
            debug::print(&b"Pre-swap state:");
            debug::print(&b"- USDC reserve:");
            debug::print(&reserve0_before);
            debug::print(&b"- USDT reserve:");
            debug::print(&reserve1_before);
            debug::print(&b"- Swap amount:");
            debug::print(&swap_amount);

            // Get expected output from router
            let expected_out = library::get_amounts_out(
                &factory,
                swap_amount_u256,
                &pair,
                true  // USDC is token0
            );
            let min_amount_out = (expected_out * 950) / 1000; // 5% slippage tolerance

            debug::print(&b"Expected outputs:");
            debug::print(&b"- Expected USDT output:");
            debug::print(&expected_out);
            debug::print(&b"- Min USDT output:");
            debug::print(&min_amount_out);

            let coin_in = mint_for_testing<USDC>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
            let actual_output = reserve1_before - reserve1_after;
            
            debug::print(&b"Post-swap state:");
            debug::print(&b"- USDC reserve:");
            debug::print(&reserve0_after);
            debug::print(&b"- USDT reserve:");
            debug::print(&reserve1_after);
            debug::print(&b"- Actual USDT output:");
            debug::print(&actual_output);

            // Verify price impact
            let initial_price = (reserve1_before * 100) / reserve0_before;
            let final_price = (reserve1_after * 100) / reserve0_after;
            
            debug::print(&b"Price analysis:");
            debug::print(&b"- Initial price (USDT/USDC * 100):");
            debug::print(&initial_price);
            debug::print(&b"- Final price (USDT/USDC * 100):");
            debug::print(&final_price);

            // Assertions with wider tolerances for large swaps
            assert!(actual_output >= min_amount_out, 1); // Output should be above minimum
            assert!(final_price < initial_price, 2);     // Price should decrease
            assert!(final_price > initial_price * 60 / 100, 3); // Price shouldn't drop more than 40%

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"=== Large Swap Price Verification Test Completed Successfully ===");
        ts::end(scenario);
    }

    #[test]
    fun test_both_direction_swaps() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting bidirectional swap test...");

        // Create SUI-USDC pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            let pair_addr = factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );
            debug::print(&b"Pair created at address:");
            debug::print(&pair_addr);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity with fee addresses
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            // Set up fee addresses
            pair::update_fee_addresses(
                &mut pair,
                TEAM_1,  // 40% of team fee
                TEAM_2,  // 50% of team fee
                DEV,     // 10% of team fee
                LOCKER,
                BUYBACK,
                &cap
            );

            // Initial 10:1 ratio for USDC:SUI
            let sui_amount = TRILLION;  // 100B SUI
            let usdc_amount = TRILLION;        // 1T USDC
            
            debug::print(&b"Adding initial liquidity with 10:1 ratio...");
            debug::print(&b"Initial SUI amount:");
            debug::print(&sui_amount);
            debug::print(&b"Initial USDC amount:");
            debug::print(&usdc_amount);

            let coin_sui = mint_for_testing<sui::sui::SUI>(sui_amount, ts::ctx(&mut scenario));
            let coin_usdc = mint_for_testing<USDC>(usdc_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_sui,
                coin_usdc,
                (sui_amount as u256),
                (usdc_amount as u256),
                (sui_amount as u256),
                (usdc_amount as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&b"SUI reserve: ");
            debug::print(&reserve0);
            debug::print(&b"USDC reserve: ");
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // First swap: SUI -> USDC 
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let (reserve_sui_before, reserve_usdc_before, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before SUI->USDC swap:");
            debug::print(&b"SUI reserve: ");
            debug::print(&reserve_sui_before);
            debug::print(&b"USDC reserve: ");
            debug::print(&reserve_usdc_before);

            let swap_amount = TEN_BILLION; // 10B SUI
            debug::print(&b"Performing SUI->USDC swap");
            debug::print(&b"Swap amount: ");
            debug::print(&swap_amount);

            // Calculate expected fees
            let total_fee = (swap_amount * 30) / 10000; // 0.3%
            let total_team_fee = (total_fee * 6) / 30;    // 0.06% total team fee
            let expected_team1_fee = (total_team_fee * 40) / 100; // 40% of team fee
            let expected_team2_fee = (total_team_fee * 50) / 100; // 50% of team fee
            let expected_dev_fee = total_team_fee - expected_team1_fee - expected_team2_fee; // 10% remainder
            
            debug::print(&b"Expected fees from SUI->USDC swap:");
            debug::print(&b"Team 1 fee (40%):");
            debug::print(&expected_team1_fee);
            debug::print(&b"Team 2 fee (50%):");
            debug::print(&expected_team2_fee);
            debug::print(&b"Dev fee (10%):");
            debug::print(&expected_dev_fee);

            // Calculate expected output
            let expected_output = library::get_amounts_out(
                &factory,
                (swap_amount as u256),
                &pair,
                true  // SUI is token0
            );
            let min_amount_out = (expected_output * 90) / 100; // 10% slippage
            debug::print(&b"Expected USDC output:");
            debug::print(&expected_output);
            debug::print(&b"Minimum USDC output:");
            debug::print(&min_amount_out);

            let coin_in = mint_for_testing<sui::sui::SUI>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_sui_after, reserve_usdc_after, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after SUI->USDC swap:");
            debug::print(&b"SUI reserve: ");
            debug::print(&reserve_sui_after);
            debug::print(&b"USDC reserve: ");
            debug::print(&reserve_usdc_after);

            // Verify reserves changed correctly
            assert!(reserve_sui_after > reserve_sui_before, 1); // SUI reserve increased
            assert!(reserve_usdc_after < reserve_usdc_before, 2); // USDC reserve decreased

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Verify TEAM_1 fees from first swap
        ts::next_tx(&mut scenario, TEAM_1);
        {
            let team1_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, TEAM_1);
            let team1_fee = coin::value(&team1_coins);
            debug::print(&b"Team 1 fee received from first swap:");
            debug::print(&team1_fee);
            assert!(team1_fee > 0, 3);
            coin::burn_for_testing(team1_coins);
        };

        // Verify TEAM_2 fees from first swap
        ts::next_tx(&mut scenario, TEAM_2);
        {
            let team2_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, TEAM_2);
            let team2_fee = coin::value(&team2_coins);
            debug::print(&b"Team 2 fee received from first swap:");
            debug::print(&team2_fee);
            assert!(team2_fee > 0, 4);
            coin::burn_for_testing(team2_coins);
        };

        // Verify DEV fees from first swap
        ts::next_tx(&mut scenario, DEV);
        {
            let dev_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, DEV);
            let dev_fee = coin::value(&dev_coins);
            debug::print(&b"Dev fee received from first swap:");
            debug::print(&dev_fee);
            assert!(dev_fee > 0, 5);
            coin::burn_for_testing(dev_coins);
        };

        // Second swap: USDC -> SUI 
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let (reserve_sui_before, reserve_usdc_before, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before USDC->SUI swap:");
            debug::print(&b"SUI reserve: ");
            debug::print(&reserve_sui_before);
            debug::print(&b"USDC reserve: ");
            debug::print(&reserve_usdc_before);

            let swap_amount = HUNDRED_BILLION; // 100B USDC (larger than first swap due to ratio)
            debug::print(&b"Performing USDC->SUI swap");
            debug::print(&b"Swap amount: ");
            debug::print(&swap_amount);

            // Calculate expected fees for USDC
            let total_fee = (swap_amount * 30) / 10000; // 0.3%
            let total_team_fee = (total_fee * 6) / 30;    // 0.06%
            let expected_team1_fee = (total_team_fee * 40) / 100; // 40% of team fee
            let expected_team2_fee = (total_team_fee * 50) / 100; // 50% of team fee
            let expected_dev_fee = total_team_fee - expected_team1_fee - expected_team2_fee; // 10% remainder

            debug::print(&b"Expected fees from USDC->SUI swap:");
            debug::print(&b"Team 1 fee (40%):");
            debug::print(&expected_team1_fee);
            debug::print(&b"Team 2 fee (50%):");
            debug::print(&expected_team2_fee);
            debug::print(&b"Dev fee (10%):");
            debug::print(&expected_dev_fee);

            // Calculate expected output
            let expected_output = library::get_amounts_out(
                &factory,
                (swap_amount as u256),
                &pair,
                false  // USDC is token1
            );
            let min_amount_out = (expected_output * 90) / 100; // 10% slippage
            debug::print(&b"Expected SUI output:");
            debug::print(&expected_output);
            debug::print(&b"Minimum SUI output:");
            debug::print(&min_amount_out);

            let coin_in = mint_for_testing<USDC>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens1_for_tokens0(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_sui_after, reserve_usdc_after, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after USDC->SUI swap:");
            debug::print(&b"SUI reserve: ");
            debug::print(&reserve_sui_after);
            debug::print(&b"USDC reserve: ");
            debug::print(&reserve_usdc_after);

            // Verify reserves changed correctly
            assert!(reserve_usdc_after > reserve_usdc_before, 6); // USDC reserve increased
            assert!(reserve_sui_after < reserve_sui_before, 7); // SUI reserve decreased

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Verify TEAM_1 fees from second swap
        ts::next_tx(&mut scenario, TEAM_1);
        {
            let team1_coins = ts::take_from_address<Coin<USDC>>(&scenario, TEAM_1);
            let team1_fee = coin::value(&team1_coins);
            debug::print(&b"Team 1 fee received from second swap:");
            debug::print(&team1_fee);
            assert!(team1_fee > 0, 8);
            coin::burn_for_testing(team1_coins);
        };

        // Verify TEAM_2 fees from second swap
        ts::next_tx(&mut scenario, TEAM_2);
        {
            let team2_coins = ts::take_from_address<Coin<USDC>>(&scenario, TEAM_2);
            let team2_fee = coin::value(&team2_coins);
            debug::print(&b"Team 2 fee received from second swap:");
            debug::print(&team2_fee);
            assert!(team2_fee > 0, 9);
            coin::burn_for_testing(team2_coins);
        };

        // Verify DEV fees from second swap
        ts::next_tx(&mut scenario, DEV);
        {
            let dev_coins = ts::take_from_address<Coin<USDC>>(&scenario, DEV);
            let dev_fee = coin::value(&dev_coins);
            debug::print(&b"Dev fee received from second swap:");
            debug::print(&dev_fee);
            assert!(dev_fee > 0, 10);
            coin::burn_for_testing(dev_coins);
        };

        debug::print(&b"Bidirectional swap test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_bidirectional_swaps() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting bidirectional swap test...");

        // Create pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            let usdc_amount = HUNDRED_BILLION;  // 100B USDC
            let usdt_amount = HUNDRED_BILLION;  // 100B USDT (1:1 ratio)

            debug::print(&b"Adding initial liquidity with 1:1 ratio");
            debug::print(&b"Initial USDC amount:");
            debug::print(&usdc_amount);
            debug::print(&b"Initial USDT amount:");
            debug::print(&usdt_amount);

            let coin_usdc = mint_for_testing<USDC>(usdc_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(usdt_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (usdc_amount as u256),
                (usdt_amount as u256),
                (usdc_amount as u256),
                (usdt_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_usdc, reserve_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves after liquidity:");
            debug::print(&b"USDC reserve:");
            debug::print(&reserve_usdc);
            debug::print(&b"USDT reserve:");
            debug::print(&reserve_usdt);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // First swap: USDC -> USDT (token0 to token1)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let (reserve_before_usdc, reserve_before_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before USDC->USDT swap:");
            debug::print(&b"USDC reserve:");
            debug::print(&reserve_before_usdc);
            debug::print(&b"USDT reserve:");
            debug::print(&reserve_before_usdt);

            let swap_amount = TEN_BILLION; // 10B USDC input
            debug::print(&b"Performing USDC->USDT swap");
            debug::print(&b"Swap amount:");
            debug::print(&swap_amount);

            let coin_in = mint_for_testing<USDC>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                0, // min_amount_out - reduced for test
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after_usdc, reserve_after_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after USDC->USDT swap:");
            debug::print(&b"USDC reserve:");
            debug::print(&reserve_after_usdc);
            debug::print(&b"USDT reserve:");
            debug::print(&reserve_after_usdt);

            assert!(reserve_after_usdc > reserve_before_usdc, 3); // USDC reserve should increase
            assert!(reserve_after_usdt < reserve_before_usdt, 4); // USDT reserve should decrease

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Second swap: USDT -> USDC (token1 to token0)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let (reserve_before_usdc, reserve_before_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before USDT->USDC swap:");
            debug::print(&b"USDC reserve:");
            debug::print(&reserve_before_usdc);
            debug::print(&b"USDT reserve:");
            debug::print(&reserve_before_usdt);

            let swap_amount = TEN_BILLION; // 10B USDT input
            debug::print(&b"Performing USDT->USDC swap");
            debug::print(&b"Swap amount:");
            debug::print(&swap_amount);

            let coin_in = mint_for_testing<USDT>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens1_for_tokens0(
                &router,
                &factory,
                &mut pair,
                coin_in,
                0, // min_amount_out - reduced for test
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after_usdc, reserve_after_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after USDT->USDC swap:");
            debug::print(&b"USDC reserve:");
            debug::print(&reserve_after_usdc);
            debug::print(&b"USDT reserve:");
            debug::print(&reserve_after_usdt);

            assert!(reserve_after_usdt > reserve_before_usdt, 5); // USDT reserve should increase
            assert!(reserve_after_usdc < reserve_before_usdc, 6); // USDC reserve should decrease

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"Bidirectional swap test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_bidirectional_exact_output_swaps() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting bidirectional exact output swap test...");

        // Create pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            let initial_amount = HUNDRED_BILLION;  // 100B each

            debug::print(&b"Adding initial liquidity with 1:1 ratio");
            debug::print(&b"Initial amount:");
            debug::print(&initial_amount);

            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // First swap: USDC -> USDT (tokens0 for exact tokens1)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let (reserve_before_usdc, reserve_before_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before USDC->USDT swap:");
            debug::print(&reserve_before_usdc);
            debug::print(&reserve_before_usdt);

            let exact_out_amount = BILLION; // Want exactly 1B USDT
            let max_in_amount = TEN_BILLION; // Willing to spend up to 10B USDC

            debug::print(&b"Performing USDC->USDT exact output swap");
            debug::print(&b"Exact output amount:");
            debug::print(&exact_out_amount);
            debug::print(&b"Max input amount:");
            debug::print(&max_in_amount);

            let coin_in = mint_for_testing<USDC>(max_in_amount, ts::ctx(&mut scenario));

            router::swap_tokens0_for_exact_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                (exact_out_amount as u256),
                (max_in_amount as u256),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after_usdc, reserve_after_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after USDC->USDT swap:");
            debug::print(&reserve_after_usdc);
            debug::print(&reserve_after_usdt);

            assert!(reserve_after_usdc > reserve_before_usdc, 1); // USDC reserve increased
            assert!(reserve_after_usdt < reserve_before_usdt, 2); // USDT reserve decreased
            assert!((reserve_before_usdt - reserve_after_usdt) == (exact_out_amount as u256), 3); // Exact output

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Second swap: USDT -> USDC (tokens1 for exact tokens0)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let (reserve_before_usdc, reserve_before_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before USDT->USDC swap:");
            debug::print(&reserve_before_usdc);
            debug::print(&reserve_before_usdt);

            let exact_out_amount = BILLION; // Want exactly 1B USDC
            let max_in_amount = TEN_BILLION; // Willing to spend up to 10B USDT

            debug::print(&b"Performing USDT->USDC exact output swap");
            debug::print(&b"Exact output amount:");
            debug::print(&exact_out_amount);
            debug::print(&b"Max input amount:");
            debug::print(&max_in_amount);

            let coin_in = mint_for_testing<USDT>(max_in_amount, ts::ctx(&mut scenario));

            router::swap_tokens1_for_exact_tokens0(
                &router,
                &factory,
                &mut pair,
                coin_in,
                (exact_out_amount as u256),
                (max_in_amount as u256),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after_usdc, reserve_after_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after USDT->USDC swap:");
            debug::print(&reserve_after_usdc);
            debug::print(&reserve_after_usdt);

            assert!(reserve_after_usdt > reserve_before_usdt, 4); // USDT reserve increased
            assert!(reserve_after_usdc < reserve_before_usdc, 5); // USDC reserve decreased
            assert!((reserve_before_usdc - reserve_after_usdc) == (exact_out_amount as u256), 6); // Exact output

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"Bidirectional exact output swap test completed successfully");
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = router::ERR_EXCESSIVE_INPUT_AMOUNT)]
    fun test_exact_output_swaps_max_input_failure() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        // Create pair and add liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let initial_amount = TEN_BILLION;
            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Try to swap with insufficient max_input amount
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let exact_out_amount = BILLION;
            let insufficient_max_in = MILLION; // Too small max input amount

            let coin_in = mint_for_testing<USDC>(insufficient_max_in, ts::ctx(&mut scenario));

            // This should fail because max_input is too low
            router::swap_tokens0_for_exact_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                (exact_out_amount as u256),
                (insufficient_max_in as u256),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_bidirectional_exact_input_swaps() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting bidirectional exact input swap test...");

        // Create pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDT>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDT"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity with fee addresses
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            // Set up fee addresses for distribution testing
            pair::update_fee_addresses(
                &mut pair,
                TEAM_1,  // 40% of team fee
                TEAM_2,  // 50% of team fee
                DEV,     // 10% of team fee
                LOCKER,
                BUYBACK,
                &cap
            );

            let initial_amount = HUNDRED_BILLION;  // 100B each
            debug::print(&b"Adding initial liquidity with 1:1 ratio");
            debug::print(&b"Initial amount:");
            debug::print(&initial_amount);

            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdt = mint_for_testing<USDT>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_usdt,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"USDC"),
                utf8(b"USDT"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // First swap: exact USDC -> USDT with fee verification
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let (reserve_before_usdc, reserve_before_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before USDC->USDT swap:");
            debug::print(&reserve_before_usdc);
            debug::print(&reserve_before_usdt);

            let swap_amount = BILLION; // 1B USDC input
            let swap_amount_u256 = (swap_amount as u256);

            debug::print(&b"Performing exact USDC->USDT swap");
            debug::print(&b"Swap amount:");
            debug::print(&swap_amount);

            // Calculate expected fees for first swap
            let total_fee = (swap_amount * 30) / 10000; // 0.3% fee
            let total_team_fee = (total_fee * 6) / 30;    // 0.06% team fee
            let expected_team1_fee = (total_team_fee * 40) / 100; // 40% of team fee
            let expected_team2_fee = (total_team_fee * 50) / 100; // 50% of team fee
            let expected_dev_fee = total_team_fee - expected_team1_fee - expected_team2_fee; // 10% remainder
            let expected_locker_fee = (total_fee * 3) / 30;  // 0.03%
            let expected_buyback_fee = (total_fee * 3) / 30; // 0.03%

            debug::print(&b"Expected fees from first swap:");
            debug::print(&b"Team1 fee (40%):");
            debug::print(&expected_team1_fee);
            debug::print(&b"Team2 fee (50%):");
            debug::print(&expected_team2_fee);
            debug::print(&b"Dev fee (10%):");
            debug::print(&expected_dev_fee);

            // Calculate minimum output with 5% slippage tolerance + fees
            let amount_out_min = (swap_amount_u256 * 94) / 100;  // 6% buffer
            let coin_in = mint_for_testing<USDC>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                amount_out_min,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after_usdc, reserve_after_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after USDC->USDT swap:");
            debug::print(&reserve_after_usdc);
            debug::print(&reserve_after_usdt);

            // Verify reserve changes
            assert!(reserve_after_usdc > reserve_before_usdc, 1);
            assert!(reserve_after_usdt < reserve_before_usdt, 2);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Check fee distribution from first swap
        ts::next_tx(&mut scenario, TEAM_1);
        {
            let team1_balance = ts::take_from_address<Coin<USDC>>(&scenario, TEAM_1);
            let actual_team1_fee = coin::value(&team1_balance);
            debug::print(&b"Actual Team1 fee received:");
            debug::print(&actual_team1_fee);
            assert!(actual_team1_fee > 0, 3);
            coin::burn_for_testing(team1_balance);
        };

        ts::next_tx(&mut scenario, TEAM_2);
        {
            let team2_balance = ts::take_from_address<Coin<USDC>>(&scenario, TEAM_2);
            let actual_team2_fee = coin::value(&team2_balance);
            debug::print(&b"Actual Team2 fee received:");
            debug::print(&actual_team2_fee);
            assert!(actual_team2_fee > 0, 4);
            coin::burn_for_testing(team2_balance);
        };

        ts::next_tx(&mut scenario, DEV);
        {
            let dev_balance = ts::take_from_address<Coin<USDC>>(&scenario, DEV);
            let actual_dev_fee = coin::value(&dev_balance);
            debug::print(&b"Actual Dev fee received:");
            debug::print(&actual_dev_fee);
            assert!(actual_dev_fee > 0, 5);
            coin::burn_for_testing(dev_balance);
        };

        ts::next_tx(&mut scenario, LOCKER);
        {
            let locker_balance = ts::take_from_address<Coin<USDC>>(&scenario, LOCKER);
            let actual_locker_fee = coin::value(&locker_balance);
            debug::print(&b"Actual locker fee received:");
            debug::print(&actual_locker_fee);
            assert!(actual_locker_fee > 0, 6);
            coin::burn_for_testing(locker_balance);
        };

        // Second swap: exact USDT -> USDC
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, USDT>>(&scenario);

            let (reserve_before_usdc, reserve_before_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves before USDT->USDC swap:");
            debug::print(&reserve_before_usdc);
            debug::print(&reserve_before_usdt);

            let swap_amount = BILLION; // 1B USDT input
            let swap_amount_u256 = (swap_amount as u256);
            let amount_out_min = (swap_amount_u256 * 94) / 100; // Using same 6% buffer
            debug::print(&b"Performing exact USDT->USDC swap");
            debug::print(&b"Swap amount:");
            debug::print(&swap_amount);

            // Calculate expected fees for second swap
            let total_fee = (swap_amount * 30) / 10000; // 0.3% fee
            let total_team_fee = (total_fee * 6) / 30;    // 0.06% team fee
            let expected_team1_fee = (total_team_fee * 40) / 100; // 40% of team fee
            let expected_team2_fee = (total_team_fee * 50) / 100; // 50% of team fee
            let expected_dev_fee = total_team_fee - expected_team1_fee - expected_team2_fee; // 10% remainder

            debug::print(&b"Expected fees from second swap:");
            debug::print(&b"Team1 fee (40%):");
            debug::print(&expected_team1_fee);
            debug::print(&b"Team2 fee (50%):");
            debug::print(&expected_team2_fee);
            debug::print(&b"Dev fee (10%):");
            debug::print(&expected_dev_fee);

            let coin_in = mint_for_testing<USDT>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens1_for_tokens0(
                &router,
                &factory,
                &mut pair,
                coin_in,
                amount_out_min,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after_usdc, reserve_after_usdt, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after USDT->USDC swap:");
            debug::print(&reserve_after_usdc);
            debug::print(&reserve_after_usdt);

            // Verify reserve changes for second swap
            assert!(reserve_after_usdt > reserve_before_usdt, 7); // USDT reserve increased
            assert!(reserve_after_usdc < reserve_before_usdc, 8); // USDC reserve decreased

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Verify fee distribution from second swap
        ts::next_tx(&mut scenario, TEAM_1);
        {
            let team1_balance = ts::take_from_address<Coin<USDT>>(&scenario, TEAM_1);
            let actual_team1_fee = coin::value(&team1_balance);
            debug::print(&b"Actual Team1 fee from second swap:");
            debug::print(&actual_team1_fee);
            assert!(actual_team1_fee > 0, 9);
            coin::burn_for_testing(team1_balance);
        };

        ts::next_tx(&mut scenario, TEAM_2);
        {
            let team2_balance = ts::take_from_address<Coin<USDT>>(&scenario, TEAM_2);
            let actual_team2_fee = coin::value(&team2_balance);
            debug::print(&b"Actual Team2 fee from second swap:");
            debug::print(&actual_team2_fee);
            assert!(actual_team2_fee > 0, 10);
            coin::burn_for_testing(team2_balance);
        };

        ts::next_tx(&mut scenario, DEV);
        {
            let dev_balance = ts::take_from_address<Coin<USDT>>(&scenario, DEV);
            let actual_dev_fee = coin::value(&dev_balance);
            debug::print(&b"Actual Dev fee from second swap:");
            debug::print(&actual_dev_fee);
            assert!(actual_dev_fee > 0, 11);
            coin::burn_for_testing(dev_balance);
        };

        debug::print(&b"Bidirectional exact input swap test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_bidirectional_sui_token_swaps() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting bidirectional SUI-Token swap test...");

        // Create SUI-USDC pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity with fee addresses
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            pair::update_fee_addresses(
                &mut pair,
                TEAM_1,
                TEAM_2,
                DEV,
                LOCKER,
                BUYBACK,
                &cap
            );

            // 1:10 ratio for price
            let sui_amount = TEN_BILLION;      // 10B SUI
            let usdc_amount = HUNDRED_BILLION; // 100B USDC
            
            debug::print(&b"Adding initial liquidity with 1:10 ratio");
            debug::print(&b"Initial SUI amount:");
            debug::print(&sui_amount);
            debug::print(&b"Initial USDC amount:");
            debug::print(&usdc_amount);

            let coin_sui = mint_for_testing<sui::sui::SUI>(sui_amount, ts::ctx(&mut scenario));
            let coin_usdc = mint_for_testing<USDC>(usdc_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_sui,
                coin_usdc,
                (sui_amount as u256),
                (usdc_amount as u256),
                (sui_amount as u256),
                (usdc_amount as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // First swap: SUI -> USDC (1% of reserve)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let (reserve_sui, reserve_usdc, _) = pair::get_reserves(&pair);
            let swap_amount = (reserve_sui / 100);  // 1% of SUI reserve
            let swap_amount_u256 = (swap_amount as u256);

            let k = reserve_sui * reserve_usdc;
            let new_sui = reserve_sui + ((swap_amount_u256 * 997) / 1000); // 0.3% fee
            let expected_usdc_out = reserve_usdc - (k / new_sui);
            let amount_out_min = (expected_usdc_out * 94) / 100; // 6% buffer

            let coin_in = mint_for_testing<sui::sui::SUI>((swap_amount as u64), ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                amount_out_min,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Second swap: USDC -> SUI (1% of reserve)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let (reserve_sui, reserve_usdc, _) = pair::get_reserves(&pair);
            let swap_amount = (reserve_usdc / 100);  // 1% of USDC reserve
            let swap_amount_u256 = (swap_amount as u256);

            let k = reserve_sui * reserve_usdc;
            let new_usdc = reserve_usdc + ((swap_amount_u256 * 997) / 1000);
            let expected_sui_out = reserve_sui - (k / new_usdc);

            // Max 45% of SUI reserves check
            let max_allowed = (reserve_sui * 45) / 100;
            let expected_sui_out = if (expected_sui_out > max_allowed) {
                max_allowed
            } else {
                expected_sui_out
            };

            let amount_out_min = (expected_sui_out * 94) / 100; // 6% buffer

            let coin_in = mint_for_testing<USDC>((swap_amount as u64), ts::ctx(&mut scenario));

            router::swap_exact_tokens1_for_tokens0(
                &router,
                &factory,
                &mut pair,
                coin_in,
                amount_out_min,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"Bidirectional SUI-Token swap test completed successfully");
        ts::end(scenario);
    }

    #[test]
    fun test_complete_cycle_operations() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting complete cycle test with medium scale numbers...");

        // Create SUI-USDC pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity in a separate transaction
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let initial_amount = 100_000_000_000_000u64; // 100M USDC with 6 decimals
            debug::print(&b"Testing with 100M tokens (100,000,000,000,000 base units)");
            debug::print(&b"Initial amount in base units:");
            debug::print(&initial_amount);

            // Add initial liquidity with exact amounts (no slippage for initial add)
            let coin_sui = mint_for_testing<sui::sui::SUI>(initial_amount, ts::ctx(&mut scenario));
            let coin_usdc = mint_for_testing<USDC>(initial_amount, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_sui,
                coin_usdc,
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                (initial_amount as u256),
                utf8(b"SUI"),
                utf8(b"USDC"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves in base units:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Perform swaps in a separate transaction
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            
            // First swap: SUI -> USDC (10% of reserves)
            let swap_amount = 10_000_000_000_000u64; // 10M tokens
            let amount_in_with_fee = (swap_amount as u256) * 9970; // 0.3% fee
            let numerator = amount_in_with_fee * reserve1;
            let denominator = (reserve0 * 10000) + amount_in_with_fee;
            let expected_output = numerator / denominator;
            let min_amount_out = (expected_output * 980) / 1000; // 2% slippage

            let coin_in = mint_for_testing<sui::sui::SUI>(swap_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            // Second swap: USDC -> SUI
            let (reserve_after_first_swap0, reserve_after_first_swap1, _) = pair::get_reserves(&pair);
            let swap_back_amount = 10_000_000_000_000u64;
            let amount_in_with_fee = (swap_back_amount as u256) * 9970;
            let numerator = amount_in_with_fee * reserve_after_first_swap0;
            let denominator = (reserve_after_first_swap1 * 10000) + amount_in_with_fee;
            let expected_output = numerator / denominator;
            let min_amount_out = (expected_output * 600) / 1000; // 40% slippage

            let coin_in = mint_for_testing<USDC>(swap_back_amount, ts::ctx(&mut scenario));

            router::swap_exact_tokens1_for_tokens0(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Remove liquidity in a final transaction
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<sui::sui::SUI, USDC>>>(&scenario, ADMIN);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            let total_lp = coin::value(&lp_coin);
            
            // Remove 99.9% of liquidity (keep as u64 for coin::split)
            let burn_amount = (total_lp * 999) / 1000; // Keep 0.1% for minimum liquidity
            let lp_burn = coin::split(&mut lp_coin, burn_amount, ts::ctx(&mut scenario));
            
            // Convert to u256 for reserve calculations
            let burn_amount_u256 = (burn_amount as u256);

            // Calculate minimum outputs with 5% slippage tolerance
            let total_lp_u256 = (total_lp as u256);
            let min_amount0_out = (reserve0_before * burn_amount_u256 / total_lp_u256) * 95 / 100;
            let min_amount1_out = (reserve1_before * burn_amount_u256 / total_lp_u256) * 95 / 100;

            // Create vector for LP coins
            let mut lp_coins = vector::empty<Coin<LPCoin<sui::sui::SUI, USDC>>>();
            vector::push_back(&mut lp_coins, lp_burn);

            router::remove_liquidity(
                &router,
                &factory,
                &mut pair,
                lp_coins,
                burn_amount as u256,
                min_amount0_out,
                min_amount1_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (final_reserve0, final_reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves after removing liquidity:");
            debug::print(&final_reserve0);
            debug::print(&final_reserve1);

            // Verify minimum liquidity remains
            assert!(final_reserve0 >= 1000 && final_reserve1 >= 1000, 1);
            // Verify final reserves make sense (should be ~0.1% of initial + minimum liquidity)
            assert!(final_reserve0 >= reserve0_before / 1000, 2);
            assert!(final_reserve1 >= reserve1_before / 1000, 3);

            // Return remaining LP tokens
            transfer::public_transfer(lp_coin, ADMIN);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"Complete cycle test completed successfully");
        ts::end(scenario);
    }


    fun to_sui_units(x: u64): u64 {
        x * 1000000000 // SUI has 9 decimals (10^9)
    }

    fun to_usdc_units(x: u64): u64 {
        x * 1000000 // USDC has 6 decimals (10^6)
    }

    fun to_sui_units_bn(x: u256): u256 {
        x * 1000000000 // SUI has 9 decimals (10^9)
    }

    fun to_usdc_units_bn(x: u256): u256 {
        x * 1000000 // USDC has 6 decimals (10^6)
    }

    #[test]
    fun test_complete_cycle_operations_medium_numbers() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"=== Starting Complete Cycle Test with Medium Numbers ===");

        // Create USDC-SUI pair with correct token ordering
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            
            debug::print(&b"Creating USDC-SUI pair...");
            factory::create_pair<USDC, sui::sui::SUI>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"SUI"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

            // Start with 50,000 USDC and 10,000 SUI (1 SUI = $5 USDC)
            let initial_usdc = to_usdc_units(50000); // 50,000 USDC
            let initial_sui = to_sui_units(10000);   // 10,000 SUI
            
            debug::print(&b"=== Adding Initial Liquidity ===");
            debug::print(&b"USDC (token0):");
            debug::print(&b"- Amount: 50000 USDC");
            debug::print(&b"- Base units:");
            debug::print(&initial_usdc);
            debug::print(&b"SUI (token1):");
            debug::print(&b"- Amount: 10000 SUI");
            debug::print(&b"- Base units:");
            debug::print(&initial_sui);

            let coin_usdc = mint_for_testing<USDC>(initial_usdc, ts::ctx(&mut scenario));
            let coin_sui = mint_for_testing<sui::sui::SUI>(initial_sui, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,
                coin_sui,
                (initial_usdc as u256),
                (initial_sui as u256),
                (initial_usdc as u256),
                (initial_sui as u256),
                utf8(b"USDC"),
                utf8(b"SUI"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&b"- USDC reserve (token0):");
            debug::print(&reserve0);
            debug::print(&b"- SUI reserve (token1):");
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // First swap: SUI -> USDC
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"=== First Swap: SUI -> USDC ===");
            debug::print(&b"Pre-swap reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&reserve0);
            debug::print(&b"- SUI (token1):");
            debug::print(&reserve1);

            // Swap 25 SUI (0.25% of liquidity)
            let swap_sui = to_sui_units(25);
            let expected_output = library::get_amounts_out(&factory, (swap_sui as u256), &pair, false);
            let min_amount_out = (expected_output * 950) / 1000; // 5% slippage

            debug::print(&b"Swap details:");
            debug::print(&b"- SUI input: 25 SUI");
            debug::print(&b"- SUI input (base units):");
            debug::print(&swap_sui);
            debug::print(&b"- Expected USDC output (base units):");
            debug::print(&expected_output);
            debug::print(&b"- Min USDC output (base units):");
            debug::print(&min_amount_out);

            let coin_in = mint_for_testing<sui::sui::SUI>(swap_sui, ts::ctx(&mut scenario));

            router::swap_exact_tokens1_for_tokens0<USDC, sui::sui::SUI>(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after0, reserve_after1, _) = pair::get_reserves(&pair);
            debug::print(&b"Post-swap reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&reserve_after0);
            debug::print(&b"- SUI (token1):");
            debug::print(&reserve_after1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Second swap: USDC -> SUI
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"=== Second Swap: USDC -> SUI ===");
            debug::print(&b"Pre-swap reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&reserve0);
            debug::print(&b"- SUI (token1):");
            debug::print(&reserve1);

            // Swap 125 USDC (0.25% of liquidity)
            let swap_usdc = to_usdc_units(125);
            let expected_output = library::get_amounts_out(&factory, (swap_usdc as u256), &pair, true);
            let min_amount_out = (expected_output * 950) / 1000; // 5% slippage

            debug::print(&b"Swap details:");
            debug::print(&b"- USDC input: 125 USDC");
            debug::print(&b"- USDC input (base units):");
            debug::print(&swap_usdc);
            debug::print(&b"- Expected SUI output (base units):");
            debug::print(&expected_output);
            debug::print(&b"- Min SUI output (base units):");
            debug::print(&min_amount_out);

            let coin_in = mint_for_testing<USDC>(swap_usdc, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1<USDC, sui::sui::SUI>(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after0, reserve_after1, _) = pair::get_reserves(&pair);
            debug::print(&b"Post-swap reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&reserve_after0);
            debug::print(&b"- SUI (token1):");
            debug::print(&reserve_after1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Remove liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<USDC, sui::sui::SUI>>>(&scenario, ADMIN);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            let total_lp = coin::value(&lp_coin);

            debug::print(&b"=== Removing Liquidity ===");
            debug::print(&b"Pre-removal reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&reserve0_before);
            debug::print(&b"- SUI (token1):");
            debug::print(&reserve1_before);
            
            // Remove 25% of liquidity
            let burn_amount = (total_lp * 25) / 100;
            let lp_burn = coin::split(&mut lp_coin, burn_amount, ts::ctx(&mut scenario));

            debug::print(&b"LP tokens:");
            debug::print(&b"- Total supply:");
            debug::print(&total_lp);
            debug::print(&b"- Amount to burn (25%):");
            debug::print(&burn_amount);

            let burn_amount_u256 = (burn_amount as u256);
            let total_lp_u256 = (total_lp as u256);

            // Calculate minimum outputs with 3% slippage tolerance
            let min_amount0_out = (reserve0_before * burn_amount_u256 / total_lp_u256) * 97 / 100;
            let min_amount1_out = (reserve1_before * burn_amount_u256 / total_lp_u256) * 97 / 100;

            debug::print(&b"Expected minimum outputs:");
            debug::print(&b"- Min USDC (base units):");
            debug::print(&min_amount0_out);
            debug::print(&b"- Min SUI (base units):");
            debug::print(&min_amount1_out);

            let mut lp_coins = vector::empty<Coin<LPCoin<USDC, sui::sui::SUI>>>();
            vector::push_back(&mut lp_coins, lp_burn);

            router::remove_liquidity(
                &router,
                &factory,
                &mut pair,
                lp_coins,
                burn_amount as u256,
                min_amount0_out,
                min_amount1_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (final_reserve0, final_reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&final_reserve0);
            debug::print(&b"- SUI (token1):");
            debug::print(&final_reserve1);

            // Verify remaining reserves are at least 73% of initial (allowing for fees)
            assert!(final_reserve0 >= reserve0_before * 73 / 100, 1);
            assert!(final_reserve1 >= reserve1_before * 73 / 100, 2);

            // Return remaining LP tokens
            transfer::public_transfer(lp_coin, ADMIN);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"=== Complete Cycle Test with Medium Numbers Completed Successfully ===");
        ts::end(scenario);
    }

const ONE_MILLION: u64 = 1000000;

    #[test]
    fun test_complete_cycle_operations_large_numbers() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"=== Starting Complete Cycle Test with Large Numbers ===");

        // Create USDC-SUI pair with correct token ordering
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            debug::print(&b"Creating USDC-SUI pair...");
            factory::create_pair<USDC, sui::sui::SUI>(  // Note: USDC first, then SUI
                &mut factory,
                utf8(b"USDC"),
                utf8(b"SUI"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

            // Add 50M USDC and 10M SUI (1 SUI = $5 USDC)
            let initial_usdc = to_usdc_units(50 * ONE_MILLION); // 50M USDC
            let initial_sui = to_sui_units(10 * ONE_MILLION);   // 10M SUI
            
            debug::print(&b"=== Adding Initial Liquidity ===");
            debug::print(&b"USDC (token0):");
            debug::print(&b"- Amount (millions): 50");
            debug::print(&b"- Base units:");
            debug::print(&initial_usdc);
            debug::print(&b"SUI (token1):");
            debug::print(&b"- Amount (millions): 10");
            debug::print(&b"- Base units:");
            debug::print(&initial_sui);

            let coin_usdc = mint_for_testing<USDC>(initial_usdc, ts::ctx(&mut scenario));
            let coin_sui = mint_for_testing<sui::sui::SUI>(initial_sui, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_usdc,  // USDC first as token0
                coin_sui,   // SUI second as token1
                (initial_usdc as u256),
                (initial_sui as u256),
                (initial_usdc as u256),
                (initial_sui as u256),
                utf8(b"USDC"),
                utf8(b"SUI"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&b"- USDC reserve (token0):");
            debug::print(&reserve0);
            debug::print(&b"- SUI reserve (token1):");
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // First Swap: SUI -> USDC
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"=== First Swap: SUI -> USDC ===");
            debug::print(&b"Pre-swap reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&reserve0);
            debug::print(&b"- SUI (token1):");
            debug::print(&reserve1);

            // Swap 1M SUI -> USDC (10% of liquidity)
            let swap_sui = to_sui_units(ONE_MILLION);
            let expected_output = library::get_amounts_out(&factory, (swap_sui as u256), &pair, false);
            let min_amount_out = (expected_output * 600) / 1000; // 40% slippage for large trades

            debug::print(&b"Swap details:");
            debug::print(&b"- SUI input (millions): 1");
            debug::print(&b"- SUI input (base units):");
            debug::print(&swap_sui);
            debug::print(&b"- Expected USDC output (base units):");
            debug::print(&expected_output);

            let coin_in = mint_for_testing<sui::sui::SUI>(swap_sui, ts::ctx(&mut scenario));

            router::swap_exact_tokens1_for_tokens0<USDC, sui::sui::SUI>(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after0, reserve_after1, _) = pair::get_reserves(&pair);
            debug::print(&b"Post-swap reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&reserve_after0);
            debug::print(&b"- SUI (token1):");
            debug::print(&reserve_after1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Second Swap: USDC -> SUI
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"=== Second Swap: USDC -> SUI ===");
            debug::print(&b"Pre-swap reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&reserve0);
            debug::print(&b"- SUI (token1):");
            debug::print(&reserve1);

            // Swap 5M USDC -> SUI (10% of liquidity)
            let swap_usdc = to_usdc_units(5 * ONE_MILLION);
            let expected_output = library::get_amounts_out(&factory, (swap_usdc as u256), &pair, true);
            let min_amount_out = (expected_output * 600) / 1000; // 40% slippage

            debug::print(&b"Swap details:");
            debug::print(&b"- USDC input (millions): 5");
            debug::print(&b"- USDC input (base units):");
            debug::print(&swap_usdc);
            debug::print(&b"- Expected SUI output (base units):");
            debug::print(&expected_output);

            let coin_in = mint_for_testing<USDC>(swap_usdc, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1<USDC, sui::sui::SUI>(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after0, reserve_after1, _) = pair::get_reserves(&pair);
            debug::print(&b"Post-swap reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&reserve_after0);
            debug::print(&b"- SUI (token1):");
            debug::print(&reserve_after1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Remove Liquidity
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);
            let mut lp_coin = ts::take_from_address<Coin<LPCoin<USDC, sui::sui::SUI>>>(&scenario, ADMIN);

            let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
            debug::print(&b"=== Removing Liquidity ===");
            debug::print(&b"Pre-removal reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&reserve0_before);
            debug::print(&b"- SUI (token1):");
            debug::print(&reserve1_before);

            let total_lp = coin::value(&lp_coin);
            
            // Remove 80% of liquidity
            let burn_amount = (total_lp * 80) / 100;
            let lp_burn = coin::split(&mut lp_coin, burn_amount, ts::ctx(&mut scenario));

            debug::print(&b"LP details:");
            debug::print(&b"- Total supply:");
            debug::print(&total_lp);
            debug::print(&b"- Amount to burn (80%):");
            debug::print(&burn_amount);

            let burn_amount_u256 = (burn_amount as u256);
            let total_lp_u256 = (total_lp as u256);

            // Calculate minimum outputs with 10% slippage tolerance
            let min_amount0_out = (reserve0_before * burn_amount_u256 / total_lp_u256) * 90 / 100;
            let min_amount1_out = (reserve1_before * burn_amount_u256 / total_lp_u256) * 90 / 100;

            debug::print(&b"Expected minimum outputs:");
            debug::print(&b"- Min USDC (base units):");
            debug::print(&min_amount0_out);
            debug::print(&b"- Min SUI (base units):");
            debug::print(&min_amount1_out);

            // Create vector for LP coins
            let mut lp_coins = vector::empty<Coin<LPCoin<USDC, sui::sui::SUI>>>();
            vector::push_back(&mut lp_coins, lp_burn);

            router::remove_liquidity(
                &router,
                &factory,
                &mut pair,
                lp_coins,           // Now passing vector of LP coins
                burn_amount as u256,        // Amount to burn
                min_amount0_out,
                min_amount1_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (final_reserve0, final_reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves:");
            debug::print(&b"- USDC (token0):");
            debug::print(&final_reserve0);
            debug::print(&b"- SUI (token1):");
            debug::print(&final_reserve1);

            // Verify remaining reserves are approximately 20% of before
            assert!(final_reserve0 >= reserve0_before * 18 / 100, 1);
            assert!(final_reserve1 >= reserve1_before * 18 / 100, 2);

            // Return remaining LP tokens
            transfer::public_transfer(lp_coin, ADMIN);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"=== Complete Cycle Test with Large Numbers Completed Successfully ===");
        ts::end(scenario);
    }

    fun to_token_units(x: u64): u64 {
        x * 1000000 // Token has 6 decimals (10^6)
    }

    #[test]
    fun test_small_pool_double_swap() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        debug::print(&b"Starting small pool double swap test...");

        // Create SUI-Token pair
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"TK1"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        // Add initial liquidity: 10 SUI = 10000 TK1 (1 SUI = 1000 TK1)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let initial_sui = to_sui_units(10);      // 10 SUI
            let initial_token = to_token_units(10000); // 10000 TK1
            
            debug::print(&b"Adding initial liquidity:");
            debug::print(&b"SUI amount (human readable):");
            debug::print(&10);
            debug::print(&b"SUI amount (base units):");
            debug::print(&initial_sui);
            debug::print(&b"Token amount (human readable):");
            debug::print(&10000);
            debug::print(&b"Token amount (base units):");
            debug::print(&initial_token);

            let coin_sui = mint_for_testing<sui::sui::SUI>(initial_sui, ts::ctx(&mut scenario));
            let coin_token = mint_for_testing<USDC>(initial_token, ts::ctx(&mut scenario));

            router::add_liquidity(
                &router,
                &mut factory,
                &mut pair,
                coin_sui,
                coin_token,
                (initial_sui as u256),
                (initial_token as u256),
                (initial_sui as u256),
                (initial_token as u256),
                utf8(b"SUI"),
                utf8(b"TK1"),
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&b"SUI reserve:");
            debug::print(&reserve0);
            debug::print(&b"Token reserve:");
            debug::print(&reserve1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // First swap: 1 SUI -> ~1000 TK1
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let swap_sui = to_sui_units(1); // 1 SUI
            let expected_output = library::get_amounts_out(&factory, (swap_sui as u256), &pair, true);
            // Using 40% slippage because small pool means high price impact
            let min_amount_out = (expected_output * 600) / 1000; 

            debug::print(&b"First swap (SUI -> TK1):");
            debug::print(&b"Input: 1 SUI");
            debug::print(&b"Expected output (base units):");
            debug::print(&expected_output);
            debug::print(&b"Minimum output (base units):");
            debug::print(&min_amount_out);

            let coin_in = mint_for_testing<sui::sui::SUI>(swap_sui, ts::ctx(&mut scenario));

            router::swap_exact_tokens0_for_tokens1(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after_first_swap0, reserve_after_first_swap1, _) = pair::get_reserves(&pair);
            debug::print(&b"Reserves after first swap:");
            debug::print(&reserve_after_first_swap0);
            debug::print(&reserve_after_first_swap1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        // Second swap: ~1000 TK1 -> SUI
        ts::next_tx(&mut scenario, ADMIN);
        {
            let router = ts::take_shared<Router>(&scenario);
            let mut factory = ts::take_shared<Factory>(&scenario);
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);

            let swap_token = to_token_units(1000); // 1000 TK1
            let expected_output = library::get_amounts_out(&factory, (swap_token as u256), &pair, false);
            // Using 40% slippage again for small pool
            let min_amount_out = (expected_output * 600) / 1000;

            debug::print(&b"Second swap (TK1 -> SUI):");
            debug::print(&b"Input: 1000 TK1");
            debug::print(&b"Expected output (base units):");
            debug::print(&expected_output);
            debug::print(&b"Minimum output (base units):");
            debug::print(&min_amount_out);

            let coin_in = mint_for_testing<USDC>(swap_token, ts::ctx(&mut scenario));

            router::swap_exact_tokens1_for_tokens0(
                &router,
                &factory,
                &mut pair,
                coin_in,
                min_amount_out,
                18446744073709551615,
                ts::ctx(&mut scenario)
            );

            let (reserve_after_second_swap0, reserve_after_second_swap1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves after both swaps:");
            debug::print(&reserve_after_second_swap0);
            debug::print(&reserve_after_second_swap1);

            ts::return_shared(router);
            ts::return_shared(factory);
            ts::return_shared(pair);
        };

        debug::print(&b"Small pool double swap test completed successfully");
        ts::end(scenario);
    }

    #[test]
fun test_multiple_lp_operations() {
    let mut scenario = ts::begin(ADMIN);
    setup(&mut scenario);
    debug::print(&b"=== Starting Multiple LP Operations Test ===");

    // Create USDC-SUI pair
    ts::next_tx(&mut scenario, ADMIN);
    {
        let router = ts::take_shared<Router>(&scenario);
        let mut factory = ts::take_shared<Factory>(&scenario);
        let cap = ts::take_from_sender<AdminCap>(&scenario);

        debug::print(&b"Creating USDC-SUI pair...");
        factory::create_pair<USDC, sui::sui::SUI>(
            &mut factory,
            utf8(b"USDC"),
            utf8(b"SUI"),
            ts::ctx(&mut scenario)
        );

        ts::return_shared(router);
        ts::return_shared(factory);
        ts::return_to_sender(&scenario, cap);
    };

    // Add initial large liquidity (100T tokens)
    ts::next_tx(&mut scenario, ADMIN);
    {
        let router = ts::take_shared<Router>(&scenario);
        let mut factory = ts::take_shared<Factory>(&scenario);
        let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

        let initial_usdc = HUNDRED_TRILLION;
        let initial_sui = HUNDRED_TRILLION;
        
        debug::print(&b"=== Adding Initial Large Liquidity ===");
        debug::print(&b"Initial amounts:");
        debug::print(&b"USDC amount: ");
        debug::print(&initial_usdc);
        debug::print(&b"SUI amount: ");
        debug::print(&initial_sui);

        let coin_usdc = mint_for_testing<USDC>(initial_usdc, ts::ctx(&mut scenario));
        let coin_sui = mint_for_testing<sui::sui::SUI>(initial_sui, ts::ctx(&mut scenario));

        router::add_liquidity(
            &router,
            &mut factory,
            &mut pair,
            coin_usdc,
            coin_sui,
            (initial_usdc as u256),
            (initial_sui as u256),
            (initial_usdc as u256),
            (initial_sui as u256),
            utf8(b"USDC"),
            utf8(b"SUI"),
            18446744073709551615,
            ts::ctx(&mut scenario)
        );

        let (reserve0, reserve1, _) = pair::get_reserves(&pair);
        debug::print(&b"Initial reserves:");
        debug::print(&b"USDC reserve: ");
        debug::print(&reserve0);
        debug::print(&b"SUI reserve: ");
        debug::print(&reserve1);

        ts::return_shared(router);
        ts::return_shared(factory);
        ts::return_shared(pair);
    };

    // Add second liquidity (50T tokens)
    ts::next_tx(&mut scenario, ADMIN);
    {
        let router = ts::take_shared<Router>(&scenario);
        let mut factory = ts::take_shared<Factory>(&scenario);
        let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);

        let add_usdc = FIFTY_TRILLION;
        let add_sui = FIFTY_TRILLION;
        
        debug::print(&b"=== Adding Second Liquidity ===");
        debug::print(&b"Adding amounts:");
        debug::print(&b"USDC amount: ");
        debug::print(&add_usdc);
        debug::print(&b"SUI amount: ");
        debug::print(&add_sui);

        let coin_usdc = mint_for_testing<USDC>(add_usdc, ts::ctx(&mut scenario));
        let coin_sui = mint_for_testing<sui::sui::SUI>(add_sui, ts::ctx(&mut scenario));

        router::add_liquidity(
            &router,
            &mut factory,
            &mut pair,
            coin_usdc,
            coin_sui,
            (add_usdc as u256),
            (add_sui as u256),
            (add_usdc as u256),
            (add_sui as u256),
            utf8(b"USDC"),
            utf8(b"SUI"),
            18446744073709551615,
            ts::ctx(&mut scenario)
        );

        let (reserve0, reserve1, _) = pair::get_reserves(&pair);
        debug::print(&b"Reserves after second addition:");
        debug::print(&b"USDC reserve: ");
        debug::print(&reserve0);
        debug::print(&b"SUI reserve: ");
        debug::print(&reserve1);

        ts::return_shared(router);
        ts::return_shared(factory);
        ts::return_shared(pair);
    };

    // Remove multiple LP portions using fixed-point math
    ts::next_tx(&mut scenario, ADMIN);
    {
        let router = ts::take_shared<Router>(&scenario);
        let factory = ts::take_shared<Factory>(&scenario);
        let mut pair = ts::take_shared<Pair<USDC, sui::sui::SUI>>(&scenario);
        let mut lp_coin = ts::take_from_address<Coin<LPCoin<USDC, sui::sui::SUI>>>(&scenario, ADMIN);

        let (reserve0_before, reserve1_before, _) = pair::get_reserves(&pair);
        let total_lp = coin::value(&lp_coin);
        
        debug::print(&b"=== Removing Multiple LP Portions ===");
        debug::print(&b"Initial state:");
        debug::print(&b"Total LP tokens: ");
        debug::print(&total_lp);
        debug::print(&b"USDC reserve: ");
        debug::print(&reserve0_before);
        debug::print(&b"SUI reserve: ");
        debug::print(&reserve1_before);

        // Create LP burn portions
        let burn_amount1 = (total_lp * 30) / 100;
        let burn_amount2 = (total_lp * 20) / 100;
        let burn_amount3 = (total_lp * 10) / 100;
        
        debug::print(&b"LP portions to burn:");
        debug::print(&b"First portion (30%): ");
        debug::print(&burn_amount1);
        debug::print(&b"Second portion (20%): ");
        debug::print(&burn_amount2);
        debug::print(&b"Third portion (10%): ");
        debug::print(&burn_amount3);

        let lp_burn1 = coin::split(&mut lp_coin, burn_amount1, ts::ctx(&mut scenario));
        let lp_burn2 = coin::split(&mut lp_coin, burn_amount2, ts::ctx(&mut scenario));
        let lp_burn3 = coin::split(&mut lp_coin, burn_amount3, ts::ctx(&mut scenario));

        let mut lp_coins = vector::empty<Coin<LPCoin<USDC, sui::sui::SUI>>>();
        vector::push_back(&mut lp_coins, lp_burn1);
        vector::push_back(&mut lp_coins, lp_burn2);
        vector::push_back(&mut lp_coins, lp_burn3);

        let total_burn_amount = burn_amount1 + burn_amount2 + burn_amount3;
        
        // Use fixed-point math for calculations
        let lp_ratio = fixed_point_math::div(
            fixed_point_math::new(total_burn_amount as u256),
            fixed_point_math::new(total_lp as u256)
        );

        // Calculate expected amounts using fixed-point math
        let amount0_base = fixed_point_math::get_raw_value(
            fixed_point_math::mul(
                fixed_point_math::new(reserve0_before),
                lp_ratio
            )
        );
        let amount1_base = fixed_point_math::get_raw_value(
            fixed_point_math::mul(
                fixed_point_math::new(reserve1_before),
                lp_ratio
            )
        );

        // Apply 25% slippage tolerance
        let min_amount0_out = amount0_base * 25 / 100;
        let min_amount1_out = amount1_base * 25 / 100;

        debug::print(&b"Calculated amounts:");
        debug::print(&b"Base amount0 (before slippage): ");
        debug::print(&amount0_base);
        debug::print(&b"Base amount1 (before slippage): ");
        debug::print(&amount1_base);
        debug::print(&b"Min amount0 (with slippage): ");
        debug::print(&min_amount0_out);
        debug::print(&b"Min amount1 (with slippage): ");
        debug::print(&min_amount1_out);

        router::remove_liquidity(
            &router,
            &factory,
            &mut pair,
            lp_coins,
            (total_burn_amount as u256),
            min_amount0_out,
            min_amount1_out,
            18446744073709551615,
            ts::ctx(&mut scenario)
        );

        let (reserve0_after, reserve1_after, _) = pair::get_reserves(&pair);
        debug::print(&b"Final reserves:");
        debug::print(&b"USDC reserve: ");
        debug::print(&reserve0_after);
        debug::print(&b"SUI reserve: ");
        debug::print(&reserve1_after);

        // Keep remaining LP tokens
        transfer::public_transfer(lp_coin, ADMIN);

        ts::return_shared(router);
        ts::return_shared(factory);
        ts::return_shared(pair);
    };

    debug::print(&b"=== Multiple LP Operations Test Completed Successfully ===");
    ts::end(scenario);
}

}