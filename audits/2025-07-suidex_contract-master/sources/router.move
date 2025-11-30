#[allow(unused_variable,unused_let_mut,unused_const,duplicate_alias,unused_use,lint(self_transfer),unused_field)]
module suitrump_dex::router {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use std::option::{Self, Option};
    use suitrump_dex::factory::{Self, Factory};
    use suitrump_dex::pair::{Self, Pair, LPCoin};
    use suitrump_dex::library;
    use std::string::String;
    use sui::event;
    use suitrump_dex::fixed_point_math::{Self, FixedPoint};

    // Error codes
    const ERR_EXPIRED: u64 = 301;
    const ERR_INSUFFICIENT_A_AMOUNT: u64 = 302;
    const ERR_INSUFFICIENT_B_AMOUNT: u64 = 303;
    const ERR_INSUFFICIENT_LIQUIDITY: u64 = 304;
    const ERR_INSUFFICIENT_OUTPUT_AMOUNT: u64 = 305;
    const ERR_EXCESSIVE_INPUT_AMOUNT: u64 = 306;
    const ERR_INVALID_PATH: u64 = 307;
    const ERR_PAIR_EXISTS: u64 = 308;
    const ERR_INVALID_INPUT: u64 = 310;
    const ERR_CALCULATION_OVERFLOW: u64 = 311;
    const ERR_SLIPPAGE_EXCEEDED: u64 = 312;

    // Constants
    const MINIMUM_LIQUIDITY: u256 = 10000;
    const BASIS_POINTS: u256 = 10000;

    /// Router struct to manage liquidity operations
    public struct Router has key {
        id: UID
    }

    /// Struct to hold reserve values
    public struct Reserves has store, copy, drop {
        reserve0: u256,
        reserve1: u256
    }

    public struct PairCreatedEvent has copy, drop {
        token0: String,
        token1: String,
        pair_address: address
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(Router {
            id: object::new(ctx)
        });
    }

    public entry fun create_pair<T0, T1>(
        _router: &Router,
        factory: &mut Factory,
        token0_name: String,
        token1_name: String,
        ctx: &mut TxContext
    ) {
        let pair_opt = factory::get_pair<T0, T1>(factory);
        assert!(std::option::is_none(&pair_opt), ERR_PAIR_EXISTS);

        let pair_addr = factory::create_pair<T0, T1>(
            factory,
            token0_name,
            token1_name,
            ctx
        );

        event::emit(PairCreatedEvent {
            token0: token0_name,
            token1: token1_name,
            pair_address: pair_addr
        });
    }

    fun add_liquidity_internal(
        amount_a_desired: u256,
        amount_b_desired: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        pair_exists: bool,
        reserves: Option<Reserves>
    ): (u256, u256) {
        assert!(fixed_point_math::is_safe_value(amount_a_desired), ERR_CALCULATION_OVERFLOW);
        assert!(fixed_point_math::is_safe_value(amount_b_desired), ERR_CALCULATION_OVERFLOW);

        if (!pair_exists) {
            return (amount_a_desired, amount_b_desired)
        };
        
        let (reserve_a, reserve_b) = if (std::option::is_some(&reserves)) {
            let r = std::option::destroy_some(reserves);
            (r.reserve0, r.reserve1)
        } else {
            (0, 0)
        };

        if (reserve_a == 0 && reserve_b == 0) {
            (amount_a_desired, amount_b_desired)
        } else {
            let amount_b_optimal = library::quote(
                amount_a_desired,
                reserve_a,
                reserve_b
            );
            if (amount_b_optimal <= amount_b_desired) {
                assert!(amount_b_optimal >= amount_b_min, ERR_INSUFFICIENT_B_AMOUNT);
                (amount_a_desired, amount_b_optimal)
            } else {
                let amount_a_optimal = library::quote(
                    amount_b_desired,
                    reserve_b,
                    reserve_a
                );
                assert!(amount_a_optimal <= amount_a_desired, ERR_EXCESSIVE_INPUT_AMOUNT);
                assert!(amount_a_optimal >= amount_a_min, ERR_INSUFFICIENT_A_AMOUNT);
                (amount_a_optimal, amount_b_desired)
            }
        }
    }

