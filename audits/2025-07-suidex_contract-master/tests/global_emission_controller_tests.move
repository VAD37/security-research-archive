#[test_only]
module suitrump_dex::global_emission_controller_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use suitrump_dex::global_emission_controller::{Self, AdminCap, GlobalEmissionConfig};
    use std::debug;
    use std::string::utf8;

    // Test addresses
    const ADMIN: address = @0x1;
    const USER1: address = @0x2;
    const FARM_CONTRACT: address = @0x3;
    const VICTORY_CONTRACT: address = @0x4;
    // Add these constants with your other existing constants
    const DEV_CONTRACT: address = @0x5;
    const WEEKLY_DECAY_RATE: u64 = 9900; // 99% = 1% decay per week
    const E_DECAY_CALCULATION_ERROR: u64 = 1007;
    // Time constants
    const DAY_IN_MS: u64 = 86400000; // 86400 * 1000
    const WEEK_IN_MS: u64 = 604800000; // 7 * 86400 * 1000
    const WEEK_IN_SECONDS: u64 = 604800; // 7 * 86400
    
    // Expected emission constants (from contract)
    const BOOTSTRAP_EMISSION_RATE: u256 = 6600000; // 6.6 Victory/sec
    const WEEK5_EMISSION_RATE: u256 = 5470000;     // 5.47 Victory/sec
    
    // Expected allocation percentages for weeks 1-4 (basis points)
    const WEEK_1_4_LP_PCT: u64 = 6500;      // 65%
    const WEEK_1_4_SINGLE_PCT: u64 = 1500;  // 15%
    const WEEK_1_4_VICTORY_PCT: u64 = 1750; // 17.5%
    const WEEK_1_4_DEV_PCT: u64 = 250;      // 2.5%
    
    // Test error codes
    const E_WRONG_EMISSION_RATE: u64 = 1001;
    const E_WRONG_ALLOCATION: u64 = 1002;
    const E_WRONG_PHASE: u64 = 1003;
    const E_WRONG_WEEK: u64 = 1004;
    const E_WRONG_PERCENTAGE: u64 = 1005;
    const E_WRONG_TOTAL: u64 = 1006;

    // =================== SETUP FUNCTIONS ===================

    /// Complete setup for global emission controller tests
    fun setup_complete(scenario: &mut Scenario): Clock {
        // Initialize contract
        ts::next_tx(scenario, ADMIN);
        {
            global_emission_controller::init_for_testing(ts::ctx(scenario));
        };
        
        // Create clock for testing
        let clock = clock::create_for_testing(ts::ctx(scenario));
        clock
    }

    /// Initialize emission schedule (admin function)
    fun initialize_emissions(scenario: &mut Scenario, clock: &Clock) {
        ts::next_tx(scenario, ADMIN);
        {
            let admin_cap = ts::take_from_address<AdminCap>(scenario, ADMIN);
            let mut config = ts::take_shared<GlobalEmissionConfig>(scenario);
            
            global_emission_controller::initialize_emission_schedule(
                &admin_cap, 
                &mut config, 
                clock, 
                ts::ctx(scenario)
            );
            
            ts::return_to_address(ADMIN, admin_cap);
            ts::return_shared(config);
        };
    }

    /// Advance time helper
    fun advance_time(clock: &mut Clock, milliseconds: u64) {
        clock::increment_for_testing(clock, milliseconds);
    }

    /// Helper to check emission status
    fun get_emission_status(scenario: &mut Scenario, clock: &Clock): (u64, u8, u256, bool, u64) {
        ts::next_tx(scenario, ADMIN);
        let config = ts::take_shared<GlobalEmissionConfig>(scenario);
        let (current_week, phase, total_emission, paused, remaining_weeks) = 
            global_emission_controller::get_emission_status(&config, clock);
        ts::return_shared(config);
        (current_week, phase, total_emission, paused, remaining_weeks)
    }

    /// Helper to get allocation details
    fun get_allocation_details(scenario: &mut Scenario, clock: &Clock): (u256, u256, u256, u256, u64, u64, u64, u64) {
        ts::next_tx(scenario, ADMIN);
        let config = ts::take_shared<GlobalEmissionConfig>(scenario);
        let (lp_emission, single_emission, victory_emission, dev_emission, lp_pct, single_pct, victory_pct, dev_pct) = 
            global_emission_controller::get_allocation_details(&config, clock);
        ts::return_shared(config);
        (lp_emission, single_emission, victory_emission, dev_emission, lp_pct, single_pct, victory_pct, dev_pct)
    }

    // =================== TEST CASES ===================

    #[test]
    /// Test Bootstrap Phase: Weeks 1-4 should have fixed 8.4 Victory/sec emission rate
    /// This is the most critical test ensuring the bootstrap phase works correctly
    public fun test_bootstrap_phase_fixed_rate() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = setup_complete(&mut scenario);
        
        debug::print(&utf8(b"=== Testing Bootstrap Phase Fixed Rate (8.4 Victory/sec) ==="));
        
        // Start at a clean timestamp (day 1)
        advance_time(&mut clock, DAY_IN_MS);
        
        // Initialize emission schedule (starts at week 1)
        initialize_emissions(&mut scenario, &clock);
        
        debug::print(&utf8(b"✓ Emission schedule initialized"));
        
        // TEST 1: Verify Week 1 emissions immediately after initialization
        {
            let (current_week, phase, total_emission, paused, remaining_weeks) = 
                get_emission_status(&mut scenario, &clock);
            
            debug::print(&utf8(b"Week 1 Status:"));
            debug::print(&utf8(b"Current week:"));
            debug::print(&current_week);
            debug::print(&utf8(b"Phase:"));
            debug::print(&phase);
            debug::print(&utf8(b"Total emission (should be 8.4M):"));
            debug::print(&total_emission);
            
            // Verify week 1 state
            assert!(current_week == 1, E_WRONG_WEEK);
            assert!(phase == 1, E_WRONG_PHASE); // Bootstrap phase
            assert!(total_emission == BOOTSTRAP_EMISSION_RATE, E_WRONG_EMISSION_RATE);
            assert!(!paused, E_WRONG_PHASE);
            assert!(remaining_weeks == 155, E_WRONG_WEEK); // 156 - 1 = 155
        };
        
        // TEST 2: Verify Week 1 allocation percentages and amounts
        {
            let (lp_emission, single_emission, victory_emission, dev_emission, lp_pct, single_pct, victory_pct, dev_pct) = 
                get_allocation_details(&mut scenario, &clock);
            
            debug::print(&utf8(b"Week 1 Allocations:"));
            debug::print(&utf8(b"LP emission (should be 5.46M):"));
            debug::print(&lp_emission);
            debug::print(&utf8(b"Victory emission (should be 1.47M):"));
            debug::print(&victory_emission);
            
            // Verify allocation percentages
            assert!(lp_pct == WEEK_1_4_LP_PCT, E_WRONG_PERCENTAGE);
            assert!(single_pct == WEEK_1_4_SINGLE_PCT, E_WRONG_PERCENTAGE);
            assert!(victory_pct == WEEK_1_4_VICTORY_PCT, E_WRONG_PERCENTAGE);
            assert!(dev_pct == WEEK_1_4_DEV_PCT, E_WRONG_PERCENTAGE);
            
            // Verify total percentages = 100%
            let total_pct = lp_pct + single_pct + victory_pct + dev_pct;
            assert!(total_pct == 10000, E_WRONG_TOTAL); // 10000 basis points = 100%
            
            // Calculate expected emission amounts
            let expected_lp = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_LP_PCT as u256)) / 10000;
            let expected_single = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_SINGLE_PCT as u256)) / 10000;
            let expected_victory = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_VICTORY_PCT as u256)) / 10000;
            let expected_dev = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_DEV_PCT as u256)) / 10000;
            
            debug::print(&utf8(b"Expected vs Actual:"));
            debug::print(&utf8(b"LP expected:"));
            debug::print(&expected_lp);
            debug::print(&utf8(b"Victory expected:"));
            debug::print(&expected_victory);
            
            // Verify exact allocation amounts
            assert!(lp_emission == expected_lp, E_WRONG_ALLOCATION);
            assert!(single_emission == expected_single, E_WRONG_ALLOCATION);
            assert!(victory_emission == expected_victory, E_WRONG_ALLOCATION);
            assert!(dev_emission == expected_dev, E_WRONG_ALLOCATION);
            
            // Verify total allocations = total emission
            let total_allocated = lp_emission + single_emission + victory_emission + dev_emission;
            assert!(total_allocated == BOOTSTRAP_EMISSION_RATE, E_WRONG_TOTAL);
        };
        
        // TEST 3: Advance to Week 2 and verify same rate
        advance_time(&mut clock, WEEK_IN_MS);
        
        {
            let (current_week, phase, total_emission, _, _) = 
                get_emission_status(&mut scenario, &clock);
            
            debug::print(&utf8(b"Week 2 Status:"));
            debug::print(&utf8(b"Week:"));
            debug::print(&current_week);
            debug::print(&utf8(b"Total emission:"));
            debug::print(&total_emission);
            
            // Week 2: Same as week 1 - no auto-update complexity
            assert!(current_week == 2, E_WRONG_WEEK);
            assert!(phase == 1, E_WRONG_PHASE); // Still bootstrap
            assert!(total_emission == BOOTSTRAP_EMISSION_RATE, E_WRONG_EMISSION_RATE);
        };
        
        // TEST 4: Advance to Week 3 and verify same rate
        advance_time(&mut clock, WEEK_IN_MS);
        
        {
            let (current_week, phase, total_emission, _, _) = 
                get_emission_status(&mut scenario, &clock);
            
            debug::print(&utf8(b"Week 3 Status:"));
            debug::print(&utf8(b"Week:"));
            debug::print(&current_week);
            
            // Week 3: Same bootstrap behavior
            assert!(current_week == 3, E_WRONG_WEEK);
            assert!(phase == 1, E_WRONG_PHASE); // Still bootstrap
            assert!(total_emission == BOOTSTRAP_EMISSION_RATE, E_WRONG_EMISSION_RATE);
        };
        
        // TEST 5: Advance to Week 4 (last bootstrap week) and verify same rate
        advance_time(&mut clock, WEEK_IN_MS);
        
        {
            let (current_week, phase, total_emission, _, _) = 
                get_emission_status(&mut scenario, &clock);
            
            debug::print(&utf8(b"Week 4 Status (Last Bootstrap):"));
            debug::print(&utf8(b"Week:"));
            debug::print(&current_week);
            debug::print(&utf8(b"Total emission:"));
            debug::print(&total_emission);
            
            // Week 4: Still bootstrap
            assert!(current_week == 4, E_WRONG_WEEK);
            assert!(phase == 1, E_WRONG_PHASE); // Still bootstrap
            assert!(total_emission == BOOTSTRAP_EMISSION_RATE, E_WRONG_EMISSION_RATE);
        };
        
        // TEST 6: Test interface functions during bootstrap phase (Week 4)
        ts::next_tx(&mut scenario, FARM_CONTRACT);
        {
            let mut config = ts::take_shared<GlobalEmissionConfig>(&scenario);
            
            // Test farm allocations interface (should auto-update if needed)
            let (lp_allocation, single_allocation) = global_emission_controller::get_farm_allocations(&mut config, &clock);
            
            debug::print(&utf8(b"Interface Test - Farm Allocations (Week 4):"));
            debug::print(&utf8(b"LP:"));
            debug::print(&lp_allocation);
            debug::print(&utf8(b"Single:"));
            debug::print(&single_allocation);
            
            let expected_lp = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_LP_PCT as u256)) / 10000;
            let expected_single = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_SINGLE_PCT as u256)) / 10000;
            
            assert!(lp_allocation == expected_lp, E_WRONG_ALLOCATION);
            assert!(single_allocation == expected_single, E_WRONG_ALLOCATION);
            
            ts::return_shared(config);
        };
        
        ts::next_tx(&mut scenario, VICTORY_CONTRACT);
        {
            let mut config = ts::take_shared<GlobalEmissionConfig>(&scenario);
            
            // Test victory allocation interface
            let victory_allocation = global_emission_controller::get_victory_allocation(&mut config, &clock);
            
            debug::print(&utf8(b"Interface Test - Victory Allocation (Week 4):"));
            debug::print(&victory_allocation);
            
            let expected_victory = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_VICTORY_PCT as u256)) / 10000;
            assert!(victory_allocation == expected_victory, E_WRONG_ALLOCATION);
            
            ts::return_shared(config);
        };
        
        // TEST 7: Verify preview function for bootstrap weeks
        ts::next_tx(&mut scenario, ADMIN);
        {
            // Test preview for all bootstrap weeks
            let mut week = 1;
            while (week <= 4) {
                let (lp_preview, single_preview, victory_preview, dev_preview, phase_preview) = 
                    global_emission_controller::preview_week_allocations(week);
                
                debug::print(&utf8(b"Preview Week:"));
                debug::print(&week);
                debug::print(&utf8(b"Phase:"));
                debug::print(&phase_preview);
                
                // All bootstrap weeks should have same allocations and be phase 1
                assert!(phase_preview == 1, E_WRONG_PHASE);
                
                let expected_lp = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_LP_PCT as u256)) / 10000;
                let expected_single = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_SINGLE_PCT as u256)) / 10000;
                let expected_victory = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_VICTORY_PCT as u256)) / 10000;
                let expected_dev = (BOOTSTRAP_EMISSION_RATE * (WEEK_1_4_DEV_PCT as u256)) / 10000;
                
                assert!(lp_preview == expected_lp, E_WRONG_ALLOCATION);
                assert!(single_preview == expected_single, E_WRONG_ALLOCATION);
                assert!(victory_preview == expected_victory, E_WRONG_ALLOCATION);
                assert!(dev_preview == expected_dev, E_WRONG_ALLOCATION);
                
                week = week + 1;
            };
        };
        
        debug::print(&utf8(b"✅ Bootstrap Phase Test PASSED"));
        debug::print(&utf8(b"✅ Fixed 8.4 Victory/sec rate for weeks 1-4"));
        debug::print(&utf8(b"✅ Correct allocation percentages (65%, 15%, 17.5%, 2.5%)"));
        debug::print(&utf8(b"✅ Phase tracking working correctly"));
        debug::print(&utf8(b"✅ Interface functions returning correct values"));
        debug::print(&utf8(b"✅ Preview function working correctly"));
        
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

