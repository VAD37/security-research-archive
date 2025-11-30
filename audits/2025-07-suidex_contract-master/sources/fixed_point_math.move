#[allow(unused_variable,unused_let_mut,unused_const,duplicate_alias,unused_use,lint(self_transfer),unused_field)]
module suitrump_dex::fixed_point_math {
    use std::{u128, u256};
    
    // Constants for precision and bounds
    const PRECISION: u256 = 1000000000000000000; // 1e18
    const MAX_U256: u256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935; // 2^256 - 1

    const MIN_VALUE: u256 = 0;
    const MAX_VALUE: u256 = MAX_U256 / PRECISION; // Maximum safe value
    
    // Error codes
    const E_OVERFLOW: u64 = 0;
    const E_DIVIDE_BY_ZERO: u64 = 1;
    const E_INVALID_CONVERSION: u64 = 2;
    const E_INVALID_DECIMALS : u64 = 3;
    public struct FixedPoint has store, copy, drop {
        value: u256
    }

    // === Core Functions ===
    
    public fun new(value: u256): FixedPoint {
        FixedPoint { value }
    }

    public fun from_raw(value: u256, decimals: u8): FixedPoint {
        let scaled_value = scale_to_precision(value, decimals);
        FixedPoint { value: scaled_value }
    }

    public fun get_raw_value(fp: FixedPoint): u256 {
        fp.value
    }

    // === Arithmetic Operations ===

    public fun add(a: FixedPoint, b: FixedPoint): FixedPoint {
        let sum = a.value + b.value;
        assert!(sum >= a.value, E_OVERFLOW);
        assert!(sum <= MAX_U256, E_OVERFLOW);
        FixedPoint { value: sum }
    }

    public fun sub(a: FixedPoint, b: FixedPoint): FixedPoint {
        assert!(a.value >= b.value, E_OVERFLOW);
        FixedPoint { value: a.value - b.value }
    }

    fun sqrt_internal(y: u256): u256 {
        if (y < 4) {
            if (y == 0) { 0 } else { 1 }
        } else {
            let mut z = y;
            let mut x = y;
            
            // First iteration outside loop to handle very large numbers
            z = x;
            x = ((y / x) + x) >> 1;

            while (x < z) {
                z = x;
                // Use right shift by 1 instead of division by 2
                // This is safer for large numbers
                x = ((y / x) + x) >> 1;
                
                // Add safety check to prevent infinite loop
                if (z - x <= 1) {
                    x = z;
                };
            };
            z
        }
    }

    public fun mul(a: FixedPoint, b: FixedPoint): FixedPoint {
        let a_val = a.value;
        let b_val = b.value;
        
        // Extract high and low parts of the numbers
        let a_high = a_val >> 128;
        let a_low = a_val & ((1u256 << 128) - 1);
        let b_high = b_val >> 128;
        let b_low = b_val & ((1u256 << 128) - 1);
        
        // Calculate partial products
        assert!(a_high == 0 || b_high == 0, E_OVERFLOW); // Ensure at least one high part is 0
        let mut result = (a_low * b_low) / PRECISION;
        
        // Add high parts if they exist
        if (a_high > 0) {
            result = result + ((a_high * b_low) << (128 - 64)) / PRECISION;
        };
        if (b_high > 0) {
            result = result + ((a_low * b_high) << (128 - 64)) / PRECISION;
        };
        
        assert!(result <= MAX_U256, E_OVERFLOW);
        FixedPoint { value: result }
    }

    public fun div(a: FixedPoint, b: FixedPoint): FixedPoint {
        assert!(b.value != 0, E_DIVIDE_BY_ZERO);
        
        let a_val = a.value;
        let b_val = b.value;
        
        // Split the dividend into high and low parts
        let a_high = a_val >> 128;
        let a_low = a_val & ((1u256 << 128) - 1);
        
        // First handle the high part if it exists
        let mut result = 0u256;
        if (a_high > 0) {
            result = (a_high << 128) / b_val;
        };
        
        // Then add the low part
        // We multiply by PRECISION first to maintain fixed-point precision
        let low_result = (a_low * PRECISION) / b_val;
        
        // Combine results
        result = (result * PRECISION + low_result);
        
        assert!(result <= MAX_U256, E_OVERFLOW);
        FixedPoint { value: result }
    }

    // === Advanced Math Operations ===

    public fun sqrt(x: FixedPoint): FixedPoint {
        if (x.value == 0) {
            return FixedPoint { value: 0 }
        };

        // Since x is already in fixed point (has 18 decimals)
        // And we want the sqrt to also be in fixed point (18 decimals)
        // We need to multiply by PRECISION before sqrt to compensate
        let value = x.value * PRECISION;
        
        let mut z = (value + PRECISION) >> 1;
        let mut y = value;
        
        while (z < y) {
            y = z;
            z = (value / z + z) >> 1;
            
            // Safer check with absolute difference
            if (if (y > z) { y - z } else { z - y } <= 1) {
                break
            };
        };

        FixedPoint { value: y }
    }

    // Add helper function
    fun abs_difference(a: u256, b: u256): u256 {
        if (a > b) { a - b } else { b - a }
    }

    public fun min(a: FixedPoint, b: FixedPoint): FixedPoint {
        if (a.value < b.value) { a } else { b }
    }

    public fun max(a: FixedPoint, b: FixedPoint): FixedPoint {
        if (a.value > b.value) { a } else { b }
    }

    // === Utility Functions ===

    fun scale_to_precision(value: u256, decimals: u8): u256 {
        assert!(decimals <= 77, E_INVALID_DECIMALS); // Add max decimal check

        if (decimals == 18) return value;
        
        if (decimals < 18) {
            // Scale up
            let scale_factor = u256::pow(10u256, ((18 - decimals) as u8));
            let result = value * scale_factor;
            assert!(result <= MAX_U256, E_OVERFLOW);
            result
        } else {
            // Scale down
            let scale_factor = u256::pow(10u256, ((decimals - 18) as u8));
            value / scale_factor
        }
    }

    public fun compare(a: FixedPoint, b: FixedPoint): u8 {
        if (a.value < b.value) return 0;
        if (a.value > b.value) return 2;
        1
    }

    public fun is_zero(fp: FixedPoint): bool {
        fp.value == 0
    }

    public fun is_safe_value(value: u256): bool {
        value >= MIN_VALUE && value <= MAX_VALUE
    }

    // === Small number multiplication ===
    public fun mul_small(a: FixedPoint, b: u64): FixedPoint {
        let b_256 = (b as u256);
        let result = a.value * b_256;
        assert!(result <= MAX_U256, E_OVERFLOW);
        FixedPoint { value: result }
    }
}