    public entry fun add_liquidity<T0, T1>(
        _router: &Router,
        factory: &mut Factory,
        pair: &mut Pair<T0, T1>,
        mut coin_a: Coin<T0>,
        mut coin_b: Coin<T1>,
        amount_a_desired: u256,
        amount_b_desired: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        token0_name: String,
        token1_name: String,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        assert!(deadline >= tx_context::epoch_timestamp_ms(ctx), ERR_EXPIRED);
        assert!(fixed_point_math::is_safe_value(amount_a_desired), ERR_CALCULATION_OVERFLOW);
        assert!(fixed_point_math::is_safe_value(amount_b_desired), ERR_CALCULATION_OVERFLOW);
        assert!(amount_a_min <= amount_a_desired && amount_b_min <= amount_b_desired, ERR_INVALID_INPUT);

        // Get the sorted token pair to determine if we need to swap amounts
        let sorted_pair = factory::sort_tokens<T0, T1>();
        let is_sorted = factory::is_token0<T0>(&sorted_pair); // Using factory's is_token0 function instead

        // If tokens are not in sorted order, swap the amounts
        let (final_amount_a_desired, final_amount_b_desired) = if (is_sorted) {
            (amount_a_desired, amount_b_desired)
        } else {
            (amount_b_desired, amount_a_desired)
        };

        let (final_amount_a_min, final_amount_b_min) = if (is_sorted) {
            (amount_a_min, amount_b_min)
        } else {
            (amount_b_min, amount_a_min)
        };

        let pair_opt = factory::get_pair<T0, T1>(factory);
        let mut pair_exists = std::option::is_some(&pair_opt);

        if (!pair_exists) {
            factory::create_pair<T0, T1>(
                factory,
                token0_name,
                token1_name,
                ctx
            );
            pair_exists = false;
        };

        let mut reserves = std::option::none();
        if (pair_exists) {
            let (reserve0, reserve1, _) = pair::get_reserves(pair);
            reserves = std::option::some(Reserves { reserve0, reserve1 });
        };

        let (amount_a, amount_b) = add_liquidity_internal(
            final_amount_a_desired,
            final_amount_b_desired,
            final_amount_a_min,
            final_amount_b_min,
            pair_exists,
            reserves
        );

        let sender = tx_context::sender(ctx);
        let value_a = (coin::value(&coin_a) as u256);
        if (value_a > amount_a) {
            let remainder_a = coin::split(&mut coin_a, ((value_a - amount_a) as u64), ctx);
            transfer::public_transfer(remainder_a, sender);
        };

        let value_b = (coin::value(&coin_b) as u256);
        if (value_b > amount_b) {
            let remainder_b = coin::split(&mut coin_b, ((value_b - amount_b) as u64), ctx);
            transfer::public_transfer(remainder_b, sender);
        };

        let lp_tokens = pair::mint(pair, coin_a, coin_b, ctx);
        transfer::public_transfer(lp_tokens, sender);
    }

    fun remove_liquidity_internal(
        total_supply: u256,
        lp_amount: u256,
        reserve0: u256,
        reserve1: u256,
        amount_a_min: u256,
        amount_b_min: u256
    ): (u256, u256) {
        assert!(lp_amount > 0 && total_supply > 0, ERR_INSUFFICIENT_LIQUIDITY);
        assert!(fixed_point_math::is_safe_value(lp_amount), ERR_CALCULATION_OVERFLOW);
        assert!(fixed_point_math::is_safe_value(total_supply), ERR_CALCULATION_OVERFLOW);
        
        // Calculate proportional amounts using fixed point math
        let lp_amount_fp = fixed_point_math::new(lp_amount);
        let total_supply_fp = fixed_point_math::new(total_supply);
        let reserve0_fp = fixed_point_math::new(reserve0);
        let reserve1_fp = fixed_point_math::new(reserve1);

        let amount0_fp = fixed_point_math::div(
            fixed_point_math::mul(lp_amount_fp, reserve0_fp),
            total_supply_fp
        );
        let amount1_fp = fixed_point_math::div(
            fixed_point_math::mul(lp_amount_fp, reserve1_fp),
            total_supply_fp
        );

        let amount0 = fixed_point_math::get_raw_value(amount0_fp);
        let amount1 = fixed_point_math::get_raw_value(amount1_fp);
        
        assert!(amount0 >= amount_a_min, ERR_INSUFFICIENT_A_AMOUNT);
        assert!(amount1 >= amount_b_min, ERR_INSUFFICIENT_B_AMOUNT);
        
        (amount0, amount1)
    }

