#[test_only]
module suitrump_dex::library_tests {
    use sui::test_utils::assert_eq;
    use suitrump_dex::library;
    use std::debug;

    // Constants
    const BASIS_POINTS: u256 = 10000;
    const TOTAL_FEE_BPS: u256 = 30;     // 0.3%
    const TEAM_FEE_BPS: u256 = 6;       // 0.06%
    const LOCKER_FEE_BPS: u256 = 3;     // 0.03%
    const BUYBACK_FEE_BPS: u256 = 3;    // 0.03%
    const LP_FEE_BPS: u256 = 18;        // 0.18%

    const ONE: u256 = 1000000000;  // 1 with 9 decimals

    const QUADRILLION: u256 = 1_000_000_000_000_000;
    const QUINTILLION: u256 = 1_000_000_000_000_000_000;
    const SEXTILLION: u256 = 1_000_000_000_000_000_000_000;

    const MAX_U256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    const HALF_MAX_U256: u256 = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    const DECILLION: u256 = 1_000_000_000_000_000_000_000_000_000_000_000; // 10^33

    #[test]
    fun test_fee_breakdown() {
        let amount: u256 = 10000 * ONE;  // 10000 tokens with 9 decimals
        let (team_fee, locker_fee, buyback_fee, lp_fee) = library::compute_fee_amounts(amount);
        
        // Calculate expected fees with high precision
        let total_fee_amount = (amount * TOTAL_FEE_BPS) / BASIS_POINTS;
        
        debug::print(&b"Test amount:");
        debug::print(&amount);
        debug::print(&b"Total fee amount:");
        debug::print(&total_fee_amount);
        debug::print(&b"Actual fees (team/locker/buyback/lp):");
        debug::print(&team_fee);
        debug::print(&locker_fee);
        debug::print(&buyback_fee);
        debug::print(&lp_fee);

        // Verify individual fees
        assert!(team_fee == (total_fee_amount * TEAM_FEE_BPS) / TOTAL_FEE_BPS, 0);
        assert!(locker_fee == (total_fee_amount * LOCKER_FEE_BPS) / TOTAL_FEE_BPS, 1);
        assert!(buyback_fee == (total_fee_amount * BUYBACK_FEE_BPS) / TOTAL_FEE_BPS, 2);
        assert!(lp_fee == (total_fee_amount * LP_FEE_BPS) / TOTAL_FEE_BPS, 3);
    }

    

    #[test]
    fun test_get_amount_out_small() {
        let amount_in = 1000 * ONE;  // 1000 tokens
        let reserve = 1000000 * ONE; // 1M tokens for both reserves
        
        let amount_out = library::get_amount_out(amount_in, reserve, reserve);
        
        // Calculate minimum expected output (considering price impact)
        let min_output = (amount_in * 996) / 1000; // 99.6% after fees and slight price impact
        
        debug::print(&b"Input amount:");
        debug::print(&amount_in);
        debug::print(&b"Output amount:");
        debug::print(&amount_out);
        debug::print(&b"Min expected:");
        debug::print(&min_output);

        assert!(amount_out > 0, 0);
        assert!(amount_out >= min_output, 1);
        assert!(amount_out < amount_in, 2); // Should be less than input due to fees
    }

    #[test]
    fun test_get_amount_in_small() {
        let amount_out = 1000 * ONE;  // Want 1000 tokens out
        let reserve = 1000000 * ONE;  // 1M tokens for both reserves
        
        let amount_in = library::get_amount_in(amount_out, reserve, reserve);
        
        // Calculate maximum expected input with adjusted tolerance
        let max_input = (amount_out * 1005) / 1000; // Allow up to 100.5% for fees and slippage
        
        debug::print(&b"Desired output:");
        debug::print(&amount_out);
        debug::print(&b"Required input:");
        debug::print(&amount_in);
        debug::print(&b"Max expected input:");
        debug::print(&max_input);

        assert!(amount_in > amount_out, 0);  // Must input more than output due to fee
        assert!(amount_in <= max_input, 1);  // Shouldn't require more than maximum
    }