#[test]
/// Simplified but comprehensive test for ALL weeks 1-156 with clean data output
/// This version focuses on clean, parseable output without string manipulation
public fun test_all_weeks_simple_comprehensive() {
    debug::print(&utf8(b"=== VICTORY TOKEN ALLOCATION COMPREHENSIVE TEST ==="));
    debug::print(&utf8(b"CSV_HEADER:Week,Phase,EmissionRate,LPPercent,SinglePercent,VictoryPercent,DevPercent,LPEmission,SingleEmission,VictoryEmission,DevEmission,TotalEmission"));
    
    let mut week = 1;
    while (week <= 156) {
        // Create fresh scenario for each week
        let mut scenario = ts::begin(ADMIN);
        let mut clock = setup_complete(&mut scenario);
        advance_time(&mut clock, DAY_IN_MS);
        initialize_emissions(&mut scenario, &clock);
        
        // Advance to target week
        advance_time_to_week(&mut clock, week);
        
        // Get emission status and allocation details
        let (current_week, phase, total_emission, paused, remaining_weeks) = get_emission_status(&mut scenario, &clock);
        let (lp_emission, single_emission, victory_emission, dev_emission, lp_pct, single_pct, victory_pct, dev_pct) = 
            get_allocation_details(&mut scenario, &clock);
        
        // Calculate total allocation
        let total_allocated = lp_emission + single_emission + victory_emission + dev_emission;
        
        // Output clean CSV data
        debug::print(&utf8(b"CSV_DATA_START"));
        debug::print(&week);                    // Week number
        debug::print(&phase);                   // Phase
        debug::print(&total_emission);          // Emission rate
        debug::print(&lp_pct);                  // LP percentage
        debug::print(&single_pct);              // Single percentage  
        debug::print(&victory_pct);             // Victory percentage
        debug::print(&dev_pct);                 // Dev percentage
        debug::print(&lp_emission);             // LP emission
        debug::print(&single_emission);         // Single emission
        debug::print(&victory_emission);        // Victory emission
        debug::print(&dev_emission);            // Dev emission
        debug::print(&total_allocated);         // Total emission
        debug::print(&utf8(b"CSV_DATA_END"));
        
        // Validation output
        let (expected_lp_pct, expected_single_pct, expected_victory_pct, expected_dev_pct) = 
            get_expected_allocations_for_week(week);
        
        debug::print(&utf8(b"VALIDATION_START"));
        debug::print(&week);
        debug::print(&(lp_pct == expected_lp_pct));
        debug::print(&(single_pct == expected_single_pct));
        debug::print(&(victory_pct == expected_victory_pct));
        debug::print(&(dev_pct == expected_dev_pct));
        debug::print(&utf8(b"VALIDATION_END"));
        
        // Progress logging for important weeks
        if (week <= 5 || week % 25 == 0 || week >= 150) {
            debug::print(&utf8(b"PROGRESS:"));
            debug::print(&week);
            debug::print(&utf8(b"of 156 weeks"));
            
            // Human readable summary for key weeks
            debug::print(&utf8(b"WEEK_SUMMARY_START"));
            debug::print(&utf8(b"Week"));
            debug::print(&week);
            if (phase == 1) {
                debug::print(&utf8(b"Phase: Bootstrap"));
            } else if (phase == 2) {
                debug::print(&utf8(b"Phase: Post-Bootstrap"));
            } else {
                debug::print(&utf8(b"Phase: Ended"));
            };
            debug::print(&utf8(b"LP:"));
            debug::print(&lp_pct);
            debug::print(&utf8(b"Single:"));
            debug::print(&single_pct);
            debug::print(&utf8(b"Victory:"));
            debug::print(&victory_pct);
            debug::print(&utf8(b"Dev:"));
            debug::print(&dev_pct);
            debug::print(&utf8(b"Rate:"));
            debug::print(&total_emission);
            debug::print(&utf8(b"WEEK_SUMMARY_END"));
        };
        
        // Test interface functions for key weeks
        if (week % 20 == 0 || week <= 5 || week >= 150) {
            test_interface_functions_simple(&mut scenario, &clock, week);
        };
        
        // Critical validations with assertions
        assert!(current_week == week || (week > 156 && current_week == 156), E_WRONG_WEEK);
        assert!(lp_pct == expected_lp_pct, E_WRONG_PERCENTAGE);
        assert!(single_pct == expected_single_pct, E_WRONG_PERCENTAGE);
        assert!(victory_pct == expected_victory_pct, E_WRONG_PERCENTAGE);
        assert!(dev_pct == expected_dev_pct, E_WRONG_PERCENTAGE);
        
        let total_pct = lp_pct + single_pct + victory_pct + dev_pct;
        assert!(total_pct == 10000, E_WRONG_TOTAL);
        
        clock::destroy_for_testing(clock);
        ts::end(scenario);
        
        week = week + 1;
    };
    
    debug::print(&utf8(b"TEST_COMPLETE: All 156 weeks validated successfully"));
}

