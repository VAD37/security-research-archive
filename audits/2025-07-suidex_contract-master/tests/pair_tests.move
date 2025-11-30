#[test_only]
module suitrump_dex::pair_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, mint_for_testing};
    use sui::test_utils::assert_eq;
    use std::string::utf8;
    use std::option;
    use std::debug;
    use suitrump_dex::pair::{Self, AdminCap, Pair, LPCoin};
    use suitrump_dex::test_coins::{Self, USDC};
    use sui::coin::Coin;
    use sui::transfer;
    use std::string::{Self, String};

    const ADMIN: address = @0x1;
    const TEAM_1: address = @0x44;  // 40% of team fee
    const TEAM_2: address = @0x45;  // 50% of team fee
    const DEV: address = @0x46;     // 10% of team fee
    const LOCKER: address = @0x47;
    const BUYBACK: address = @0x48;

    // Test amounts updated for u128
    const MILLION: u64 = 1_000_000;
    const BILLION: u64 = 1_000_000_000;
    const INITIAL_LIQUIDITY: u64 = 1_000_000_000;      // 1B tokens
    const SWAP_AMOUNT: u64 = 10_000_000;               // 10M tokens
    const MINIMUM_LIQUIDITY: u128 = 1000;

    fun setup(scenario: &mut Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            pair::init_for_testing(ts::ctx(scenario));
        };
    }

    #[test]
    fun test_create_pair() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let pair = pair::new<sui::sui::SUI, USDC>(
                utf8(b"SUI"),
                utf8(b"USDC"),
                TEAM_1,
                TEAM_2, 
                DEV,
                LOCKER,
                BUYBACK,
                ts::ctx(&mut scenario)
            );
            pair::share_pair(pair);
            ts::return_to_sender(&scenario, cap);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_add_liquidity() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let pair = pair::new<sui::sui::SUI, USDC>(
                utf8(b"SUI"),
                utf8(b"USDC"),
                TEAM_1,
                TEAM_2, 
                DEV,
                LOCKER,
                BUYBACK,
                ts::ctx(&mut scenario)
            );
            pair::share_pair(pair);
            ts::return_to_sender(&scenario, cap);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            let coin0 = mint_for_testing<sui::sui::SUI>(INITIAL_LIQUIDITY, ts::ctx(&mut scenario));
            let coin1 = mint_for_testing<USDC>(INITIAL_LIQUIDITY, ts::ctx(&mut scenario));
            
            let lp_tokens = pair::mint(&mut pair, coin0, coin1, ts::ctx(&mut scenario));

            // Verify LP tokens were minted
            let lp_amount = coin::value(&lp_tokens);
            debug::print(&b"LP tokens minted:");
            debug::print(&lp_amount);
            assert!(lp_amount > 0, 1);

            // Verify reserves
            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            assert_eq(reserve0, (INITIAL_LIQUIDITY as u256));
            assert_eq(reserve1, (INITIAL_LIQUIDITY as u256));

            ts::return_shared(pair);
            coin::burn_for_testing(lp_tokens);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_swap() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let pair = pair::new<sui::sui::SUI, USDC>(
                utf8(b"SUI"),
                utf8(b"USDC"),
                TEAM_1,
                TEAM_2, 
                DEV,
                LOCKER,
                BUYBACK,
                ts::ctx(&mut scenario)
            );
            pair::share_pair(pair);
            ts::return_to_sender(&scenario, cap);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            
            // Add initial liquidity
            let coin0 = mint_for_testing<sui::sui::SUI>(INITIAL_LIQUIDITY, ts::ctx(&mut scenario));
            let coin1 = mint_for_testing<USDC>(INITIAL_LIQUIDITY, ts::ctx(&mut scenario));
            let lp_tokens = pair::mint(&mut pair, coin0, coin1, ts::ctx(&mut scenario));

            let (r0, r1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial reserves:");
            debug::print(&r0);
            debug::print(&r1);

            // Perform swap
            let swap_in = mint_for_testing<sui::sui::SUI>(SWAP_AMOUNT, ts::ctx(&mut scenario));
            let expected_output = (SWAP_AMOUNT * 997) / 1000; // Approximate considering 0.3% fee
            
            let (coin0_out, mut coin1_out) = pair::swap(
                &mut pair,
                option::some(swap_in),
                option::none(),
                0,
                (expected_output as u256),
                ts::ctx(&mut scenario)
            );

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            // Check outputs
            option::destroy_none(coin0_out);
            if (option::is_some(&coin1_out)) {
                let coin = option::extract(&mut coin1_out);
                assert!(coin::value(&coin) <= SWAP_AMOUNT, 0);
                coin::burn_for_testing(coin);
            };
            option::destroy_none(coin1_out);

            coin::burn_for_testing(lp_tokens);
            ts::return_shared(pair);
        };

        // Verify fees were distributed
        ts::next_tx(&mut scenario, TEAM_1);
        {
            let team_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, TEAM_1);
            assert!(coin::value(&team_coins) > 0, 0);
            coin::burn_for_testing(team_coins);
        };

        ts::next_tx(&mut scenario, TEAM_2);
        {
            let team_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, TEAM_2);
            assert!(coin::value(&team_coins) > 0, 0);
            coin::burn_for_testing(team_coins);
        };

        ts::next_tx(&mut scenario, DEV);
        {
            let team_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, DEV);
            assert!(coin::value(&team_coins) > 0, 0);
            coin::burn_for_testing(team_coins);
        };

        ts::next_tx(&mut scenario, LOCKER);
        {
            let locker_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, LOCKER);
            assert!(coin::value(&locker_coins) > 0, 0);
            coin::burn_for_testing(locker_coins);
        };

        ts::next_tx(&mut scenario, BUYBACK);
        {
            let buyback_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, BUYBACK);
            assert!(coin::value(&buyback_coins) > 0, 0);
            coin::burn_for_testing(buyback_coins);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_remove_liquidity() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let pair = pair::new<sui::sui::SUI, USDC>(
                utf8(b"SUI"),
                utf8(b"USDC"),
                TEAM_1,
                TEAM_2, 
                DEV,
                LOCKER,
                BUYBACK,
                ts::ctx(&mut scenario)
            );
            pair::share_pair(pair);
            ts::return_to_sender(&scenario, cap);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            
            // Add liquidity
            let coin0 = mint_for_testing<sui::sui::SUI>(INITIAL_LIQUIDITY, ts::ctx(&mut scenario));
            let coin1 = mint_for_testing<USDC>(INITIAL_LIQUIDITY, ts::ctx(&mut scenario));
            let mut lp_tokens = pair::mint(&mut pair, coin0, coin1, ts::ctx(&mut scenario));

            let initial_lp_supply = coin::value(&lp_tokens);
            let burn_amount = initial_lp_supply - 1000;
            let burn_tokens = coin::split(&mut lp_tokens, burn_amount, ts::ctx(&mut scenario));

            // Remove liquidity
            let (coin0_out, coin1_out) = pair::burn(&mut pair, burn_tokens, ts::ctx(&mut scenario));

            // Verify output amounts
            assert!(coin::value(&coin0_out) > 0, 1);
            assert!(coin::value(&coin1_out) > 0, 2);

            // Keep minimum liquidity
            transfer::public_transfer(lp_tokens, ADMIN);
            
            coin::burn_for_testing(coin0_out);
            coin::burn_for_testing(coin1_out);
            
            ts::return_shared(pair);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_fee_distribution() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let pair = pair::new<sui::sui::SUI, USDC>(
                utf8(b"SUI"),
                utf8(b"USDC"),
                TEAM_1,
                TEAM_2, 
                DEV,
                LOCKER,
                BUYBACK,
                ts::ctx(&mut scenario)
            );
            pair::share_pair(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Use a larger swap amount to ensure visible fees
        let initial_liquidity: u64 = 1_000_000_000_000; // 1 trillion
        let swap_amount: u64 = 100_000_000_000; // 100 billion

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            
            // Add initial liquidity
            let coin0 = mint_for_testing<sui::sui::SUI>(initial_liquidity, ts::ctx(&mut scenario));
            let coin1 = mint_for_testing<USDC>(initial_liquidity, ts::ctx(&mut scenario));
            let lp_tokens = pair::mint(&mut pair, coin0, coin1, ts::ctx(&mut scenario));

            // Perform swap
            let swap_in = mint_for_testing<sui::sui::SUI>(swap_amount, ts::ctx(&mut scenario));
            let expected_output = (swap_amount * 997) / 1000; // After 0.3% fee
            
            let (coin0_out, mut coin1_out) = pair::swap(
                &mut pair,
                option::some(swap_in),
                option::none(),
                0,
                (expected_output as u256),
                ts::ctx(&mut scenario)
            );

            // Clean up
            option::destroy_none(coin0_out);
            if (option::is_some(&coin1_out)) {
                coin::burn_for_testing(option::extract(&mut coin1_out));
            };
            option::destroy_none(coin1_out);
            coin::burn_for_testing(lp_tokens);
            ts::return_shared(pair);
        };

        // Calculate expected fees
        let total_fee = (swap_amount * 30) / 10000; // 0.3%
        let total_team_fee = (total_fee * 6) / 30;    // 0.06%
        let expected_team1_fee = (total_team_fee * 40) / 100; // 40% of team fee
        let expected_team2_fee = (total_team_fee * 50) / 100; // 50% of team fee
        let expected_dev_fee = total_team_fee - expected_team1_fee - expected_team2_fee; // Remainder (10%)
        let expected_locker_fee = (total_fee * 3) / 30;  // 0.03%
        let expected_buyback_fee = (total_fee * 3) / 30; // 0.03%

        // Verify team1 fee
        ts::next_tx(&mut scenario, TEAM_1);
        {
            let team_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, TEAM_1);
            let team_fee = coin::value(&team_coins);
            debug::print(&b"Team1 fee received:");
            debug::print(&team_fee);
            assert!(team_fee >= expected_team1_fee, 0);
            coin::burn_for_testing(team_coins);
        };

        // Verify team2 fee
        ts::next_tx(&mut scenario, TEAM_2);
        {
            let team_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, TEAM_2);
            let team_fee = coin::value(&team_coins);
            debug::print(&b"Team2 fee received:");
            debug::print(&team_fee);
            assert!(team_fee >= expected_team2_fee, 0);
            coin::burn_for_testing(team_coins);
        };

        // Verify dev fee
        ts::next_tx(&mut scenario, DEV);
        {
            let team_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, DEV);
            let team_fee = coin::value(&team_coins);
            debug::print(&b"Dev fee received:");
            debug::print(&team_fee);
            assert!(team_fee >= expected_dev_fee, 0);
            coin::burn_for_testing(team_coins);
        };

        // Verify locker fee
        ts::next_tx(&mut scenario, LOCKER);
        {
            let locker_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, LOCKER);
            let locker_fee = coin::value(&locker_coins);
            debug::print(&b"Locker fee received:");
            debug::print(&locker_fee);
            assert!(locker_fee >= expected_locker_fee, 0);
            coin::burn_for_testing(locker_coins);
        };

        // Verify buyback fee
        ts::next_tx(&mut scenario, BUYBACK);
        {
            let buyback_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, BUYBACK);
            let buyback_fee = coin::value(&buyback_coins);
            debug::print(&b"Buyback fee received:");
            debug::print(&buyback_fee);
            assert!(buyback_fee >= expected_buyback_fee, 0);
            coin::burn_for_testing(buyback_coins);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_large_numbers() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let pair = pair::new<sui::sui::SUI, USDC>(
                utf8(b"SUI"),
                utf8(b"USDC"),
                TEAM_1,
                TEAM_2, 
                DEV,
                LOCKER,
                BUYBACK,
                ts::ctx(&mut scenario)
            );
            pair::share_pair(pair);
            ts::return_to_sender(&scenario, cap);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            
            // Test with billion tokens
            let coin0 = mint_for_testing<sui::sui::SUI>(BILLION, ts::ctx(&mut scenario));
            let coin1 = mint_for_testing<USDC>(BILLION, ts::ctx(&mut scenario));
            let lp_tokens = pair::mint(&mut pair, coin0, coin1, ts::ctx(&mut scenario));

            let (reserve0, reserve1, _) = pair::get_reserves(&pair);
            debug::print(&b"Billion scale reserves:");
            debug::print(&reserve0);
            debug::print(&reserve1);

            assert!(reserve0 == (BILLION as u256), 0);
            assert!(reserve1 == (BILLION as u256), 0);

            coin::burn_for_testing(lp_tokens);
            ts::return_shared(pair);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_pair_name() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let pair = pair::new<sui::sui::SUI, USDC>(
                utf8(b"SUI"),
                utf8(b"USDC"),
                TEAM_1,
                TEAM_2, 
                DEV,
                LOCKER,
                BUYBACK,
                ts::ctx(&mut scenario)
            );

            assert_eq(pair::get_name(&pair), string::utf8(b"Suitrump V2 SUI/USDC"));
            assert_eq(pair::get_symbol(&pair), string::utf8(b"SUIT-V2"));

            pair::share_pair(pair);
            ts::return_to_sender(&scenario, cap);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_large_value_swap() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(&scenario);
            let pair = pair::new<sui::sui::SUI, USDC>(
                utf8(b"SUI"),
                utf8(b"USDC"),
                TEAM_1,
                TEAM_2, 
                DEV,
                LOCKER,
                BUYBACK,
                ts::ctx(&mut scenario)
            );
            pair::share_pair(pair);
            ts::return_to_sender(&scenario, cap);
        };

        // Test with large values (100 billion tokens)
        let large_amount: u64 = 100_000_000_000;
        let swap_amount: u64 = 10_000_000_000; // 10 billion tokens

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
            
            // Add initial liquidity with large amounts
            let coin0 = mint_for_testing<sui::sui::SUI>(large_amount, ts::ctx(&mut scenario));
            let coin1 = mint_for_testing<USDC>(large_amount, ts::ctx(&mut scenario));
            let lp_tokens = pair::mint(&mut pair, coin0, coin1, ts::ctx(&mut scenario));

            // Log initial reserves
            let (r0, r1, _) = pair::get_reserves(&pair);
            debug::print(&b"Initial large reserves:");
            debug::print(&r0);
            debug::print(&r1);

            // Perform large swap
            let swap_in = mint_for_testing<sui::sui::SUI>(swap_amount, ts::ctx(&mut scenario));
            let expected_output = (swap_amount * 997) / 1000; // Approximate after 0.3% fee
            
            let (coin0_out, mut coin1_out) = pair::swap(
                &mut pair,
                option::some(swap_in),
                option::none(),
                0,
                (expected_output as u256),
                ts::ctx(&mut scenario)
            );

            // Log final reserves
            let (final_r0, final_r1, _) = pair::get_reserves(&pair);
            debug::print(&b"Final large reserves:");
            debug::print(&final_r0);
            debug::print(&final_r1);

            // Clean up
            option::destroy_none(coin0_out);
            if (option::is_some(&coin1_out)) {
                coin::burn_for_testing(option::extract(&mut coin1_out));
            };
            option::destroy_none(coin1_out);
            coin::burn_for_testing(lp_tokens);

            ts::return_shared(pair);
        };

        ts::end(scenario);
    }

    #[test]
