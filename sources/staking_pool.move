// // Meta Pool
// // SPDX-License-Identifier: MIT

// /// Example coin with a trusted manager responsible for minting/burning (e.g., a stablecoin)
// /// By convention, modules defining custom coin types use upper case names, in contrast to
// /// ordinary modules, which use camel case.
// module meta_pool::staking_pool {

//     use sui::object::{Self, UID};
//     use sui::balance::{Self, Balance, Supply};
//     use sui::sui::SUI;


//     // use 0x3::sui_system::sui_system::{Self};
//     // use 0x3::sui_system::sui_system;

//     // use sui::table::Table;

//     use std::option;
//     use sui::coin::{Self, Coin, TreasuryCap};
//     use sui::transfer;
//     use sui::tx_context::{Self, TxContext};

//     const ENotEnoughBalance: u64 = 0;

//     /// Capability that grants an owner the right to collect profits.
//     struct MetaPoolOwnerCap has key { id: UID }

//     /// Name of the coin. By convention, this type has the same name as its parent module
//     /// and has no fields. The full type of the coin defined by this module will be `COIN<MPSUI>`.
//     struct MPSUI has drop {}

//     /// Shared object that anybody can talk to. `key` ability is required.
//     struct StakingPool has key {
//         id: UID,

//         /// capability allowing the reserve to mint and burn MPSUI Tokens.
//         // total_supply: Supply<MPSUI>,
//         treasury_cap: TreasuryCap<MPSUI>,

//         min_deposit_amount: u64,
//         balance: Balance<SUI>
//     }

//     /// Register the managed currency to acquire its `TreasuryCap`. Because
//     /// this is a module initializer, it ensures the currency only gets
//     /// registered once.
//     fun init(witness: MPSUI, ctx: &mut TxContext) {
//         transfer::transfer(
//             MetaPoolOwnerCap {id: object::new(ctx)},
//             tx_context::sender(ctx)
//         );

//         // Treasury cap contains the total_supply: https://github.com/sui-foundation/sui-move-intro-course/blob/main/unit-three/lessons/4_the_coin_resource_and_create_currency.md#the-create_currency-method
//         // Get a treasury cap for the coin and give it to the transaction sender
//         let (treasury_cap, metadata) = coin::create_currency<MPSUI>(
//             witness,
//             2,
//             b"mpSUI",
//             b"Meta Pool Staked SUI",
//             b"",
//             option::none(),
//             ctx
//         );
//         transfer::public_freeze_object(metadata);
//         transfer::public_transfer(treasury_cap, tx_context::sender(ctx));

//         // Share the object to make it accessible to everyone!
//         transfer::share_object(
//             StakingPool {
//                 id: object::new(ctx),
//                 treasury_cap: treasury_cap,
//                 min_deposit_amount: 1000,
//                 balance: balance::zero()
//             }
//         );
//     }

//     /// Entry function available to everyone who owns a Coin.
//     /// function deposit(uint256 assets, address receiver) public virtual override returns (uint256)
//     public entry fun deposit(
//         pool: &mut StakingPool,
//         assets: &mut Coin<SUI>,
//         ctx: &mut TxContext
//     ): Coin<MPSUI> {
//         assert!(coin::value(assets) >= pool.min_deposit_amount, ENotEnoughBalance);


//         coin::put(&mut pool.balance, assets);

//         let minted_balance = balance::increase_supply(
//             &mut pool.treasury_cap.total_supply,
//             num_sui
//         );

//         coin::from_balance(minted_balance, ctx)

//         // // Take amount = `shop.price` from Coin<SUI>
//         // let coin_balance = coin::balance_mut(payment);
//         // let paid = balance::split(coin_balance, shop.price);

//         // // Put the coin to the Shop's balance
//         // balance::join(&mut shop.balance, paid);

//         // transfer::transfer(Donut {
//         //     id: object::new(ctx)
//         // }, tx_context::sender(ctx))
//     }

//     /// Consume donut and get nothing...
//     public entry fun eat_donut(d: Donut) {
//         let Donut { id } = d;
//         object::delete(id);
//     }

//     /// Take coin from `DonutShop` and transfer it to tx sender.
//     /// Requires authorization with `ShopOwnerCap`.
//     public entry fun collect_profits(
//         _: &ShopOwnerCap, shop: &mut DonutShop, ctx: &mut TxContext
//     ) {
//         let amount = balance::value(&shop.balance);
//         let profits = coin::take(&mut shop.balance, amount, ctx);

//         transfer::public_transfer(profits, tx_context::sender(ctx))
//     }


