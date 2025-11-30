#[allow(unused_variable,unused_let_mut,unused_const,duplicate_alias,unused_use,lint(self_transfer),unused_field)]
module suitrump_dex::victory_token_locker {
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use suitrump_dex::victory_token::{VICTORY_TOKEN};
    use sui::sui::SUI;
    use sui::event;
    use sui::table::{Self, Table};
    use std::vector;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use suitrump_dex::global_emission_controller::{Self, GlobalEmissionConfig};

    // Error codes
    const ENO_LOCK_PERIOD_MATCH: u64 = 1;
    const ELOCK_NOT_EXPIRED: u64 = 2;
    const EZERO_AMOUNT: u64 = 3;
    const ELOCK_NOT_FOUND: u64 = 4;
    const E_THREE_YEAR_LOCK_UNAVAILABLE: u64 = 5;
    const E_NOT_AUTHORIZED: u64 = 6;
    const E_INSUFFICIENT_REWARDS: u64 = 7;
    const E_INVALID_LOCK_PERIOD: u64 = 8;
    const EALREADY_CLAIMED: u64 = 9;
    const EWEEK_NOT_FINISHED: u64 = 10;
    const ECLAIMING_DISABLED: u64 = 11;
    const EEPOCH_NOT_FOUND: u64 = 12;
    const ESTAKED_AFTER_WEEK_START: u64 = 13;
    const ELOCK_EXPIRED_DURING_WEEK: u64 = 14;
    const ESTAKED_DURING_WEEK_NOT_ELIGIBLE: u64 = 15;
    const ENO_SUI_REWARDS: u64 = 16;
    const ENO_VICTORY_REWARDS: u64 = 17;
    const ENO_TIME_ELAPSED: u64 = 18;
    const ECLAIM_TOO_SOON: u64 = 19;
    const EVICTORY_ALLOCATION_NOT_100_PERCENT: u64 = 20;
    const ESUI_ALLOCATION_NOT_100_PERCENT: u64 = 21;
    // New emission-related error codes
    const ERROR_EMISSIONS_NOT_INITIALIZED: u64 = 22;
    const ERROR_EMISSIONS_ENDED: u64 = 23;
    const ERROR_EMISSIONS_PAUSED: u64 = 24;
    // New balance management error codes
    const E_INSUFFICIENT_LOCKED_BALANCE: u64 = 25;
    const E_BALANCE_TRACKING_ERROR: u64 = 26;
    const E_VAULT_BALANCE_MISMATCH: u64 = 27;
    // Production error codes
    const E_EPOCH_ALREADY_FINALIZED: u64 = 28;
    const E_ALLOCATIONS_NOT_FINALIZED: u64 = 29;
    const E_ZERO_ADDRESS: u64 = 30; 
    const E_INVALID_BATCH_DATA: u64 = 31;
    const E_INSUFFICIENT_TOKEN_BALANCE: u64 = 32;
    // Constants for lock periods (in days)
    const WEEK_LOCK: u64 = 7;
    const THREE_MONTH_LOCK: u64 = 90;
    const YEAR_LOCK: u64 = 365;
    const THREE_YEAR_LOCK: u64 = 1095;
    
    const SECONDS_PER_DAY: u64 = 86400;
    const BASIS_POINTS: u64 = 10000;
    
    // Events
    public struct TokensLocked has copy, drop {
        user: address,
        lock_id: u64,
        amount: u64,
        lock_period: u64,
        lock_end: u64,
    }
    
    public struct TokensUnlocked has copy, drop {
        user: address,
        lock_id: u64,
        amount: u64,
        victory_rewards: u64,
        sui_rewards: u64,
        timestamp: u64,
    }
    
    public struct VictoryRewardsClaimed has copy, drop {
        user: address,
        lock_id: u64,
        amount: u64,
        timestamp: u64,
        total_claimed_for_lock: u64,
    }
    
    public struct PoolSUIClaimed has copy, drop {
        user: address,
        epoch_id: u64,
        lock_id: u64,
        lock_period: u64,
        pool_type: u8,
        amount_staked: u64,
        sui_claimed: u64,
        timestamp: u64,
    }
    
    public struct WeeklyRevenueAdded has copy, drop {
        epoch_id: u64,
        amount: u64,
        total_week_revenue: u64,
        week_pool_sui: u64,
        three_month_pool_sui: u64,
        year_pool_sui: u64,
        three_year_pool_sui: u64,
        dynamic_allocations_used: bool,
        timestamp: u64,
    }
    
    public struct VictoryAllocationsUpdated has copy, drop {
        week_allocation: u64,
        three_month_allocation: u64,
        year_allocation: u64,
        three_year_allocation: u64,
        total_check: u64,
        timestamp: u64,
    }
    
    public struct SUIAllocationsUpdated has copy, drop {
        week_allocation: u64,
        three_month_allocation: u64,
        year_allocation: u64,
        three_year_allocation: u64,
        total_check: u64,
        timestamp: u64,
    }
    
    public struct VaultDeposit has copy, drop {
        vault_type: String,
        amount: u64,
        total_balance: u64,
        timestamp: u64,
    }

    // New balance tracking events
    public struct BalanceValidation has copy, drop {
        locked_vault_balance: u64,
        reward_vault_balance: u64,
        total_locked_tracked: u64,
        total_rewards_tracked: u64,
        timestamp: u64,
    }

    // New emission-related events
    public struct EmissionWarning has copy, drop {
        message: String,
        lock_id: Option<u64>,
        timestamp: u64,
    }

    public struct EpochCreated has copy, drop {
        epoch_id: u64,
        week_start: u64,
        week_end: u64,
        timestamp: u64,
    }

    public struct AdminPresaleLockCreated has copy, drop {
        admin: address,
        user: address,
        lock_id: u64,
        amount: u64,
        lock_period: u64,
        lock_end: u64,
        timestamp: u64,
    }
    
    // Admin capability
    public struct AdminCap has key { 
        id: UID 
    }
    
    // 🔒 Dedicated vault for users' locked tokens (NEVER touched for rewards)
    public struct LockedTokenVault has key {
        id: UID,
        locked_balance: Balance<VICTORY_TOKEN>,  // Only stores locked tokens
        total_locked_amount: u64,                // Tracking total locked
        total_unlocked_amount: u64,              // Tracking total unlocked
        lock_count: u64,                         // Number of active locks
        unlock_count: u64,                       // Number of completed unlocks
    }
    
    // 🎁 Victory rewards vault (admin-funded rewards only)
    public struct VictoryRewardVault has key {
        id: UID,
        victory_balance: Balance<VICTORY_TOKEN>,
        total_deposited: u64,                    // Admin deposits tracking
        total_distributed: u64,                  // Reward distributions tracking
    }
    
    // 💰 SUI rewards vault (epoch-based distribution)
    public struct SUIRewardVault has key {
        id: UID,
        sui_balance: Balance<SUI>,
        total_deposited: u64,                    // SUI revenue tracking
        total_distributed: u64,                  // SUI distributions tracking
    }
    
    // Weekly pool allocation structure
    public struct WeeklyPoolAllocations has store, drop, copy {
        epoch_id: u64,
        week_pool_allocation: u64,
        three_month_pool_allocation: u64,
        year_pool_allocation: u64,
        three_year_pool_allocation: u64,
        week_pool_sui: u64,
        three_month_pool_sui: u64,
        year_pool_sui: u64,
        three_year_pool_sui: u64,
        week_pool_total_staked: u64,
        three_month_pool_total_staked: u64,
        year_pool_total_staked: u64,
        three_year_pool_total_staked: u64,
    }
    
    // Weekly revenue epoch structure
    public struct WeeklyRevenueEpoch has store, drop {
        epoch_id: u64,
        week_start_timestamp: u64,
        week_end_timestamp: u64,
        total_sui_revenue: u64,
        pool_allocations: WeeklyPoolAllocations,
        week_pool_claimed: u64,
        three_month_pool_claimed: u64,
        year_pool_claimed: u64,
        three_year_pool_claimed: u64,
        is_claimable: bool,
        allocations_finalized: bool,
    }
    
    // 🏗️ UPDATED: Main locker structure (removed victory_balance)
    public struct TokenLocker has key {
        id: UID,
        
        // Lock period pools
        week_locks: Table<address, vector<Lock>>,
        three_month_locks: Table<address, vector<Lock>>,
        year_locks: Table<address, vector<Lock>>,
        three_year_locks: Table<address, vector<Lock>>,
        
        // Pool totals
        week_total_locked: u64,
        three_month_total_locked: u64,
        year_total_locked: u64,
        three_year_total_locked: u64,
        total_locked: u64,
        
        // Balance tracking (NEW)
        total_locked_tokens: u64,        // Should match LockedTokenVault
        total_reward_tokens: u64,        // Should match VictoryRewardVault deposits
        
        // Dynamic Victory allocations (admin configurable)
        victory_week_allocation: u64,
        victory_three_month_allocation: u64,
        victory_year_allocation: u64,
        victory_three_year_allocation: u64,
        
        // Dynamic SUI allocations (admin configurable)
        sui_week_allocation: u64,
        sui_three_month_allocation: u64,
        sui_year_allocation: u64,
        sui_three_year_allocation: u64,
        
        // SUI epoch system
        weekly_epochs: Table<u64, WeeklyRevenueEpoch>,
        current_epoch_id: u64,
        current_week_start: u64,
        
        // Anti-double claim tracking
        user_epoch_claims: Table<address, Table<u64, PoolClaimRecord>>,
        user_victory_claims: Table<address, Table<u64, VictoryClaimRecord>>,
        
        next_lock_id: u64,
        launch_timestamp: u64,
    }
    