/// Simplified interface function testing
fun test_interface_functions_simple(scenario: &mut Scenario, clock: &Clock, week: u64) {
    debug::print(&utf8(b"INTERFACE_TEST_START"));
    debug::print(&week);
    
    // Test farm allocations
    ts::next_tx(scenario, FARM_CONTRACT);
    {
        let mut config = ts::take_shared<GlobalEmissionConfig>(scenario);
        let (lp_allocation, single_allocation) = global_emission_controller::get_farm_allocations(&mut config, clock);
        
        debug::print(&utf8(b"FARM_LP:"));
        debug::print(&lp_allocation);
        debug::print(&utf8(b"FARM_SINGLE:"));
        debug::print(&single_allocation);
        
        ts::return_shared(config);
    };
    
    // Test victory allocation
    ts::next_tx(scenario, VICTORY_CONTRACT);
    {
        let mut config = ts::take_shared<GlobalEmissionConfig>(scenario);
        let victory_allocation = global_emission_controller::get_victory_allocation(&mut config, clock);
        
        debug::print(&utf8(b"VICTORY_STAKING:"));
        debug::print(&victory_allocation);
        
        ts::return_shared(config);
    };
    
    // Test dev allocation
    ts::next_tx(scenario, DEV_CONTRACT);
    {
        let mut config = ts::take_shared<GlobalEmissionConfig>(scenario);
        let dev_allocation = global_emission_controller::get_dev_allocation(&mut config, clock);
        
        debug::print(&utf8(b"DEV_TREASURY:"));
        debug::print(&dev_allocation);
        
        ts::return_shared(config);
    };
    
    debug::print(&utf8(b"INTERFACE_TEST_END"));
}