    #[test]
    fun test_price_impact() {
        let reserve = 1000000 * ONE;  // 1M token reserve
        
        // Use much smaller percentages to show price impact
        let small_trade = reserve / 10000;    // 0.01% of reserve
        let medium_trade = reserve / 1000;    // 0.1% of reserve
        let large_trade = reserve / 100;      // 1% of reserve
        
        let small_out = library::get_amount_out(small_trade, reserve, reserve);
        let medium_out = library::get_amount_out(medium_trade, reserve, reserve);
        let large_out = library::get_amount_out(large_trade, reserve, reserve);
        
        // Calculate effective output rates
        let small_rate = (small_out * BASIS_POINTS) / small_trade;
        let medium_rate = (medium_out * BASIS_POINTS) / medium_trade;
        let large_rate = (large_out * BASIS_POINTS) / large_trade;
        
        debug::print(&b"Trade amounts (small/medium/large):");
        debug::print(&small_trade);
        debug::print(&medium_trade);
        debug::print(&large_trade);
        debug::print(&b"Output rates (small/medium/large):");
        debug::print(&small_rate);
        debug::print(&medium_rate);
        debug::print(&large_rate);

        // Smaller trades should have better rates
        assert!(small_rate >= medium_rate, 0);
        assert!(medium_rate >= large_rate, 1);
    }

    #[test]
    fun test_extreme_values() {
        // Test with huge amounts (simulating meme coins with 18 decimals)
        let amount_in = QUINTILLION;  // 1 quintillion tokens
        let reserve = SEXTILLION;     // 1 sextillion tokens in reserve
        
        // Test get_amount_out with extreme values
        let amount_out = library::get_amount_out(amount_in, reserve, reserve);
        
        // Calculate expected minimum output (after 0.3% fee)
        let min_expected_out = (amount_in * 996) / 1000; // 99.6% considering fee and minor price impact
        
        debug::print(&b"Extreme Value Swap Test:");
        debug::print(&b"Input amount (quintillion):");
        debug::print(&amount_in);
        debug::print(&b"Reserve size (sextillion):");
        debug::print(&reserve);
        debug::print(&b"Output amount:");
        debug::print(&amount_out);
        debug::print(&b"Minimum expected:");
        debug::print(&min_expected_out);

        // Verify output is within expected range
        assert!(amount_out > 0, 0);
        assert!(amount_out >= min_expected_out, 1);
        assert!(amount_out < amount_in, 2); // Should be less than input due to fees

        // Test fee computation with large numbers
        let (team_fee, locker_fee, buyback_fee, lp_fee) = library::compute_fee_amounts(amount_in);

        debug::print(&b"Fee breakdown for huge amount:");
        debug::print(&b"Team fee (0.06%):");
        debug::print(&team_fee);
        debug::print(&b"Locker fee (0.03%):");
        debug::print(&locker_fee);
        debug::print(&b"Buyback fee (0.03%):");
        debug::print(&buyback_fee);
        debug::print(&b"LP fee (0.18%):");
        debug::print(&lp_fee);

        // Verify fees add up correctly
        let total_fee = team_fee + locker_fee + buyback_fee + lp_fee;
        let expected_total_fee = (amount_in * 30) / 10000; // 0.3%
        assert!(total_fee == expected_total_fee, 3);

        // Test get_amount_in with extreme values
        let huge_output = QUINTILLION;  // Want 1 quintillion tokens out
        let amount_in_required = library::get_amount_in(huge_output, reserve, reserve);
        
        // Expected input should be around 100.3% of output due to fees
        let max_input_expected = (huge_output * 1005) / 1000; // Allow up to 100.5% for fees + slippage

        debug::print(&b"Extreme Value Get Amount In Test:");
        debug::print(&b"Desired output (quintillion):");
        debug::print(&huge_output);
        debug::print(&b"Required input:");
        debug::print(&amount_in_required);
        debug::print(&b"Max expected input:");
        debug::print(&max_input_expected);

        assert!(amount_in_required > huge_output, 4); // Must be more than output due to fees
        assert!(amount_in_required <= max_input_expected, 5); // Shouldn't exceed max expected

        // Test price impact with large values
        let large_trade = reserve / 100;     // 1% of reserve
        let larger_trade = reserve / 10;     // 10% of reserve
        let largest_trade = reserve / 4;     // 25% of reserve

        let out1 = library::get_amount_out(large_trade, reserve, reserve);
        let out2 = library::get_amount_out(larger_trade, reserve, reserve);
        let out3 = library::get_amount_out(largest_trade, reserve, reserve);

        debug::print(&b"Large trades price impact:");
        debug::print(&b"1% trade effective rate:");
        debug::print(&((out1 * 10000) / large_trade));
        debug::print(&b"10% trade effective rate:");
        debug::print(&((out2 * 10000) / larger_trade));
        debug::print(&b"25% trade effective rate:");
        debug::print(&((out3 * 10000) / largest_trade));

        // Verify price impact increases with size
        let rate1 = (out1 * 10000) / large_trade;
        let rate2 = (out2 * 10000) / larger_trade;
        let rate3 = (out3 * 10000) / largest_trade;
        
        assert!(rate1 >= rate2, 6);
        assert!(rate2 >= rate3, 7);
    }