    public entry fun remove_liquidity<T0, T1>(
        _router: &Router,
        factory: &Factory,
        pair: &mut Pair<T0, T1>,
        mut lp_coins: vector<Coin<LPCoin<T0, T1>>>,
        amount_to_burn: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        assert!(deadline >= tx_context::epoch_timestamp_ms(ctx), ERR_EXPIRED);
        
        // Get the sorted token pair to determine the order
        let sorted_pair = factory::sort_tokens<T0, T1>();
        let is_sorted = factory::is_token0<T0>(&sorted_pair);

        // Get final minimum amounts based on token order
        let (final_amount_a_min, final_amount_b_min) = if (is_sorted) {
            (amount_a_min, amount_b_min)
        } else {
            (amount_b_min, amount_a_min)
        };
        
        // Merge LP coins
        let mut merged_coin = vector::pop_back(&mut lp_coins);
        while (!vector::is_empty(&lp_coins)) {
            coin::join(&mut merged_coin, vector::pop_back(&mut lp_coins));
        };
        vector::destroy_empty(lp_coins);
        
        let total_lp = (coin::value(&merged_coin) as u256);
        assert!(total_lp >= amount_to_burn, ERR_INSUFFICIENT_LIQUIDITY);

        // Split merged coin into burn amount and remainder
        let sender = tx_context::sender(ctx);
        let burn_coin = if (total_lp == amount_to_burn) {
            merged_coin
        } else {
            let remaining = ((total_lp - amount_to_burn) as u64);
            let remaining_coin = coin::split(&mut merged_coin, remaining, ctx);
            transfer::public_transfer(remaining_coin, sender);
            merged_coin
        };

        // Get current reserves and total supply
        let (reserve0, reserve1, _) = pair::get_reserves(pair);
        let total_supply = pair::total_supply(pair);

        // Calculate amounts using internal function
        let (amount0, amount1) = remove_liquidity_internal(
            total_supply,
            amount_to_burn,
            reserve0,
            reserve1,
            final_amount_a_min,
            final_amount_b_min
        );

        // Burn LP tokens and get underlying assets
        let (coin0, coin1) = pair::burn(pair, burn_coin, ctx);
        
        // Transfer tokens back based on the original order
        if (is_sorted) {
            transfer::public_transfer(coin0, sender);
            transfer::public_transfer(coin1, sender);
        } else {
            transfer::public_transfer(coin1, sender);
            transfer::public_transfer(coin0, sender);
        };
    }

    fun exact_tokens0_swap<T0, T1>(
        factory: &Factory,
        pair: &mut Pair<T0, T1>,
        coin_in: Coin<T0>,
        amount_out_min: u256,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let amount_in = (coin::value(&coin_in) as u256);
        assert!(fixed_point_math::is_safe_value(amount_in), ERR_CALCULATION_OVERFLOW);

        let amount_out = library::get_amounts_out(factory, amount_in, pair, true);
        assert!(amount_out >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);

        let (mut coin0_out, mut coin1_out) = pair::swap(
            pair,
            option::some(coin_in),
            option::none(),
            0,
            amount_out,
            ctx
        );

        if (option::is_some(&coin0_out)) {
            transfer::public_transfer(option::extract(&mut coin0_out), sender);
        };
        option::destroy_none(coin0_out);

        if (option::is_some(&coin1_out)) {
            transfer::public_transfer(option::extract(&mut coin1_out), sender);
        };
        option::destroy_none(coin1_out);
    }