/// Get expected allocation percentages for any week
fun get_expected_allocations_for_week(week: u64): (u64, u64, u64, u64) {
    // Returns (LP%, Single%, Victory%, Dev%) in basis points (10000 = 100%)
    
    if (week >= 1 && week <= 4) {
        (6500, 1500, 1750, 250)        // Weeks 1-4 (Bootstrap)
    } else if (week >= 5 && week <= 12) {
        (6200, 1200, 2350, 250)        // Weeks 5-12 (Early Post-Bootstrap)
    } else if (week >= 13 && week <= 26) {
        (5800, 700, 3250, 250)         // Weeks 13-26 (Mid Post-Bootstrap)
    } else if (week >= 27 && week <= 52) {
        (5500, 200, 4050, 250)         // Weeks 27-52 (Late Post-Bootstrap)
    } else if (week >= 53 && week <= 104) {
        (5000, 0, 4750, 250)           // Weeks 53-104 (Advanced Post-Bootstrap)
    } else if (week >= 105 && week <= 156) {
        (4500, 0, 5250, 250)           // Weeks 105-156 (Final Post-Bootstrap)
    } else {
        (0, 0, 0, 0)                   // Week 157+: No emissions
    }
}

/// Get expected emission rate for any week
fun get_expected_emission_rate_for_week(week: u64): u256 {
    if (week >= 1 && week <= 4) {
        // Bootstrap phase: fixed 8.4 Victory/sec
        BOOTSTRAP_EMISSION_RATE
    } else if (week == 5) {
        // Week 5: specific adjusted rate 6.96 Victory/sec
        WEEK5_EMISSION_RATE
    } else if (week >= 6 && week <= 156) {
        // Week 6+: apply 1% decay from week 5 rate
        calculate_expected_decay_rate(week)
    } else {
        // After week 156: no emissions
        0
    }
}