    // Individual lock structure
    public struct Lock has store, copy, drop {
        id: u64,
        amount: u64,
        lock_period: u64,
        lock_end: u64,
        stake_timestamp: u64,
        last_victory_claim_timestamp: u64,
        total_victory_claimed: u64,
        last_sui_epoch_claimed: u64,
        claimed_sui_epochs: vector<u64>,
    }
    
    // SUI claim record for anti-double claiming
    public struct PoolClaimRecord has store {
        epoch_id: u64,
        lock_id: u64,
        lock_period: u64,
        pool_type: u8,
        amount_staked: u64,
        sui_claimed: u64,
        claim_timestamp: u64,
    }
    
    // Victory claim record for anti-double claiming
    public struct VictoryClaimRecord has store {
        lock_id: u64,
        last_claim_timestamp: u64,
        total_claimed: u64,
        last_claim_amount: u64,
    }
    
    // Initialize the contract
    fun init(ctx: &mut TxContext) {
        // Create and transfer AdminCap to deployer
        transfer::transfer(AdminCap {
            id: object::new(ctx),
        }, tx_context::sender(ctx));
        
        // Create TokenLocker with default allocations (NO victory_balance)
        let locker = TokenLocker {
            id: object::new(ctx),
            
            week_locks: table::new(ctx),
            three_month_locks: table::new(ctx),
            year_locks: table::new(ctx),
            three_year_locks: table::new(ctx),
            
            week_total_locked: 0,
            three_month_total_locked: 0,
            year_total_locked: 0,
            three_year_total_locked: 0,
            total_locked: 0,
            
            // Balance tracking
            total_locked_tokens: 0,
            total_reward_tokens: 0,
            
            // Default Victory allocations (100% = 10000 basis points)
            victory_week_allocation: 200,        // 2%
            victory_three_month_allocation: 800, // 8%
            victory_year_allocation: 2500,       // 25%
            victory_three_year_allocation: 6500, // 65%
            
            // Default SUI allocations (100% = 10000 basis points)
            sui_week_allocation: 1000,           // 10%
            sui_three_month_allocation: 2000,    // 20%
            sui_year_allocation: 3000,           // 30%
            sui_three_year_allocation: 4000,     // 40%
            
            weekly_epochs: table::new(ctx),
            current_epoch_id: 0,
            current_week_start: 0,
            
            user_epoch_claims: table::new(ctx),
            user_victory_claims: table::new(ctx),
            
            next_lock_id: 0,
            launch_timestamp: 0,
        };
        
        transfer::share_object(locker);
    }
    
    // === SAFE ARITHMETIC HELPERS ===
    
    /// Safe multiplication using u128 to prevent overflow
    fun safe_mul_div(a: u64, b: u64, c: u64): u64 {
        if (c == 0) return 0;
        
        let a_u128 = (a as u128);
        let b_u128 = (b as u128);
        let c_u128 = (c as u128);
        
        let result_u128 = (a_u128 * b_u128) / c_u128;
        
        // Convert back to u64 safely
        if (result_u128 > (18446744073709551615 as u128)) {
            18446744073709551615 // Max u64 value
        } else {
            (result_u128 as u64)
        }
    }
    
    /// Safe percentage calculation using u128
    fun safe_percentage(amount: u64, percentage_bp: u64): u64 {
        safe_mul_div(amount, percentage_bp, BASIS_POINTS)
    }

    // === EMISSION VALIDATION HELPERS ===
    
    /// Validate emission state safely
    fun validate_emission_state(
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): (bool, bool, bool) {
        let (start_timestamp, is_paused) = global_emission_controller::get_config_info(global_config);
        let is_initialized = start_timestamp > 0;
        let is_active = global_emission_controller::is_emissions_active(global_config, clock);
        
        (is_initialized, is_active, is_paused)
    }

    /// Get Victory allocation safely - returns 0 if any emission issue
    fun get_victory_allocation_safe(
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): u256 {
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        
        if (!is_initialized || !is_active || is_paused) {
            return 0 // No allocation if any issue
        };
        
        // Safe to call Global Controller now
        global_emission_controller::get_victory_allocation(global_config, clock)
    }

    // === BALANCE VALIDATION HELPERS ===

    /// Validate balance integrity across all vaults
    fun validate_balance_integrity(
        locked_vault: &LockedTokenVault,
        reward_vault: &VictoryRewardVault,
        locker: &TokenLocker,
        clock: &Clock
    ) {
        let actual_locked = balance::value(&locked_vault.locked_balance);
        let actual_rewards = balance::value(&reward_vault.victory_balance);
        
        // Locked vault should have at least what we think is locked
        assert!(actual_locked >= (locker.total_locked as u64), E_BALANCE_TRACKING_ERROR);
        
        // Emit validation event
        event::emit(BalanceValidation {
            locked_vault_balance: actual_locked,
            reward_vault_balance: actual_rewards,
            total_locked_tracked: locker.total_locked,
            total_rewards_tracked: locker.total_reward_tokens,
            timestamp: clock::timestamp_ms(clock) / 1000,
        });
    }

    /// Check if locked vault has sufficient balance for unlock
    fun check_unlock_balance(
        locked_vault: &LockedTokenVault,
        amount: u64
    ): bool {
        let available = balance::value(&locked_vault.locked_balance);
        available >= amount
    }

    // === PRODUCTION-READY EPOCH MANAGEMENT SYSTEM ===
    
    /// Get current active epoch ID safely
    /// Returns 0 if no epochs have been created yet
    fun get_current_epoch_id(locker: &TokenLocker): u64 {
        locker.current_epoch_id
    }
    
    /// Check if epoch exists
    fun epoch_exists(locker: &TokenLocker, epoch_id: u64): bool {
        table::contains(&locker.weekly_epochs, epoch_id)
    }
    
    /// Get epoch safely with proper error handling
    fun get_epoch(locker: &TokenLocker, epoch_id: u64): &WeeklyRevenueEpoch {
        assert!(epoch_exists(locker, epoch_id), EEPOCH_NOT_FOUND);
        table::borrow(&locker.weekly_epochs, epoch_id)
    }
    
    /// Get mutable epoch safely with proper error handling
    fun get_epoch_mut(locker: &mut TokenLocker, epoch_id: u64): &mut WeeklyRevenueEpoch {
        assert!(epoch_exists(locker, epoch_id), EEPOCH_NOT_FOUND);
        table::borrow_mut(&mut locker.weekly_epochs, epoch_id)
    }
    
    /// Check if current week needs a new epoch
    fun needs_new_epoch(locker: &TokenLocker, current_time: u64): bool {
        let week_duration = 7 * SECONDS_PER_DAY;
        
        // First epoch case
        if (locker.current_week_start == 0) {
            return true
        };
        
        // Check if current week has expired
        current_time >= locker.current_week_start + week_duration
    }
    
    /// Create new epoch with proper ID management
    fun create_new_epoch(locker: &mut TokenLocker, week_start: u64): u64 {
        let week_duration = 7 * SECONDS_PER_DAY;
        
        // 🎯 PRODUCTION FIX: Increment epoch ID BEFORE creating epoch
        // This ensures current_epoch_id always points to the actual current epoch
        let new_epoch_id = locker.current_epoch_id + 1;
        locker.current_epoch_id = new_epoch_id;
        
        let new_epoch = WeeklyRevenueEpoch {
            epoch_id: new_epoch_id,
            week_start_timestamp: week_start,
            week_end_timestamp: week_start + week_duration,
            total_sui_revenue: 0,
            pool_allocations: WeeklyPoolAllocations {
                epoch_id: new_epoch_id,
                week_pool_allocation: 0,
                three_month_pool_allocation: 0,
                year_pool_allocation: 0,
                three_year_pool_allocation: 0,
                week_pool_sui: 0,
                three_month_pool_sui: 0,
                year_pool_sui: 0,
                three_year_pool_sui: 0,
                week_pool_total_staked: 0,
                three_month_pool_total_staked: 0,
                year_pool_total_staked: 0,
                three_year_pool_total_staked: 0,
            },
            week_pool_claimed: 0,
            three_month_pool_claimed: 0,
            year_pool_claimed: 0,
            three_year_pool_claimed: 0,
            is_claimable: false,
            allocations_finalized: false,
        };
        
        // Store epoch with the new epoch ID
        table::add(&mut locker.weekly_epochs, new_epoch_id, new_epoch);
        locker.current_week_start = week_start;
        
        new_epoch_id
    }
    
    /// 🎯 PRODUCTION-READY: Ensure current week epoch exists with proper error handling
    fun ensure_current_week_epoch(locker: &mut TokenLocker, current_time: u64) {
        if (!needs_new_epoch(locker, current_time)) {
            return // Current epoch is still valid
        };
        
        let new_week_start = if (locker.current_week_start == 0) {
            // First epoch - start immediately
            current_time
        } else {
            // Subsequent epochs - start at exact week boundaries
            let week_duration = 7 * SECONDS_PER_DAY;
            locker.current_week_start + week_duration
        };
        
        let new_epoch_id = create_new_epoch(locker, new_week_start);
        
        // Emit epoch creation event for monitoring
        event::emit(EpochCreated {
            epoch_id: new_epoch_id,
            week_start: new_week_start,
            week_end: new_week_start + (7 * SECONDS_PER_DAY),
            timestamp: current_time,
        });
    }
    
    // === VAULT MANAGEMENT FUNCTIONS ===
    