    fun exact_tokens1_swap<T0, T1>(
        factory: &Factory,
        pair: &mut Pair<T0, T1>,
        coin_in: Coin<T1>,
        amount_out_min: u256,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let amount_in = (coin::value(&coin_in) as u256);
        assert!(fixed_point_math::is_safe_value(amount_in), ERR_CALCULATION_OVERFLOW);

        let amount_out = library::get_amounts_out(factory, amount_in, pair, false);
        assert!(amount_out >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);

        let (mut coin0_out, mut coin1_out) = pair::swap(
            pair,
            option::none(),
            option::some(coin_in),
            amount_out,
            0,
            ctx
        );

        if (option::is_some(&coin0_out)) {
            transfer::public_transfer(option::extract(&mut coin0_out), sender);
        };
        option::destroy_none(coin0_out);

        if (option::is_some(&coin1_out)) {
            transfer::public_transfer(option::extract(&mut coin1_out), sender);
        };
        option::destroy_none(coin1_out);
    }

    fun exact_output_tokens0_swap<T0, T1>(
        factory: &Factory,
        pair: &mut Pair<T0, T1>,
        mut coin_in: Coin<T0>,
        amount_out: u256,
        amount_in_max: u256,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(fixed_point_math::is_safe_value(amount_out), ERR_CALCULATION_OVERFLOW);
        assert!(fixed_point_math::is_safe_value(amount_in_max), ERR_CALCULATION_OVERFLOW);

        let amount_in_required = library::get_amounts_in(factory, amount_out, pair, true);
        assert!(amount_in_required <= amount_in_max, ERR_EXCESSIVE_INPUT_AMOUNT);

        let coin_value = (coin::value(&coin_in) as u256);
        
        if (coin_value > amount_in_required) {
            let remainder = coin::split(&mut coin_in, ((coin_value - amount_in_required) as u64), ctx);
            transfer::public_transfer(remainder, sender);
        };

        let (mut coin0_out, mut coin1_out) = pair::swap(
            pair,
            option::some(coin_in),
            option::none(),
            0,
            amount_out,
            ctx
        );

        if (option::is_some(&coin0_out)) {
            transfer::public_transfer(option::extract(&mut coin0_out), sender);
        };
        option::destroy_none(coin0_out);

        if (option::is_some(&coin1_out)) {
            transfer::public_transfer(option::extract(&mut coin1_out), sender);
        };
        option::destroy_none(coin1_out);
    }

    fun exact_output_tokens1_swap<T0, T1>(
        factory: &Factory,
        pair: &mut Pair<T0, T1>,
        mut coin_in: Coin<T1>,
        amount_out: u256,
        amount_in_max: u256,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(fixed_point_math::is_safe_value(amount_out), ERR_CALCULATION_OVERFLOW);
        assert!(fixed_point_math::is_safe_value(amount_in_max), ERR_CALCULATION_OVERFLOW);

        let amount_in_required = library::get_amounts_in(factory, amount_out, pair, true);
        assert!(amount_in_required <= amount_in_max, ERR_EXCESSIVE_INPUT_AMOUNT);

        let coin_value = (coin::value(&coin_in) as u256);
        
        if (coin_value > amount_in_required) {
            let remainder = coin::split(&mut coin_in, ((coin_value - amount_in_required) as u64), ctx);
            transfer::public_transfer(remainder, sender);
        };

        let (mut coin0_out, mut coin1_out) = pair::swap(
            pair,
            option::none(),
            option::some(coin_in),
            amount_out,
            0,
            ctx
        );

        if (option::is_some(&coin0_out)) {
            transfer::public_transfer(option::extract(&mut coin0_out), sender);
        };
        option::destroy_none(coin0_out);

        if (option::is_some(&coin1_out)) {
            transfer::public_transfer(option::extract(&mut coin1_out), sender);
        };
        option::destroy_none(coin1_out);
    }

    // Entry points that use original handlers
    public entry fun swap_exact_tokens0_for_tokens1<T0, T1>(
        _router: &Router,
        factory: &Factory,
        pair: &mut Pair<T0, T1>,
        coin_in: Coin<T0>,
        amount_out_min: u256,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        assert!(deadline >= tx_context::epoch_timestamp_ms(ctx), ERR_EXPIRED);
        exact_tokens0_swap(factory, pair, coin_in, amount_out_min, ctx);
    }

