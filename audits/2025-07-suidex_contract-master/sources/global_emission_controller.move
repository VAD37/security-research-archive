#[allow(unused_variable,unused_let_mut,unused_const,duplicate_alias,unused_use,lint(self_transfer),unused_field)]
module suitrump_dex::global_emission_controller {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::event;
    use std::string::{Self, String};
    
    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 4;
    const E_ALREADY_INITIALIZED: u64 = 5;
    
    // Constants
    const SECONDS_PER_WEEK: u64 = 604800; // 7 * 24 * 60 * 60
    const BASIS_POINTS: u64 = 10000; // 100% = 10000 basis points
    
    // === EMISSION CONSTANTS (IMMUTABLE) ===
    const BOOTSTRAP_PHASE_EMISSION_RATE: u256 = 6600000; // 6.6 Victory/sec  
    const POST_BOOTSTRAP_START_RATE: u256 = 5470000;     // 5.47 Victory/sec
    const WEEKLY_DECAY_RATE: u64 = 9900;                 // 99% = 1% decay per week
    const TOTAL_EMISSION_WEEKS: u64 = 156;               // 3 years total
    
    // Admin capability
    public struct AdminCap has key, store {
        id: UID
    }
    
    // Simplified global emission configuration
    public struct GlobalEmissionConfig has key {
        id: UID,
        
        // MINIMAL STATE - Only what we need
        emission_start_timestamp: u64,      // When emissions started (0 = not started)
        paused: bool,                       // Emergency pause only
    }
    
    // Events
    public struct EmissionScheduleStarted has copy, drop {
        start_timestamp: u64,
        total_weeks: u64,
    }
    
    public struct EmissionPaused has copy, drop {
        paused: bool,
        timestamp: u64,
        admin: address,
    }
    
    public struct ContractAllocationRequested has copy, drop {
        contract_type: String,
        week: u64,
        phase: u8,
        allocation: u256,
        timestamp: u64,
    }
    
    // Initialize with admin capability
    fun init(ctx: &mut TxContext) {
        // Create admin capability
        transfer::transfer(AdminCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx));
        
        // Create minimal global config
        let config = GlobalEmissionConfig {
            id: object::new(ctx),
            emission_start_timestamp: 0, // Not started yet
            paused: false,
        };
        