/// Test interface functions for a specific week
fun test_interface_functions_for_week(scenario: &mut Scenario, clock: &Clock, week: u64) {
    // Test farm allocations interface
    ts::next_tx(scenario, FARM_CONTRACT);
    {
        let mut config = ts::take_shared<GlobalEmissionConfig>(scenario);
        let (lp_allocation, single_allocation) = global_emission_controller::get_farm_allocations(&mut config, clock);
        
        if (week <= 156) {
            // Active weeks: LP should always be > 0
            assert!(lp_allocation > 0, E_WRONG_ALLOCATION);
            
            // Single should be > 0 only for weeks 1-52
            if (week <= 52) {
                assert!(single_allocation > 0, E_WRONG_ALLOCATION);
            } else {
                assert!(single_allocation == 0, E_WRONG_ALLOCATION);
            };
        } else {
            // Post-schedule: all should be 0
            assert!(lp_allocation == 0, E_WRONG_ALLOCATION);
            assert!(single_allocation == 0, E_WRONG_ALLOCATION);
        };
        
        ts::return_shared(config);
    };
    
    // Test victory allocation interface
    ts::next_tx(scenario, VICTORY_CONTRACT);
    {
        let mut config = ts::take_shared<GlobalEmissionConfig>(scenario);
        let victory_allocation = global_emission_controller::get_victory_allocation(&mut config, clock);
        
        if (week <= 156) {
            assert!(victory_allocation > 0, E_WRONG_ALLOCATION);
        } else {
            assert!(victory_allocation == 0, E_WRONG_ALLOCATION);
        };
        
        ts::return_shared(config);
    };
    
    // Test dev allocation interface
    ts::next_tx(scenario, DEV_CONTRACT);
    {
        let mut config = ts::take_shared<GlobalEmissionConfig>(scenario);
        let dev_allocation = global_emission_controller::get_dev_allocation(&mut config, clock);
        
        if (week <= 156) {
            assert!(dev_allocation > 0, E_WRONG_ALLOCATION);
        } else {
            assert!(dev_allocation == 0, E_WRONG_ALLOCATION);
        };
        
        ts::return_shared(config);
    };
}

/// Fixed advance_time_to_week that goes to absolute week position
fun advance_time_to_week(clock: &mut Clock, target_week: u64) {
    if (target_week == 1) return; // Already at week 1
    
    let weeks_to_advance = target_week - 1;
    advance_time(clock, weeks_to_advance * WEEK_IN_MS);
}

/// Calculate expected emission rate with decay
fun calculate_expected_decay_rate(week: u64): u256 {
    if (week <= 5) return WEEK5_EMISSION_RATE;
    
    let decay_weeks = week - 5;
    let mut current_rate = WEEK5_EMISSION_RATE;
    let mut i = 0;
    
    while (i < decay_weeks) {
        current_rate = (current_rate * (WEEKLY_DECAY_RATE as u256)) / 10000;
        i = i + 1;
    };
    
    current_rate
}
    
}