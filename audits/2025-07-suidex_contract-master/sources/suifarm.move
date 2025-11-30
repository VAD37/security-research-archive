#[allow(unused_variable,unused_let_mut,unused_const,duplicate_alias,unused_use,lint(self_transfer),unused_field)]
module suitrump_dex::farm {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, TreasuryCap};
    use std::string::{Self, String};
    use std::type_name::{Self, TypeName};
    use std::option::{Self, Option};
    use std::vector;
    use suitrump_dex::pair::{Self, Pair, LPCoin};
    use suitrump_dex::fixed_point_math::{Self, FixedPoint};
    use suitrump_dex::victory_token::{Self, VICTORY_TOKEN,TreasuryCapWrapper};
    use sui::clock::{Self, Clock};
    use suitrump_dex::factory::{Self, Factory};
    use suitrump_dex::global_emission_controller::{Self, GlobalEmissionConfig};

    // Error codes
    const ERROR_NOT_ADMIN: u64 = 1;
    const ERROR_ZERO_ADDRESS: u64 = 2;
    const ERROR_INVALID_FEE: u64 = 3;
    const ERROR_POOL_EXISTS: u64 = 4;
    const ERROR_POOL_NOT_FOUND: u64 = 5;
    const ERROR_INVALID_AMOUNT: u64 = 6;
    const ERROR_INACTIVE_POOL: u64 = 7;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 8;
    const ERROR_NO_REWARDS: u64 = 9;
    const ERROR_NOT_OWNER: u64 = 10;
    const ERROR_CALCULATION_OVERFLOW: u64 = 11;
    const ERROR_INVALID_LP_TYPE: u64 = 12;
    const ERROR_MISSING_TREASURY_CAP: u64 = 13;
    const ERROR_INVALID_VAULT: u64 = 14;
    const ERROR_ALREADY_INITIALIZED: u64 = 15;
    // New emission-related error codes
    const ERROR_EMISSIONS_NOT_INITIALIZED: u64 = 16;
    const ERROR_EMISSIONS_PAUSED: u64 = 17;
    const ERROR_EMISSIONS_ENDED: u64 = 18;
    const ERROR_SINGLE_REWARDS_ENDED: u64 = 19;

    // Fee constraints
    const MAX_FEE: u256 = 1000; // 10% maximum fee in basis points (10000 = 100%)
    const BASIS_POINTS: u256 = 10000;
    
    // Precision factor for calculations
    const PRECISION: u256 = 1000000000000000000; // 1e18 - same as FixedPoint
    
    public struct FARM has drop {}

    /// Simple Reward Vault - holds Victory tokens for distribution
    public struct RewardVault has key {
        id: UID,
        victory_balance: Balance<VICTORY_TOKEN>,
    }

    /// Farm configuration object
    public struct Farm has key {
        id: UID,
        admin: address,
        pools: Table<TypeName, Pool>,
        pool_list: vector<TypeName>,
        burn_address: address,
        locker_address: address,
        team_address: address,
        dev_address: address,
        total_victory_distributed: u256,
        last_update_timestamp: u64,
        paused: bool,
        allowed_lp_types: Table<TypeName, bool>,
        
        total_allocation_points: u256,           
        total_lp_allocation_points: u256,        
        total_single_allocation_points: u256,    
        
        position_to_vault: Table<ID, ID>,
        user_positions: Table<address, Table<TypeName, vector<ID>>>,
    }

    /// Pool structure for LP staking
    public struct Pool has store {
        pool_type: TypeName,
        total_staked: u256,
        allocation_points: u256,
        reward_per_token_stored: FixedPoint,
        last_update_timestamp: u64,
        deposit_fee: u256, // In basis points
        withdrawal_fee: u256, // In basis points
        active: bool,
        stakers: Table<address, Staker>,
        is_native_pair: bool, // Native pairs have higher emissions
        is_lp_token: bool, // LP token or single asset
        accumulated_deposit_fees: u256,
        accumulated_withdrawal_fees: u256
    }

    /// Individual staker information
    public struct Staker has store, drop {
        amount: u256,
        reward_debt: FixedPoint,
        rewards_claimed: u256,
        last_stake_timestamp: u64,
        last_claim_timestamp: u64
    }

    public struct StakedTokenVault<phantom T> has key, store {
        id: UID,
        balance: Balance<T>,
        owner: address,
        pool_type: TypeName,
        amount: u256,
        initial_stake_timestamp: u64
    }

    /// Staking position NFT that represents a user's stake
    public struct StakingPosition<phantom T> has key, store {
        id: UID,
        owner: address,
        pool_type: TypeName,
        amount: u256,
        initial_stake_timestamp: u64,
        vault_id: ID // ID of the corresponding vault
    }

    // Events
    public struct PoolCreated has copy, drop {
        pool_type: TypeName,
        allocation_points: u256,
        deposit_fee: u256,
        withdrawal_fee: u256,
        is_native_pair: bool,
        is_lp_token: bool
    }

    public struct LPTypeAllowed has copy, drop {
        lp_type: TypeName
    }

    public struct Staked has copy, drop {
        staker: address,
        pool_type: TypeName,
        amount: u256,
        timestamp: u64
    }

    public struct Unstaked has copy, drop {
        staker: address,
        pool_type: TypeName,
        amount: u256,
        timestamp: u64
    }

    public struct RewardClaimed has copy, drop {
        staker: address,
        pool_type: TypeName,
        amount: u256,
        timestamp: u64
    }

    public struct FeesCollected has copy, drop {
        pool_type: TypeName,
        amount: u256,
        fee_type: String, // "deposit" or "withdrawal"
        timestamp: u64
    }

    public struct VaultDeposit has copy, drop {
        amount: u256,
        total_balance: u256,
        timestamp: u64
    }

    // New emission-related events
    public struct EmissionWarning has copy, drop {
        message: String,
        pool_type: Option<TypeName>,
        timestamp: u64
    }

    public struct EmissionStatusChange has copy, drop {
        old_status: String,
        new_status: String,
        week_number: u64,
        timestamp: u64
    }

    fun init(witness: FARM, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        
        let farm = Farm {
            id: object::new(ctx),
            admin: sender,
            pools: table::new(ctx),
            pool_list: vector::empty(),
            burn_address: @0x0,
            locker_address: sender,
            team_address: sender,
            dev_address: sender,
            total_victory_distributed: 0,
            last_update_timestamp: 0,
            paused: false,
            allowed_lp_types: table::new(ctx),
            total_allocation_points: 0,
            total_lp_allocation_points: 0,
            total_single_allocation_points: 0,
            position_to_vault: table::new(ctx),
            user_positions: table::new(ctx),
        };
        
        transfer::share_object(farm);
        
        transfer::transfer(
            AdminCap {
                id: object::new(ctx)
            },
            sender
        );
    }

    /// Admin capability for privileged operations
    public struct AdminCap has key, store {
        id: UID
    }

    // === EMISSION INTEGRATION HELPERS ===
    
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

    /// Get allocations safely - returns (0,0) if any emission issue
    fun get_allocations_safe(
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): (u256, u256) {
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        
        if (!is_initialized || !is_active || is_paused) {
            return (0, 0) // No allocations if any issue
        };
        
        // Safe to call Global Controller now
        global_emission_controller::get_farm_allocations(global_config, clock)
    }

    // === VAULT FUNCTIONS ===
    
    /// Create reward vault for Victory token distribution
    public entry fun create_reward_vault(
        _admin: &AdminCap,
        ctx: &mut TxContext
    ) {
        let vault = RewardVault {
            id: object::new(ctx),
            victory_balance: balance::zero<VICTORY_TOKEN>(),
        };
        
        transfer::share_object(vault);
    }

    /// Deposit Victory tokens into vault for distribution
    public entry fun deposit_victory_tokens(
        vault: &mut RewardVault,
        tokens: Coin<VICTORY_TOKEN>,
        _admin: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&tokens);
        assert!(amount > 0, ERROR_INVALID_AMOUNT);
        
        balance::join(&mut vault.victory_balance, coin::into_balance(tokens));
        
        let current_time = clock::timestamp_ms(clock) / 1000;
        
        event::emit(VaultDeposit {
            amount: (amount as u256),
            total_balance: balance::value(&vault.victory_balance) as u256,
            timestamp: current_time
        });
    }

    /// Distribute rewards from vault
    fun distribute_from_vault(
        vault: &mut RewardVault,
        amount: u256,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let amount_u64 = if (amount > 18446744073709551615) { // u64::MAX
            18446744073709551615
        } else {
            (amount as u64)
        };
        
        let available = balance::value(&vault.victory_balance);
        assert!(available >= amount_u64, ERROR_INSUFFICIENT_BALANCE);
        
        let reward_balance = balance::split(&mut vault.victory_balance, amount_u64);
        let reward_coin = coin::from_balance(reward_balance, ctx);
        transfer::public_transfer(reward_coin, recipient);
    }

    // === REWARD CALCULATION ===
    
    fun calculate_pool_reward(
        is_lp_token: bool,
        allocation_points: u256,
        total_lp_allocation_points: u256,
        total_single_allocation_points: u256,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        time_elapsed: u256
    ): u256 {
        // Use safe allocation getter
        let (lp_allocation_per_sec, single_allocation_per_sec) = 
            get_allocations_safe(global_config, clock);
        
        // Early return if no allocations for this pool type
        if (is_lp_token && lp_allocation_per_sec == 0) return 0;
        if (!is_lp_token && single_allocation_per_sec == 0) return 0;
        
        if (is_lp_token) {
            if (total_lp_allocation_points > 0) {
                (lp_allocation_per_sec * allocation_points * time_elapsed) / total_lp_allocation_points
            } else { 0 }
        } else {
            if (total_single_allocation_points > 0) {
                (single_allocation_per_sec * allocation_points * time_elapsed) / total_single_allocation_points
            } else { 0 }
        }
    }

    // === Admin Functions ===
    public entry fun initialize_timestamps(
        farm: &mut Farm,
        _admin: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(farm.last_update_timestamp == 0, ERROR_ALREADY_INITIALIZED);
        
        let current_time = clock::timestamp_ms(clock) / 1000;
        farm.last_update_timestamp = current_time;
    }

    public entry fun create_single_asset_pool<T>(
        farm: &mut Farm,
        allocation_points: u256,
        deposit_fee: u256,
        withdrawal_fee: u256,
        is_native_token: bool,
        _admin: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let pool_type = type_name::get<T>();
        assert!(!table::contains(&farm.pools, pool_type), ERROR_POOL_EXISTS);
        assert!(deposit_fee <= MAX_FEE && withdrawal_fee <= MAX_FEE, ERROR_INVALID_FEE);
        
        let pool = Pool {
            pool_type,
            total_staked: 0,
            allocation_points,
            reward_per_token_stored: fixed_point_math::new(0),
            last_update_timestamp: clock::timestamp_ms(clock)/ 1000,
            deposit_fee,
            withdrawal_fee,
            active: true,
            stakers: table::new(ctx),
            is_native_pair: is_native_token,
            is_lp_token: false,
            accumulated_deposit_fees: 0,
            accumulated_withdrawal_fees: 0
        };
        
        farm.total_allocation_points = farm.total_allocation_points + allocation_points;
        farm.total_single_allocation_points = farm.total_single_allocation_points + allocation_points;
        
        table::add(&mut farm.pools, pool_type, pool);
        vector::push_back(&mut farm.pool_list, pool_type);
        
        event::emit(PoolCreated {
            pool_type,
            allocation_points,
            deposit_fee,
            withdrawal_fee,
            is_native_pair: is_native_token,
            is_lp_token: false
        });
    }
    
    public entry fun create_lp_pool<T0, T1>(
        farm: &mut Farm,
        allocation_points: u256,
        deposit_fee: u256,
        withdrawal_fee: u256,
        is_native_pair: bool,
        _admin: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sorted_pair = factory::sort_tokens<T0, T1>();
        let is_sorted = factory::is_token0<T0>(&sorted_pair);

        if (is_sorted) {
            create_lp_pool_sorted<T0, T1>(
                farm,
                allocation_points,
                deposit_fee,
                withdrawal_fee,
                is_native_pair,
                clock,
                ctx
            );
        } else {
            create_lp_pool_sorted<T1, T0>(
                farm,
                allocation_points,
                deposit_fee,
                withdrawal_fee,
                is_native_pair,
                clock,
                ctx
            );
        };
    }

    fun create_lp_pool_sorted<T0, T1>(
        farm: &mut Farm,
        allocation_points: u256,
        deposit_fee: u256,
        withdrawal_fee: u256,
        is_native_pair: bool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let lp_type = type_name::get<LPCoin<T0, T1>>();
        assert!(!table::contains(&farm.pools, lp_type), ERROR_POOL_EXISTS);
        assert!(deposit_fee <= MAX_FEE, ERROR_INVALID_FEE);
        assert!(withdrawal_fee <= MAX_FEE, ERROR_INVALID_FEE);

        let current_time = clock::timestamp_ms(clock) / 1000;

        let pool = Pool {
            pool_type: lp_type,
            total_staked: 0,
            allocation_points,
            reward_per_token_stored: fixed_point_math::new(0),
            last_update_timestamp: current_time,
            deposit_fee,
            withdrawal_fee,
            active: true,
            stakers: table::new(ctx),
            is_native_pair,
            is_lp_token: true,
            accumulated_deposit_fees: 0,
            accumulated_withdrawal_fees: 0
        };
        
        farm.total_allocation_points = farm.total_allocation_points + allocation_points;
        farm.total_lp_allocation_points = farm.total_lp_allocation_points + allocation_points;
        
        table::add(&mut farm.pools, lp_type, pool);
        vector::push_back(&mut farm.pool_list, lp_type);
        
        table::add(&mut farm.allowed_lp_types, lp_type, true);
        
        event::emit(PoolCreated {
            pool_type: lp_type,
            allocation_points,
            deposit_fee,
            withdrawal_fee,
            is_native_pair,
            is_lp_token: true
        });
        
        event::emit(LPTypeAllowed {
            lp_type
        });
    }

    public entry fun allow_lp_type<T0, T1>(
        farm: &mut Farm,
        _admin: &AdminCap
    ) {
        let lp_type = type_name::get<LPCoin<T0, T1>>();
        
        if (!table::contains(&farm.allowed_lp_types, lp_type)) {
            table::add(&mut farm.allowed_lp_types, lp_type, true);
            
            event::emit(LPTypeAllowed {
                lp_type
            });
        };
    }

    public entry fun update_pool_config<T>(
        farm: &mut Farm,
        allocation_points: u256,
        deposit_fee: u256,
        withdrawal_fee: u256,
        active: bool,
        _admin: &AdminCap,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let pool_type = type_name::get<T>();
        assert!(table::contains(&farm.pools, pool_type), ERROR_POOL_NOT_FOUND);
        assert!(deposit_fee <= MAX_FEE && withdrawal_fee <= MAX_FEE, ERROR_INVALID_FEE);
        
        let current_time = clock::timestamp_ms(clock)/ 1000;
        farm.last_update_timestamp = current_time;
        
        let total_lp_allocation_points = farm.total_lp_allocation_points;
        let total_single_allocation_points = farm.total_single_allocation_points;
        
        let pool = table::borrow_mut(&mut farm.pools, pool_type);
        
        if (pool.total_staked > 0) {
            let time_elapsed = ((current_time - pool.last_update_timestamp) as u256);
            
            let reward_amount = calculate_pool_reward(
                pool.is_lp_token,
                pool.allocation_points,
                total_lp_allocation_points,
                total_single_allocation_points,
                global_config,
                clock,
                time_elapsed
            );
            
            if (reward_amount > 0) {
                let reward_per_token_delta = fixed_point_math::div(
                    fixed_point_math::new(reward_amount * PRECISION),
                    fixed_point_math::new(pool.total_staked)
                );
                
                pool.reward_per_token_stored = fixed_point_math::add(
                    pool.reward_per_token_stored,
                    reward_per_token_delta
                );
            };
        };
        
        pool.last_update_timestamp = current_time;
        
        let old_allocation = pool.allocation_points;
        farm.total_allocation_points = farm.total_allocation_points - old_allocation + allocation_points;
        
        if (pool.is_lp_token) {
            farm.total_lp_allocation_points = farm.total_lp_allocation_points - old_allocation + allocation_points;
        } else {
            farm.total_single_allocation_points = farm.total_single_allocation_points - old_allocation + allocation_points;
        };
        
        pool.allocation_points = allocation_points;
        pool.deposit_fee = deposit_fee;
        pool.withdrawal_fee = withdrawal_fee;
        pool.active = active;
    }

    public entry fun set_addresses(
        farm: &mut Farm,
        burn_address: address,
        locker_address: address,
        team_address: address,
        dev_address: address,
        _admin: &AdminCap
    ) {
        assert!(
            burn_address != @0x0 && 
            locker_address != @0x0 && 
            team_address != @0x0 &&
            dev_address != @0x0,
            ERROR_ZERO_ADDRESS
        );
        
        farm.burn_address = burn_address;
        farm.locker_address = locker_address;
        farm.team_address = team_address;
        farm.dev_address = dev_address;
    }

    public entry fun set_pause_state(
        farm: &mut Farm, 
        paused: bool,
        _admin: &AdminCap
    ) {
        farm.paused = paused;
    }

    public entry fun mass_update_pools(
        farm: &mut Farm,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock)/ 1000;
        farm.last_update_timestamp = current_time;
        
        let total_lp_allocation_points = farm.total_lp_allocation_points;
        let total_single_allocation_points = farm.total_single_allocation_points;
        
        let len = vector::length(&farm.pool_list);
        let mut i = 0;
        
        while (i < len) {
            let pool_type = *vector::borrow(&farm.pool_list, i);
            let pool = table::borrow_mut(&mut farm.pools, pool_type);
            
            if (pool.total_staked > 0) {
                let time_elapsed = ((current_time - pool.last_update_timestamp) as u256);
                
                let reward_amount = calculate_pool_reward(
                    pool.is_lp_token,
                    pool.allocation_points,
                    total_lp_allocation_points,
                    total_single_allocation_points,
                    global_config,
                    clock,
                    time_elapsed
                );
                
                if (reward_amount > 0) {
                    let reward_per_token_delta = fixed_point_math::div(
                        fixed_point_math::new(reward_amount * PRECISION),
                        fixed_point_math::new(pool.total_staked)
                    );
                    
                    pool.reward_per_token_stored = fixed_point_math::add(
                        pool.reward_per_token_stored,
                        reward_per_token_delta
                    );
                };
            };
            
            pool.last_update_timestamp = current_time;
            i = i + 1;
        }
    }

    // === User Functions ===

    public entry fun stake_lp<T0, T1>(
        farm: &mut Farm,
        vault: &mut RewardVault,
        mut lp_tokens: vector<Coin<LPCoin<T0, T1>>>,
        amount: u256,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!farm.paused, ERROR_INACTIVE_POOL);
    
        let lp_type = type_name::get<LPCoin<T0, T1>>();
        assert!(table::contains(&farm.pools, lp_type), ERROR_POOL_NOT_FOUND);
        assert!(table::contains(&farm.allowed_lp_types, lp_type), ERROR_INVALID_LP_TYPE);
        
        let current_time = clock::timestamp_ms(clock)/ 1000;
        farm.last_update_timestamp = current_time;
        let sender = tx_context::sender(ctx);
        
        let total_lp_allocation_points = farm.total_lp_allocation_points;
        let total_single_allocation_points = farm.total_single_allocation_points;
        
        let pool = table::borrow_mut(&mut farm.pools, lp_type);
        assert!(pool.active, ERROR_INACTIVE_POOL);
        
        // Check emission state for reward calculations
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        
        if (pool.total_staked > 0 && is_initialized && is_active && !is_paused) {
            let time_elapsed = ((current_time - pool.last_update_timestamp) as u256);
            
            let reward_amount = calculate_pool_reward(
                pool.is_lp_token,
                pool.allocation_points,
                total_lp_allocation_points,
                total_single_allocation_points,
                global_config,
                clock,
                time_elapsed
            );
            
            if (reward_amount > 0) {
                let reward_per_token_delta = fixed_point_math::div(
                    fixed_point_math::new(reward_amount * PRECISION),
                    fixed_point_math::new(pool.total_staked)
                );
                
                pool.reward_per_token_stored = fixed_point_math::add(
                    pool.reward_per_token_stored,
                    reward_per_token_delta
                );
            };
        };
        pool.last_update_timestamp = current_time;
        
        let fee_amount = (amount * pool.deposit_fee) / BASIS_POINTS;
        let stake_amount = amount - fee_amount;
        
        let mut merged_lp = vector::pop_back(&mut lp_tokens);
        while (!vector::is_empty(&lp_tokens)) {
            coin::join(&mut merged_lp, vector::pop_back(&mut lp_tokens));
        };
        vector::destroy_empty(lp_tokens);
        
        let total_value = (coin::value(&merged_lp) as u256);
        assert!(total_value >= amount, ERROR_INSUFFICIENT_BALANCE);
        
        if (!table::contains(&pool.stakers, sender)) {
            table::add(&mut pool.stakers, sender, Staker {
                amount: 0,
                reward_debt: fixed_point_math::new(0),
                rewards_claimed: 0,
                last_stake_timestamp: current_time,
                last_claim_timestamp: current_time
            });
        };
        
        let staker = table::borrow_mut(&mut pool.stakers, sender);
        
        let mut pending_rewards = 0;
        if (staker.amount > 0 && is_initialized && is_active && !is_paused) {
            let accumulated_rewards = fixed_point_math::mul(
                fixed_point_math::new(staker.amount),
                pool.reward_per_token_stored
            );
            
            let debt = staker.reward_debt;
            
            if (fixed_point_math::compare(accumulated_rewards, debt) == 2) {
                let pending = fixed_point_math::sub(accumulated_rewards, debt);
                pending_rewards = fixed_point_math::get_raw_value(pending) / PRECISION;
            };
        } else if (staker.amount > 0) {
            // Emit warning about no rewards
            let warning_msg = if (!is_initialized) {
                string::utf8(b"Staking allowed but no rewards - emissions not started")
            } else if (!is_active) {
                string::utf8(b"Staking allowed but no rewards - emissions ended")  
            } else {
                string::utf8(b"Staking allowed but no rewards - emissions paused")
            };
            
            event::emit(EmissionWarning {
                message: warning_msg,
                pool_type: option::some(lp_type),
                timestamp: current_time
            });
        };
        
        if (fee_amount > 0) {
            let mut fee_coin = coin::split(&mut merged_lp, (fee_amount as u64), ctx);
            
            let fee_amount_u256 = (coin::value(&fee_coin) as u256);
            let burn_amount = (fee_amount_u256 * 40) / 100;
            let locker_amount = (fee_amount_u256 * 40) / 100;
            let team_amount = (fee_amount_u256 * 10) / 100;
            let dev_amount = fee_amount_u256 - burn_amount - locker_amount - team_amount;
            
            if (burn_amount > 0) {
                let burn_coin = coin::split(&mut fee_coin, (burn_amount as u64), ctx);
                transfer::public_transfer(burn_coin, farm.burn_address);
            };
            
            if (locker_amount > 0) {
                let locker_coin = coin::split(&mut fee_coin, (locker_amount as u64), ctx);
                transfer::public_transfer(locker_coin, farm.locker_address);
            };
            
            if (team_amount > 0) {
                let team_coin = coin::split(&mut fee_coin, (team_amount as u64), ctx);
                transfer::public_transfer(team_coin, farm.team_address);
            };
            
            transfer::public_transfer(fee_coin, farm.dev_address);
            
            pool.accumulated_deposit_fees = pool.accumulated_deposit_fees + fee_amount_u256;
            
            event::emit(FeesCollected {
                pool_type: pool.pool_type,
                amount: fee_amount_u256,
                fee_type: string::utf8(b"deposit"),
                timestamp: current_time
            });
        };
        
        let stake_coin = coin::split(&mut merged_lp, (stake_amount as u64), ctx);
        
        let vault_id = object::new(ctx);
        let token_vault = StakedTokenVault<LPCoin<T0, T1>> {
            id: vault_id,
            balance: coin::into_balance(stake_coin),
            owner: sender,
            pool_type: lp_type,
            amount: stake_amount,
            initial_stake_timestamp: current_time
        };
        
        if (coin::value(&merged_lp) > 0) {
            transfer::public_transfer(merged_lp, sender);
        } else {
            coin::destroy_zero(merged_lp);
        };
        
        let position_id = object::new(ctx);
        let position = StakingPosition<LPCoin<T0, T1>> {
            id: position_id,
            owner: sender,
            pool_type: lp_type,
            amount: stake_amount,
            initial_stake_timestamp: current_time,
            vault_id: object::uid_to_inner(&token_vault.id)
        };
        
        let position_uid_bytes = object::uid_to_inner(&position.id);
        
        if (!table::contains(&mut farm.user_positions, sender)) {
            table::add(&mut farm.user_positions, sender, table::new(ctx));
        };
        
        let user_table = table::borrow_mut(&mut farm.user_positions, sender);
        
        if (!table::contains(user_table, lp_type)) {
            table::add(user_table, lp_type, vector::empty<ID>());
        };
        
        let positions = table::borrow_mut(user_table, lp_type);
        vector::push_back(positions, position_uid_bytes);

        table::add(&mut farm.position_to_vault, position_uid_bytes, object::uid_to_inner(&token_vault.id));
        
        transfer::share_object(token_vault);
        transfer::transfer(position, sender);
        
        let staker = table::borrow_mut(&mut pool.stakers, sender);
        staker.amount = staker.amount + stake_amount;
        staker.reward_debt = fixed_point_math::mul(
            fixed_point_math::new(staker.amount),
            pool.reward_per_token_stored
        );
        staker.last_stake_timestamp = current_time;
        
        if (pending_rewards > 0) {
            farm.total_victory_distributed = farm.total_victory_distributed + pending_rewards;
            
            distribute_from_vault(vault, pending_rewards, sender, ctx);
            
            let staker = table::borrow_mut(&mut pool.stakers, sender);
            staker.rewards_claimed = staker.rewards_claimed + pending_rewards;
            staker.last_claim_timestamp = current_time;
            
            event::emit(RewardClaimed {
                staker: sender,
                pool_type: lp_type,
                amount: pending_rewards,
                timestamp: current_time
            });
        };
        
        pool.total_staked = pool.total_staked + stake_amount;
        
        event::emit(Staked {
            staker: sender,
            pool_type: lp_type,
            amount: stake_amount,
            timestamp: current_time
        });
    }

    public entry fun unstake_lp<T0, T1>(
        farm: &mut Farm,
        vault: &mut RewardVault,
        mut position: StakingPosition<LPCoin<T0, T1>>,
        token_vault: &mut StakedTokenVault<LPCoin<T0, T1>>,
        amount: u256,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!farm.paused, ERROR_INACTIVE_POOL);

        let lp_type = type_name::get<LPCoin<T0, T1>>();
        assert!(table::contains(&farm.pools, lp_type), ERROR_POOL_NOT_FOUND);
        
        let sender = tx_context::sender(ctx);
        assert!(position.owner == sender, ERROR_NOT_OWNER);
        
        let position_id = object::uid_to_inner(&position.id);
        let vault_id = object::uid_to_inner(&token_vault.id);
        assert!(position.vault_id == vault_id, ERROR_INVALID_VAULT);
        
        assert!(token_vault.owner == sender, ERROR_NOT_OWNER);
        assert!(position.amount == token_vault.amount, ERROR_CALCULATION_OVERFLOW);
        assert!(amount > 0 && amount <= position.amount, ERROR_INVALID_AMOUNT);
        assert!(balance::value(&token_vault.balance) >= (amount as u64), ERROR_INSUFFICIENT_BALANCE);
        
        let current_time = clock::timestamp_ms(clock)/ 1000;
        farm.last_update_timestamp = current_time;
        
        let total_lp_allocation_points = farm.total_lp_allocation_points;
        let total_single_allocation_points = farm.total_single_allocation_points;
        
        let pool = table::borrow_mut(&mut farm.pools, lp_type);
        assert!(pool.active, ERROR_INACTIVE_POOL);
        
        // Check emission state for reward calculations
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        
        if (pool.total_staked > 0 && is_initialized && is_active && !is_paused) {
            let time_elapsed = ((current_time - pool.last_update_timestamp) as u256);
            
            let reward_amount = calculate_pool_reward(
                pool.is_lp_token,
                pool.allocation_points,
                total_lp_allocation_points,
                total_single_allocation_points,
                global_config,
                clock,
                time_elapsed
            );
            
            if (reward_amount > 0 && pool.total_staked > 0) {
                let reward_per_token_delta = fixed_point_math::div(
                    fixed_point_math::new(reward_amount * PRECISION),
                    fixed_point_math::new(pool.total_staked)
                );
                
                pool.reward_per_token_stored = fixed_point_math::add(
                    pool.reward_per_token_stored,
                    reward_per_token_delta
                );
            };
        };
        pool.last_update_timestamp = current_time;
        
        let mut pending_rewards = 0;
        
        if (table::contains(&pool.stakers, sender)) {
            let staker = table::borrow(&pool.stakers, sender);
            
            if (staker.amount > 0 && is_initialized && is_active && !is_paused) {
                let accumulated_rewards = fixed_point_math::mul(
                    fixed_point_math::new(staker.amount),
                    pool.reward_per_token_stored
                );
                
                let debt = staker.reward_debt;
                
                if (fixed_point_math::compare(accumulated_rewards, debt) == 2) {
                    let pending = fixed_point_math::sub(accumulated_rewards, debt);
                    pending_rewards = fixed_point_math::get_raw_value(pending) / PRECISION;
                };
            } else if (staker.amount > 0) {
                // Emit warning about no rewards
                let warning_msg = if (!is_initialized) {
                    string::utf8(b"Unstaking allowed but no rewards - emissions not started")
                } else if (!is_active) {
                    string::utf8(b"Unstaking allowed but no rewards - emissions ended")  
                } else {
                    string::utf8(b"Unstaking allowed but no rewards - emissions paused")
                };
                
                event::emit(EmissionWarning {
                    message: warning_msg,
                    pool_type: option::some(lp_type),
                    timestamp: current_time
                });
            };
        };
        
        let fee_amount = (amount * pool.withdrawal_fee) / BASIS_POINTS;
        let unstake_amount = amount - fee_amount;
        
        let fee_amount_u64 = (fee_amount as u64);
        let unstake_amount_u64 = (unstake_amount as u64);
        
        if (pending_rewards > 0) {
            farm.total_victory_distributed = farm.total_victory_distributed + pending_rewards;
            
            distribute_from_vault(vault, pending_rewards, sender, ctx);
            
            if (table::contains(&pool.stakers, sender)) {
                let staker_ref = table::borrow_mut(&mut pool.stakers, sender);
                staker_ref.rewards_claimed = staker_ref.rewards_claimed + pending_rewards;
                staker_ref.last_claim_timestamp = current_time;
            };
            
            event::emit(RewardClaimed {
                staker: sender,
                pool_type: lp_type,
                amount: pending_rewards,
                timestamp: current_time
            });
        };
        
        if (unstake_amount_u64 > 0) {
            let unstake_coin = coin::from_balance(
                balance::split(&mut token_vault.balance, unstake_amount_u64),
                ctx
            );
            transfer::public_transfer(unstake_coin, sender);
        };
        
        if (fee_amount_u64 > 0) {
            let fee_balance = balance::split(&mut token_vault.balance, fee_amount_u64);
            let mut fee_coin = coin::from_balance(fee_balance, ctx);
            let fee_amount_u256 = (coin::value(&fee_coin) as u256);
            
            let burn_amount = (fee_amount_u256 * 40) / 100;
            let locker_amount = (fee_amount_u256 * 40) / 100;
            let team_amount = (fee_amount_u256 * 10) / 100;
            let _dev_amount = fee_amount_u256 - burn_amount - locker_amount - team_amount;
            
            let burn_amount_u64 = (burn_amount as u64);
            let locker_amount_u64 = (locker_amount as u64);
            let team_amount_u64 = (team_amount as u64);
            
            if (burn_amount_u64 > 0) {
                let burn_coin = coin::split(&mut fee_coin, burn_amount_u64, ctx);
                transfer::public_transfer(burn_coin, farm.burn_address);
            };
            
            if (locker_amount_u64 > 0) {
                let locker_coin = coin::split(&mut fee_coin, locker_amount_u64, ctx);
                transfer::public_transfer(locker_coin, farm.locker_address);
            };
            
            if (team_amount_u64 > 0) {
                let team_coin = coin::split(&mut fee_coin, team_amount_u64, ctx);
                transfer::public_transfer(team_coin, farm.team_address);
            };
            
            transfer::public_transfer(fee_coin, farm.dev_address);
            
            pool.accumulated_withdrawal_fees = pool.accumulated_withdrawal_fees + fee_amount;
            
            event::emit(FeesCollected {
                pool_type: pool.pool_type,
                amount: fee_amount,
                fee_type: string::utf8(b"withdrawal"),
                timestamp: current_time
            });
        };
        
        if (table::contains(&pool.stakers, sender)) {
            let staker_ref = table::borrow_mut(&mut pool.stakers, sender);
            staker_ref.amount = staker_ref.amount - amount;
            
            staker_ref.reward_debt = fixed_point_math::mul(
                fixed_point_math::new(staker_ref.amount),
                pool.reward_per_token_stored
            );
        };
        
        pool.total_staked = pool.total_staked - amount;
        token_vault.amount = token_vault.amount - amount;
        
        if (amount == position.amount) {
            if (table::contains(&farm.user_positions, sender)) {
                let user_table = table::borrow_mut(&mut farm.user_positions, sender);
                
                if (table::contains(user_table, lp_type)) {
                    let positions = table::borrow_mut(user_table, lp_type);
                    
                    let mut i = 0;
                    let len = vector::length(positions);
                    let mut found = false;
                    
                    while (i < len && !found) {
                        if (*vector::borrow(positions, i) == position_id) {
                            vector::swap_remove(positions, i);
                            found = true;
                        } else {
                            i = i + 1;
                        };
                    };
                };
            };
            
            if (table::contains(&farm.position_to_vault, position_id)) {
                table::remove(&mut farm.position_to_vault, position_id);
            };
            
            let StakingPosition<LPCoin<T0, T1>> { 
                id, 
                owner: _, 
                pool_type: _, 
                amount: _, 
                initial_stake_timestamp: _, 
                vault_id: _ 
            } = position;
            object::delete(id);
            
            if (balance::value(&token_vault.balance) == 0) {
                token_vault.owner = @0x0;
            };
        } else {
            position.amount = position.amount - amount;
            transfer::transfer(position, sender);
        };
        
        event::emit(Unstaked {
            staker: sender,
            pool_type: lp_type,
            amount,
            timestamp: current_time
        });
    }
    
    public entry fun stake_single<T>(
        farm: &mut Farm,
        vault: &mut RewardVault,
        mut tokens: Coin<T>,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!farm.paused, ERROR_INACTIVE_POOL);
        
        let token_type = type_name::get<T>();
        assert!(table::contains(&farm.pools, token_type), ERROR_POOL_NOT_FOUND);
        
        let current_time = clock::timestamp_ms(clock)/ 1000;
        farm.last_update_timestamp = current_time;
        let sender = tx_context::sender(ctx);
        
        let total_lp_allocation_points = farm.total_lp_allocation_points;
        let total_single_allocation_points = farm.total_single_allocation_points;
        
        let pool = table::borrow_mut(&mut farm.pools, token_type);
        assert!(pool.active, ERROR_INACTIVE_POOL);
        
        // Check emission state and single asset phase-out
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        let (_, single_allocation) = get_allocations_safe(global_config, clock);
        
        if (single_allocation == 0 && is_initialized) {
            event::emit(EmissionWarning {
                message: string::utf8(b"Single asset rewards ended - consider LP staking"),
                pool_type: option::some(token_type),
                timestamp: current_time
            });
        };
        
        if (pool.total_staked > 0 && is_initialized && is_active && !is_paused) {
            let time_elapsed = ((current_time - pool.last_update_timestamp) as u256);
            
            let reward_amount = calculate_pool_reward(
                pool.is_lp_token,
                pool.allocation_points,
                total_lp_allocation_points,
                total_single_allocation_points,
                global_config,
                clock,
                time_elapsed
            );
            
            if (reward_amount > 0) {
                let reward_per_token_delta = fixed_point_math::div(
                    fixed_point_math::new(reward_amount * PRECISION),
                    fixed_point_math::new(pool.total_staked)
                );
                
                pool.reward_per_token_stored = fixed_point_math::add(
                    pool.reward_per_token_stored,
                    reward_per_token_delta
                );
            };
        };
        pool.last_update_timestamp = current_time;
        
        let amount = (coin::value(&tokens) as u256);
        assert!(amount > 0, ERROR_INVALID_AMOUNT);
        
        let fee_amount = (amount * pool.deposit_fee) / BASIS_POINTS;
        let stake_amount = amount - fee_amount;
        
        if (!table::contains(&pool.stakers, sender)) {
            table::add(&mut pool.stakers, sender, Staker {
                amount: 0,
                reward_debt: fixed_point_math::new(0),
                rewards_claimed: 0,
                last_stake_timestamp: current_time,
                last_claim_timestamp: current_time
            });
        };
        
        let staker = table::borrow_mut(&mut pool.stakers, sender);
        
        let mut pending_rewards = 0;
        if (staker.amount > 0 && is_initialized && is_active && !is_paused) {
            let accumulated_rewards = fixed_point_math::mul(
                fixed_point_math::new(staker.amount),
                pool.reward_per_token_stored
            );
            
            let debt = staker.reward_debt;
            
            if (fixed_point_math::compare(accumulated_rewards, debt) == 2) {
                let pending = fixed_point_math::sub(accumulated_rewards, debt);
                pending_rewards = fixed_point_math::get_raw_value(pending) / PRECISION;
            };
        } else if (staker.amount > 0) {
            // Emit warning about no rewards
            let warning_msg = if (!is_initialized) {
                string::utf8(b"Staking allowed but no rewards - emissions not started")
            } else if (!is_active) {
                string::utf8(b"Staking allowed but no rewards - emissions ended")  
            } else {
                string::utf8(b"Staking allowed but no rewards - emissions paused")
            };
            
            event::emit(EmissionWarning {
                message: warning_msg,
                pool_type: option::some(token_type),
                timestamp: current_time
            });
        };
        
        if (fee_amount > 0) {
            let mut fee_coin = coin::split(&mut tokens, (fee_amount as u64), ctx);
            
            let fee_amount_u256 = (coin::value(&fee_coin) as u256);
            let burn_amount = (fee_amount_u256 * 40) / 100;
            let locker_amount = (fee_amount_u256 * 40) / 100;
            let team_amount = (fee_amount_u256 * 10) / 100;
            let dev_amount = fee_amount_u256 - burn_amount - locker_amount - team_amount;
            
            if (burn_amount > 0) {
                let burn_coin = coin::split(&mut fee_coin, (burn_amount as u64), ctx);
                transfer::public_transfer(burn_coin, farm.burn_address);
            };
            
            if (locker_amount > 0) {
                let locker_coin = coin::split(&mut fee_coin, (locker_amount as u64), ctx);
                transfer::public_transfer(locker_coin, farm.locker_address);
            };
            
            if (team_amount > 0) {
                let team_coin = coin::split(&mut fee_coin, (team_amount as u64), ctx);
                transfer::public_transfer(team_coin, farm.team_address);
            };
            
            transfer::public_transfer(fee_coin, farm.dev_address);
            
            pool.accumulated_deposit_fees = pool.accumulated_deposit_fees + fee_amount_u256;
            
            event::emit(FeesCollected {
                pool_type: pool.pool_type,
                amount: fee_amount_u256,
                fee_type: string::utf8(b"deposit"),
                timestamp: current_time
            });
        };
        
        let vault_id = object::new(ctx);
        let token_vault = StakedTokenVault<T> {
            id: vault_id,
            balance: coin::into_balance(tokens),
            owner: sender,
            pool_type: token_type,
            amount: stake_amount,
            initial_stake_timestamp: current_time
        };
        
        let position_id = object::new(ctx);
        let position = StakingPosition<T> {
            id: position_id,
            owner: sender,
            pool_type: token_type,
            amount: stake_amount,
            initial_stake_timestamp: current_time,
            vault_id: object::uid_to_inner(&token_vault.id)
        };
        
        let position_uid_bytes = object::uid_to_inner(&position.id);
        
        if (!table::contains(&mut farm.user_positions, sender)) {
            table::add(&mut farm.user_positions, sender, table::new(ctx));
        };
        
        let user_table = table::borrow_mut(&mut farm.user_positions, sender);
        
        if (!table::contains(user_table, token_type)) {
            table::add(user_table, token_type, vector::empty<ID>());
        };
        
        let positions = table::borrow_mut(user_table, token_type);
        vector::push_back(positions, position_uid_bytes);
        
        table::add(&mut farm.position_to_vault, position_uid_bytes, object::uid_to_inner(&token_vault.id));
        
        transfer::share_object(token_vault);
        transfer::transfer(position, sender);
        
        let staker = table::borrow_mut(&mut pool.stakers, sender);
        staker.amount = staker.amount + stake_amount;
        staker.reward_debt = fixed_point_math::mul(
            fixed_point_math::new(staker.amount),
            pool.reward_per_token_stored
        );
        staker.last_stake_timestamp = current_time;
        
        if (pending_rewards > 0) {
            farm.total_victory_distributed = farm.total_victory_distributed + pending_rewards;
            
            distribute_from_vault(vault, pending_rewards, sender, ctx);
            
            let staker = table::borrow_mut(&mut pool.stakers, sender);
            staker.rewards_claimed = staker.rewards_claimed + pending_rewards;
            staker.last_claim_timestamp = current_time;
            
            event::emit(RewardClaimed {
                staker: sender,
                pool_type: token_type,
                amount: pending_rewards,
                timestamp: current_time
            });
        };
        
        pool.total_staked = pool.total_staked + stake_amount;
        
        event::emit(Staked {
            staker: sender,
            pool_type: token_type,
            amount: stake_amount,
            timestamp: current_time
        });
    }

    public entry fun unstake_single<T>(
        farm: &mut Farm,
        vault: &mut RewardVault,
        mut position: StakingPosition<T>,
        token_vault: &mut StakedTokenVault<T>,
        amount: u256,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!farm.paused, ERROR_INACTIVE_POOL);
        
        let token_type = type_name::get<T>();
        assert!(table::contains(&farm.pools, token_type), ERROR_POOL_NOT_FOUND);
        
        let sender = tx_context::sender(ctx);
        assert!(position.owner == sender, ERROR_NOT_OWNER);
        
        let position_id = object::uid_to_inner(&position.id);
        let vault_id = object::uid_to_inner(&token_vault.id);
        assert!(position.vault_id == vault_id, ERROR_INVALID_VAULT);
        
        assert!(token_vault.owner == sender, ERROR_NOT_OWNER);
        assert!(position.amount == token_vault.amount, ERROR_CALCULATION_OVERFLOW);
        assert!(amount > 0 && amount <= position.amount, ERROR_INVALID_AMOUNT);
        assert!(balance::value(&token_vault.balance) >= (amount as u64), ERROR_INSUFFICIENT_BALANCE);
        
        let current_time = clock::timestamp_ms(clock)/ 1000;
        farm.last_update_timestamp = current_time;
        
        let total_lp_allocation_points = farm.total_lp_allocation_points;
        let total_single_allocation_points = farm.total_single_allocation_points;
        
        let pool = table::borrow_mut(&mut farm.pools, token_type);
        assert!(pool.active, ERROR_INACTIVE_POOL);
        
        // Check emission state for reward calculations
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        
        if (pool.total_staked > 0 && is_initialized && is_active && !is_paused) {
            let time_elapsed = ((current_time - pool.last_update_timestamp) as u256);
            
            let reward_amount = calculate_pool_reward(
                pool.is_lp_token,
                pool.allocation_points,
                total_lp_allocation_points,
                total_single_allocation_points,
                global_config,
                clock,
                time_elapsed
            );
            
            if (reward_amount > 0 && pool.total_staked > 0) {
                let reward_per_token_delta = fixed_point_math::div(
                    fixed_point_math::new(reward_amount * PRECISION),
                    fixed_point_math::new(pool.total_staked)
                );
                
                pool.reward_per_token_stored = fixed_point_math::add(
                    pool.reward_per_token_stored,
                    reward_per_token_delta
                );
            };
        };
        pool.last_update_timestamp = current_time;
        
        let mut pending_rewards = 0;
        
        if (table::contains(&pool.stakers, sender)) {
            let staker = table::borrow(&pool.stakers, sender);
            
            if (staker.amount > 0 && is_initialized && is_active && !is_paused) {
                let accumulated_rewards = fixed_point_math::mul(
                    fixed_point_math::new(staker.amount),
                    pool.reward_per_token_stored
                );
                
                let debt = staker.reward_debt;
                
                if (fixed_point_math::compare(accumulated_rewards, debt) == 2) {
                    let pending = fixed_point_math::sub(accumulated_rewards, debt);
                    pending_rewards = fixed_point_math::get_raw_value(pending) / PRECISION;
                };
            } else if (staker.amount > 0) {
                // Emit warning about no rewards
                let warning_msg = if (!is_initialized) {
                    string::utf8(b"Unstaking allowed but no rewards - emissions not started")
                } else if (!is_active) {
                    string::utf8(b"Unstaking allowed but no rewards - emissions ended")  
                } else {
                    string::utf8(b"Unstaking allowed but no rewards - emissions paused")
                };
                
                event::emit(EmissionWarning {
                    message: warning_msg,
                    pool_type: option::some(token_type),
                    timestamp: current_time
                });
            };
        };
        
        let fee_amount = (amount * pool.withdrawal_fee) / BASIS_POINTS;
        let unstake_amount = amount - fee_amount;
        
        let fee_amount_u64 = (fee_amount as u64);
        let unstake_amount_u64 = (unstake_amount as u64);
        
        if (pending_rewards > 0) {
            farm.total_victory_distributed = farm.total_victory_distributed + pending_rewards;
            
            distribute_from_vault(vault, pending_rewards, sender, ctx);
            
            if (table::contains(&pool.stakers, sender)) {
                let staker_ref = table::borrow_mut(&mut pool.stakers, sender);
                staker_ref.rewards_claimed = staker_ref.rewards_claimed + pending_rewards;
                staker_ref.last_claim_timestamp = current_time;
            };
            
            event::emit(RewardClaimed {
                staker: sender,
                pool_type: token_type,
                amount: pending_rewards,
                timestamp: current_time
            });
        };
        
        if (unstake_amount_u64 > 0) {
            let unstake_coin = coin::from_balance(
                balance::split(&mut token_vault.balance, unstake_amount_u64),
                ctx
            );
            transfer::public_transfer(unstake_coin, sender);
        };
        
        if (fee_amount_u64 > 0) {
            let fee_balance = balance::split(&mut token_vault.balance, fee_amount_u64);
            let mut fee_coin = coin::from_balance(fee_balance, ctx);
            let fee_amount_u256 = (coin::value(&fee_coin) as u256);
            
            let burn_amount = (fee_amount_u256 * 40) / 100;
            let locker_amount = (fee_amount_u256 * 40) / 100;
            let team_amount = (fee_amount_u256 * 10) / 100;
            let _dev_amount = fee_amount_u256 - burn_amount - locker_amount - team_amount;
            
            let burn_amount_u64 = (burn_amount as u64);
            let locker_amount_u64 = (locker_amount as u64);
            let team_amount_u64 = (team_amount as u64);
            
            if (burn_amount_u64 > 0) {
                let burn_coin = coin::split(&mut fee_coin, burn_amount_u64, ctx);
                transfer::public_transfer(burn_coin, farm.burn_address);
            };
            
            if (locker_amount_u64 > 0) {
                let locker_coin = coin::split(&mut fee_coin, locker_amount_u64, ctx);
                transfer::public_transfer(locker_coin, farm.locker_address);
            };
            
            if (team_amount_u64 > 0) {
                let team_coin = coin::split(&mut fee_coin, team_amount_u64, ctx);
                transfer::public_transfer(team_coin, farm.team_address);
            };
            
            transfer::public_transfer(fee_coin, farm.dev_address);
            
            pool.accumulated_withdrawal_fees = pool.accumulated_withdrawal_fees + fee_amount;
            
            event::emit(FeesCollected {
                pool_type: pool.pool_type,
                amount: fee_amount,
                fee_type: string::utf8(b"withdrawal"),
                timestamp: current_time
            });
        };
        
        if (table::contains(&pool.stakers, sender)) {
            let staker_ref = table::borrow_mut(&mut pool.stakers, sender);
            staker_ref.amount = staker_ref.amount - amount;
            
            staker_ref.reward_debt = fixed_point_math::mul(
                fixed_point_math::new(staker_ref.amount),
                pool.reward_per_token_stored
            );
        };
        
        pool.total_staked = pool.total_staked - amount;
        token_vault.amount = token_vault.amount - amount;
        
        if (amount == position.amount) {
            if (table::contains(&farm.user_positions, sender)) {
                let user_table = table::borrow_mut(&mut farm.user_positions, sender);
                
                if (table::contains(user_table, token_type)) {
                    let positions = table::borrow_mut(user_table, token_type);
                    
                    let mut i = 0;
                    let len = vector::length(positions);
                    let mut found = false;
                    
                    while (i < len && !found) {
                        if (*vector::borrow(positions, i) == position_id) {
                            vector::swap_remove(positions, i);
                            found = true;
                        } else {
                            i = i + 1;
                        };
                    };
                };
            };
            
            if (table::contains(&farm.position_to_vault, position_id)) {
                table::remove(&mut farm.position_to_vault, position_id);
            };
            
            let StakingPosition<T> { 
                id, 
                owner: _, 
                pool_type: _, 
                amount: _, 
                initial_stake_timestamp: _, 
                vault_id: _ 
            } = position;
            object::delete(id);
            
            if (balance::value(&token_vault.balance) == 0) {
                token_vault.owner = @0x0;
            };
        } else {
            position.amount = position.amount - amount;
            transfer::transfer(position, sender);
        };
        
        event::emit(Unstaked {
            staker: sender,
            pool_type: token_type,
            amount,
            timestamp: current_time
        });
    }

    public entry fun claim_rewards_lp<T0, T1>(
        farm: &mut Farm,
        vault: &mut RewardVault,
        position: &StakingPosition<LPCoin<T0, T1>>,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!farm.paused, ERROR_INACTIVE_POOL);
        
        // Strict emission validation for claiming
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        assert!(is_initialized, ERROR_EMISSIONS_NOT_INITIALIZED);
        assert!(is_active, ERROR_EMISSIONS_ENDED);
        assert!(!is_paused, ERROR_EMISSIONS_PAUSED);
        
        let lp_type = type_name::get<LPCoin<T0, T1>>();
        assert!(table::contains(&farm.pools, lp_type), ERROR_POOL_NOT_FOUND);
        
        let sender = tx_context::sender(ctx);
        assert!(position.owner == sender, ERROR_NOT_OWNER);
        
        let current_time = clock::timestamp_ms(clock)/ 1000;
        farm.last_update_timestamp = current_time;
        
        let position_id = object::uid_to_inner(&position.id);
        assert!(table::contains(&farm.position_to_vault, position_id), ERROR_POOL_NOT_FOUND);
        
        let total_lp_allocation_points = farm.total_lp_allocation_points;
        let total_single_allocation_points = farm.total_single_allocation_points;
        
        let pool = table::borrow_mut(&mut farm.pools, lp_type);
        assert!(pool.active, ERROR_INACTIVE_POOL);
        
        if (pool.total_staked > 0) {
            let time_elapsed = ((current_time - pool.last_update_timestamp) as u256);
            
            let reward_amount = calculate_pool_reward(
                pool.is_lp_token,
                pool.allocation_points,
                total_lp_allocation_points,
                total_single_allocation_points,
                global_config,
                clock,
                time_elapsed
            );
            
            if (reward_amount > 0) {
                let reward_per_token_delta = fixed_point_math::div(
                    fixed_point_math::new(reward_amount * PRECISION),
                    fixed_point_math::new(pool.total_staked)
                );
                
                pool.reward_per_token_stored = fixed_point_math::add(
                    pool.reward_per_token_stored,
                    reward_per_token_delta
                );
            };
        };
        pool.last_update_timestamp = current_time;
        
        assert!(table::contains(&pool.stakers, sender), ERROR_NOT_OWNER);
        let staker = table::borrow(&pool.stakers, sender);
        
        assert!(staker.amount > 0, ERROR_INSUFFICIENT_BALANCE);
        
        let accumulated_rewards = fixed_point_math::mul(
            fixed_point_math::new(staker.amount),
            pool.reward_per_token_stored
        );
        
        let debt = staker.reward_debt;
        let mut pending_rewards = 0;
        
        if (fixed_point_math::compare(accumulated_rewards, debt) == 2) {
            let pending = fixed_point_math::sub(accumulated_rewards, debt);
            pending_rewards = fixed_point_math::get_raw_value(pending) / PRECISION;
        };
        
        assert!(pending_rewards > 0, ERROR_NO_REWARDS);
        
        farm.total_victory_distributed = farm.total_victory_distributed + pending_rewards;
        
        distribute_from_vault(vault, pending_rewards, sender, ctx);
        
        let staker_ref = table::borrow_mut(&mut pool.stakers, sender);
        staker_ref.reward_debt = accumulated_rewards;
        staker_ref.rewards_claimed = staker_ref.rewards_claimed + pending_rewards;
        staker_ref.last_claim_timestamp = current_time;
        
        event::emit(RewardClaimed {
            staker: sender,
            pool_type: lp_type,
            amount: pending_rewards,
            timestamp: current_time
        });
    }

    public entry fun claim_rewards_single<T>(
        farm: &mut Farm,
        vault: &mut RewardVault,
        position: &StakingPosition<T>,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!farm.paused, ERROR_INACTIVE_POOL);
        
        // Strict emission validation for claiming
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        assert!(is_initialized, ERROR_EMISSIONS_NOT_INITIALIZED);
        assert!(is_active, ERROR_EMISSIONS_ENDED);
        assert!(!is_paused, ERROR_EMISSIONS_PAUSED);
        
        // Extra check for single asset phase-out
        let (_, single_allocation) = get_allocations_safe(global_config, clock);
        assert!(single_allocation > 0, ERROR_SINGLE_REWARDS_ENDED);
        
        let token_type = type_name::get<T>();
        assert!(table::contains(&farm.pools, token_type), ERROR_POOL_NOT_FOUND);
        
        let sender = tx_context::sender(ctx);
        assert!(position.owner == sender, ERROR_NOT_OWNER);
        
        let current_time = clock::timestamp_ms(clock)/ 1000;
        farm.last_update_timestamp = current_time;
        
        let position_id = object::uid_to_inner(&position.id);
        assert!(table::contains(&farm.position_to_vault, position_id), ERROR_POOL_NOT_FOUND);
        
        let total_lp_allocation_points = farm.total_lp_allocation_points;
        let total_single_allocation_points = farm.total_single_allocation_points;
        
        let pool = table::borrow_mut(&mut farm.pools, token_type);
        assert!(pool.active, ERROR_INACTIVE_POOL);
        
        if (pool.total_staked > 0) {
            let time_elapsed = ((current_time - pool.last_update_timestamp) as u256);
            
            let reward_amount = calculate_pool_reward(
                pool.is_lp_token,
                pool.allocation_points,
                total_lp_allocation_points,
                total_single_allocation_points,
                global_config,
                clock,
                time_elapsed
            );
            
            if (reward_amount > 0) {
                let reward_per_token_delta = fixed_point_math::div(
                    fixed_point_math::new(reward_amount * PRECISION),
                    fixed_point_math::new(pool.total_staked)
                );
                
                pool.reward_per_token_stored = fixed_point_math::add(
                    pool.reward_per_token_stored,
                    reward_per_token_delta
                );
            };
        };
        pool.last_update_timestamp = current_time;
        
        assert!(table::contains(&pool.stakers, sender), ERROR_NOT_OWNER);
        let staker = table::borrow(&pool.stakers, sender);
        
        assert!(staker.amount > 0, ERROR_INSUFFICIENT_BALANCE);
        
        let accumulated_rewards = fixed_point_math::mul(
            fixed_point_math::new(staker.amount),
            pool.reward_per_token_stored
        );
        
        let debt = staker.reward_debt;
        let mut pending_rewards = 0;
        
        if (fixed_point_math::compare(accumulated_rewards, debt) == 2) {
            let pending = fixed_point_math::sub(accumulated_rewards, debt);
            pending_rewards = fixed_point_math::get_raw_value(pending) / PRECISION;
        };
        
        assert!(pending_rewards > 0, ERROR_NO_REWARDS);
        
        farm.total_victory_distributed = farm.total_victory_distributed + pending_rewards;
        
        distribute_from_vault(vault, pending_rewards, sender, ctx);
        
        let staker_ref = table::borrow_mut(&mut pool.stakers, sender);
        staker_ref.reward_debt = accumulated_rewards;
        staker_ref.rewards_claimed = staker_ref.rewards_claimed + pending_rewards;
        staker_ref.last_claim_timestamp = current_time;
        
        event::emit(RewardClaimed {
            staker: sender,
            pool_type: token_type,
            amount: pending_rewards,
            timestamp: current_time
        });
    }

    // === View Functions ===
    
    public fun get_pending_rewards<T>(
        farm: &Farm, 
        staker_address: address,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ): u256 {
        let pool_type = type_name::get<T>();
        
        if (!table::contains(&farm.pools, pool_type)) {
            return 0
        };
        
        // Check emission state first
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        if (!is_initialized || !is_active || is_paused) {
            return 0
        };
        
        let pool = table::borrow(&farm.pools, pool_type);
        
        if (!table::contains(&pool.stakers, staker_address)) {
            return 0
        };
        
        // Check pool-specific allocation
        let (lp_allocation, single_allocation) = get_allocations_safe(global_config, clock);
        if (pool.is_lp_token && lp_allocation == 0) return 0;
        if (!pool.is_lp_token && single_allocation == 0) return 0;
        
        let staker = table::borrow(&pool.stakers, staker_address);
        
        let current_time = clock::timestamp_ms(clock) / 1000;
        let time_elapsed = ((current_time - pool.last_update_timestamp) as u256);
        
        if (time_elapsed == 0 || pool.total_staked == 0) {
            return 0
        };
        
        let reward_value = calculate_pool_reward(
            pool.is_lp_token,
            pool.allocation_points,
            farm.total_lp_allocation_points,
            farm.total_single_allocation_points,
            global_config,
            clock,
            time_elapsed
        );
        
        if (reward_value == 0) return 0;
        
        let reward_per_token_delta = fixed_point_math::div(
            fixed_point_math::new(reward_value * PRECISION),
            fixed_point_math::new(pool.total_staked)
        );
        
        let current_reward_per_token = fixed_point_math::add(
            pool.reward_per_token_stored,
            reward_per_token_delta
        );
        
        let accumulated_rewards = fixed_point_math::mul(
            fixed_point_math::new(staker.amount),
            current_reward_per_token
        );
        
        if (fixed_point_math::compare(accumulated_rewards, staker.reward_debt) == 2) {
            let pending = fixed_point_math::sub(accumulated_rewards, staker.reward_debt);
            fixed_point_math::get_raw_value(pending) / PRECISION
        } else {
            0
        }
    }
    
    // === EMISSION-RELATED VIEW FUNCTIONS ===
    
    /// Get emission status for farm
    public fun get_emission_status_for_farm(
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): (bool, bool, bool, u64, u8) {
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        let (current_week, phase, _, _, _) = global_emission_controller::get_emission_status(global_config, clock);
        
        (is_initialized, is_active, is_paused, current_week, phase)
    }
    
    /// Check if single assets can earn rewards
    public fun can_stake_single_assets(
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): bool {
        let (_, single_allocation) = get_allocations_safe(global_config, clock);
        single_allocation > 0
    }
    
    /// Get pool-specific reward status
    public fun get_pool_reward_status<T>(
        farm: &Farm,
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): (bool, u256, String) {
        let pool_type = type_name::get<T>();
        
        if (!table::contains(&farm.pools, pool_type)) {
            return (false, 0, string::utf8(b"Pool not found"))
        };
        
        let pool = table::borrow(&farm.pools, pool_type);
        let (lp_allocation, single_allocation) = get_allocations_safe(global_config, clock);
        
        if (pool.is_lp_token) {
            (lp_allocation > 0, lp_allocation, 
             if (lp_allocation > 0) string::utf8(b"Active") else string::utf8(b"Ended"))
        } else {
            (single_allocation > 0, single_allocation,
             if (single_allocation > 0) string::utf8(b"Active") else string::utf8(b"Single rewards ended"))
        }
    }
    
    /// Get current allocations with status
    public fun get_current_allocations(
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): (u256, u256, bool, u64) {
        let (lp_allocation, single_allocation) = get_allocations_safe(global_config, clock);
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        let active_allocations = is_initialized && is_active && !is_paused;
        let (current_week, _, _, _, _) = global_emission_controller::get_emission_status(global_config, clock);
        
        (lp_allocation, single_allocation, active_allocations, current_week)
    }
    
    // === EXISTING VIEW FUNCTIONS (unchanged) ===
    
    public fun get_vault_balance(vault: &RewardVault): u256 {
        balance::value(&vault.victory_balance) as u256
    }
    
    public fun get_pool_info<T>(farm: &Farm): (u256, u256, u256, bool, bool, bool) {
        let pool_type = type_name::get<T>();
        
        if (!table::contains(&farm.pools, pool_type)) {
            return (0, 0, 0, false, false, false)
        };
        
        let pool = table::borrow(&farm.pools, pool_type);
        
        (
            pool.total_staked,
            pool.deposit_fee,
            pool.withdrawal_fee,
            pool.active,
            pool.is_native_pair,
            pool.is_lp_token
        )
    }
    
    public fun get_staker_info<T>(farm: &Farm, staker_address: address): (u256, u256, u64, u64) {
        let pool_type = type_name::get<T>();
        
        if (!table::contains(&farm.pools, pool_type)) {
            return (0, 0, 0, 0)
        };
        
        let pool = table::borrow(&farm.pools, pool_type);
        
        if (!table::contains(&pool.stakers, staker_address)) {
            return (0, 0, 0, 0)
        };
        
        let staker = table::borrow(&pool.stakers, staker_address);
        
        (
            staker.amount,
            staker.rewards_claimed,
            staker.last_stake_timestamp,
            staker.last_claim_timestamp
        )
    }
    
    public fun get_farm_info(farm: &Farm): (bool, u256, u256) {
        (
            farm.paused,
            farm.total_lp_allocation_points,
            farm.total_single_allocation_points
        )
    }
    
    public fun get_pool_list(farm: &Farm): &vector<TypeName> {
        &farm.pool_list
    }

    /// Get total Victory tokens distributed by the farm
    public fun get_total_victory_distributed(farm: &Farm): u256 {
        farm.total_victory_distributed
    }
    
    /// Enhanced farm info including total distributed
    public fun get_farm_info_detailed(farm: &Farm): (bool, u256, u256, u256) {
        (
            farm.paused,
            farm.total_lp_allocation_points,
            farm.total_single_allocation_points,
            farm.total_victory_distributed
        )
    }
    
    public fun is_lp_type_allowed<T0, T1>(farm: &Farm): bool {
        let lp_type = type_name::get<LPCoin<T0, T1>>();
        table::contains(&farm.allowed_lp_types, lp_type)
    }

    public fun get_all_user_positions(farm: &Farm, user_address: address): vector<ID> {
        let mut all_position_ids = vector::empty<ID>();
        
        if (!table::contains(&farm.user_positions, user_address)) {
            return all_position_ids
        };
        
        let user_table = table::borrow(&farm.user_positions, user_address);
        
        let mut i = 0;
        let len = vector::length(&farm.pool_list);
        
        while (i < len) {
            let token_type = *vector::borrow(&farm.pool_list, i);
            
            if (table::contains(user_table, token_type)) {
                let positions = table::borrow(user_table, token_type);
                let mut j = 0;
                let pos_len = vector::length(positions);
                
                while (j < pos_len) {
                    vector::push_back(&mut all_position_ids, *vector::borrow(positions, j));
                    j = j + 1;
                };
            };
            
            i = i + 1;
        };
        
        all_position_ids
    }

    public fun get_vault_id_for_position(farm: &Farm, position_id: ID): ID {
        *table::borrow(&farm.position_to_vault, position_id)
    }

    public fun get_user_token_positions(farm: &Farm, user_address: address, token_type: TypeName): vector<ID> {
        if (!table::contains(&farm.user_positions, user_address)) {
            return vector::empty<ID>()
        };
        
        let user_table = table::borrow(&farm.user_positions, user_address);
        
        if (!table::contains(user_table, token_type)) {
            return vector::empty<ID>()
        };
        
        *table::borrow(user_table, token_type)
    }

    public struct PositionSummary has copy, drop {
        id: ID,
        token_type: TypeName,
        amount: u256
    }

    public fun get_user_position_summaries(farm: &Farm, user_address: address): vector<PositionSummary> {
        let mut summaries = vector::empty<PositionSummary>();
        
        if (!table::contains(&farm.user_positions, user_address)) {
            return summaries
        };
        
        let user_table = table::borrow(&farm.user_positions, user_address);
        
        let mut i = 0;
        let len = vector::length(&farm.pool_list);
        
        while (i < len) {
            let token_type = *vector::borrow(&farm.pool_list, i);
            
            if (table::contains(user_table, token_type)) {
                let positions = table::borrow(user_table, token_type);
                let mut j = 0;
                let pos_len = vector::length(positions);
                
                while (j < pos_len) {
                    let position_id = *vector::borrow(positions, j);
                    
                    if (table::contains(&farm.position_to_vault, position_id)) {
                        let pool = table::borrow(&farm.pools, token_type);
                        
                        if (table::contains(&pool.stakers, user_address)) {
                            let staker = table::borrow(&pool.stakers, user_address);
                            
                            let summary = PositionSummary {
                                id: position_id,
                                token_type: token_type,
                                amount: staker.amount
                            };
                            
                            vector::push_back(&mut summaries, summary);
                        };
                    };
                    
                    j = j + 1;
                };
            };
            
            i = i + 1;
        };
        
        summaries
    }

    public struct UserTokenStake has copy, drop {
        token_type: TypeName,
        total_amount: u256,
        position_count: u64,
        pending_rewards: u256
    }

    public fun get_user_token_stakes(
        farm: &Farm, 
        user_address: address, 
        global_config: &GlobalEmissionConfig,
        clock: &Clock, 
        ctx: &mut TxContext
    ): vector<UserTokenStake> {
        let mut token_stakes = vector::empty<UserTokenStake>();
        
        let mut i = 0;
        let len = vector::length(&farm.pool_list);
        
        while (i < len) {
            let token_type = *vector::borrow(&farm.pool_list, i);
            
            if (table::contains(&farm.pools, token_type)) {
                let pool = table::borrow(&farm.pools, token_type);
                
                if (table::contains(&pool.stakers, user_address)) {
                    let staker = table::borrow(&pool.stakers, user_address);
                    
                    let mut position_count = 0;
                    if (table::contains(&farm.user_positions, user_address)) {
                        let user_table = table::borrow(&farm.user_positions, user_address);
                        if (table::contains(user_table, token_type)) {
                            let positions = table::borrow(user_table, token_type);
                            position_count = vector::length(positions);
                        };
                    };
                    
                    let mut pending_rewards = 0;
                    if (staker.amount > 0) {
                        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
                        if (is_initialized && is_active && !is_paused) {
                            let current_time = clock::timestamp_ms(clock) / 1000;
                            let time_elapsed = ((current_time - pool.last_update_timestamp) as u256);
                            
                            if (time_elapsed > 0 && pool.total_staked > 0) {
                                let reward_value = calculate_pool_reward(
                                    pool.is_lp_token,
                                    pool.allocation_points,
                                    farm.total_lp_allocation_points,
                                    farm.total_single_allocation_points,
                                    global_config,
                                    clock,
                                    time_elapsed
                                );
                                
                                if (reward_value > 0) {
                                    let reward_per_token_delta = fixed_point_math::div(
                                        fixed_point_math::new(reward_value * PRECISION),
                                        fixed_point_math::new(pool.total_staked)
                                    );
                                    
                                    let current_reward_per_token = fixed_point_math::add(
                                        pool.reward_per_token_stored,
                                        reward_per_token_delta
                                    );
                                    
                                    let accumulated_rewards = fixed_point_math::mul(
                                        fixed_point_math::new(staker.amount),
                                        current_reward_per_token
                                    );
                                    
                                    if (fixed_point_math::compare(accumulated_rewards, staker.reward_debt) == 2) {
                                        let pending = fixed_point_math::sub(accumulated_rewards, staker.reward_debt);
                                        pending_rewards = fixed_point_math::get_raw_value(pending) / PRECISION;
                                    };
                                };
                            };
                        };
                    };
                    
                    let token_stake = UserTokenStake {
                        token_type: token_type,
                        total_amount: staker.amount,
                        position_count: position_count,
                        pending_rewards: pending_rewards
                    };
                    
                    vector::push_back(&mut token_stakes, token_stake);
                };
            };
            
            i = i + 1;
        };
        
        token_stakes
    }

    // Add these two functions to your farm contract in the view functions section

    /// Get current APY for a specific pool (returns basis points, 10000 = 100%)
    public fun get_pool_apy<T>(
        farm: &Farm,
        global_config: &GlobalEmissionConfig,
        clock: &Clock,
        victory_price_usd: u256, // Price in cents (e.g., 500 = $0.005)
        pool_tvl_usd: u256       // TVL in cents to avoid decimals
    ): u256 {
        let pool_type = type_name::get<T>();
        
        if (!table::contains(&farm.pools, pool_type)) {
            return 0
        };
        
        let pool = table::borrow(&farm.pools, pool_type);
        if (!pool.active || pool.total_staked == 0) {
            return 0
        };
        
        // Check emission state
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        if (!is_initialized || !is_active || is_paused) {
            return 0
        };
        
        // Get current allocations
        let (lp_allocation, single_allocation) = get_allocations_safe(global_config, clock);
        let pool_allocation_per_sec = if (pool.is_lp_token) lp_allocation else single_allocation;
        
        if (pool_allocation_per_sec == 0) {
            return 0
        };
        
        // Calculate this pool's share of the allocation
        let total_allocation_points = if (pool.is_lp_token) {
            farm.total_lp_allocation_points
        } else {
            farm.total_single_allocation_points
        };
        
        if (total_allocation_points == 0) {
            return 0
        };
        
        // Pool's share of emissions per second
        let pool_rewards_per_sec = (pool_allocation_per_sec * pool.allocation_points) / total_allocation_points;
        
        // Annual rewards (Victory tokens)
        let annual_rewards_victory = pool_rewards_per_sec * 31536000; // seconds per year
        
        // Convert to USD value (in cents)
        let annual_rewards_usd = annual_rewards_victory * victory_price_usd / 1000000; // Adjust for token decimals
        
        if (pool_tvl_usd == 0) {
            return 0
        };
        
        // APY = (annual_rewards_usd / pool_tvl_usd) * 10000 (to get basis points)
        let apy_basis_points = (annual_rewards_usd * 10000) / pool_tvl_usd;
        
        apy_basis_points
    }
    
    /// Get user-specific earning projections
    public fun get_user_earning_projections<T>(
        farm: &Farm,
        user: address,
        global_config: &GlobalEmissionConfig,
        clock: &Clock
    ): (u256, u256, u256, u256, u256) {
        let pool_type = type_name::get<T>();
        
        if (!table::contains(&farm.pools, pool_type)) {
            return (0, 0, 0, 0, 0)
        };
        
        let pool = table::borrow(&farm.pools, pool_type);
        
        if (!table::contains(&pool.stakers, user)) {
            return (0, 0, 0, 0, 0)
        };
        
        let staker = table::borrow(&pool.stakers, user);
        let user_stake = staker.amount;
        
        if (user_stake == 0 || pool.total_staked == 0) {
            return (0, 0, 0, 0, 0)
        };
        
        // Check emission state
        let (is_initialized, is_active, is_paused) = validate_emission_state(global_config, clock);
        if (!is_initialized || !is_active || is_paused) {
            return (0, 0, 0, 0, 0)
        };
        
        // Get current allocations
        let (lp_allocation, single_allocation) = get_allocations_safe(global_config, clock);
        let pool_allocation_per_sec = if (pool.is_lp_token) lp_allocation else single_allocation;
        
        if (pool_allocation_per_sec == 0) {
            return (0, 0, 0, 0, 0)
        };
        
        // Calculate pool's total rewards per second
        let total_allocation_points = if (pool.is_lp_token) {
            farm.total_lp_allocation_points
        } else {
            farm.total_single_allocation_points
        };
        
        if (total_allocation_points == 0) {
            return (0, 0, 0, 0, 0)
        };
        
        let pool_rewards_per_sec = (pool_allocation_per_sec * pool.allocation_points) / total_allocation_points;
        
        // Calculate user's share
        let user_share_per_sec = (pool_rewards_per_sec * user_stake) / pool.total_staked;
        
        // Project different time periods
        let earnings_per_hour = user_share_per_sec * 3600;
        let earnings_per_day = user_share_per_sec * 86400;
        let earnings_per_week = user_share_per_sec * 604800;
        let earnings_per_month = user_share_per_sec * 2592000; // 30 days
        
        (
            user_share_per_sec,
            earnings_per_hour,
            earnings_per_day,
            earnings_per_week,
            earnings_per_month
        )
    }

    public fun get_token_type<T>(): TypeName {
        type_name::get<T>()
    }
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(FARM {}, ctx)
    }
}