        transfer::share_object(config);
    }
    
    // === ADMIN FUNCTIONS ===
    
    // Initialize emission schedule - starts the 156-week countdown
    public entry fun initialize_emission_schedule(
        _: &AdminCap,
        config: &mut GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(config.emission_start_timestamp == 0, E_ALREADY_INITIALIZED);
        
        let current_time = clock::timestamp_ms(clock) / 1000;
        config.emission_start_timestamp = current_time;
        
        event::emit(EmissionScheduleStarted {
            start_timestamp: current_time,
            total_weeks: TOTAL_EMISSION_WEEKS,
        });
    }
    
    // Emergency pause/unpause
    public entry fun set_pause_state(
        _: &AdminCap,
        config: &mut GlobalEmissionConfig,
        paused: bool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        config.paused = paused;
        
        event::emit(EmissionPaused {
            paused,
            timestamp: clock::timestamp_ms(clock) / 1000,
            admin: tx_context::sender(ctx),
        });
    }
    
    // === CONTRACT INTERFACE FUNCTIONS ===
    
    // For SuiFarm contract - get LP and Single asset allocations
    public fun get_farm_allocations(
        config: &GlobalEmissionConfig,
        clock: &Clock
    ): (u256, u256) {
        assert!(!config.paused, E_NOT_AUTHORIZED);
        assert!(config.emission_start_timestamp > 0, E_NOT_INITIALIZED);
        
        let current_week = calculate_current_week(config, clock);
        let total_emission = calculate_total_emission_for_week(current_week);
        let (lp_pct, single_pct, _, _) = get_week_allocation_percentages(current_week);
        
        let lp_emission = (total_emission * (lp_pct as u256)) / (BASIS_POINTS as u256);
        let single_emission = (total_emission * (single_pct as u256)) / (BASIS_POINTS as u256);
        
        let phase = if (current_week <= 4) 1 else if (current_week <= 156) 2 else 3;
        
        event::emit(ContractAllocationRequested {
            contract_type: string::utf8(b"farm"),
            week: current_week,
            phase,
            allocation: lp_emission + single_emission,
            timestamp: clock::timestamp_ms(clock) / 1000,
        });
        
        (lp_emission, single_emission)
    }
    
    // For Victory staking contract - get Victory allocation
    public fun get_victory_allocation(
        config: &GlobalEmissionConfig,
        clock: &Clock
    ): u256 {
        assert!(!config.paused, E_NOT_AUTHORIZED);
        assert!(config.emission_start_timestamp > 0, E_NOT_INITIALIZED);
        
        let current_week = calculate_current_week(config, clock);
        let total_emission = calculate_total_emission_for_week(current_week);
        let (_, _, victory_pct, _) = get_week_allocation_percentages(current_week);
        
        let victory_emission = (total_emission * (victory_pct as u256)) / (BASIS_POINTS as u256);
        
        let phase = if (current_week <= 4) 1 else if (current_week <= 156) 2 else 3;
        
        event::emit(ContractAllocationRequested {
            contract_type: string::utf8(b"victory_staking"),
            week: current_week,
            phase,
            allocation: victory_emission,
            timestamp: clock::timestamp_ms(clock) / 1000,
        });
        
        victory_emission
    }
    
    // For Treasury/Dev contract - get dev allocation
    public fun get_dev_allocation(
        config: &GlobalEmissionConfig,
        clock: &Clock
    ): u256 {
        assert!(!config.paused, E_NOT_AUTHORIZED);
        assert!(config.emission_start_timestamp > 0, E_NOT_INITIALIZED);
        
        let current_week = calculate_current_week(config, clock);
        let total_emission = calculate_total_emission_for_week(current_week);
        let (_, _, _, dev_pct) = get_week_allocation_percentages(current_week);
        
        let dev_emission = (total_emission * (dev_pct as u256)) / (BASIS_POINTS as u256);
        
        let phase = if (current_week <= 4) 1 else if (current_week <= 156) 2 else 3;
        
        event::emit(ContractAllocationRequested {
            contract_type: string::utf8(b"dev_treasury"),
            week: current_week,
            phase,
            allocation: dev_emission,
            timestamp: clock::timestamp_ms(clock) / 1000,
        });
        
        dev_emission
    }
    
    // Get all current allocations in one call
    public fun get_all_allocations(
        config: &GlobalEmissionConfig,
        clock: &Clock
    ): (u256, u256, u256, u256, u64) {
        assert!(!config.paused, E_NOT_AUTHORIZED);
        assert!(config.emission_start_timestamp > 0, E_NOT_INITIALIZED);
        
        let current_week = calculate_current_week(config, clock);
        let total_emission = calculate_total_emission_for_week(current_week);
        let (lp_pct, single_pct, victory_pct, dev_pct) = get_week_allocation_percentages(current_week);
        
        let lp_emission = (total_emission * (lp_pct as u256)) / (BASIS_POINTS as u256);
        let single_emission = (total_emission * (single_pct as u256)) / (BASIS_POINTS as u256);
        let victory_emission = (total_emission * (victory_pct as u256)) / (BASIS_POINTS as u256);
        let dev_emission = (total_emission * (dev_pct as u256)) / (BASIS_POINTS as u256);
        
        (lp_emission, single_emission, victory_emission, dev_emission, current_week)
    }
    
    // === PURE CALCULATION FUNCTIONS (No State Needed) ===
    
    // Calculate current week based on elapsed time
    fun calculate_current_week(config: &GlobalEmissionConfig, clock: &Clock): u64 {
        if (config.emission_start_timestamp == 0) {
            return 0
        };
        
        let current_time = clock::timestamp_ms(clock) / 1000;
        if (current_time < config.emission_start_timestamp) {
            return 0
        };
        
        let elapsed_seconds = current_time - config.emission_start_timestamp;
        let weeks_elapsed = elapsed_seconds / SECONDS_PER_WEEK;
        let current_week = weeks_elapsed + 1; // Week 1 starts immediately
        
        // Cap at total emission weeks
        if (current_week > TOTAL_EMISSION_WEEKS) {
            TOTAL_EMISSION_WEEKS
        } else {
            current_week
        }
    }
    
    // Calculate total emission for any week (pure function)
    fun calculate_total_emission_for_week(week: u64): u256 {
        if (week <= 4) {
            // Bootstrap phase: fixed 8.4 Victory/sec
            BOOTSTRAP_PHASE_EMISSION_RATE
        } else if (week == 5) {
            // Week 5: specific adjusted rate 6.96 Victory/sec
            POST_BOOTSTRAP_START_RATE
        } else if (week <= TOTAL_EMISSION_WEEKS) {
            // Week 6+: apply 1% decay from week 5 rate
            let decay_weeks = week - 5;
            let mut current_emission = POST_BOOTSTRAP_START_RATE;
            
            // Apply 1% decay for each week after week 5
            let mut i = 0;
            while (i < decay_weeks) {
                current_emission = (current_emission * (WEEKLY_DECAY_RATE as u256)) / 10000;
                i = i + 1;
            };
            
            current_emission
        } else {
            // After week 156: no emissions
            0
        }
    }
    
    // Get allocation percentages for any week (pure function)
    fun get_week_allocation_percentages(week: u64): (u64, u64, u64, u64) {
        // Returns (LP%, Single%, Victory%, Dev%) in basis points (10000 = 100%)
        
        if (week <= 4) return (6500, 1500, 1750, 250);        // Weeks 1-4 (Bootstrap)
        if (week <= 12) return (6200, 1200, 2350, 250);       // Weeks 5-12 (Early Post-Bootstrap)
        if (week <= 26) return (5800, 700, 3250, 250);        // Weeks 13-26 (Mid Post-Bootstrap)
        if (week <= 52) return (5500, 200, 4050, 250);        // Weeks 27-52 (Late Post-Bootstrap)
        if (week <= 104) return (5000, 0, 4750, 250);         // Weeks 53-104 (Advanced Post-Bootstrap)
        if (week <= 156) return (4500, 0, 5250, 250);         // Weeks 105-156 (Final Post-Bootstrap)
        
        // After 156 weeks: no emissions
        return (0, 0, 0, 0)
    }
    
    // === VIEW FUNCTIONS ===
    
    // Get current emission status
    public fun get_emission_status(config: &GlobalEmissionConfig, clock: &Clock): (u64, u8, u256, bool, u64) {
        let current_week = calculate_current_week(config, clock);
        let total_emission = calculate_total_emission_for_week(current_week);
        
        let phase = if (current_week == 0) {
            0 // Not started
        } else if (current_week <= 4) {
            1 // Bootstrap
        } else if (current_week <= TOTAL_EMISSION_WEEKS) {
            2 // Post-bootstrap
        } else {
            3 // Ended
        };
        
        let remaining_weeks = if (current_week <= TOTAL_EMISSION_WEEKS) {
            TOTAL_EMISSION_WEEKS - current_week
        } else {
            0
        };
        
        (current_week, phase, total_emission, config.paused, remaining_weeks)
    }
    
    // Get allocation details for current week
    public fun get_allocation_details(config: &GlobalEmissionConfig, clock: &Clock): (u256, u256, u256, u256, u64, u64, u64, u64) {
        let current_week = calculate_current_week(config, clock);
        let total_emission = calculate_total_emission_for_week(current_week);
        let (lp_pct, single_pct, victory_pct, dev_pct) = get_week_allocation_percentages(current_week);
        
        let lp_emission = (total_emission * (lp_pct as u256)) / (BASIS_POINTS as u256);
        let single_emission = (total_emission * (single_pct as u256)) / (BASIS_POINTS as u256);
        let victory_emission = (total_emission * (victory_pct as u256)) / (BASIS_POINTS as u256);
        let dev_emission = (total_emission * (dev_pct as u256)) / (BASIS_POINTS as u256);
        
        (lp_emission, single_emission, victory_emission, dev_emission, lp_pct, single_pct, victory_pct, dev_pct)
    }
    
    // Get configuration info
    public fun get_config_info(config: &GlobalEmissionConfig): (u64, bool) {
        (config.emission_start_timestamp, config.paused)
    }
    
    // Get emission phase parameters (constants)
    public fun get_emission_phase_parameters(): (u256, u256, u64, u64) {
        (BOOTSTRAP_PHASE_EMISSION_RATE, POST_BOOTSTRAP_START_RATE, WEEKLY_DECAY_RATE, TOTAL_EMISSION_WEEKS)
    }
    
    // Preview allocation for any week (pure function)
    public fun preview_week_allocations(week: u64): (u256, u256, u256, u256, u8) {
        let total_emission = calculate_total_emission_for_week(week);
        let (lp_pct, single_pct, victory_pct, dev_pct) = get_week_allocation_percentages(week);
        
        // Determine phase
        let phase = if (week == 0) {
            0 // Not started
        } else if (week <= 4) {
            1 // Bootstrap
        } else if (week <= TOTAL_EMISSION_WEEKS) {
            2 // Post-bootstrap
        } else {
            3 // Ended
        };
        
        let lp_allocation = (total_emission * (lp_pct as u256)) / (BASIS_POINTS as u256);
        let single_allocation = (total_emission * (single_pct as u256)) / (BASIS_POINTS as u256);
        let victory_allocation = (total_emission * (victory_pct as u256)) / (BASIS_POINTS as u256);
        let dev_allocation = (total_emission * (dev_pct as u256)) / (BASIS_POINTS as u256);
        
        (lp_allocation, single_allocation, victory_allocation, dev_allocation, phase)
    }
    
    // Calculate total emissions for entire 156-week schedule (pure function)
    public fun calculate_total_schedule_emissions(): u256 {
        let mut total = 0;
        let mut week = 1;
        
        while (week <= TOTAL_EMISSION_WEEKS) {
            let weekly_rate = calculate_total_emission_for_week(week);
            let weekly_total = weekly_rate * (SECONDS_PER_WEEK as u256);
            total = total + weekly_total;
            week = week + 1;
        };
        
        total
    }
    
    // Check if emissions are active
    public fun is_emissions_active(config: &GlobalEmissionConfig, clock: &Clock): bool {
        if (config.paused || config.emission_start_timestamp == 0) {
            return false
        };
        
        let current_week = calculate_current_week(config, clock);
        current_week <= TOTAL_EMISSION_WEEKS && current_week > 0
    }
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}