    // ===== HANDLER 1: Input token is token0 in first pair, Output token is token0 in second pair =====
    // First hop: Input token (T0) -> Middle token (TMid)
    // Second hop: Middle token (TMid) -> Output token (T1)
    // First pair: Pair<T0, TMid>
    // Second pair: Pair<T1, TMid>
    public entry fun swap_exact_token0_to_mid_then_mid_to_token0<T0, TMid, T1>(
        _router: &Router,
        factory: &Factory,
        pair_first: &mut Pair<T0, TMid>,
        pair_second: &mut Pair<T1, TMid>,
        coin_in: Coin<T0>,
        amount_out_min: u256,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        assert!(deadline >= tx_context::epoch_timestamp_ms(ctx), ERR_EXPIRED);
        let sender = tx_context::sender(ctx);

        // First hop: T0 (token0) -> TMid (token1)
        let amount_in = (coin::value(&coin_in) as u256);
        assert!(fixed_point_math::is_safe_value(amount_in), ERR_CALCULATION_OVERFLOW);
        
        let mid_amount_out = library::get_amounts_out(factory, amount_in, pair_first, true);
        
        let (mut coin0_mid, mut coin1_mid) = pair::swap(
            pair_first,
            option::some(coin_in),
            option::none(),
            0,
            mid_amount_out,
            ctx
        );
        
        assert!(option::is_some(&coin1_mid), ERR_INSUFFICIENT_LIQUIDITY);
        let mid_coin = option::extract(&mut coin1_mid);
        
        option::destroy_none(coin0_mid);
        option::destroy_none(coin1_mid);
        
        // Second hop: TMid (token1) -> T1 (token0)
        let mid_amount = (coin::value(&mid_coin) as u256);
        let final_amount_out = library::get_amounts_out(factory, mid_amount, pair_second, false);
        
        assert!(final_amount_out >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        
        let (mut coin0_final, mut coin1_final) = pair::swap(
            pair_second,
            option::none(),
            option::some(mid_coin),
            final_amount_out,
            0,
            ctx
        );
        
        assert!(option::is_some(&coin0_final), ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        let final_coin = option::extract(&mut coin0_final);
        
        option::destroy_none(coin0_final);
        option::destroy_none(coin1_final);
        
        transfer::public_transfer(final_coin, sender);
    }

    // ===== HANDLER 2: Input token is token0 in first pair, Middle token is token0 in second pair =====
    // First hop: Input token (T0) -> Middle token (TMid)
    // Second hop: Middle token (TMid) -> Output token (T2)
    // First pair: Pair<T0, TMid>
    // Second pair: Pair<TMid, T2>
    public entry fun swap_exact_token0_to_mid_then_mid_to_token1<T0, TMid, T2>(
        _router: &Router,
        factory: &Factory,
        pair_first: &mut Pair<T0, TMid>,
        pair_second: &mut Pair<TMid, T2>,
        coin_in: Coin<T0>,
        amount_out_min: u256,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        assert!(deadline >= tx_context::epoch_timestamp_ms(ctx), ERR_EXPIRED);
        let sender = tx_context::sender(ctx);

        // First hop: T0 (token0) -> TMid (token1)
        let amount_in = (coin::value(&coin_in) as u256);
        assert!(fixed_point_math::is_safe_value(amount_in), ERR_CALCULATION_OVERFLOW);
        
        let mid_amount_out = library::get_amounts_out(factory, amount_in, pair_first, true);
        
        let (mut coin0_mid, mut coin1_mid) = pair::swap(
            pair_first,
            option::some(coin_in),
            option::none(),
            0,
            mid_amount_out,
            ctx
        );
        
        assert!(option::is_some(&coin1_mid), ERR_INSUFFICIENT_LIQUIDITY);
        let mid_coin = option::extract(&mut coin1_mid);
        
        option::destroy_none(coin0_mid);
        option::destroy_none(coin1_mid);
        
        // Second hop: TMid (token0) -> T2 (token1)
        let mid_amount = (coin::value(&mid_coin) as u256);
        let final_amount_out = library::get_amounts_out(factory, mid_amount, pair_second, true);
        
        assert!(final_amount_out >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        
        let (mut coin0_final, mut coin1_final) = pair::swap(
            pair_second,
            option::some(mid_coin),
            option::none(),
            0,
            final_amount_out,
            ctx
        );
        
        assert!(option::is_some(&coin1_final), ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        let final_coin = option::extract(&mut coin1_final);
        
        option::destroy_none(coin0_final);
        option::destroy_none(coin1_final);
        
        transfer::public_transfer(final_coin, sender);
    }

    // ===== HANDLER 3: Input token is token1 in first pair, Output token is token0 in second pair =====
    // First hop: Input token (T1) -> Middle token (TMid)
    // Second hop: Middle token (TMid) -> Output token (T0)
    // First pair: Pair<TMid, T1>
    // Second pair: Pair<T0, TMid>
    public entry fun swap_exact_token1_to_mid_then_mid_to_token0<T0, TMid, T1>(
        _router: &Router,
        factory: &Factory,
        pair_first: &mut Pair<TMid, T1>,
        pair_second: &mut Pair<T0, TMid>,
        coin_in: Coin<T1>,
        amount_out_min: u256,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        assert!(deadline >= tx_context::epoch_timestamp_ms(ctx), ERR_EXPIRED);
        let sender = tx_context::sender(ctx);

        // First hop: T1 (token1) -> TMid (token0)
        let amount_in = (coin::value(&coin_in) as u256);
        assert!(fixed_point_math::is_safe_value(amount_in), ERR_CALCULATION_OVERFLOW);
        
        let mid_amount_out = library::get_amounts_out(factory, amount_in, pair_first, false);
        
        let (mut coin0_mid, mut coin1_mid) = pair::swap(
            pair_first,
            option::none(),
            option::some(coin_in),
            mid_amount_out,
            0,
            ctx
        );
        
        assert!(option::is_some(&coin0_mid), ERR_INSUFFICIENT_LIQUIDITY);
        let mid_coin = option::extract(&mut coin0_mid);
        
        option::destroy_none(coin0_mid);
        option::destroy_none(coin1_mid);
        
        // Second hop: TMid (token1) -> T0 (token0)
        let mid_amount = (coin::value(&mid_coin) as u256);
        let final_amount_out = library::get_amounts_out(factory, mid_amount, pair_second, false);
        
        assert!(final_amount_out >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        
        let (mut coin0_final, mut coin1_final) = pair::swap(
            pair_second,
            option::none(),
            option::some(mid_coin),
            final_amount_out,
            0,
            ctx
        );
        
        assert!(option::is_some(&coin0_final), ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        let final_coin = option::extract(&mut coin0_final);
        
        option::destroy_none(coin0_final);
        option::destroy_none(coin1_final);
        
        transfer::public_transfer(final_coin, sender);
    }

    // ===== HANDLER 4: Input token is token1 in first pair, Middle token is token0 in second pair =====
    // First hop: Input token (T1) -> Middle token (TMid)
    // Second hop: Middle token (TMid) -> Output token (T2)
    // First pair: Pair<TMid, T1>
    // Second pair: Pair<TMid, T2>
    public entry fun swap_exact_token1_to_mid_then_mid_to_token1<TMid, T1, T2>(
        _router: &Router,
        factory: &Factory,
        pair_first: &mut Pair<TMid, T1>,
        pair_second: &mut Pair<TMid, T2>,
        coin_in: Coin<T1>,
        amount_out_min: u256,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        assert!(deadline >= tx_context::epoch_timestamp_ms(ctx), ERR_EXPIRED);
        let sender = tx_context::sender(ctx);

        // First hop: T1 (token1) -> TMid (token0)
        let amount_in = (coin::value(&coin_in) as u256);
        assert!(fixed_point_math::is_safe_value(amount_in), ERR_CALCULATION_OVERFLOW);
        
        let mid_amount_out = library::get_amounts_out(factory, amount_in, pair_first, false);
        
        let (mut coin0_mid, mut coin1_mid) = pair::swap(
            pair_first,
            option::none(),
            option::some(coin_in),
            mid_amount_out,
            0,
            ctx
        );
        
        assert!(option::is_some(&coin0_mid), ERR_INSUFFICIENT_LIQUIDITY);
        let mid_coin = option::extract(&mut coin0_mid);
        
        option::destroy_none(coin0_mid);
        option::destroy_none(coin1_mid);
        
        // Second hop: TMid (token0) -> T2 (token1)
        let mid_amount = (coin::value(&mid_coin) as u256);
        let final_amount_out = library::get_amounts_out(factory, mid_amount, pair_second, true);
        
        assert!(final_amount_out >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        
        let (mut coin0_final, mut coin1_final) = pair::swap(
            pair_second,
            option::some(mid_coin),
            option::none(),
            0,
            final_amount_out,
            ctx
        );
        
        assert!(option::is_some(&coin1_final), ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        let final_coin = option::extract(&mut coin1_final);
        
        option::destroy_none(coin0_final);
        option::destroy_none(coin1_final);
        
        transfer::public_transfer(final_coin, sender);
    }

    public entry fun swap_exact_tokens1_for_tokens0<T0, T1>(
        _router: &Router,
        factory: &Factory,
        pair: &mut Pair<T0, T1>,
        coin_in: Coin<T1>,
        amount_out_min: u256,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        assert!(deadline >= tx_context::epoch_timestamp_ms(ctx), ERR_EXPIRED);
        exact_tokens1_swap(factory, pair, coin_in, amount_out_min, ctx);
    }

    public entry fun swap_tokens0_for_exact_tokens1<T0, T1>(
        _router: &Router,
        factory: &Factory,
        pair: &mut Pair<T0, T1>,
        coin_in: Coin<T0>,
        amount_out: u256,
        amount_in_max: u256,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        assert!(deadline >= tx_context::epoch_timestamp_ms(ctx), ERR_EXPIRED);
        exact_output_tokens0_swap(factory, pair, coin_in, amount_out, amount_in_max, ctx);
    }

    public entry fun swap_tokens1_for_exact_tokens0<T0, T1>(
        _router: &Router,
        factory: &Factory,
        pair: &mut Pair<T0, T1>,
        coin_in: Coin<T1>,
        amount_out: u256,
        amount_in_max: u256,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        assert!(deadline >= tx_context::epoch_timestamp_ms(ctx), ERR_EXPIRED);
        exact_output_tokens1_swap(factory, pair, coin_in, amount_out, amount_in_max, ctx);
    }

    // Quote and utility functions
    public fun quote_liquidity_amount<T0, T1>(
        factory: &Factory,
        pair: &Pair<T0, T1>,
        amount0_desired: u256,
        amount1_desired: u256
    ): u256 {
        let (reserve0, reserve1) = library::get_reserves(factory, pair);
        let supply = pair::total_supply(pair);
        
        if (reserve0 == 0 && reserve1 == 0) {
            let liquidity_fp = fixed_point_math::sqrt(
                fixed_point_math::mul(
                    fixed_point_math::new(amount0_desired),
                    fixed_point_math::new(amount1_desired)
                )
            );
            let initial_liquidity = fixed_point_math::get_raw_value(liquidity_fp);
            assert!(initial_liquidity > MINIMUM_LIQUIDITY, ERR_INSUFFICIENT_LIQUIDITY);
            initial_liquidity - MINIMUM_LIQUIDITY
        } else {
            let amount0_fp = fixed_point_math::div(
                fixed_point_math::mul(
                    fixed_point_math::new(amount0_desired),
                    fixed_point_math::new(supply)
                ),
                fixed_point_math::new(reserve0)
            );
            let amount1_fp = fixed_point_math::div(
                fixed_point_math::mul(
                    fixed_point_math::new(amount1_desired),
                    fixed_point_math::new(supply)
                ),
                fixed_point_math::new(reserve1)
            );
            
            min(
                fixed_point_math::get_raw_value(amount0_fp),
                fixed_point_math::get_raw_value(amount1_fp)
            )
        }
    }

    fun min(a: u256, b: u256): u256 {
        if (a < b) { a } else { b }
    }

    public fun get_reserves_ratio<T0, T1>(
        pair: &Pair<T0, T1>
    ): FixedPoint {
        let (reserve0, reserve1, _) = pair::get_reserves(pair);
        assert!(reserve1 != 0, ERR_INSUFFICIENT_LIQUIDITY);
        
        fixed_point_math::div(
            fixed_point_math::new(reserve0),
            fixed_point_math::new(reserve1)
        )
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    #[test_only]
    public fun create_for_testing(ctx: &mut TxContext): Router {
        Router {
            id: object::new(ctx)
        }
    }
}