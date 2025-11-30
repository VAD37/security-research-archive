#[allow(unused_variable,unused_let_mut,unused_const,duplicate_alias,unused_use,lint(self_transfer),unused_field)]
module suitrump_dex::pair {
    use std::ascii;
    use std::string::{Self, String};
    use std::type_name::{Self, TypeName};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance, Supply};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use sui::event;
    use suitrump_dex::fixed_point_math::{Self, FixedPoint};

    // Constants
    const MAX_LIQUIDITY: u256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935 / 2; // Half of max u256
    const PRECISION: u256 = 1000000000000000000; // 1e18
    const MAX_SWAP_PERCENT: u256 = 45; // Maximum 45% of reserves can be swapped at once
    const MINIMUM_RESERVE_AFTER_SWAP: u256 = 1000000; // Minimum reserve that must remain after swap
    const MINIMUM_LIQUIDITY: u256 = 1000;
    const BASIS_POINTS: u256 = 10000;
    const TOTAL_FEE: u256 = 30; // 0.3%
    const LP_FEE: u256 = 15;    // 0.15%
    const TEAM_FEE: u256 = 6;   // 0.06%
    const LOCKER_FEE: u256 = 3; // 0.03%
    const BUYBACK_FEE: u256 = 3;// 0.03%
    const MAX_PRICE_IMPACT: u256 = 4500; // 45% maximum price impact (increased from 10%)
    const PRECISION_FACTOR: u256 = 10000; // For percentage calculations

    // Error codes
    const ERR_LOCKED: u64 = 101;
    const ERR_INSUFFICIENT_LIQUIDITY_MINTED: u64 = 102;
    const ERR_INSUFFICIENT_LIQUIDITY_BURNED: u64 = 103;
    const ERR_INSUFFICIENT_OUTPUT_AMOUNT: u64 = 104;
    const ERR_INSUFFICIENT_LIQUIDITY: u64 = 105;
    const ERR_INVALID_K: u64 = 106;
    const ERR_INSUFFICIENT_INPUT_AMOUNT: u64 = 107;
    const ERR_VALUE_TOO_HIGH: u64 = 108;
    const ERR_CALCULATION_OVERFLOW: u64 = 109;
    const ERR_EXCESSIVE_PRICE_IMPACT: u64 = 110;
    const ERR_INSUFFICIENT_FEE_AMOUNT: u64 = 111;

    public struct Fees has copy, drop {
        team_fee: u256,
        locker_fee: u256,
        buyback_fee: u256,
        remaining_amount: FixedPoint
    }

    public struct LPCoin<phantom T0, phantom T1> has drop {}

    public struct Pair<phantom T0, phantom T1> has key {
        id: UID,
        balance0: Balance<T0>,
        balance1: Balance<T1>,
        reserve0: u256,
        reserve1: u256,
        block_timestamp_last: u64,
        price0_cumulative_last: u256,
        price1_cumulative_last: u256,
        unlocked: bool,
        total_supply: u256,
        k_last: u256,
        team_1_address: address,    // 40%
        team_2_address: address,    // 50%
        dev_address: address,       // 10%
        locker_address: address,
        buyback_address: address,
        name: String,
        symbol: String,
        lp_supply: Supply<LPCoin<T0, T1>>
    }

    public struct AdminCap has key {
        id: UID
    }

    /// Event emitted when LP tokens are minted
    public struct LPMint<phantom T0, phantom T1> has copy, drop {
        sender: address,               // LP provider address
        lp_coin_id: ID,               // ID of the LP coin minted
        token0_type: TypeName,        // Type of token0
        token1_type: TypeName,        // Type of token1
        amount0: u256,                // Amount of token0 added
        amount1: u256,                // Amount of token1 added
        liquidity: u256,              // Amount of LP tokens minted
        total_supply: u256            // Total supply after mint
    }

    /// Event emitted when LP tokens are burned
    public struct LPBurn<phantom T0, phantom T1> has copy, drop {
        sender: address,               // LP provider address
        lp_coin_id: ID,               // ID of the LP coin burned
        token0_type: TypeName,        // Type of token0
        token1_type: TypeName,        // Type of token1
        amount0: u256,                // Amount of token0 removed
        amount1: u256,                // Amount of token1 removed
        liquidity: u256,              // Amount of LP tokens burned
        total_supply: u256            // Total supply after burn
    }

    public struct Swap<phantom T0, phantom T1> has copy, drop {
        sender: address,
        amount0_in: u256,
        amount1_in: u256,
        amount0_out: u256,
        amount1_out: u256
    }

    public struct Sync<phantom T0, phantom T1> has copy, drop {
        reserve0: u256,
        reserve1: u256
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    fun verify_k(balance0: u256, balance1: u256, new_balance0: u256, new_balance1: u256) {
        let k1 = fixed_point_math::get_raw_value(
            fixed_point_math::mul(
                fixed_point_math::new(balance0),
                fixed_point_math::new(balance1)
            )
        );
        let k2 = fixed_point_math::get_raw_value(
            fixed_point_math::mul(
                fixed_point_math::new(new_balance0),
                fixed_point_math::new(new_balance1)
            )
        );
        assert!(k1 >= k2, ERR_INVALID_K);
    }

    fun check_price_impact(amount_in: u256, reserve_in: u256) {
        // Calculate impact with higher precision
        let amount_fp = fixed_point_math::new(amount_in);
        let reserve_fp = fixed_point_math::new(reserve_in);
        
        let impact = fixed_point_math::get_raw_value(
            fixed_point_math::div(
                fixed_point_math::mul(
                    amount_fp,
                    fixed_point_math::new(PRECISION_FACTOR)
                ),
                reserve_fp
            )
        );

        assert!(impact <= MAX_PRICE_IMPACT, ERR_EXCESSIVE_PRICE_IMPACT);
    }

    fun calculate_fees(amount: u256): Fees {
        // Calculate fees using basis points directly first, then convert to fixed point
        let total_fee = (amount * TOTAL_FEE) / BASIS_POINTS;
        let team_fee = (total_fee * TEAM_FEE) / TOTAL_FEE;
        let locker_fee = (total_fee * LOCKER_FEE) / TOTAL_FEE;
        let buyback_fee = (total_fee * BUYBACK_FEE) / TOTAL_FEE;

        // Convert remaining amount to fixed point for K calculations
        let remaining_amount = fixed_point_math::new(
            amount - team_fee - locker_fee - buyback_fee
        );

        Fees {
            team_fee,
            locker_fee,
            buyback_fee,
            remaining_amount
        }
    }

    // In pair.move, modify the transfer_fees function:

    fun transfer_fees<T0, T1>(
        pair: &mut Pair<T0, T1>,
        is_token0: bool,
        fees: Fees,
        ctx: &mut TxContext
    ) {
        if (is_token0) {
            if (fees.team_fee > 0) {
                // Calculate individual team fee shares
                let team_1_fee = (fees.team_fee * 40) / 100;  // 40% of team fee
                let team_2_fee = (fees.team_fee * 50) / 100;  // 50% of team fee
                
                // Handle any rounding errors by calculating dev fee as the remainder
                let dev_fee = fees.team_fee - team_1_fee - team_2_fee;
                
                // Transfer to each address
                if (team_1_fee > 0) {
                    transfer::public_transfer(
                        coin::take(&mut pair.balance0, (team_1_fee as u64), ctx),
                        pair.team_1_address
                    );
                };
                
                if (team_2_fee > 0) {
                    transfer::public_transfer(
                        coin::take(&mut pair.balance0, (team_2_fee as u64), ctx),
                        pair.team_2_address
                    );
                };
                
                if (dev_fee > 0) {
                    transfer::public_transfer(
                        coin::take(&mut pair.balance0, (dev_fee as u64), ctx),
                        pair.dev_address
                    );
                };
            };
            
            // Rest of the fee transfers remain the same
            if (fees.locker_fee > 0) {
                transfer::public_transfer(
                    coin::take(&mut pair.balance0, (fees.locker_fee as u64), ctx),
                    pair.locker_address
                );
            };
            
            if (fees.buyback_fee > 0) {
                transfer::public_transfer(
                    coin::take(&mut pair.balance0, (fees.buyback_fee as u64), ctx),
                    pair.buyback_address
                );
            };
        } else {
            // Same logic for token1
            if (fees.team_fee > 0) {
                // Calculate individual team fee shares
                let team_1_fee = (fees.team_fee * 40) / 100;  // 40% of team fee
                let team_2_fee = (fees.team_fee * 50) / 100;  // 50% of team fee
                
                // Handle any rounding errors by calculating dev fee as the remainder
                let dev_fee = fees.team_fee - team_1_fee - team_2_fee;
                
                // Transfer to each address
                if (team_1_fee > 0) {
                    transfer::public_transfer(
                        coin::take(&mut pair.balance1, (team_1_fee as u64), ctx),
                        pair.team_1_address
                    );
                };
                
                if (team_2_fee > 0) {
                    transfer::public_transfer(
                        coin::take(&mut pair.balance1, (team_2_fee as u64), ctx),
                        pair.team_2_address
                    );
                };
                
                if (dev_fee > 0) {
                    transfer::public_transfer(
                        coin::take(&mut pair.balance1, (dev_fee as u64), ctx),
                        pair.dev_address
                    );
                };
            };
            
            // Rest of the fee transfers remain the same
            if (fees.locker_fee > 0) {
                transfer::public_transfer(
                    coin::take(&mut pair.balance1, (fees.locker_fee as u64), ctx),
                    pair.locker_address
                );
            };
            
            if (fees.buyback_fee > 0) {
                transfer::public_transfer(
                    coin::take(&mut pair.balance1, (fees.buyback_fee as u64), ctx),
                    pair.buyback_address
                );
            };
        }
    }

    fun update_price_accumulators<T0, T1>(pair: &mut Pair<T0, T1>, timestamp: u64) {
        if (pair.block_timestamp_last != 0) {
            let time_elapsed = fixed_point_math::new((timestamp - pair.block_timestamp_last as u256));
            let price0_fp = fixed_point_math::div(
                fixed_point_math::new(pair.reserve1),
                fixed_point_math::new(pair.reserve0)
            );
            let price1_fp = fixed_point_math::div(
                fixed_point_math::new(pair.reserve0),
                fixed_point_math::new(pair.reserve1)
            );
            
            pair.price0_cumulative_last = fixed_point_math::get_raw_value(
                fixed_point_math::add(
                    fixed_point_math::new(pair.price0_cumulative_last),
                    fixed_point_math::mul(price0_fp, time_elapsed)
                )
            );
            pair.price1_cumulative_last = fixed_point_math::get_raw_value(
                fixed_point_math::add(
                    fixed_point_math::new(pair.price1_cumulative_last),
                    fixed_point_math::mul(price1_fp, time_elapsed)
                )
            );
        }
    }

    fun min_amount(a: u256, b: u256): u256 {
        fixed_point_math::get_raw_value(
            fixed_point_math::min(
                fixed_point_math::new(a),
                fixed_point_math::new(b)
            )
        )
    }

    public(package) fun new<T0, T1>(
        token0_name: String,
        token1_name: String,
        team_1: address,
        team_2: address,
        dev: address,
        locker: address,
        buyback: address,
        ctx: &mut TxContext
    ): Pair<T0, T1> {
        let mut name = string::utf8(b"Suitrump V2 ");
        string::append(&mut name, token0_name);
        string::append_utf8(&mut name, b"/");
        string::append(&mut name, token1_name);

        Pair {
            id: object::new(ctx),
            balance0: balance::zero(),
            balance1: balance::zero(),
            reserve0: 0,
            reserve1: 0,
            block_timestamp_last: 0,
            price0_cumulative_last: 0,
            price1_cumulative_last: 0,
            unlocked: true,
            total_supply: 0,
            k_last: 0,
            team_1_address: team_1,
            team_2_address: team_2,
            dev_address: dev,
            locker_address: locker,
            buyback_address: buyback,
            name,
            symbol: string::utf8(b"SUIT-V2"),
            lp_supply: balance::create_supply<LPCoin<T0, T1>>(LPCoin<T0, T1> {})
        }
    }

    fun update<T0, T1>(
        pair: &mut Pair<T0, T1>,
        new_balance0: u256,
        new_balance1: u256,
        ctx: &TxContext
    ) {
        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        update_price_accumulators(pair, timestamp);

        pair.reserve0 = new_balance0;
        pair.reserve1 = new_balance1;
        pair.block_timestamp_last = timestamp;

        event::emit(Sync<T0, T1> {
            reserve0: new_balance0,
            reserve1: new_balance1
        });
    }

    public(package) fun mint<T0, T1>(
        pair: &mut Pair<T0, T1>,
        coin0: Coin<T0>,
        coin1: Coin<T1>,
        ctx: &mut TxContext
    ): Coin<LPCoin<T0, T1>> {
        assert!(pair.unlocked, ERR_LOCKED);

        let amount0_desired = (coin::value(&coin0) as u256);
        let amount1_desired = (coin::value(&coin1) as u256);

        assert!(fixed_point_math::is_safe_value(amount0_desired), ERR_VALUE_TOO_HIGH);
        assert!(fixed_point_math::is_safe_value(amount1_desired), ERR_VALUE_TOO_HIGH);

        balance::join(&mut pair.balance0, coin::into_balance(coin0));
        balance::join(&mut pair.balance1, coin::into_balance(coin1));

        let liquidity = if (pair.total_supply == 0) {
            let initial_fp = fixed_point_math::mul(
                fixed_point_math::new(amount0_desired),
                fixed_point_math::new(amount1_desired)
            );
            let initial = fixed_point_math::sqrt(initial_fp);
            let initial_value = fixed_point_math::get_raw_value(initial);
            assert!(initial_value > MINIMUM_LIQUIDITY, ERR_INSUFFICIENT_LIQUIDITY_MINTED);
            initial_value - MINIMUM_LIQUIDITY
        } else {
            let amount0_fp = fixed_point_math::new(amount0_desired);
            let amount1_fp = fixed_point_math::new(amount1_desired);
            let supply_fp = fixed_point_math::new(pair.total_supply);
            let reserve0_fp = fixed_point_math::new(pair.reserve0);
            let reserve1_fp = fixed_point_math::new(pair.reserve1);

            let liquidity0_fp = fixed_point_math::div(
                fixed_point_math::mul(amount0_fp, supply_fp),
                reserve0_fp
            );
            let liquidity1_fp = fixed_point_math::div(
                fixed_point_math::mul(amount1_fp, supply_fp),
                reserve1_fp
            );

            min_amount(
                fixed_point_math::get_raw_value(liquidity0_fp),
                fixed_point_math::get_raw_value(liquidity1_fp)
            )
        };

        assert!(liquidity > 0, ERR_INSUFFICIENT_LIQUIDITY_MINTED);
        assert!(liquidity <= MAX_LIQUIDITY, ERR_VALUE_TOO_HIGH);

        pair.total_supply = fixed_point_math::get_raw_value(
            fixed_point_math::add(
                fixed_point_math::new(pair.total_supply),
                fixed_point_math::new(liquidity)
            )
        );

        let new_balance0 = fixed_point_math::get_raw_value(
            fixed_point_math::add(
                fixed_point_math::new(pair.reserve0),
                fixed_point_math::new(amount0_desired)
            )
        );
        let new_balance1 = fixed_point_math::get_raw_value(
            fixed_point_math::add(
                fixed_point_math::new(pair.reserve1),
                fixed_point_math::new(amount1_desired)
            )
        );

        update(pair, new_balance0, new_balance1, ctx);

        let lp_coin = coin::from_balance(balance::increase_supply(&mut pair.lp_supply, (liquidity as u64)), ctx);
        let lp_coin_id = object::id(&lp_coin);

        event::emit(LPMint<T0, T1> {
            sender: tx_context::sender(ctx),
            lp_coin_id,
            token0_type: type_name::get<T0>(),
            token1_type: type_name::get<T1>(),
            amount0: amount0_desired,
            amount1: amount1_desired,
            liquidity,
            total_supply: pair.total_supply
        });

        lp_coin
    }

    public(package) fun burn<T0, T1>(
        pair: &mut Pair<T0, T1>,
        lp_token: Coin<LPCoin<T0, T1>>,
        ctx: &mut TxContext
    ): (Coin<T0>, Coin<T1>) {
        assert!(pair.unlocked, ERR_LOCKED);

        let liquidity = (coin::value(&lp_token) as u256);
        assert!(fixed_point_math::is_safe_value(liquidity), ERR_VALUE_TOO_HIGH);

        let lp_coin_id = object::id(&lp_token);

        let liquidity_fp = fixed_point_math::new(liquidity);
        let total_supply_fp = fixed_point_math::new(pair.total_supply);
        let reserve0_fp = fixed_point_math::new(pair.reserve0);
        let reserve1_fp = fixed_point_math::new(pair.reserve1);

        let amount0_fp = fixed_point_math::div(
            fixed_point_math::mul(liquidity_fp, reserve0_fp),
            total_supply_fp
        );
        let amount1_fp = fixed_point_math::div(
            fixed_point_math::mul(liquidity_fp, reserve1_fp),
            total_supply_fp
        );

        let amount0 = fixed_point_math::get_raw_value(amount0_fp);
        let amount1 = fixed_point_math::get_raw_value(amount1_fp);

        assert!(amount0 > 0 && amount1 > 0, ERR_INSUFFICIENT_LIQUIDITY_BURNED);

        balance::decrease_supply(&mut pair.lp_supply, coin::into_balance(lp_token));
        
        pair.total_supply = fixed_point_math::get_raw_value(
            fixed_point_math::sub(
                fixed_point_math::new(pair.total_supply),
                fixed_point_math::new(liquidity)
            )
        );

        let new_balance0 = fixed_point_math::get_raw_value(
            fixed_point_math::sub(
                fixed_point_math::new(pair.reserve0),
                amount0_fp
            )
        );
        let new_balance1 = fixed_point_math::get_raw_value(
            fixed_point_math::sub(
                fixed_point_math::new(pair.reserve1),
                amount1_fp
            )
        );

        update(pair, new_balance0, new_balance1, ctx);

        event::emit(LPBurn<T0, T1> {
            sender: tx_context::sender(ctx),
            lp_coin_id,
            token0_type: type_name::get<T0>(),
            token1_type: type_name::get<T1>(),
            amount0,
            amount1,
            liquidity,
            total_supply: pair.total_supply
        });

        (
            coin::take(&mut pair.balance0, (amount0 as u64), ctx),
            coin::take(&mut pair.balance1, (amount1 as u64), ctx)
        )
    }

    public(package) fun swap<T0, T1>(
        pair: &mut Pair<T0, T1>,
        mut coin0_in: Option<Coin<T0>>,
        mut coin1_in: Option<Coin<T1>>,
        amount0_out: u256,
        amount1_out: u256,
        ctx: &mut TxContext
    ): (Option<Coin<T0>>, Option<Coin<T1>>) {
        assert!(pair.unlocked, ERR_LOCKED);
        assert!(amount0_out > 0 || amount1_out > 0, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        assert!(amount0_out < pair.reserve0 && amount1_out < pair.reserve1, ERR_INSUFFICIENT_LIQUIDITY);

        let mut amount0_in = if (std::option::is_some(&coin0_in)) {
            let coin = std::option::extract(&mut coin0_in);
            let amount = (coin::value(&coin) as u256);
            assert!(fixed_point_math::is_safe_value(amount), ERR_VALUE_TOO_HIGH);
            balance::join(&mut pair.balance0, coin::into_balance(coin));
            amount
        } else {
            0
        };
        std::option::destroy_none(coin0_in);

        let mut amount1_in = if (std::option::is_some(&coin1_in)) {
            let coin = std::option::extract(&mut coin1_in);
            let amount = (coin::value(&coin) as u256);
            assert!(fixed_point_math::is_safe_value(amount), ERR_VALUE_TOO_HIGH);
            balance::join(&mut pair.balance1, coin::into_balance(coin));
            amount
        } else {
            0
        };
        std::option::destroy_none(coin1_in);

        // Check price impact
        if (amount0_in > 0) {
            check_price_impact(amount0_in, pair.reserve0);
        };
        if (amount1_in > 0) {
            check_price_impact(amount1_in, pair.reserve1);
        };

        // Calculate and apply fees using FixedPoint arithmetic
        if (amount0_in > 0) {
            let fees = calculate_fees(amount0_in);
            amount0_in = fixed_point_math::get_raw_value(fees.remaining_amount);
            transfer_fees(pair, true, fees, ctx);
        };

        if (amount1_in > 0) {
            let fees = calculate_fees(amount1_in);
            amount1_in = fixed_point_math::get_raw_value(fees.remaining_amount);
            transfer_fees(pair, false, fees, ctx);
        };

        let balance0_before = (balance::value(&pair.balance0) as u256);
        let balance1_before = (balance::value(&pair.balance1) as u256);

        let coin0_out = if (amount0_out > 0) {
            std::option::some(coin::take(&mut pair.balance0, (amount0_out as u64), ctx))
        } else {
            std::option::none()
        };

        let coin1_out = if (amount1_out > 0) {
            std::option::some(coin::take(&mut pair.balance1, (amount1_out as u64), ctx))
        } else {
            std::option::none()
        };

        let new_balance0 = (balance::value(&pair.balance0) as u256);
        let new_balance1 = (balance::value(&pair.balance1) as u256);

        verify_k(balance0_before, balance1_before, new_balance0, new_balance1);
        update(pair, new_balance0, new_balance1, ctx);

        event::emit(Swap<T0, T1> {
            sender: tx_context::sender(ctx),
            amount0_in,
            amount1_in,
            amount0_out,
            amount1_out
        });

        (coin0_out, coin1_out)
    }

    public fun sync<T0, T1>(pair: &mut Pair<T0, T1>, ctx: &TxContext) {
        let new_balance0 = (balance::value(&pair.balance0) as u256);
        let new_balance1 = (balance::value(&pair.balance1) as u256);
        update(pair, new_balance0, new_balance1, ctx);
    }

    // Utility functions
    public fun get_name<T0, T1>(pair: &Pair<T0, T1>): String {
        pair.name
    }

    public fun get_symbol<T0, T1>(pair: &Pair<T0, T1>): String {
        pair.symbol
    }

    public fun get_reserves<T0, T1>(pair: &Pair<T0, T1>): (u256, u256, u64) {
        (pair.reserve0, pair.reserve1, pair.block_timestamp_last)
    }

    public fun share_pair<T0, T1>(pair: Pair<T0, T1>) {
        transfer::share_object(pair)
    }

    public fun get_price_cumulative_last<T0, T1>(pair: &Pair<T0, T1>): (u256, u256) {
        (pair.price0_cumulative_last, pair.price1_cumulative_last)
    }

    public fun get_k_last<T0, T1>(pair: &Pair<T0, T1>): u256 {
        pair.k_last
    }

    public fun total_supply<T0, T1>(pair: &Pair<T0, T1>): u256 {
        pair.total_supply
    }

    public entry fun update_fee_addresses<T0, T1>(
        pair: &mut Pair<T0, T1>,
        team_1: address,
        team_2: address,
        dev: address,
        locker: address,
        buyback: address,
        _admin: &AdminCap
    ) {
        pair.team_1_address = team_1;
        pair.team_2_address = team_2;
        pair.dev_address = dev;
        pair.locker_address = locker;
        pair.buyback_address = buyback;
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}