    /// 🔒 Create locked token vault (for users' locked tokens)
    public entry fun create_locked_token_vault(
        _admin: &AdminCap,
        ctx: &mut TxContext
    ) {
        let vault = LockedTokenVault {
            id: object::new(ctx),
            locked_balance: balance::zero<VICTORY_TOKEN>(),
            total_locked_amount: 0,
            total_unlocked_amount: 0,
            lock_count: 0,
            unlock_count: 0,
        };
        transfer::share_object(vault);
    }
    
    /// 🎁 Create Victory reward vault (for admin-funded rewards)
    public entry fun create_victory_reward_vault(
        _admin: &AdminCap,
        ctx: &mut TxContext
    ) {
        let vault = VictoryRewardVault {
            id: object::new(ctx),
            victory_balance: balance::zero<VICTORY_TOKEN>(),
            total_deposited: 0,
            total_distributed: 0,
        };
        transfer::share_object(vault);
    }
    
    /// 💰 Create SUI reward vault
    public entry fun create_sui_reward_vault(
        _admin: &AdminCap,
        ctx: &mut TxContext
    ) {
        let vault = SUIRewardVault {
            id: object::new(ctx),
            sui_balance: balance::zero<SUI>(),
            total_deposited: 0,
            total_distributed: 0,
        };
        transfer::share_object(vault);
    }
    
    /// Deposit Victory tokens into reward vault (for distribution)
    public entry fun deposit_victory_tokens(
        vault: &mut VictoryRewardVault,
        locker: &mut TokenLocker,
        tokens: Coin<VICTORY_TOKEN>,
        _admin: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&tokens);
        assert!(amount > 0, EZERO_AMOUNT);
        
        balance::join(&mut vault.victory_balance, coin::into_balance(tokens));
        vault.total_deposited = vault.total_deposited + amount;
        locker.total_reward_tokens = locker.total_reward_tokens + amount;
        
