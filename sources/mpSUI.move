// Meta Pool
// SPDX-License-Identifier: MIT

// Reference:
// https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-framework/sources/coin.move#L251

module meta_pool::mpsui {
    use std::option;

    use sui::coin::{Self, Coin, TreasuryCap};
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
        // total_supply: Supply<MPSUI>,
        treasury: TreasuryCap<MPSUI>,
        min_deposit_amount: u64,
        sui: Balance<SUI>,
    }

    const ENotEnoughSui: u64 = 0;

    #[allow(unused_function)]
    fun init(witness: MPSUI, ctx: &mut TxContext) {
        // Get a treasury cap for the coin put it in the reserve
        // let total_supply = balance::create_supply<MPSUI>(witness);

        let (treasury, metadata) = coin::create_currency(
            witness,
            9,
            b"mpSUI",
            b"Meta Pool Staked SUI",
            b"",
            option::none(),
            ctx
        );

        transfer::share_object(StakingPool {
            id: object::new(ctx),
            treasury,
            min_deposit_amount: 1000,
            sui: balance::zero<SUI>(),
        });

        transfer::public_freeze_object(metadata);
        // transfer::public_transfer(treasury, tx_context::sender(ctx));
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
            coin::supply_mut(&mut pool.treasury),
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
            coin::supply_mut(&mut pool.treasury),
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

    /// Return the number of `mpSUI` coins in circulation
    public fun total_supply(pool: &StakingPool): u64 {
        coin::total_supply(&pool.treasury)
    }

    /// Return the number of SUI in the reserve
    public fun total_assets(pool: &StakingPool): u64 {
        balance::value(&pool.sui)
    }

    public fun convert_to_shares(pool: &StakingPool, assets: u64): u64 {
        internal_convert_to_shares(pool, assets, false)
    }
    
    fun proportional(value: u64, multiplier: u64, divisor: u64, round_up: bool): u64 {
        let product = value * multiplier;
        let quotient = product / divisor;
        
        if (round_up && product % divisor > 0) {
            quotient + 1
        } else {
            quotient
        }
    }

    fun internal_convert_to_shares(pool: &StakingPool, assets: u64, round_up: bool): u64 {
        // uint256 supply = totalSupply();
        // return
        //     (assets == 0 || supply == 0)
        //         ? _initialConvertToShares(assets, rounding)
        //         : assets.mulDiv(supply, totalAssets(), rounding);
        let total_supply = total_supply(pool);
        if (assets == 0 || total_supply == 0) {
            assets
        } else {
            proportional(assets, total_supply, total_assets(pool), round_up)
        }
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(MPSUI {}, ctx)
    }
}