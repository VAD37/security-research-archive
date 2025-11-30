#[allow(unused_variable,unused_let_mut,unused_const,duplicate_alias,unused_use,lint(self_transfer),unused_field)]
module suitrump_dex::library {
    use sui::coin::{Self, Coin};
    use sui::tx_context::TxContext;
    use sui::balance::{Self, Balance};
    use suitrump_dex::factory::{Self, Factory, TokenPair};
    use suitrump_dex::pair::{Self, Pair};
    use std::option::{Self, Option};
    use suitrump_dex::fixed_point_math::{Self, FixedPoint};

    // Error codes
    const ERR_INSUFFICIENT_AMOUNT: u64 = 201;
    const ERR_INSUFFICIENT_LIQUIDITY: u64 = 202;
    const ERR_INVALID_PATH: u64 = 203;
    const ERR_CALCULATION_OVERFLOW: u64 = 204;

    // Constants
    const BASIS_POINTS: u256 = 10000;
    const TOTAL_FEE: u256 = 30;     // 0.3%
    const LP_FEE: u256 = 18;        // 0.18%
    const TEAM_FEE: u256 = 6;       // 0.06%
    const LOCKER_FEE: u256 = 3;     // 0.03%
    const BUYBACK_FEE: u256 = 3;    // 0.03%

    // Fixed point precision constant
    const PRECISION: u256 = 1_000_000_000; // 1e9

    public fun quote(
        amount_in: u256,
        reserve_in: u256,
        reserve_out: u256
    ): u256 {
        assert!(amount_in > 0, ERR_INSUFFICIENT_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERR_INSUFFICIENT_LIQUIDITY);
        
        (amount_in * reserve_out) / reserve_in
    }

    public fun get_reserves<T0, T1>(
        factory: &Factory,
        pair: &Pair<T0, T1>
    ): (u256, u256) {
        let (reserve0, reserve1, _) = pair::get_reserves(pair);
        (reserve0, reserve1)
    }

    public fun get_amount_out(
        amount_in: u256,
        reserve_in: u256,
        reserve_out: u256
    ): u256 {
        assert!(amount_in > 0, ERR_INSUFFICIENT_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERR_INSUFFICIENT_LIQUIDITY);
        assert!(fixed_point_math::is_safe_value(amount_in), ERR_CALCULATION_OVERFLOW);
        assert!(fixed_point_math::is_safe_value(reserve_in), ERR_CALCULATION_OVERFLOW);
        assert!(fixed_point_math::is_safe_value(reserve_out), ERR_CALCULATION_OVERFLOW);

        let amount_in_with_fee = amount_in * (BASIS_POINTS - TOTAL_FEE);
        let numerator = amount_in_with_fee * reserve_out;
        let denominator = reserve_in * BASIS_POINTS;
        
        // Regular division since we already ensure minimum output via slippage
        numerator / denominator
    }

    public fun get_amount_in(
        amount_out: u256,
        reserve_in: u256,
        reserve_out: u256
    ): u256 {
        assert!(amount_out > 0, ERR_INSUFFICIENT_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERR_INSUFFICIENT_LIQUIDITY);
        assert!(amount_out < reserve_out, ERR_INSUFFICIENT_LIQUIDITY);
        assert!(fixed_point_math::is_safe_value(amount_out), ERR_CALCULATION_OVERFLOW);
        assert!(fixed_point_math::is_safe_value(reserve_in), ERR_CALCULATION_OVERFLOW);
        assert!(fixed_point_math::is_safe_value(reserve_out), ERR_CALCULATION_OVERFLOW);

        // Calculate with rounding down to ensure we don't overcharge
        let numerator = reserve_in * amount_out * BASIS_POINTS;
        let denominator = (reserve_out - amount_out) * (BASIS_POINTS - TOTAL_FEE);
        
        // Round down division and no extra +1
        numerator / denominator
    }

    public fun get_amounts_out<T0, T1>(
        factory: &Factory,
        amount_in: u256,
        pair: &Pair<T0, T1>,
        isToken0: bool
    ): u256 {
        let (reserve0, reserve1) = get_reserves(factory, pair);
        let (reserve_in, reserve_out) = if (isToken0) {
            (reserve0, reserve1) // token0 -> token1
        } else {
            (reserve1, reserve0) // token1 -> token0
        };
        get_amount_out(amount_in, reserve_in, reserve_out)
    }

    public fun get_amounts_in<T0, T1>(
        factory: &Factory,
        amount_out: u256,
        pair: &Pair<T0, T1>,
         isToken0: bool
    ): u256 {
        let (reserve0, reserve1) = get_reserves(factory, pair);
        let (reserve_in, reserve_out) = if ( isToken0) {
            (reserve1, reserve0) // token1 -> token0 (since we want input amount)
        } else {
            (reserve0, reserve1) // token0 -> token1 (since we want input amount)
        };
        get_amount_in(amount_out, reserve_in, reserve_out)
    }

    public struct FeeAmounts {
        team_fee: u256,
        locker_fee: u256,
        buyback_fee: u256,
        lp_fee: u256
    }

    public fun compute_fee_amounts(amount: u256): (u256, u256, u256, u256) {
        assert!(fixed_point_math::is_safe_value(amount), ERR_CALCULATION_OVERFLOW);

        // Calculate total fee amount first (0.3% = 30 bps)
        let total_fee_amount = (amount * TOTAL_FEE) / BASIS_POINTS;
        
        // Calculate individual fees as portions of total fee
        let team_fee = (total_fee_amount * TEAM_FEE) / TOTAL_FEE;
        let locker_fee = (total_fee_amount * LOCKER_FEE) / TOTAL_FEE;
        let buyback_fee = (total_fee_amount * BUYBACK_FEE) / TOTAL_FEE;
        
        // LP fee is the remainder
        let lp_fee = total_fee_amount - team_fee - locker_fee - buyback_fee;

        (team_fee, locker_fee, buyback_fee, lp_fee)
    }

    public fun get_fee_parameters(): (u256, u256, u256, u256, u256) {
        (TOTAL_FEE, LP_FEE, TEAM_FEE, LOCKER_FEE, BUYBACK_FEE)
    }
}