    #[test]
    fun test_consecutive_large_swaps() {
        let initial_reserve = SEXTILLION;
        let mut reserve_in = initial_reserve;
        let mut reserve_out = initial_reserve;
        let swap_amount = QUINTILLION;

        debug::print(&b"Consecutive large swaps test:");
        debug::print(&b"Initial reserves:");
        debug::print(&initial_reserve);
        debug::print(&b"Swap amount:");
        debug::print(&swap_amount);

        let mut i = 0;
        while (i < 5) {
            let out_amount = library::get_amount_out(swap_amount, reserve_in, reserve_out);
            
            debug::print(&b"Swap number:");
            debug::print(&i);
            debug::print(&b"Output amount:");
            debug::print(&out_amount);
            debug::print(&b"Effective rate:");
            debug::print(&((out_amount * 10000) / swap_amount));

            reserve_in = reserve_in + swap_amount;
            reserve_out = reserve_out - out_amount;

            assert!(out_amount > 0, 0);
            assert!(reserve_out > initial_reserve / 2, 1); // Should never drain more than 50%
            
            i = i + 1;
        };
    }
    #[test]
    fun test_maximum_possible_values() {
        let initial_reserve = DECILLION * 1000;  // 10^36
        let swap_amount = DECILLION;             // 10^33
        
        debug::print(&b"Maximum value test:");
        debug::print(&b"Initial reserve (10^36):");
        debug::print(&initial_reserve);
        debug::print(&b"Swap amount (10^33):");
        debug::print(&swap_amount);

        // Test 1: Extreme swap
        let amount_out = library::get_amount_out(swap_amount, initial_reserve, initial_reserve);
        debug::print(&b"Output amount for extreme swap:");
        debug::print(&amount_out);
        debug::print(&b"Effective rate:");
        debug::print(&((amount_out * 10000) / swap_amount));

        // Test 2: Fee distribution at extreme values
        let (team_fee, locker_fee, buyback_fee, lp_fee) = library::compute_fee_amounts(swap_amount);
        
        debug::print(&b"Fee breakdown for extreme amount:");
        debug::print(&b"Team fee (0.06%):");
        debug::print(&team_fee);
        debug::print(&b"Locker fee (0.03%):");
        debug::print(&locker_fee);
        debug::print(&b"Buyback fee (0.03%):");
        debug::print(&buyback_fee);
        debug::print(&b"LP fee (0.18%):");
        debug::print(&lp_fee);

        // Test 3: Multiple large swaps simulation
        let mut reserve_in = initial_reserve;
        let mut reserve_out = initial_reserve;

        debug::print(&b"Sequential extreme swaps:");
        let mut i = 0;
        while (i < 3) {
            let out = library::get_amount_out(swap_amount, reserve_in, reserve_out);
            debug::print(&b"Swap:");
            debug::print(&i);
            debug::print(&b"Output:");
            debug::print(&out);
            debug::print(&b"Rate:");
            debug::print(&((out * 10000) / swap_amount));

            reserve_in = reserve_in + swap_amount;
            reserve_out = reserve_out - out;
            i = i + 1;
        };

        // Test 4: Maximum possible input test
        let max_safe_input = initial_reserve / 2;  // 50% of reserve
        let huge_out = library::get_amount_out(max_safe_input, initial_reserve, initial_reserve);
        
        debug::print(&b"Maximum safe input test (50% of reserve):");
        debug::print(&b"Input amount:");
        debug::print(&max_safe_input);
        debug::print(&b"Output amount:");
        debug::print(&huge_out);
        debug::print(&b"Price impact (bps):");
        debug::print(&(10000 - (huge_out * 10000) / max_safe_input));

        // Verify all values are within safe bounds
        assert!(huge_out < initial_reserve, 0);
        assert!(huge_out > 0, 1);
        
        // Verify fee calculations remain accurate at extreme values
        let total_fee = team_fee + locker_fee + buyback_fee + lp_fee;
        let expected_total_fee = (swap_amount * 30) / 10000;
        assert!(total_fee == expected_total_fee, 2);

        // Verify price impact increases proportionally
        let small_rate = ((amount_out * 10000) / swap_amount);
        let large_rate = ((huge_out * 10000) / max_safe_input);
        assert!(small_rate >= large_rate, 3);
    }
}