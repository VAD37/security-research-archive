#[allow(unused_variable,unused_let_mut,unused_const,duplicate_alias,unused_use,lint(self_transfer),unused_field)]
module suitrump_dex::factory {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::table::{Self, Table};
    use std::string::String;
    use std::type_name::{Self, TypeName};
    use std::option::{Self, Option};
    use suitrump_dex::pair::{Self, Pair, AdminCap};
    use std::vector;
    use std::ascii;
    use suitrump_dex::fixed_point_math::{Self, FixedPoint};

    // Error codes
    const ERROR_IDENTICAL_TOKENS: u64 = 1;
    const ERROR_PAIR_EXISTS: u64 = 2;
    const ERROR_ZERO_ADDRESS: u64 = 3;
    const ERROR_NOT_ADMIN: u64 = 4;
    const ERROR_INVALID_FEE_SETTING: u64 = 5;
    const ERROR_CALCULATION_OVERFLOW: u64 = 6;

    // Fee constraints
    const MAX_PROTOCOL_FEE: u256 = 100; // 1% max protocol fee
    const PRECISION: u256 = 10000; // Fee precision (basis points)

    public struct TokenPair has store, copy, drop {
        token0: TypeName,
        token1: TypeName
    }

    public struct Factory has key {
        id: UID,
        admin: address,
        pairs: Table<TokenPair, address>,
        all_pairs: vector<address>,
        fee_to: address,
        fee_to_setter: address,
        team_1_address: address,     // 40% of team fee
        team_2_address: address,     // 50% of team fee
        dev_address: address,        // 10% of team fee
        locker_address: address,
        buyback_address: address,
        protocol_fee: u256
    }

    public struct PairCreated has copy, drop {
        token0: TypeName,
        token1: TypeName,
        pair: address,
        pair_len: u64
    }

    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let factory = Factory {
            id: object::new(ctx),
            admin: sender,
            pairs: table::new(ctx),
            all_pairs: vector::empty(),
            fee_to: @0x0,
            fee_to_setter: sender,
            team_1_address: @0x5cf81060260cd6285918d637463433758a89b23268f7da43fc08e3175041acf4, // 40%
            team_2_address: @0x11d00b1f0594da0aedc3dab291e619cea33e5cfcd3554738bfc1dd0375b65b56, // 50%
            dev_address: @0xc17889dee9255f80462972cd1218165c3a16e37d5242aa4c2070af4f46cebb01, // 10%
            locker_address: sender,
            buyback_address: sender,
            protocol_fee: 0
        };
        transfer::share_object(factory);
    }

    public fun sort_tokens<T0, T1>(): TokenPair {
        let token0 = type_name::get<T0>();
        let token1 = type_name::get<T1>();
        assert!(token0 != token1, ERROR_IDENTICAL_TOKENS);

        let str0 = ascii::into_bytes(type_name::into_string(token0));
        let str1 = ascii::into_bytes(type_name::into_string(token1));

        if (compare_bytes(&str0, &str1)) {
            TokenPair { token0, token1 }
        } else {
            TokenPair { token0: token1, token1: token0 }
        }
    }

    fun compare_bytes(a: &vector<u8>, b: &vector<u8>): bool {
        let len_a = vector::length(a);
        let len_b = vector::length(b);
        let min_len = if (len_a < len_b) len_a else len_b;
        let mut i = 0;

        while (i < min_len) {
            let byte_a = *vector::borrow(a, i);
            let byte_b = *vector::borrow(b, i);
            if (byte_a != byte_b) {
                return byte_a < byte_b
            };
            i = i + 1;
        };
        len_a < len_b
    }

    public(package) fun create_pair<T0, T1>(
        factory: &mut Factory,
        token0_name: String,
        token1_name: String,
        ctx: &mut TxContext
    ): address {
        let token0 = type_name::get<T0>();
        let token1 = type_name::get<T1>();
        assert!(token0 != token1, ERROR_IDENTICAL_TOKENS);

        let sorted_pair = sort_tokens<T0, T1>();
        assert!(!table::contains(&factory.pairs, sorted_pair), ERROR_PAIR_EXISTS);

        let pair = pair::new<T0, T1>(
            token0_name,
            token1_name,
            factory.team_1_address,
            factory.team_2_address,
            factory.dev_address,
            factory.locker_address,
            factory.buyback_address,
            ctx
        );

        let pair_addr = object::id_address(&pair);
        table::add(&mut factory.pairs, sorted_pair, pair_addr);
        vector::push_back(&mut factory.all_pairs, pair_addr);

        pair::share_pair(pair);

        event::emit(PairCreated {
            token0,
            token1,
            pair: pair_addr,
            pair_len: vector::length(&factory.all_pairs)
        });

        pair_addr
    }

    public fun all_pairs_length(factory: &Factory): u64 {
        vector::length(&factory.all_pairs)
    }

    public fun set_fee_to(
        factory: &mut Factory,
        new_fee_to: address,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == factory.fee_to_setter, ERROR_NOT_ADMIN);
        assert!(new_fee_to != @0x0, ERROR_ZERO_ADDRESS);
        factory.fee_to = new_fee_to;
    }

    public fun set_protocol_fee(
        factory: &mut Factory,
        new_fee: u256,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == factory.admin, ERROR_NOT_ADMIN);
        assert!(new_fee <= MAX_PROTOCOL_FEE, ERROR_INVALID_FEE_SETTING);
        assert!(fixed_point_math::is_safe_value(new_fee), ERROR_CALCULATION_OVERFLOW);
        
        factory.protocol_fee = new_fee;
    }

    public fun set_fee_to_setter(
        factory: &mut Factory,
        new_fee_to_setter: address,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == factory.fee_to_setter, ERROR_NOT_ADMIN);
        assert!(new_fee_to_setter != @0x0, ERROR_ZERO_ADDRESS);
        factory.fee_to_setter = new_fee_to_setter;
    }

    public fun set_addresses(
        factory: &mut Factory,
        team_1: address,
        team_2: address,
        dev: address,
        locker: address,
        buyback: address,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == factory.admin, ERROR_NOT_ADMIN);
        assert!(
            team_1 != @0x0 && team_2 != @0x0 && dev != @0x0 && 
            locker != @0x0 && buyback != @0x0, 
            ERROR_ZERO_ADDRESS
        );
        
        factory.team_1_address = team_1;
        factory.team_2_address = team_2;
        factory.dev_address = dev;
        factory.locker_address = locker;
        factory.buyback_address = buyback;
    }

    public fun get_team_addresses(factory: &Factory): (address, address, address, address, address) {
        (factory.team_1_address, factory.team_2_address, factory.dev_address, factory.locker_address, factory.buyback_address)
    }

    public fun get_pair<T0, T1>(factory: &Factory): Option<address> {
        let sorted_pair = sort_tokens<T0, T1>();
        if (table::contains(&factory.pairs, sorted_pair)) {
            option::some(*table::borrow(&factory.pairs, sorted_pair))
        } else {
            option::none()
        }
    }

    public fun get_protocol_fee(factory: &Factory): u256 {
        factory.protocol_fee
    }

    public fun is_token0<T>(token_pair: &TokenPair): bool {
        type_name::get<T>() == token_pair.token0
    }

    public fun get_all_pairs(factory: &Factory): &vector<address> {
        &factory.all_pairs
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}