# Velodrome Finance Concentrated Liquidity Specification

Concentrated liquidity pool and associated contracts adapted from UniswapV3's concentrate
liquidity implementation to work within the Velodrome ecosystem. 

The overarching goals of this implementation is to maximize incentive efficiency, while
ensuring liquidity providers are fairly compensated based on their contribution to the pool. 

The core concentrated liquidity contracts have been taken from v3-core at commit [d8b1c63](https://github.com/Uniswap/v3-core/commit/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb).
The periphery contracts have been taken from v3-periphery at commit [6cce88e](https://github.com/Uniswap/v3-periphery/commit/6cce88e63e176af1ddb6cc56e029110289622317).

## Definitions
- Liquidity providers (LPers) are users that deposit tokens into a pool in order to provide liquidity.
- Staking into a gauge refers to the act of transferring your pool position to the gauge. In doing so, the user relinquishes the ability to collect fees and instead collects emissions. 
    - Users that LP in the pool will be referred to as pool LPers.
    - Users that LP in the pool and then stake their position in the gauge will be referred to as gauge LPers.
- 1 unit of unbounded liquidity refers to liquidity applied over the entire range of the pool, i.e. similar to liquidity applied to a vanilla UniswapV2 pool.
- Active tick refers to the tick (as defined in UniswapV3) that the last swap took place in. 

## Features

Concentrated liquidity implementation identical to Uniswap V3's liquidity pools. A few additional
features have been included to provide better integration with Velodrome's ecosystem.

### Gauges

The concentrated liquidity pools that are created will be incentivizable like any other pool on Velodrome.
Gauge rewards are distributed over time and only in the active tick. Distributing over time is similar to V2
and encourages persistent liquidity. Incentivizing only the active tick means we maximize capital efficiency 
by only rewarding useful liquidity. 

Similar to existing pools and gauges, LPers can choose whether to collect fees or to collect emissions. 
By minting a position in the pool, LPers will earn fees. If they then choose to stake the nft that represents
their position in the gauge, they can earn emissions instead, with the fees that they would have earned being directed to the voters of the gauge. 

When an NFT is staked (`deposit`) into a gauge:
- Only callable by the owner of an NFT, while the gauge is alive.
- The NFT's fee accumulator will remain unchanged while it is in the gauge as it is not earning any fees.
- Any uncollected fees on the NFT will remain there.
- The NFT's reward accumulator is updated inside the gauge.

When an NFT is unstaked (`withdraw`) from a gauge:
- Only callable by the owner of an NFT.
- The NFT's fee accumulator remains unchanged.
- Any outstanding rewards owed to the position are distributed (equivalent to a call to `getReward`) and the reward accumulator is updated.
- Even when a gauge is killed, NFTs can be withdrawn at any time. The gauge will no longer receive emissions.

When emissions are claimed (`getReward`) from a gauge:
- Only callable by the owner of an NFT that is deposited in the gauge.
- The rewards owed to the position at that time are distributed. The reward accumulator is then updated.
- V2 gauges allow `getReward` to be called at any time even after the stake is withdrawn. This is not possible here.

The above has been achieved by taking advantage of several features of UniswapV3's design. Note that each pool has
a corresponding gauge. 
- On each swap, fees proportional to the amount that are owed to gauge LPers in the current active tick are accrued.
- The `collectProtocol` function is called (indirectly via `Voter.distribute()`) by the gauge once per epoch to fetch the aforementioned fees. 
    - These fees are passed onwards to `FeeVotingRewards`, just like in Velodrome V2. 
- We introduce a new accumulator reward growth global, which tracks the total reward for 1 unit of unbounded liquidity. Using math similar to the fee accumulators, we can calculate the share of rewards a given position is owed. 
- When a user deposits into a gauge, the reward growth accumulator is recorded. 
    - When a user withdraws / collects fees from the gauge, they are distributed their share of gauge rewards proportional to the amount of time their positions were in the active tick. 
- Gauge interactions must go through the `NFTPositionManager`. 

Technical details about gauges:
- Gauges are created atomically with a pool (i.e. on `factory.createPool` as opposed to `voter.createGauge`)

### Fee Modules

The UniswapV3Factory supports a fee module, with pools fetching the fees dynamically from this module. The 
factory will ship with a custom fee module that is identical to the fee module available for V2 pools. As newer 
fee research comes out, different mechanisms can be implemented to bring value to the Velodrome ecosystem.

### Unstaked Liquidity Fee Module

The UniswapV3Factory supports an unstaked liquidity fee module, with pools fetching the fee levied on unstaked
LPers dynamically from this module. The factory will ship with a custom fee module similar to that used for the 
pool fee module described above. 

### Oracle

The oracle has been modified to provide a consistent experience across chains with different block times. An observation will be written once every 15 seconds as opposed to once every block.