// Meta Pool
// SPDX-License-Identifier: MIT

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
    public fun total_assets(pool: &StakingPool): u64 {
        balance::value(&pool.sui)
    }

    // public fun convert_to_shares(assets: u64): u64 {

    // }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(MPSUI {}, ctx)
    }
}