        event::emit(VaultDeposit {
            vault_type: string::utf8(b"Victory Rewards"),
            amount: (amount as u64),
            total_balance: balance::value(&vault.victory_balance) as u64,
            timestamp: clock::timestamp_ms(clock) / 1000,
        });
    }
    
    /// Distribute Victory rewards from vault
    fun distribute_victory_from_vault(
        vault: &mut VictoryRewardVault,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let available = balance::value(&vault.victory_balance);
        assert!(available >= amount, E_INSUFFICIENT_REWARDS);
        
        let reward_balance = balance::split(&mut vault.victory_balance, amount);
        let reward_coin = coin::from_balance(reward_balance, ctx);
        transfer::public_transfer(reward_coin, recipient);
        
        vault.total_distributed = vault.total_distributed + amount;
    }
    
    /// Distribute SUI rewards from vault
    fun distribute_sui_from_vault(
        vault: &mut SUIRewardVault,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let available = balance::value(&vault.sui_balance);
        assert!(available >= amount, E_INSUFFICIENT_REWARDS);
        
        let reward_balance = balance::split(&mut vault.sui_balance, amount);
        let reward_coin = coin::from_balance(reward_balance, ctx);
        transfer::public_transfer(reward_coin, recipient);
        
        vault.total_distributed = vault.total_distributed + amount;
    }
    
    // === ADMIN CONFIGURATION FUNCTIONS ===
    
    /// Configure Victory pool allocations (must sum to 100%)
    public entry fun configure_victory_allocations(
        locker: &mut TokenLocker,
        week_allocation: u64,
        three_month_allocation: u64,
        year_allocation: u64,
        three_year_allocation: u64,
        _admin: &AdminCap,
        clock: &Clock
    ) {
        // Validate total equals exactly 100%
        let total = week_allocation + three_month_allocation + year_allocation + three_year_allocation;
        assert!(total == BASIS_POINTS, EVICTORY_ALLOCATION_NOT_100_PERCENT);
        
        locker.victory_week_allocation = week_allocation;
        locker.victory_three_month_allocation = three_month_allocation;
        locker.victory_year_allocation = year_allocation;
        locker.victory_three_year_allocation = three_year_allocation;
        
        event::emit(VictoryAllocationsUpdated {
            week_allocation,
            three_month_allocation,
            year_allocation,
            three_year_allocation,
            total_check: total,
            timestamp: clock::timestamp_ms(clock) / 1000,
        });
    }
    
    /// Configure SUI pool allocations (must sum to 100%)
    public entry fun configure_sui_allocations(
        locker: &mut TokenLocker,
        week_allocation: u64,
        three_month_allocation: u64,
        year_allocation: u64,
        three_year_allocation: u64,
        _admin: &AdminCap,
        clock: &Clock
    ) {
        // Validate total equals exactly 100%
        let total = week_allocation + three_month_allocation + year_allocation + three_year_allocation;
        assert!(total == BASIS_POINTS, ESUI_ALLOCATION_NOT_100_PERCENT);
        
        locker.sui_week_allocation = week_allocation;
        locker.sui_three_month_allocation = three_month_allocation;
        locker.sui_year_allocation = year_allocation;
        locker.sui_three_year_allocation = three_year_allocation;
        
        event::emit(SUIAllocationsUpdated {
            week_allocation,
            three_month_allocation,
            year_allocation,
            three_year_allocation,
            total_check: total,
            timestamp: clock::timestamp_ms(clock) / 1000,
        });
    }
    
    /// 🎯 PRODUCTION-READY: Add weekly SUI revenue with bulletproof epoch management
    public entry fun add_weekly_sui_revenue(
        locker: &mut TokenLocker,
        vault: &mut SUIRewardVault,
        sui_tokens: Coin<SUI>,
        _admin: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock) / 1000;
        let sui_amount = coin::value(&sui_tokens);
        
        // Validate input
        assert!(sui_amount > 0, EZERO_AMOUNT);
        
        // Ensure current epoch exists
        ensure_current_week_epoch(locker, current_time);
        
        // Get current epoch ID (now guaranteed to be correct)
        let current_epoch_id = get_current_epoch_id(locker);
        
        // 🔧 FIX: Extract allocation values BEFORE getting mutable epoch reference
        let sui_week_allocation = locker.sui_week_allocation;
        let sui_three_month_allocation = locker.sui_three_month_allocation;
        let sui_year_allocation = locker.sui_year_allocation;
        let sui_three_year_allocation = locker.sui_three_year_allocation;
        
        // Extract staking totals BEFORE getting mutable epoch reference
        let week_total_locked = locker.week_total_locked;
        let three_month_total_locked = locker.three_month_total_locked;
        let year_total_locked = locker.year_total_locked;
        let three_year_total_locked = locker.three_year_total_locked;
        
        // 🎯 PRODUCTION FIX: Use current_epoch_id directly (no arithmetic needed)
        let current_epoch = get_epoch_mut(locker, current_epoch_id);
        
        // Validate epoch is not finalized (prevent double-addition)
        assert!(!current_epoch.allocations_finalized || current_epoch.total_sui_revenue == 0, E_EPOCH_ALREADY_FINALIZED);
        
        // Add SUI to current week
        current_epoch.total_sui_revenue = current_epoch.total_sui_revenue + sui_amount;
        
        // 🔧 FIX: Calculate pool SUI amounts using safe arithmetic
        let week_sui = safe_percentage(current_epoch.total_sui_revenue, sui_week_allocation);
        let three_month_sui = safe_percentage(current_epoch.total_sui_revenue, sui_three_month_allocation);
        let year_sui = safe_percentage(current_epoch.total_sui_revenue, sui_year_allocation);
        let three_year_sui = current_epoch.total_sui_revenue - week_sui - three_month_sui - year_sui;
        
        // Update pool allocations with extracted values
        current_epoch.pool_allocations = WeeklyPoolAllocations {
            epoch_id: current_epoch_id,
            week_pool_allocation: sui_week_allocation,
            three_month_pool_allocation: sui_three_month_allocation,
            year_pool_allocation: sui_year_allocation,
            three_year_pool_allocation: sui_three_year_allocation,
            week_pool_sui: week_sui,
            three_month_pool_sui: three_month_sui,
            year_pool_sui: year_sui,
            three_year_pool_sui: three_year_sui,
            // Snapshot current staking totals at time of allocation
            week_pool_total_staked: week_total_locked,
            three_month_pool_total_staked: three_month_total_locked,
            year_pool_total_staked: year_total_locked,
            three_year_pool_total_staked: three_year_total_locked,
        };
        
        // Enable claiming and finalize allocations
        current_epoch.is_claimable = true;
        current_epoch.allocations_finalized = true;
        
        // Store final values for event emission
        let final_total_revenue = current_epoch.total_sui_revenue;
        
        // Store SUI in vault
        balance::join(&mut vault.sui_balance, coin::into_balance(sui_tokens));
        vault.total_deposited = vault.total_deposited + sui_amount;
        
        // Emit comprehensive event
        event::emit(WeeklyRevenueAdded {
            epoch_id: current_epoch_id, // ✅ Now always correct
            amount: sui_amount,
            total_week_revenue: final_total_revenue,
            week_pool_sui: week_sui,
            three_month_pool_sui: three_month_sui,
            year_pool_sui: year_sui,
            three_year_pool_sui: three_year_sui,
            dynamic_allocations_used: true,
            timestamp: current_time,
        });
    }
    
    // === USER FUNCTIONS ===
    
    /// 🔒 FIXED: Lock Victory tokens for specified period (now uses LockedTokenVault)
    public entry fun lock_tokens(
        locker: &mut TokenLocker,
        locked_vault: &mut LockedTokenVault,
        tokens: Coin<VICTORY_TOKEN>,
        lock_period: u64,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&tokens);
        assert!(amount > 0, EZERO_AMOUNT);
        
        // Validate lock period
        assert!(
            lock_period == WEEK_LOCK || 
            lock_period == THREE_MONTH_LOCK || 
            lock_period == YEAR_LOCK || 
            lock_period == THREE_YEAR_LOCK, 
            E_INVALID_LOCK_PERIOD
        );
        
        let current_time = clock::timestamp_ms(clock) / 1000;
        let sender = tx_context::sender(ctx);
        let lock_id = locker.next_lock_id;
        
        // Set launch timestamp on first lock if not set
        if (locker.launch_timestamp == 0) {
            locker.launch_timestamp = current_time;
        };
        
        // Check if 3-year lock is still available
        if (lock_period == THREE_YEAR_LOCK) {
            let weeks_since_launch = (current_time - locker.launch_timestamp) / (7 * SECONDS_PER_DAY);
            let remaining_emission_weeks = if (weeks_since_launch >= 156) 0 else 156 - weeks_since_launch;
            assert!(remaining_emission_weeks >= 156, E_THREE_YEAR_LOCK_UNAVAILABLE);
        };
        
        // 🔥 EMISSION CHECK (warn if no rewards but still allow locking)
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        if (!is_initialized || !is_active || is_paused) {
            let warning_msg = if (!is_initialized) {
                string::utf8(b"Locking allowed but no rewards - emissions not started")
            } else if (!is_active) {
                string::utf8(b"Locking allowed but no rewards - emissions ended")  
            } else {
                string::utf8(b"Locking allowed but no rewards - emissions paused")
            };
            
            event::emit(EmissionWarning {
                message: warning_msg,
                lock_id: option::some(lock_id),
                timestamp: current_time,
            });
        };
        
        let lock_end = current_time + (lock_period * SECONDS_PER_DAY);
        
        let new_lock = Lock {
            id: lock_id,
            amount,
            lock_period,
            lock_end,
            stake_timestamp: current_time,
            last_victory_claim_timestamp: current_time,
            total_victory_claimed: 0,
            last_sui_epoch_claimed: 0,
            claimed_sui_epochs: vector::empty(),
        };
        
        // Add to appropriate lock table
        add_lock_to_pool(locker, sender, new_lock, lock_period, ctx);
        
        // Update totals
        update_pool_totals(locker, lock_period, amount, true);
        locker.next_lock_id = locker.next_lock_id + 1;
        locker.total_locked = locker.total_locked + amount;
        
        // 🔒 FIXED: Store tokens in LockedTokenVault (not locker.victory_balance)
        let token_balance = coin::into_balance(tokens);
        balance::join(&mut locked_vault.locked_balance, token_balance);
        locked_vault.total_locked_amount = locked_vault.total_locked_amount + amount;
        locked_vault.lock_count = locked_vault.lock_count + 1;
        locker.total_locked_tokens = locker.total_locked_tokens + amount;
        
        event::emit(TokensLocked {
            user: sender,
            lock_id,
            amount,
            lock_period,
            lock_end,
        });
    }
    
    /// Claim Victory rewards using Global Emission Controller (FIXED VERSION)
    public entry fun claim_victory_rewards(
        locker: &mut TokenLocker,
        vault: &mut VictoryRewardVault,
        global_config: &GlobalEmissionConfig,
        lock_id: u64,
        lock_period: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock) / 1000;
        
        // 🔥 STRICT EMISSION VALIDATION FOR CLAIMING (like SuiFarm)
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        assert!(is_initialized, ERROR_EMISSIONS_NOT_INITIALIZED);
        assert!(is_active, ERROR_EMISSIONS_ENDED);
        assert!(!is_paused, ERROR_EMISSIONS_PAUSED);
        
        // Get user's lock data first (read-only to avoid borrowing conflicts)
        let (user_lock_copy, time_since_last_claim) = {
            let user_lock = get_user_lock_mut(locker, sender, lock_id, lock_period);
            
            // Anti-double-claim: Check minimum time between claims
            let min_claim_interval = 3600; // 1 hour
            assert!(
                current_time >= user_lock.last_victory_claim_timestamp + min_claim_interval,
                ECLAIM_TOO_SOON
            );
            
            let time_elapsed = current_time - user_lock.last_victory_claim_timestamp;
            assert!(time_elapsed > 0, ENO_TIME_ELAPSED);
            
            (*user_lock, time_elapsed)
        };
        
        // 🔥 SAFE ALLOCATION GETTER (returns 0 if emissions issues)
        let total_victory_per_sec = get_victory_allocation_safe(global_config, clock);
        
        // Calculate user's Victory rewards
        let victory_rewards = calculate_user_victory_share(
            locker,
            &user_lock_copy,
            lock_period,
            total_victory_per_sec,
            time_since_last_claim
        );
        
        assert!(victory_rewards > 0, ENO_VICTORY_REWARDS);
        
        // Update tracking BEFORE distribution (get fresh mutable reference)
        {
            let user_lock = get_user_lock_mut(locker, sender, lock_id, lock_period);
            user_lock.last_victory_claim_timestamp = current_time;
            user_lock.total_victory_claimed = user_lock.total_victory_claimed + victory_rewards;
        };
        
        // Update global tracking
        update_global_victory_claim_record(locker, sender, lock_id, victory_rewards, current_time, ctx);
        
        // Distribute rewards from VictoryRewardVault
        distribute_victory_from_vault(vault, victory_rewards, sender, ctx);
        
        event::emit(VictoryRewardsClaimed {
            user: sender,
            lock_id,
            amount: victory_rewards,
            timestamp: current_time,
            total_claimed_for_lock: user_lock_copy.total_victory_claimed + victory_rewards,
        });
    }
    
    /// 🎯 PRODUCTION-READY: Claim SUI rewards with enhanced validation
    public entry fun claim_pool_sui_rewards(
        locker: &mut TokenLocker,
        vault: &mut SUIRewardVault,
        epoch_id: u64,
        lock_id: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock) / 1000;
        
        // Validate epoch exists and is claimable
        let epoch = get_epoch(locker, epoch_id);
        assert!(current_time >= epoch.week_end_timestamp, EWEEK_NOT_FINISHED);
        assert!(epoch.is_claimable, ECLAIMING_DISABLED);
        assert!(epoch.allocations_finalized, E_ALLOCATIONS_NOT_FINALIZED);
        
        // Extract epoch data to avoid borrowing conflicts
        let (week_start, week_end, pool_allocations_copy) = {
            (epoch.week_start_timestamp, epoch.week_end_timestamp, epoch.pool_allocations)
        };
        
        // Check user hasn't claimed this epoch already
        assert!(!has_user_claimed_pool_epoch(locker, sender, epoch_id, lock_id), EALREADY_CLAIMED);
        
        // Find user's lock and validate eligibility
        let (user_lock_copy, lock_period) = {
            let (user_lock, period) = find_user_lock_any_pool(locker, sender, lock_id);
            (*user_lock, period)
        };
        
        // Validate full week staking eligibility
        validate_full_week_staking_with_timestamps(&user_lock_copy, week_start, week_end);
        
        // Calculate SUI rewards using pool allocations
        let sui_rewards = calculate_pool_based_sui_rewards_with_allocations(
            &pool_allocations_copy, 
            &user_lock_copy, 
            lock_period
        );
        assert!(sui_rewards > 0, ENO_SUI_REWARDS);
        
        // Mark as claimed BEFORE distribution (prevent reentrancy)
        mark_pool_epoch_claimed(locker, sender, epoch_id, lock_id, lock_period, sui_rewards, current_time, ctx);
        
        // Update lock's claim tracking
        {
            let user_lock_mut = get_user_lock_mut(locker, sender, lock_id, lock_period);
            user_lock_mut.last_sui_epoch_claimed = epoch_id;
            vector::push_back(&mut user_lock_mut.claimed_sui_epochs, epoch_id);
        };
        
        // Update epoch claim tracking
        update_epoch_pool_claimed(locker, epoch_id, lock_period, sui_rewards);
        
        // Distribute SUI (this should be last to prevent reentrancy)
        distribute_sui_from_vault(vault, sui_rewards, sender, ctx);
        
        event::emit(PoolSUIClaimed {
            user: sender,
            epoch_id,
            lock_id,
            lock_period,
            pool_type: get_pool_type_id(lock_period),
            amount_staked: user_lock_copy.amount,
            sui_claimed: sui_rewards,
            timestamp: current_time,
        });
    }
    
    /// 🔒 FIXED: Unlock tokens and claim all pending rewards (now uses LockedTokenVault)
    public entry fun unlock_tokens(
        locker: &mut TokenLocker,
        locked_vault: &mut LockedTokenVault,
        victory_vault: &mut VictoryRewardVault,
        global_config: &GlobalEmissionConfig,
        lock_id: u64,
        lock_period: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock) / 1000;
        
        // Find and copy lock data to avoid borrowing conflicts
        let (lock_to_remove, lock_index) = {
            let (lock, index) = find_and_prepare_unlock(locker, sender, lock_id, lock_period, current_time);
            (lock, index)
        };
        
        // 🔒 CRITICAL: Validate locked vault has sufficient balance
        assert!(check_unlock_balance(locked_vault, lock_to_remove.amount), E_INSUFFICIENT_LOCKED_BALANCE);
        
        // 🔥 SAFE EMISSION CHECK (don't crash if emissions ended)
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        
        let victory_rewards = if (is_initialized && is_active && !is_paused) {
            // Calculate pending Victory rewards only if emissions active
            let time_since_last_claim = current_time - lock_to_remove.last_victory_claim_timestamp;
            let total_victory_per_sec = get_victory_allocation_safe(global_config, clock);
            calculate_user_victory_share(
                locker,
                &lock_to_remove,
                lock_period,
                total_victory_per_sec,
                time_since_last_claim
            )
        } else {
            // Emit warning about no rewards
            let warning_msg = if (!is_initialized) {
                string::utf8(b"Unlocking allowed but no rewards - emissions not started")
            } else if (!is_active) {
                string::utf8(b"Unlocking allowed but no rewards - emissions ended")  
            } else {
                string::utf8(b"Unlocking allowed but no rewards - emissions paused")
            };
            
            event::emit(EmissionWarning {
                message: warning_msg,
                lock_id: option::some(lock_id),
                timestamp: current_time,
            });
            
            0 // No rewards if emissions not active
        };
        
        // Remove lock from table
        remove_lock_from_pool(locker, sender, lock_index, lock_period);
        
        // Update totals
        update_pool_totals(locker, lock_period, lock_to_remove.amount, false);
        locker.total_locked = locker.total_locked - lock_to_remove.amount;
        locker.total_locked_tokens = locker.total_locked_tokens - lock_to_remove.amount;
        
        // 🔒 FIXED: Return locked tokens from LockedTokenVault (not locker.victory_balance)
        let token_coin = coin::take(&mut locked_vault.locked_balance, lock_to_remove.amount, ctx);
        transfer::public_transfer(token_coin, sender);
        
        // Update vault tracking
        locked_vault.total_unlocked_amount = locked_vault.total_unlocked_amount + lock_to_remove.amount;
        locked_vault.unlock_count = locked_vault.unlock_count + 1;
        
        // Send Victory rewards if available (from separate vault)
        let actual_victory = if (victory_rewards > 0) {
            let available_victory = balance::value(&victory_vault.victory_balance);
            let actual = if (victory_rewards > available_victory) available_victory else victory_rewards;
            if (actual > 0) {
                distribute_victory_from_vault(victory_vault, actual, sender, ctx);
            };
            actual
        } else {
            0
        };
        
        event::emit(TokensUnlocked {
            user: sender,
            lock_id: lock_to_remove.id,
            amount: lock_to_remove.amount,
            victory_rewards: actual_victory,
            sui_rewards: 0, // SUI claimed separately per epoch
            timestamp: current_time,
        });
    }
    
    // === HELPER FUNCTIONS ===
    
    /// Add lock to appropriate pool
    fun add_lock_to_pool(
        locker: &mut TokenLocker,
        user: address,
        lock: Lock,
        lock_period: u64,
        ctx: &mut TxContext
    ) {
        let lock_table = if (lock_period == WEEK_LOCK) {
            &mut locker.week_locks
        } else if (lock_period == THREE_MONTH_LOCK) {
            &mut locker.three_month_locks
        } else if (lock_period == YEAR_LOCK) {
            &mut locker.year_locks
        } else {
            &mut locker.three_year_locks
        };
        
        if (!table::contains(lock_table, user)) {
            table::add(lock_table, user, vector::empty());
        };
        
        let user_locks = table::borrow_mut(lock_table, user);
        vector::push_back(user_locks, lock);
    }
    
    /// Update pool totals
    fun update_pool_totals(locker: &mut TokenLocker, lock_period: u64, amount: u64, is_adding: bool) {
        if (lock_period == WEEK_LOCK) {
            if (is_adding) {
                locker.week_total_locked = locker.week_total_locked + amount;
            } else {
                locker.week_total_locked = locker.week_total_locked - amount;
            };
        } else if (lock_period == THREE_MONTH_LOCK) {
            if (is_adding) {
                locker.three_month_total_locked = locker.three_month_total_locked + amount;
            } else {
                locker.three_month_total_locked = locker.three_month_total_locked - amount;
            };
        } else if (lock_period == YEAR_LOCK) {
            if (is_adding) {
                locker.year_total_locked = locker.year_total_locked + amount;
            } else {
                locker.year_total_locked = locker.year_total_locked - amount;
            };
        } else {
            if (is_adding) {
                locker.three_year_total_locked = locker.three_year_total_locked + amount;
            } else {
                locker.three_year_total_locked = locker.three_year_total_locked - amount;
            };
        };
    }
    
    /// Get mutable reference to user's lock
    fun get_user_lock_mut(locker: &mut TokenLocker, user: address, lock_id: u64, lock_period: u64): &mut Lock {
        let lock_table = if (lock_period == WEEK_LOCK) {
            &mut locker.week_locks
        } else if (lock_period == THREE_MONTH_LOCK) {
            &mut locker.three_month_locks
        } else if (lock_period == YEAR_LOCK) {
            &mut locker.year_locks
        } else {
            &mut locker.three_year_locks
        };
        
        assert!(table::contains(lock_table, user), ELOCK_NOT_FOUND);
        let user_locks = table::borrow_mut(lock_table, user);
        
        let mut i = 0;
        let len = vector::length(user_locks);
        while (i < len) {
            let lock = vector::borrow_mut(user_locks, i);
            if (lock.id == lock_id) {
                return lock
            };
            i = i + 1;
        };
        abort ELOCK_NOT_FOUND
    }
    
    /// Find user's lock in any pool
    fun find_user_lock_any_pool(locker: &TokenLocker, user: address, lock_id: u64): (&Lock, u64) {
        let periods = vector[WEEK_LOCK, THREE_MONTH_LOCK, YEAR_LOCK, THREE_YEAR_LOCK];
        
        let mut i = 0;
        while (i < vector::length(&periods)) {
            let period = *vector::borrow(&periods, i);
            let lock_table = if (period == WEEK_LOCK) {
                &locker.week_locks
            } else if (period == THREE_MONTH_LOCK) {
                &locker.three_month_locks
            } else if (period == YEAR_LOCK) {
                &locker.year_locks
            } else {
                &locker.three_year_locks
            };
            
            if (table::contains(lock_table, user)) {
                let user_locks = table::borrow(lock_table, user);
                let mut j = 0;
                let len = vector::length(user_locks);
                while (j < len) {
                    let lock = vector::borrow(user_locks, j);
                    if (lock.id == lock_id) {
                        return (lock, period)
                    };
                    j = j + 1;
                };
            };
            i = i + 1;
        };
        abort ELOCK_NOT_FOUND
    }
    
    /// Calculate user's Victory share using dynamic allocations
    fun calculate_user_victory_share(
        locker: &TokenLocker,
        user_lock: &Lock,
        lock_period: u64,
        total_victory_per_sec: u256,
        time_elapsed_seconds: u64
    ): u64 {
        if (total_victory_per_sec == 0) return 0;
        
        // Get dynamic Victory allocation for this lock period
        let period_allocation_bp = get_dynamic_victory_allocation(locker, lock_period);
        
        // Calculate this lock period's Victory per second
        let period_victory_per_sec = (total_victory_per_sec * (period_allocation_bp as u256)) / (BASIS_POINTS as u256);
        
        // Get pool total for this lock period
        let pool_total = get_pool_total_locked(locker, lock_period);
        if (pool_total == 0) return 0;
        
        // Calculate user's share within their lock period pool
        let user_share_per_sec = (period_victory_per_sec * (user_lock.amount as u256)) / (pool_total as u256);
        
        // Calculate total for time elapsed
        let total_victory = user_share_per_sec * (time_elapsed_seconds as u256);
        
        // Convert back to u64 safely
        if (total_victory > (18446744073709551615 as u256)) {
            18446744073709551615
        } else {
            (total_victory as u64)
        }
    }
    
    /// Get dynamic Victory allocation
    fun get_dynamic_victory_allocation(locker: &TokenLocker, lock_period: u64): u64 {
        if (lock_period == WEEK_LOCK) locker.victory_week_allocation
        else if (lock_period == THREE_MONTH_LOCK) locker.victory_three_month_allocation
        else if (lock_period == YEAR_LOCK) locker.victory_year_allocation
        else locker.victory_three_year_allocation
    }
    
    /// Get dynamic SUI allocation
    fun get_dynamic_sui_allocation(locker: &TokenLocker, lock_period: u64): u64 {
        if (lock_period == WEEK_LOCK) locker.sui_week_allocation
        else if (lock_period == THREE_MONTH_LOCK) locker.sui_three_month_allocation
        else if (lock_period == YEAR_LOCK) locker.sui_year_allocation
        else locker.sui_three_year_allocation
    }
    
    /// Get pool total locked
    fun get_pool_total_locked(locker: &TokenLocker, lock_period: u64): u64 {
        if (lock_period == WEEK_LOCK) locker.week_total_locked
        else if (lock_period == THREE_MONTH_LOCK) locker.three_month_total_locked
        else if (lock_period == YEAR_LOCK) locker.year_total_locked
        else locker.three_year_total_locked
    }
    
    /// Calculate SUI rewards using pool allocations directly - FIXED for overflow protection
    fun calculate_pool_based_sui_rewards_with_allocations(
        allocations: &WeeklyPoolAllocations,
        user_lock: &Lock,
        lock_period: u64
    ): u64 {
        // Get pool SUI amount and total staked for this lock period
        let (pool_sui, pool_total_staked) = if (lock_period == WEEK_LOCK) {
            (allocations.week_pool_sui, allocations.week_pool_total_staked)
        } else if (lock_period == THREE_MONTH_LOCK) {
            (allocations.three_month_pool_sui, allocations.three_month_pool_total_staked)
        } else if (lock_period == YEAR_LOCK) {
            (allocations.year_pool_sui, allocations.year_pool_total_staked)
        } else {
            (allocations.three_year_pool_sui, allocations.three_year_pool_total_staked)
        };
        
        if (pool_total_staked == 0 || pool_sui == 0) {
            return 0
        };
        
        // 🔧 FIX: Use safe multiplication helper to prevent overflow
        // User's share = (User Stake / Pool Total) × Pool SUI
        safe_mul_div(user_lock.amount, pool_sui, pool_total_staked)
    }
    
    /// Validate user staked for full week using timestamps
    fun validate_full_week_staking_with_timestamps(user_lock: &Lock, week_start: u64, week_end: u64) {
        // User must have staked before the week started
        assert!(
            user_lock.stake_timestamp <= week_start,
            ESTAKED_AFTER_WEEK_START
        );
        
        // User's lock must still be active after the week ends
        assert!(
            user_lock.lock_end >= week_end,
            ELOCK_EXPIRED_DURING_WEEK
        );
        
        // Additional check: prevent gaming by staking during the week
        assert!(
            user_lock.stake_timestamp < week_start,
            ESTAKED_DURING_WEEK_NOT_ELIGIBLE
        );
    }
    
    /// Check if user has claimed specific epoch
    fun has_user_claimed_pool_epoch(locker: &TokenLocker, user: address, epoch_id: u64, lock_id: u64): bool {
        if (!table::contains(&locker.user_epoch_claims, user)) {
            return false
        };
        
        let user_claims = table::borrow(&locker.user_epoch_claims, user);
        table::contains(user_claims, epoch_id)
    }
    
    /// Mark epoch as claimed
    fun mark_pool_epoch_claimed(
        locker: &mut TokenLocker,
        user: address,
        epoch_id: u64,
        lock_id: u64,
        lock_period: u64,
        amount: u64,
        timestamp: u64,
        ctx: &mut TxContext
    ) {
        if (!table::contains(&locker.user_epoch_claims, user)) {
            table::add(&mut locker.user_epoch_claims, user, table::new(ctx));
        };
        
        let user_claims = table::borrow_mut(&mut locker.user_epoch_claims, user);
        assert!(!table::contains(user_claims, epoch_id), EALREADY_CLAIMED);
        
        let claim_record = PoolClaimRecord {
            epoch_id,
            lock_id,
            lock_period,
            pool_type: get_pool_type_id(lock_period),
            amount_staked: amount,
            sui_claimed: amount,
            claim_timestamp: timestamp,
        };
        
        table::add(user_claims, epoch_id, claim_record);
    }
    
    /// Update global Victory claim record
    fun update_global_victory_claim_record(
        locker: &mut TokenLocker,
        user: address,
        lock_id: u64,
        amount: u64,
        timestamp: u64,
        ctx: &mut TxContext
    ) {
        if (!table::contains(&locker.user_victory_claims, user)) {
            table::add(&mut locker.user_victory_claims, user, table::new(ctx));
        };
        
        let user_claims = table::borrow_mut(&mut locker.user_victory_claims, user);
        
        if (!table::contains(user_claims, lock_id)) {
            table::add(user_claims, lock_id, VictoryClaimRecord {
                lock_id,
                last_claim_timestamp: timestamp,
                total_claimed: amount,
                last_claim_amount: amount,
            });
        } else {
            let record = table::borrow_mut(user_claims, lock_id);
            record.last_claim_timestamp = timestamp;
            record.total_claimed = record.total_claimed + amount;
            record.last_claim_amount = amount;
        };
    }
    
    /// Update epoch pool claimed amounts
    fun update_epoch_pool_claimed(locker: &mut TokenLocker, epoch_id: u64, lock_period: u64, amount: u64) {
        let epoch = get_epoch_mut(locker, epoch_id);
        
        if (lock_period == WEEK_LOCK) {
            epoch.week_pool_claimed = epoch.week_pool_claimed + amount;
        } else if (lock_period == THREE_MONTH_LOCK) {
            epoch.three_month_pool_claimed = epoch.three_month_pool_claimed + amount;
        } else if (lock_period == YEAR_LOCK) {
            epoch.year_pool_claimed = epoch.year_pool_claimed + amount;
        } else {
            epoch.three_year_pool_claimed = epoch.three_year_pool_claimed + amount;
        };
    }
    
    /// Get pool type ID
    fun get_pool_type_id(lock_period: u64): u8 {
        if (lock_period == WEEK_LOCK) 0
        else if (lock_period == THREE_MONTH_LOCK) 1
        else if (lock_period == YEAR_LOCK) 2
        else 3
    }
    
    /// Find and prepare for unlock
    fun find_and_prepare_unlock(
        locker: &TokenLocker,
        user: address,
        lock_id: u64,
        lock_period: u64,
        current_time: u64
    ): (Lock, u64) {
        let lock_table = if (lock_period == WEEK_LOCK) {
            &locker.week_locks
        } else if (lock_period == THREE_MONTH_LOCK) {
            &locker.three_month_locks
        } else if (lock_period == YEAR_LOCK) {
            &locker.year_locks
        } else {
            &locker.three_year_locks
        };
        
        assert!(table::contains(lock_table, user), ELOCK_NOT_FOUND);
        let user_locks = table::borrow(lock_table, user);
        
        let mut i = 0;
        let len = vector::length(user_locks);
        while (i < len) {
            let lock = vector::borrow(user_locks, i);
            if (lock.id == lock_id) {
                assert!(current_time >= lock.lock_end, ELOCK_NOT_EXPIRED);
                return (*lock, i)
            };
            i = i + 1;
        };
        abort ELOCK_NOT_FOUND
    }
    
    /// Remove lock from pool
    fun remove_lock_from_pool(locker: &mut TokenLocker, user: address, lock_index: u64, lock_period: u64) {
        let lock_table = if (lock_period == WEEK_LOCK) {
            &mut locker.week_locks
        } else if (lock_period == THREE_MONTH_LOCK) {
            &mut locker.three_month_locks
        } else if (lock_period == YEAR_LOCK) {
            &mut locker.year_locks
        } else {
            &mut locker.three_year_locks
        };
        
        let user_locks = table::borrow_mut(lock_table, user);
        vector::remove(user_locks, lock_index);
        
        if (vector::is_empty(user_locks)) {
            table::remove(lock_table, user);
        };
    }
    
    // === VIEW FUNCTIONS ===
    
    /// Get current Victory allocations
    public fun get_victory_allocations(locker: &TokenLocker): (u64, u64, u64, u64, u64) {
        let total = locker.victory_week_allocation + 
                    locker.victory_three_month_allocation + 
                    locker.victory_year_allocation + 
                    locker.victory_three_year_allocation;
                    
        (
            locker.victory_week_allocation,
            locker.victory_three_month_allocation,
            locker.victory_year_allocation,
            locker.victory_three_year_allocation,
            total
        )
    }
    
    /// Get current SUI allocations
    public fun get_sui_allocations(locker: &TokenLocker): (u64, u64, u64, u64, u64) {
        let total = locker.sui_week_allocation + 
                    locker.sui_three_month_allocation + 
                    locker.sui_year_allocation + 
                    locker.sui_three_year_allocation;
                    
        (
            locker.sui_week_allocation,
            locker.sui_three_month_allocation,
            locker.sui_year_allocation,
            locker.sui_three_year_allocation,
            total
        )
    }
    
    /// Get pool statistics
    public fun get_pool_statistics(locker: &TokenLocker): (u64, u64, u64, u64, u64) {
        (
            locker.week_total_locked,
            locker.three_month_total_locked,
            locker.year_total_locked,
            locker.three_year_total_locked,
            locker.total_locked
        )
    }

    /// 🔒: Get locked vault statistics
    public fun get_locked_vault_statistics(
        locked_vault: &LockedTokenVault
    ): (u64, u64, u64, u64, u64) {
        (
            balance::value(&locked_vault.locked_balance),
            locked_vault.total_locked_amount,
            locked_vault.total_unlocked_amount,
            locked_vault.lock_count,
            locked_vault.unlock_count
        )
    }

    /// 🎁 Get reward vault statistics  
    public fun get_reward_vault_statistics(
        reward_vault: &VictoryRewardVault
    ): (u64, u64, u64) {
        (
            balance::value(&reward_vault.victory_balance),
            reward_vault.total_deposited,
            reward_vault.total_distributed
        )
    }

    /// 💰 Get SUI vault statistics
    public fun get_sui_vault_statistics(
        sui_vault: &SUIRewardVault
    ): (u64, u64, u64) {
        (
            balance::value(&sui_vault.sui_balance),
            sui_vault.total_deposited,
            sui_vault.total_distributed
        )
    }

    /// 🔍 Get comprehensive balance overview
    public fun get_balance_overview(
        locker: &TokenLocker,
        locked_vault: &LockedTokenVault,
        reward_vault: &VictoryRewardVault,
        sui_vault: &SUIRewardVault
    ): (u64, u64, u64, u64, u64, u64, u64, u64) {
        (
            // Locked tokens
            balance::value(&locked_vault.locked_balance),
            locker.total_locked,
            
            // Reward tokens
            balance::value(&reward_vault.victory_balance),
            locker.total_reward_tokens,
            
            // SUI
            balance::value(&sui_vault.sui_balance),
            sui_vault.total_deposited,
            
            // Tracking totals
            locked_vault.total_locked_amount,
            locked_vault.total_unlocked_amount
        )
    }
    
    /// Get user's locks for specific period
    public fun get_user_locks_for_period(locker: &TokenLocker, user: address, lock_period: u64): vector<Lock> {
        let lock_table = if (lock_period == WEEK_LOCK) {
            &locker.week_locks
        } else if (lock_period == THREE_MONTH_LOCK) {
            &locker.three_month_locks
        } else if (lock_period == YEAR_LOCK) {
            &locker.year_locks
        } else {
            &locker.three_year_locks
        };
        
        if (!table::contains(lock_table, user)) {
            vector::empty()
        } else {
            *table::borrow(lock_table, user)
        }
    }
    
    /// Get weekly epoch info - UPDATED to use safe epoch access
    public fun get_weekly_epoch_info(locker: &TokenLocker, epoch_id: u64): (u64, u64, u64, u64, u64, bool) {
        if (!epoch_exists(locker, epoch_id)) {
            return (0, 0, 0, 0, 0, false)
        };
        
        let epoch = get_epoch(locker, epoch_id);
        (
            epoch.total_sui_revenue,
            epoch.week_start_timestamp,
            epoch.week_end_timestamp,
            epoch.pool_allocations.week_pool_sui + epoch.pool_allocations.three_month_pool_sui + 
            epoch.pool_allocations.year_pool_sui + epoch.pool_allocations.three_year_pool_sui,
            epoch.week_pool_claimed + epoch.three_month_pool_claimed + 
            epoch.year_pool_claimed + epoch.three_year_pool_claimed,
            epoch.is_claimable
        )
    }
    
    /// Validate all allocations
    public fun validate_all_allocations(locker: &TokenLocker): (bool, bool, String) {
        let victory_total = locker.victory_week_allocation + 
                           locker.victory_three_month_allocation + 
                           locker.victory_year_allocation + 
                           locker.victory_three_year_allocation;
                           
        let sui_total = locker.sui_week_allocation + 
                       locker.sui_three_month_allocation + 
                       locker.sui_year_allocation + 
                       locker.sui_three_year_allocation;
        
        let victory_valid = victory_total == BASIS_POINTS;
        let sui_valid = sui_total == BASIS_POINTS;
        
        let status = if (victory_valid && sui_valid) {
            string::utf8(b"All allocations valid (100% each)")
        } else if (!victory_valid && !sui_valid) {
            string::utf8(b"Both Victory and SUI allocations invalid")
        } else if (!victory_valid) {
            string::utf8(b"Victory allocations invalid")
        } else {
            string::utf8(b"SUI allocations invalid")
        };
        
        (victory_valid, sui_valid, status)
    }

    // === EMISSION-RELATED VIEW FUNCTIONS ===
    
    /// Get emission status for Victory locker
    public fun get_emission_status_for_locker(
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): (bool, bool, bool, u64, u8) {
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        let (current_week, phase, _, _, _) = global_emission_controller::get_emission_status(global_config, clock);
        
        (is_initialized, is_active, is_paused, current_week, phase)
    }
    
    /// Get Victory allocation with status
    public fun get_victory_allocation_with_status(
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): (u256, bool, String) {
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        let victory_allocation = get_victory_allocation_safe(global_config, clock);
        
        let status = if (!is_initialized) {
            string::utf8(b"Not initialized")
        } else if (!is_active) {
            string::utf8(b"Ended")
        } else if (is_paused) {
            string::utf8(b"Paused")
        } else {
            string::utf8(b"Active")
        };
        
        let active = is_initialized && is_active && !is_paused;
        
        (victory_allocation, active, status)
    }

    /// Calculate pending Victory rewards for a user's lock
    public fun calculate_pending_victory_rewards(
        locker: &TokenLocker,
        user: address,
        lock_id: u64,
        lock_period: u64,
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): u64 {
        // Check emission state first
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        if (!is_initialized || !is_active || is_paused) {
            return 0
        };

        // Find user's lock
        let (user_lock, _) = find_user_lock_any_pool(locker, user, lock_id);
        
        let current_time = clock::timestamp_ms(clock) / 1000;
        let time_since_last_claim = current_time - user_lock.last_victory_claim_timestamp;
        
        if (time_since_last_claim == 0) {
            return 0
        };
        
        let total_victory_per_sec = get_victory_allocation_safe(global_config, clock);
        
        calculate_user_victory_share(
            locker,
            user_lock,
            lock_period,
            total_victory_per_sec,
            time_since_last_claim
        )
    }

    /// Get user's total staked across all lock periods
    public fun get_user_total_staked(locker: &TokenLocker, user: address): (u64, u64, u64, u64, u64) {
        let week_amount = get_user_period_total(locker, user, WEEK_LOCK);
        let three_month_amount = get_user_period_total(locker, user, THREE_MONTH_LOCK);
        let year_amount = get_user_period_total(locker, user, YEAR_LOCK);
        let three_year_amount = get_user_period_total(locker, user, THREE_YEAR_LOCK);
        let total = week_amount + three_month_amount + year_amount + three_year_amount;
        
        (week_amount, three_month_amount, year_amount, three_year_amount, total)
    }

    /// Helper function to get user's total for a specific period
    fun get_user_period_total(locker: &TokenLocker, user: address, lock_period: u64): u64 {
        let lock_table = if (lock_period == WEEK_LOCK) {
            &locker.week_locks
        } else if (lock_period == THREE_MONTH_LOCK) {
            &locker.three_month_locks
        } else if (lock_period == YEAR_LOCK) {
            &locker.year_locks
        } else {
            &locker.three_year_locks
        };
        
        if (!table::contains(lock_table, user)) {
            return 0
        };
        
        let user_locks = table::borrow(lock_table, user);
        let mut total = 0;
        let mut i = 0;
        let len = vector::length(user_locks);
        
        while (i < len) {
            let lock = vector::borrow(user_locks, i);
            total = total + lock.amount;
            i = i + 1;
        };
        
        total
    }

    /// Get all user locks across all periods
    public fun get_all_user_locks(locker: &TokenLocker, user: address): vector<Lock> {
        let mut all_locks = vector::empty<Lock>();
        
        // Add locks from each period
        let periods = vector[WEEK_LOCK, THREE_MONTH_LOCK, YEAR_LOCK, THREE_YEAR_LOCK];
        let mut i = 0;
        
        while (i < vector::length(&periods)) {
            let period = *vector::borrow(&periods, i);
            let period_locks = get_user_locks_for_period(locker, user, period);
            
            let mut j = 0;
            while (j < vector::length(&period_locks)) {
                vector::push_back(&mut all_locks, *vector::borrow(&period_locks, j));
                j = j + 1;
            };
            i = i + 1;
        };
        
        all_locks
    }

    // === PRODUCTION VIEW FUNCTIONS ===
    
    /// Get current epoch information safely
    public fun get_current_epoch_info(locker: &TokenLocker): (u64, u64, u64, bool, bool) {
        let current_epoch_id = get_current_epoch_id(locker);
        
        if (current_epoch_id == 0 || !epoch_exists(locker, current_epoch_id)) {
            return (0, 0, 0, false, false) // No current epoch
        };
        
        let epoch = get_epoch(locker, current_epoch_id);
        (
            current_epoch_id,
            epoch.week_start_timestamp,
            epoch.week_end_timestamp,
            epoch.is_claimable,
            epoch.allocations_finalized
        )
    }
    
    /// Get epoch information safely
    public fun get_epoch_info_safe(locker: &TokenLocker, epoch_id: u64): (u64, u64, u64, u64, u64, bool) {
        if (!epoch_exists(locker, epoch_id)) {
            return (0, 0, 0, 0, 0, false)
        };
        
        let epoch = get_epoch(locker, epoch_id);
        (
            epoch.total_sui_revenue,
            epoch.week_start_timestamp,
            epoch.week_end_timestamp,
            epoch.pool_allocations.week_pool_sui + epoch.pool_allocations.three_month_pool_sui + 
            epoch.pool_allocations.year_pool_sui + epoch.pool_allocations.three_year_pool_sui,
            epoch.week_pool_claimed + epoch.three_month_pool_claimed + 
            epoch.year_pool_claimed + epoch.three_year_pool_claimed,
            epoch.is_claimable
        )
    }
    
    /// Check if user can claim specific epoch
    public fun can_user_claim_epoch(
        locker: &TokenLocker, 
        user: address, 
        epoch_id: u64, 
        lock_id: u64,
        clock: &Clock
    ): (bool, String) {
        let current_time = clock::timestamp_ms(clock) / 1000;
        
        // Check epoch exists
        if (!epoch_exists(locker, epoch_id)) {
            return (false, string::utf8(b"Epoch does not exist"))
        };
        
        let epoch = get_epoch(locker, epoch_id);
        
        // Check epoch is finished
        if (current_time < epoch.week_end_timestamp) {
            return (false, string::utf8(b"Week not finished"))
        };
        
        // Check epoch is claimable
        if (!epoch.is_claimable) {
            return (false, string::utf8(b"Claiming disabled"))
        };
        
        // Check user hasn't already claimed
        if (has_user_claimed_pool_epoch(locker, user, epoch_id, lock_id)) {
            return (false, string::utf8(b"Already claimed"))
        };
        
        (true, string::utf8(b"Can claim"))
    }

    /// Get specific lock details for testing and verification
    /// Returns (amount, lock_period, lock_id, lock_end, stake_timestamp)
    public fun get_user_lock_details(
        locker: &TokenLocker, 
        user: address, 
        lock_period: u64,
        lock_index: u64
    ): (u64, u64, u64, u64, u64) {
        let lock_table = if (lock_period == WEEK_LOCK) {
            &locker.week_locks
        } else if (lock_period == THREE_MONTH_LOCK) {
            &locker.three_month_locks
        } else if (lock_period == YEAR_LOCK) {
            &locker.year_locks
        } else {
            &locker.three_year_locks
        };
        
        if (!table::contains(lock_table, user)) {
            return (0, 0, 0, 0, 0)
        };
        
        let user_locks = table::borrow(lock_table, user);
        if (lock_index >= vector::length(user_locks)) {
            return (0, 0, 0, 0, 0)
        };
        
        let lock = vector::borrow(user_locks, lock_index);
        (
            lock.amount,
            lock.lock_period,
            lock.id,
            lock.lock_end,
            lock.stake_timestamp
        )
    }
        

    /// 🎯 ADMIN PRESALE LOCK HANDLER - Create locks for presale participants
    /// This function allows admins to automatically lock Victory tokens for users
    /// who participated in the presale, fulfilling the 100-day lock promise.
    public entry fun admin_create_user_lock(
        locker: &mut TokenLocker,
        locked_vault: &mut LockedTokenVault,
        tokens: Coin<VICTORY_TOKEN>,
        user_address: address,
        lock_period: u64,
        global_config: &GlobalEmissionConfig,
        _admin: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&tokens);
        assert!(amount > 0, EZERO_AMOUNT);
        
        // Validate user address
        assert!(user_address != @0x0, E_ZERO_ADDRESS);
        
        // Validate lock period
        assert!(
            lock_period == WEEK_LOCK || 
            lock_period == THREE_MONTH_LOCK || 
            lock_period == YEAR_LOCK || 
            lock_period == THREE_YEAR_LOCK, 
            E_INVALID_LOCK_PERIOD
        );
        
        let current_time = clock::timestamp_ms(clock) / 1000;
        let lock_id = locker.next_lock_id;
        
        // Set launch timestamp on first lock if not set
        if (locker.launch_timestamp == 0) {
            locker.launch_timestamp = current_time;
        };
        
        // Check if 3-year lock is still available (for presale participants)
        if (lock_period == THREE_YEAR_LOCK) {
            let weeks_since_launch = (current_time - locker.launch_timestamp) / (7 * SECONDS_PER_DAY);
            let remaining_emission_weeks = if (weeks_since_launch >= 156) 0 else 156 - weeks_since_launch;
            assert!(remaining_emission_weeks >= 156, E_THREE_YEAR_LOCK_UNAVAILABLE);
        };
        
        // 🔥 EMISSION CHECK (warn if no rewards but still allow locking for presale)
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        if (!is_initialized || !is_active || is_paused) {
            let warning_msg = if (!is_initialized) {
                string::utf8(b"Admin locking for presale - emissions not started yet")
            } else if (!is_active) {
                string::utf8(b"Admin locking for presale - emissions ended")  
            } else {
                string::utf8(b"Admin locking for presale - emissions paused")
            };
            
            event::emit(EmissionWarning {
                message: warning_msg,
                lock_id: option::some(lock_id),
                timestamp: current_time,
            });
        };
        
        let lock_end = current_time + (lock_period * SECONDS_PER_DAY);
        
        let new_lock = Lock {
            id: lock_id,
            amount,
            lock_period,
            lock_end,
            stake_timestamp: current_time,
            last_victory_claim_timestamp: current_time,
            total_victory_claimed: 0,
            last_sui_epoch_claimed: 0,
            claimed_sui_epochs: vector::empty(),
        };
        
        // Add to appropriate lock table for the specified user
        add_lock_to_pool(locker, user_address, new_lock, lock_period, ctx);
        
        // Update totals
        update_pool_totals(locker, lock_period, amount, true);
        locker.next_lock_id = locker.next_lock_id + 1;
        locker.total_locked = locker.total_locked + amount;
        
        // Store tokens in LockedTokenVault
        let token_balance = coin::into_balance(tokens);
        balance::join(&mut locked_vault.locked_balance, token_balance);
        locked_vault.total_locked_amount = locked_vault.total_locked_amount + amount;
        locked_vault.lock_count = locked_vault.lock_count + 1;
        locker.total_locked_tokens = locker.total_locked_tokens + amount;
        
        // Emit special event for admin-created locks
        event::emit(AdminPresaleLockCreated {
            admin: tx_context::sender(ctx),
            user: user_address,
            lock_id,
            amount,
            lock_period,
            lock_end,
            timestamp: current_time,
        });
        
        // Also emit standard lock event for consistency
        event::emit(TokensLocked {
            user: user_address,
            lock_id,
            amount,
            lock_period,
            lock_end,
        });
    }

    // 🎯 BATCH PROCESSING: Create multiple locks at once for efficiency
    public entry fun admin_batch_create_user_locks(
        locker: &mut TokenLocker,
        locked_vault: &mut LockedTokenVault,
        mut tokens: Coin<VICTORY_TOKEN>,  // 🔧 FIXED: Added mut keyword
        user_addresses: vector<address>,
        amounts: vector<u64>,
        lock_periods: vector<u64>,
        global_config: &GlobalEmissionConfig,
        _admin: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let total_amount = coin::value(&tokens);
        assert!(total_amount > 0, EZERO_AMOUNT);
        
        let users_len = vector::length(&user_addresses);
        let amounts_len = vector::length(&amounts);
        let periods_len = vector::length(&lock_periods);
        
        // Validate all vectors have same length
        assert!(users_len == amounts_len && amounts_len == periods_len, E_INVALID_BATCH_DATA);
        assert!(users_len > 0, E_INVALID_BATCH_DATA);
        
        // Calculate total required amount
        let mut total_required = 0;
        let mut i = 0;
        while (i < amounts_len) {
            total_required = total_required + *vector::borrow(&amounts, i);
            i = i + 1;
        };
        
        assert!(total_amount >= total_required, E_INSUFFICIENT_TOKEN_BALANCE);
        
        // Process each lock
        let mut processed = 0;
        while (processed < users_len) {
            let user = *vector::borrow(&user_addresses, processed);
            let amount = *vector::borrow(&amounts, processed);
            let lock_period = *vector::borrow(&lock_periods, processed);
            
            // Split the required amount for this lock
            let lock_tokens = coin::split(&mut tokens, amount, ctx);
            
            // Create the lock (reuse single lock logic)
            admin_create_single_lock_internal(
                locker,
                locked_vault,
                lock_tokens,
                user,
                lock_period,
                global_config,
                clock,
                ctx
            );
            
            processed = processed + 1;
        };
        
        // Return any remaining tokens to admin
        if (coin::value(&tokens) > 0) {
            transfer::public_transfer(tokens, tx_context::sender(ctx));
        } else {
            coin::destroy_zero(tokens);
        };
    }

    // 🎯 INTERNAL HELPER: Single lock creation for batch processing
    fun admin_create_single_lock_internal(
        locker: &mut TokenLocker,
        locked_vault: &mut LockedTokenVault,
        tokens: Coin<VICTORY_TOKEN>,
        user_address: address,
        lock_period: u64,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&tokens);
        assert!(amount > 0, EZERO_AMOUNT);
        assert!(user_address != @0x0, E_ZERO_ADDRESS);
        
        // Validate lock period
        assert!(
            lock_period == WEEK_LOCK || 
            lock_period == THREE_MONTH_LOCK || 
            lock_period == YEAR_LOCK || 
            lock_period == THREE_YEAR_LOCK, 
            E_INVALID_LOCK_PERIOD
        );
        
        let current_time = clock::timestamp_ms(clock) / 1000;
        let lock_id = locker.next_lock_id;
        let lock_end = current_time + (lock_period * SECONDS_PER_DAY);
        
        let new_lock = Lock {
            id: lock_id,
            amount,
            lock_period,
            lock_end,
            stake_timestamp: current_time,
            last_victory_claim_timestamp: current_time,
            total_victory_claimed: 0,
            last_sui_epoch_claimed: 0,
            claimed_sui_epochs: vector::empty(),
        };
        
        // Add to appropriate lock table
        add_lock_to_pool(locker, user_address, new_lock, lock_period, ctx);
        
        // Update totals
        update_pool_totals(locker, lock_period, amount, true);
        locker.next_lock_id = locker.next_lock_id + 1;
        locker.total_locked = locker.total_locked + amount;
        
        // Store tokens in vault
        let token_balance = coin::into_balance(tokens);
        balance::join(&mut locked_vault.locked_balance, token_balance);
        locked_vault.total_locked_amount = locked_vault.total_locked_amount + amount;
        locked_vault.lock_count = locked_vault.lock_count + 1;
        locker.total_locked_tokens = locker.total_locked_tokens + amount;
        
        // Emit events
        event::emit(AdminPresaleLockCreated {
            admin: tx_context::sender(ctx),
            user: user_address,
            lock_id,
            amount,
            lock_period,
            lock_end,
            timestamp: current_time,
        });
        
        event::emit(TokensLocked {
            user: user_address,
            lock_id,
            amount,
            lock_period,
            lock_end,
        });
    }

    // 🎯 PRESALE HELPER: Get recommended lock period for presale (100 days ≈ 3 months)
    public fun get_presale_recommended_lock_period(): u64 {
        THREE_MONTH_LOCK // 90 days - closest to 100 days promised
    }

    // 🎯 VIEW FUNCTION: Check if user has any locks (for presale verification)
    public fun user_has_locks(locker: &TokenLocker, user: address): bool {
        let periods = vector[WEEK_LOCK, THREE_MONTH_LOCK, YEAR_LOCK, THREE_YEAR_LOCK];
        
        let mut i = 0;
        while (i < vector::length(&periods)) {
            let period = *vector::borrow(&periods, i);
            let lock_table = if (period == WEEK_LOCK) {
                &locker.week_locks
            } else if (period == THREE_MONTH_LOCK) {
                &locker.three_month_locks
            } else if (period == YEAR_LOCK) {
                &locker.year_locks
            } else {
                &locker.three_year_locks
            };
            
            if (table::contains(lock_table, user)) {
                let user_locks = table::borrow(lock_table, user);
                if (!vector::is_empty(user_locks)) {
                    return true
                };
            };
            i = i + 1;
        };
        
        false
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}