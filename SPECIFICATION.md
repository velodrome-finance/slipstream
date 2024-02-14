# Slipstream Specification

Concentrated liquidity pool and associated contracts adapted from UniswapV3's concentrated
liquidity implementation to work within the Velodrome ecosystem. 

The overarching goals of this implementation is to maximize incentive efficiency, while
ensuring liquidity providers are fairly compensated based on their contribution to the pool. 

The core concentrated liquidity contracts have been taken from v3-core at commit [d8b1c63](https://github.com/Uniswap/v3-core/commit/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb).
The periphery contracts have been taken from v3-periphery at commit [6cce88e](https://github.com/Uniswap/v3-periphery/commit/6cce88e63e176af1ddb6cc56e029110289622317).

Although the contracts have been renamed, we have preserved the UniswapV3 interface (including callbacks)
to make integration with the pools easier. 

## Definitions
- Liquidity providers (LPers) are users that deposit tokens into a pool in order to provide liquidity.
- Staking into a gauge refers to the act of transferring your pool position to the gauge. In doing so, 
the user relinquishes the ability to collect fees and instead collects emissions. 
    - Users that LP in the pool will be referred to as pool LPers.
    - Users that LP in the pool and then stake their position in the gauge will be referred to as gauge LPers.
- 1 unit of unbounded liquidity refers to liquidity applied over the entire range of the pool, i.e. similar to
the liquidity applied to a vanilla UniswapV2 pool.
- Active tick refers to the tick (as defined in UniswapV3) that the last swap took place in. 
- Gauge will always refer to a concentrated liquidity gauge unless otherwise mentioned.
- Position manager will always refer to the UniswapV3 `NonfungiblePositionManager` (the contract that allows a user to create UniswapV3 positions represented as nfts).
- Emissions and rewards can be used interchangeably. 

## Features

Concentrated liquidity implementation identical to Uniswap V3's liquidity pools. A few additional
features have been included to provide better integration with Velodrome's ecosystem.

The implementation takes advantage of a few key features of UniswapV3's concentrated liquidity implementation.
- Staked liquidity is accounted for on a per-tick basis, similar to `liquidity`, allowing fees to be accumulated for the gauge to collect.
- Staked liquidity is assigned virtually to the corresponding gauge, allowing fees on both staked and unstaked positions created by the position manager to be tracked separately.
- The position manager is used to manage both staked and unstaked positions, allowing fee accrual in both the position manager and the pool to be in sync.
- Emissions (rewards) accumulate (as `rewardGrowthGlobal`) for a given position in a manner that is similar to how UniswapV3's existing fee system accumulates. 
- On each swap, fees proportional to the amount that are owed to gauge LPers in the current active tick are accrued.
- The `collectProtocol` function is called (indirectly via `Voter.distribute()`) by the gauge once per epoch to fetch the aforementioned fees. 
    - These fees are passed onwards to `FeeVotingRewards`, just like in Velodrome V2.  

## Daily Operations

Users will deposit liquidity into a CL pool (either directly or via the `NonfungiblePositionManager`).
As swaps take place over the course of the epoch, fees owed to staked LPers accumulate and fees owed to unstaked LPers
can be collected (net of the unstaked LP fee). At the beginning of the following epoch, emissions are deposited
into the gauge based on the voting weight attracted by the gauge, with fees earned by staked LPers + unstaked LP fees
being transferred to the fee reward contract associated with the gauge. Staked LPers will then be able to collect
rewards earned by supplying liquidity to the pool.

### Pool
The pools are standard UniswapV3Pools that have been modified to support gauges. The pools 
ship with the following tick spacings, with support for additional tick spacings available. 
Note that fees are not particularly important as they can be modified with the custom swap fee modules.

Pools are created alongside gauges, and come initialized with a price. Pools cannot exist in an uninitialized state.

The tick spacing / fee combinations are listed as follows:
- ts: 1 | fee: 1 bps
- ts: 50 | fee: 5 bps
- ts: 100 | fee: 5 bps
- ts: 200 | fee: 30 bps
- ts: 2000 | fee: 100 bps

### Gauges

The concentrated liquidity pools that are created will be incentivizable like any other pool in the Velodrome ecosystem.
Gauge rewards are distributed over time and only in the active tick. Distributing over time is similar to V2
and encourages persistent liquidity. Incentivizing only the active tick means we maximize capital efficiency 
by only rewarding useful liquidity. 

Similar to existing pools and gauges, LPers can choose whether to collect fees or to collect emissions. 
By minting a position in the pool, LPers will earn fees. If they then choose to stake the nft (that represents
their position) in the gauge, they can earn emissions instead, with the fees that they would have earned being 
directed to the voters of the gauge. Only positions created by the position manager can be staked in the pool.

When an NFT is staked (`deposit`) into a gauge:
- Only callable by the owner of the NFT, while the gauge is alive.
- Pool state will update to reflect the newly added staked liquidity.
- Pool state will update to transfer the liquidity from the position manager to the gauge, to ensure fees on staked and unstaked positions can be tracked separately. 
- The NFT's fee acumulator in the position manager will update, with any existing fees collected and sent to the depositor. The NFT will not accumulate fees while staked.
- The NFT's reward accumulator is updated inside the gauge.

When an NFT is unstaked (`withdraw`) from a gauge:
- Only callable by the owner of the NFT.
- Pool state will update to reflect the newly removed staked liquidity.
- Pool state will update to transfer the liquidity from the gauge to the position manager, to ensure fees on staked and unstaked positions can be tracked separately. 
- The NFT's fee acumulator in the position manager will update, but the amount of fees owed to the nft will remain zero, as the nft will not accumulate fees while staked. 
- Any outstanding rewards owed to the position are distributed (equivalent to a call to `getReward`) and the reward accumulator is updated.
    - This will update the NFT's reward accumulator.
- Even when a gauge is killed, NFTs can be withdrawn at any time. The gauge will no longer receive emissions.

When emissions are claimed (`getReward`) from a gauge:
- Only callable by the owner of an NFT that is staked in the gauge.
- The rewards owed to the position at that time are distributed. The reward accumulator is then updated.
- The rewards owed to a user depend on the amount of rewards accumulated while their position was in the active tick, as well as the total amount of liquidity (both staked and unstaked) supplied in the active tick.
- V2 gauges allow `getReward` to be called at any time even after the stake is withdrawn. This is not possible here as all rewards are collected on withdrawal.

The gauge also ships with two helper functions that allow liquidity management of staked positions.
Increase staked liquidity (`increaseStakedLiquidity`):
- Callable by anyone (mimics `nft.increaseLiquidity()` permissions).
- Requires permissions to transfer the tokens. Residual tokens refunded. 
- Increases the liquidity supplied to a position staked in the gauge. 

Decrease staked liquidity (`decreaseStakedLiquidity`):
- Callable by the owner of an NFT that is staked in the gauge.
- Decreases liquidity supplied to a position and collects the tokens. This is equivalent to a `nft.decreaseLiquidity()` and `nft.collect()` call.
- It is possible to collect the entire position in this way.

It is possible for a permissioned user to add rewards to a gauge (`notifyRewardAmountWithoutClaim`):
- This adds rewards only (i.e. fees are not collected). 
- The amount notified is added to existing rewards that are being distributed.

As concentrated liquidity is limited to certain tick ranges, it is possible for rewards to get stuck if the active tick is moved into a tick range with no staked liquidity. These rewards are rolled forward by the gauge based on the following rules:
- Rewards roll based on the amount of seconds that the pool spent in a tick range with no active liquidity. 
- Rewards roll on the next call to a notify function. If neither notify function is called within a given epoch, then the rewards remain stuck until the next time it is called.
- This does not address rewards stuck in the gauge from rounding errors.

Other:
- Gauges are created atomically with a pool (i.e. on `factory.createPool` as opposed to `voter.createGauge`).
- Gauges are created using deterministic clones in a manner similar to pools.

### Swap Fee Module

The UniswapV3Factory supports a swap fee module, with pools fetching the swap fee dynamically from this module. The 
factory will ship with a custom fee module that is identical to the fee module available for V2 pools. As newer 
fee research comes out, different mechanisms can be implemented to bring value to the Velodrome ecosystem.

The default custom swap fee module has a maximum fee of 3%. Swap fees are set using pips instead of bips. This is 
consistent with UniswapV3 but not consistent with Velodrome's existing fee mechanisms.

### Unstaked Liquidity Fee Module

The UniswapV3Factory supports an unstaked liquidity fee module, with pools fetching the fee levied on unstaked
LPers dynamically from this module. The factory will ship with a custom fee module similar to that used for the 
pool fee module described above. 

The custom unstaked liquidity fee module will have a default fee of 10% and a maximum fee of 50%. Fees are set 
using pips instead of bips. This is consistent with UniswapV3 but not consistent with Velodrome's existing fee mechanisms.
The default fee will be settable.

### Oracle

The oracle has been modified to provide a consistent experience across chains with different block times. Observations
can only be written at most once every 15 seconds. When the observation timestamp overflows, a new observation will be
written regardless of the time that has passed (i.e. may be written before 15 seconds has passed).

### UniversalRouter

UniswapV3's universal router will be modified to support the current V3 implementation as well as the VelodromeV2 router. 
Only volatile pools will be supported on VelodromeV2 pools.