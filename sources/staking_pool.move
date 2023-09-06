// Meta Pool
// SPDX-License-Identifier: MIT

/// Example coin with a trusted manager responsible for minting/burning (e.g., a stablecoin)
/// By convention, modules defining custom coin types use upper case names, in contrast to
/// ordinary modules, which use camel case.
module meta_pool::staking_pool {
    use 0x3::sui_system::sui_system::{Self};

    use sui::table::Table;

    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Capability that grants an owner the right to collect profits.
    struct MetaPoolOwnerCap has key { id: UID }

    /// Name of the coin. By convention, this type has the same name as its parent module
    /// and has no fields. The full type of the coin defined by this module will be `COIN<MPSUI>`.
    struct MPSUI has drop {}

    /// Shared object that anybody can talk to. `key` ability is required.
    struct StakingPool has key {
        id: UID,
        price: u64,
        balance: Balance<SUI>
    }

    /// Register the managed currency to acquire its `TreasuryCap`. Because
    /// this is a module initializer, it ensures the currency only gets
    /// registered once.
    fun init(witness: MPSUI, ctx: &mut TxContext) {
        transfer::transfer(
            MetaPoolOwnerCap {id: object::new(ctx)},
            tx_context::sender(ctx)
        );

        // Share the object to make it accessible to everyone!
        transfer::share_object(
            StakingPool {
                id: object::new(ctx),
                price: 1000,
                balance: balance::zero()
            }
        );

        // Get a treasury cap for the coin and give it to the transaction sender
        let (treasury_cap, metadata) = coin::create_currency<MPSUI>(
            witness,
            2,
            b"mpSUI",
            b"Meta Pool Staked SUI",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    /// Entry function available to everyone who owns a Coin.
    /// function deposit(uint256 assets, address receiver) public virtual override returns (uint256)
    public entry fun deposit(
        pool: &mut StakingPool, assets: &mut Coin<SUI>, ctx: &mut TxContext
    ) {
        assert!(coin::value(payment) >= shop.price, ENotEnough);

        // Take amount = `shop.price` from Coin<SUI>
        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, shop.price);

        // Put the coin to the Shop's balance
        balance::join(&mut shop.balance, paid);

        transfer::transfer(Donut {
            id: object::new(ctx)
        }, tx_context::sender(ctx))
    }

    /// Consume donut and get nothing...
    public entry fun eat_donut(d: Donut) {
        let Donut { id } = d;
        object::delete(id);
    }

    /// Take coin from `DonutShop` and transfer it to tx sender.
    /// Requires authorization with `ShopOwnerCap`.
    public entry fun collect_profits(
        _: &ShopOwnerCap, shop: &mut DonutShop, ctx: &mut TxContext
    ) {
        let amount = balance::value(&shop.balance);
        let profits = coin::take(&mut shop.balance, amount, ctx);

        transfer::public_transfer(profits, tx_context::sender(ctx))
    }


    // public entry fun transfer(to, uint256 amount) public virtual override returns (bool)

    // /// Manager can mint new coins
    // public entry fun mint(
    //     treasury_cap: &mut TreasuryCap<MPSUI>, amount: u64, recipient: address, ctx: &mut TxContext
    // ) {
    //     coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    // }

    // /// Manager can burn coins
    // public entry fun burn(treasury_cap: &mut TreasuryCap<MPSUI>, coin: Coin<MPSUI>) {
    //     coin::burn(treasury_cap, coin);
    // }

    // #[test_only]
    // /// Wrapper of module initializer for testing
    // public fun test_init(ctx: &mut TxContext) {
    //     init(MPSUI {}, ctx)
    // }
}