//     // public entry fun transfer(to, uint256 amount) public virtual override returns (bool)

//     /// Manager can mint new coins
//     public entry fun mint(
//         treasury_cap: &mut TreasuryCap<MPSUI>, amount: u64, recipient: address, ctx: &mut TxContext
//     ) {
//         coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
//     }

//     // /// Manager can burn coins
//     // public entry fun burn(treasury_cap: &mut TreasuryCap<MPSUI>, coin: Coin<MPSUI>) {
//     //     coin::burn(treasury_cap, coin);
//     // }

//     // #[test_only]
//     // /// Wrapper of module initializer for testing
//     // public fun test_init(ctx: &mut TxContext) {
//     //     init(MPSUI {}, ctx)
//     // }
// }

// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A synthetic fungible token backed by a basket of other tokens.
/// Here, we use a basket that is 1:1 SUI and MANAGED,
/// but this approach would work for a basket with arbitrary assets/ratios.
/// E.g., [SDR](https://www.imf.org/en/About/Factsheets/Sheets/2016/08/01/14/51/Special-Drawing-Right-SDR)
/// could be implemented this way.
module meta_pool::mpsui {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance, Supply};
    use sui::object::{Self, UID};
    use sui::sui::SUI;
    use sui::transfer;
    // use sui::tx_context::TxContext;
    use sui::tx_context::{Self, TxContext};

    /// Name of the coin. By convention, this type has the same name as its parent module
    /// and has no fields. The full type of the coin defined by this module will be `COIN<MPSUI>`.
    struct MPSUI has drop { }

    /// Shared object that anybody can talk to. `key` ability is required.
    struct StakingPool has key {
        id: UID,
        /// capability allowing the pool to mint and burn MPSUI Tokens.
        total_supply: Supply<MPSUI>,
        min_deposit_amount: u64,
        sui: Balance<SUI>,
    }

    const ENotEnoughSui: u64 = 0;

    #[allow(unused_function)]
    fun init(witness: MPSUI, ctx: &mut TxContext) {
        // Get a treasury cap for the coin put it in the reserve
        let total_supply = balance::create_supply<MPSUI>(witness);

        transfer::share_object(StakingPool {
            id: object::new(ctx),
            total_supply,
            min_deposit_amount: 1000,
            sui: balance::zero<SUI>(),
        })
    }

    public entry fun deposit(
        pool: &mut StakingPool,
        assets: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let shares = internal_deposit(pool, assets, ctx);
        transfer::public_transfer(shares, tx_context::sender(ctx));
    }

    public entry fun redeem(
        pool: &mut StakingPool,
        shares: Coin<MPSUI>,
        ctx: &mut TxContext
    ) {
        let assets = internal_redeem(pool, shares, ctx);
        transfer::public_transfer(assets, tx_context::sender(ctx));
    }

    /// === Writes ===

    /// Entry function available to everyone who owns a Coin.
    /// function deposit(uint256 assets, address receiver) public virtual override returns (uint256)
    public fun internal_deposit(
        pool: &mut StakingPool,
        assets: Coin<SUI>,
        ctx: &mut TxContext
    ): Coin<MPSUI> {
        let num_assets: u64 = coin::value(&assets);
        assert!(num_assets >= pool.min_deposit_amount, ENotEnoughSui);

        coin::put(&mut pool.sui, assets);

        let minted_balance = balance::increase_supply(
            &mut pool.total_supply,
            num_assets
        );

        coin::from_balance(minted_balance, ctx)
    }

    // function redeem(uint256 _shares, address _receiver, address _owner) public override returns (uint256)
    /// Burn MPSUI coins and return the underlying reserve assets
    public fun internal_redeem(
        pool: &mut StakingPool,
        shares: Coin<MPSUI>,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let num_sui = balance::decrease_supply(
            &mut pool.total_supply,
            coin::into_balance(shares)
        );
        let sui = coin::take(
            &mut pool.sui,
            num_sui,
            ctx
        );

        sui
    }

    // === Reads ===

    /// Return the number of `MANAGED` coins in circulation
    public fun total_supply(pool: &StakingPool): u64 {
        balance::supply_value(&pool.total_supply)
    }

    /// Return the number of SUI in the reserve
    public fun sui_supply(pool: &StakingPool): u64 {
        balance::value(&pool.sui)
    }

    // /// Return the number of MANAGED in the reserve
    // public fun managed_supply(reserve: &Reserve): u64 {
    //     balance::value(&reserve.managed)
    // }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(MPSUI {}, ctx)
    }
}