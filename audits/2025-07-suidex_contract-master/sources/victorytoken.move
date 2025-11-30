#[allow(unused_variable,unused_let_mut,unused_const,duplicate_alias,unused_use,lint(self_transfer),unused_field)]
module suitrump_dex::victory_token {
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::transfer;
    use sui::event;
    use sui::object::{Self, UID};
    use std::string::{Self, String};
    use std::option;
    
    /// One-time witness for the Victory token
    public struct VICTORY_TOKEN has drop {}
    
    /// Capability that grants permission to mint new coins
    public struct MinterCap has key, store {
        id: UID
    }
    
    /// Wrapper that holds the TreasuryCap and can be shared
    public struct TreasuryCapWrapper has key {
        id: UID,
        cap: TreasuryCap<VICTORY_TOKEN>
    }
    
    /// Event emitted when VICTORY tokens are minted
    public struct VictoryMinted has copy, drop {
        amount: u256,
        recipient: address
    }
    
    /// Event emitted when VICTORY tokens are burned
    public struct VictoryBurned has copy, drop {
        amount: u256
    }
    
    /// Initialize the VICTORY token
    fun init(witness: VICTORY_TOKEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<VICTORY_TOKEN>(
            witness, 
            6, // 6 decimals
            b"VICTORY", 
            b"Victory Token", 
            b"Reward token for Suitrump Farm", 
            option::none(), 
            ctx
        );
        
        // Create a wrapper for the treasury cap and share it
        transfer::share_object(
            TreasuryCapWrapper {
                id: object::new(ctx),
                cap: treasury_cap
            }
        );
        
        // Make Metadata shared or frozen
        transfer::public_freeze_object(metadata);
        
        // Create and transfer MinterCap to sender
        transfer::transfer(
            MinterCap { id: object::new(ctx) },
            tx_context::sender(ctx)
        );
    }
    
    /// Mint new VICTORY tokens (admin only)
    public entry fun mint(
        wrapper: &mut TreasuryCapWrapper,
        amount: u64,
        recipient: address,
        _minter_cap: &MinterCap,
        ctx: &mut TxContext
    ) {
        let coins = coin::mint(&mut wrapper.cap, amount, ctx);
        transfer::public_transfer(coins, recipient);
        
        event::emit(VictoryMinted {
            amount: (amount as u256),
            recipient
        });
    }
    
    /// Mint tokens for farm (module-only function)
    public fun mint_for_farm(
        wrapper: &mut TreasuryCapWrapper,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coins = coin::mint(&mut wrapper.cap, amount, ctx);
        transfer::public_transfer(coins, recipient);
        
        event::emit(VictoryMinted {
            amount: (amount as u256),
            recipient
        });
    }
    
    /// Burn VICTORY tokens
    public entry fun burn(
        wrapper: &mut TreasuryCapWrapper,
        coin: Coin<VICTORY_TOKEN>
    ) {
        let amount = coin::value(&coin);
        coin::burn(&mut wrapper.cap, coin);
        
        event::emit(VictoryBurned {
            amount: (amount as u256)
        });
    }
    
    /// Transfer MinterCap to a new address
    public entry fun transfer_minter_cap(
        minter_cap: MinterCap,
        new_owner: address,
        _ctx: &TxContext
    ) {
        // Only the current owner can transfer (enforced by object ownership)
        transfer::transfer(minter_cap, new_owner);
    }
    
    /// Get metadata information
    public fun get_metadata_info(metadata: &CoinMetadata<VICTORY_TOKEN>): (String, String, String, u8) {
        (
            coin::get_name(metadata),
            std::string::utf8(std::ascii::into_bytes(coin::get_symbol(metadata))),
            coin::get_description(metadata),
            coin::get_decimals(metadata)
        )
    }

    #[test_only]
    /// Initialize VICTORY token for testing
    public fun init_for_testing(ctx: &mut TxContext) {
        init(VICTORY_TOKEN {}, ctx)
    }
}