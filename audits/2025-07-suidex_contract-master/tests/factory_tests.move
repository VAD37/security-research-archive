#[test_only]
module suitrump_dex::factory_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use std::string::utf8;
    use std::option;
    use sui::test_utils::assert_eq;
    use suitrump_dex::factory::{Self, Factory};
    use suitrump_dex::pair::{Self, AdminCap};
    use suitrump_dex::test_coins::{Self, USDC};

    const ADMIN: address = @0x1;
    const USER: address = @0x2;
    const TEAM: address = @0x44;
    const LOCKER: address = @0x45;
    const BUYBACK: address = @0x46;

    // Add constants for large number testing
    const BILLION: u128 = 1_000_000_000;
    const TRILLION: u128 = 1_000_000_000_000;

    fun setup(scenario: &mut Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            factory::init_for_testing(ts::ctx(scenario));
            pair::init_for_testing(ts::ctx(scenario));
        };
    }

    #[test]
    fun test_create_pair() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            let pair_addr = factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            let mut existing_pair = factory::get_pair<sui::sui::SUI, USDC>(&factory);
            assert!(option::is_some(&existing_pair), 1);
            assert!(option::extract(&mut existing_pair) == pair_addr, 2);
            assert_eq(factory::all_pairs_length(&factory), 1);

            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_pair_name_and_symbol() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            ts::next_tx(&mut scenario, ADMIN);
            {
                let pair = ts::take_shared<pair::Pair<sui::sui::SUI, USDC>>(&scenario);
                assert_eq(pair::get_name(&pair), utf8(b"Suitrump V2 SUI/USDC"));
                assert_eq(pair::get_symbol(&pair), utf8(b"SUIT-V2"));
                ts::return_shared(pair);
            };

            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_get_pair() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            let pair_addr = factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            // Forward lookup
            let mut existing_pair = factory::get_pair<sui::sui::SUI, USDC>(&factory);
            assert!(option::is_some(&existing_pair), 1);
            assert!(option::extract(&mut existing_pair) == pair_addr, 2);

            // Reverse lookup
            let mut reverse_pair = factory::get_pair<USDC, sui::sui::SUI>(&factory);
            assert!(option::is_some(&reverse_pair), 3);
            assert!(option::extract(&mut reverse_pair) == pair_addr, 4);

            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_create_identical_tokens() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            factory::create_pair<USDC, USDC>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_create_existing_pair() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            // Create first pair
            factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            // Attempt to create same pair again
            factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_pair_uniqueness_different_order() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            // Create first pair: SUI/USDC
            factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            // Attempt to create pair in reverse order: USDC/SUI
            factory::create_pair<USDC, sui::sui::SUI>(
                &mut factory,
                utf8(b"USDC"),
                utf8(b"SUI"),
                ts::ctx(&mut scenario)
            );

            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_multiple_pairs() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut factory = ts::take_shared<Factory>(&scenario);
            let cap = ts::take_from_sender<AdminCap>(&scenario);

            // Create first pair
            let pair1_addr = factory::create_pair<sui::sui::SUI, USDC>(
                &mut factory,
                utf8(b"SUI"),
                utf8(b"USDC"),
                ts::ctx(&mut scenario)
            );

            // Verify first pair
            let mut existing_pair = factory::get_pair<sui::sui::SUI, USDC>(&factory);
            assert!(option::extract(&mut existing_pair) == pair1_addr, 1);
            assert_eq(factory::all_pairs_length(&factory), 1);

            ts::return_shared(factory);
            ts::return_to_sender(&scenario, cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_fee_setter() {
        let mut scenario = ts::begin(ADMIN);
        setup(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut factory = ts::take_shared<Factory>(&scenario);
            
            // Set new fee address
            factory::set_fee_to(&mut factory, USER, ts::ctx(&mut scenario));
            
            ts::return_shared(factory);
        };

        ts::end(scenario);
    }
}