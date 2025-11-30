#[test_only]
module suitrump_dex::test_coins {
    use std::option;
    use sui::coin::{Self, TreasuryCap, CoinMetadata};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use sui::test_utils;

    public struct USDC has drop {}
    public struct USDT has drop {}  // Add this line
    public struct STK1 has drop {}  // Add this line
    public struct STK5 has drop {}  // Add this line
    public struct STK10 has drop {}  // Add this line




    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {}
}