fun test_extreme_value_fee_distribution() {
    let mut scenario = ts::begin(ADMIN);
    setup(&mut scenario);

    // Constants for extreme values
    // Using quadrillion (10^15) as base unit to simulate meme coins
    let qUADRILLION: u64 = 1_000_000_000_000_000;
    
    // Initial liquidity of 1 quintillion (10^18)
    let initial_liquidity: u64 = qUADRILLION * 1000;
    
    // Swap amount of 100 quadrillion (10^17)
    let swap_amount: u64 = qUADRILLION * 10;

    ts::next_tx(&mut scenario, ADMIN);
    {
        let cap = ts::take_from_sender<AdminCap>(&scenario);
        let pair = pair::new<sui::sui::SUI, USDC>(
            utf8(b"SUI"),
            utf8(b"USDC"),
            TEAM_1,
            TEAM_2, 
            DEV,
            LOCKER,
            BUYBACK,
            ts::ctx(&mut scenario)
        );
        pair::share_pair(pair);
        ts::return_to_sender(&scenario, cap);
    };

    ts::next_tx(&mut scenario, ADMIN);
    {
        let mut pair = ts::take_shared<Pair<sui::sui::SUI, USDC>>(&scenario);
        
        // Add massive initial liquidity
        let coin0 = mint_for_testing<sui::sui::SUI>(initial_liquidity, ts::ctx(&mut scenario));
        let coin1 = mint_for_testing<USDC>(initial_liquidity, ts::ctx(&mut scenario));
        
        debug::print(&b"Initial liquidity amount:");
        debug::print(&initial_liquidity);
        
        let lp_tokens = pair::mint(&mut pair, coin0, coin1, ts::ctx(&mut scenario));

        // Log initial reserves
        let (r0, r1, _) = pair::get_reserves(&pair);
        debug::print(&b"Initial extreme reserves:");
        debug::print(&r0);
        debug::print(&r1);

        // Perform massive swap
        let swap_in = mint_for_testing<sui::sui::SUI>(swap_amount, ts::ctx(&mut scenario));
        
        debug::print(&b"Swap amount:");
        debug::print(&swap_amount);

        // Calculate expected output (99.7% of input due to 0.3% fee)
        let expected_output:u256 = (1000000000000000000 * 997) / 1000;
        
        let (coin0_out, mut coin1_out) = pair::swap(
            &mut pair,
            option::some(swap_in),
            option::none(),
            0,
            (expected_output ),
            ts::ctx(&mut scenario)
        );

        // Log final reserves
        let (final_r0, final_r1, _) = pair::get_reserves(&pair);
        debug::print(&b"Final extreme reserves:");
        debug::print(&final_r0);
        debug::print(&final_r1);

        // Clean up outputs
        option::destroy_none(coin0_out);
        if (option::is_some(&coin1_out)) {
            coin::burn_for_testing(option::extract(&mut coin1_out));
        };
        option::destroy_none(coin1_out);
        coin::burn_for_testing(lp_tokens);
        ts::return_shared(pair);
    };

    // Calculate expected extreme fees
    let total_fee = (swap_amount * 30) / 10000; // 0.3%
    debug::print(&b"Total fee amount:");
    debug::print(&total_fee);

    // Calculate expected extreme fees
    let total_fee = (swap_amount * 30) / 10000; // 0.3%
    let total_team_fee = (total_fee * 6) / 30;    // 0.06%
    let expected_team1_fee = (total_team_fee * 40) / 100; // 40% of team fee
    let expected_team2_fee = (total_team_fee * 50) / 100; // 50% of team fee
    let expected_dev_fee = total_team_fee - expected_team1_fee - expected_team2_fee; // Remainder (10%)
    let expected_locker_fee = (total_fee * 3) / 30;  // 0.03%
    let expected_buyback_fee = (total_fee * 3) / 30; // 0.03%

    debug::print(&b"Expected fee breakdown:");
    debug::print(&b"Team1 fee (40%):");
    debug::print(&expected_team1_fee);
    debug::print(&b"Team2 fee (50%):");
    debug::print(&expected_team2_fee);
    debug::print(&b"Dev fee (10%):");
    debug::print(&expected_dev_fee);
    debug::print(&b"Locker fee:");
    debug::print(&expected_locker_fee);
    debug::print(&b"Buyback fee:");
    debug::print(&expected_buyback_fee);

    // Verify team 1 fee
    ts::next_tx(&mut scenario, TEAM_1);
    {
        let team_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, TEAM_1);
        let team_fee = coin::value(&team_coins);
        debug::print(&b"Actual team fee received:");
        debug::print(&team_fee);
        assert!(team_fee >= expected_team1_fee, 0);
        
        // Verify fee is within expected range (shouldn't exceed expected by more than 1 unit)
        assert!(team_fee <= expected_team1_fee + 1, 1);
        
        coin::burn_for_testing(team_coins);
    };

     // Verify team 2 fee
    ts::next_tx(&mut scenario, TEAM_2);
    {
        let team_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, TEAM_2);
        let team_fee = coin::value(&team_coins);
        debug::print(&b"Actual team fee received:");
        debug::print(&team_fee);
        assert!(team_fee >= expected_team2_fee, 0);
        
        // Verify fee is within expected range (shouldn't exceed expected by more than 1 unit)
        assert!(team_fee <= expected_team2_fee + 1, 1);
        
        coin::burn_for_testing(team_coins);
    };

     // Verify dev fee
    ts::next_tx(&mut scenario, DEV);
    {
        let team_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, DEV);
        let team_fee = coin::value(&team_coins);
        debug::print(&b"Actual team fee received:");
        debug::print(&team_fee);
        assert!(team_fee >= expected_dev_fee, 0);
        
        // Verify fee is within expected range (shouldn't exceed expected by more than 1 unit)
        assert!(team_fee <= expected_dev_fee + 1, 1);
        
        coin::burn_for_testing(team_coins);
    };

    // Verify locker fee
    ts::next_tx(&mut scenario, LOCKER);
    {
        let locker_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, LOCKER);
        let locker_fee = coin::value(&locker_coins);
        debug::print(&b"Actual locker fee received:");
        debug::print(&locker_fee);
        assert!(locker_fee >= expected_locker_fee, 2);
        assert!(locker_fee <= expected_locker_fee + 1, 3);
        coin::burn_for_testing(locker_coins);
    };

    // Verify buyback fee
    ts::next_tx(&mut scenario, BUYBACK);
    {
        let buyback_coins = ts::take_from_address<Coin<sui::sui::SUI>>(&scenario, BUYBACK);
        let buyback_fee = coin::value(&buyback_coins);
        debug::print(&b"Actual buyback fee received:");
        debug::print(&buyback_fee);
        assert!(buyback_fee >= expected_buyback_fee, 4);
        assert!(buyback_fee <= expected_buyback_fee + 1, 5);
        coin::burn_for_testing(buyback_coins);
    };

    ts::end(scenario);
}

// Helper function to calculate percentage of a value with proper scaling
fun calculate_percentage(value: u64, numerator: u64, denominator: u64): u64 {
    ((value as u128) * (numerator as u128) / (denominator as u128) as u64)
}

}