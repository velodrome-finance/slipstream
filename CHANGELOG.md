# CHANGELOG

A list of high level changes made to the vanilla UniswapV3 Contracts to work with the Velodrome ecosystem. For more details, see `SPECIFICATION.md``

The core concentrated liquidity contracts have been taken from v3-core at commit [d8b1c63](https://github.com/Uniswap/v3-core/commit/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb). Core contracts can be found in `contracts/core`.
The periphery contracts have been taken from v3-periphery at commit [6cce88e](https://github.com/Uniswap/v3-periphery/commit/6cce88e63e176af1ddb6cc56e029110289622317). Periphery contracts can be found in `contracts/periphery`.
Gauge contracts can be found in `contracts/gauge`

Certain mock files (located in `contracts/core/test` or `contracts/core/periphery`) and test files have
been renamed or removed. 

## Core

### All Contracts
- NoDelegateCall was removed from all contracts.

### Factory (contracts/core/UniswapV3Factory.sol)

The Factory has been modified in the following ways:
- Pools are created by the factory using Clones (EIP-1167 Proxies). 
- The clones are created deterministically, using `tickSpacing` instead of `fee`. 
- Creating a pool automatically creates a gauge as the two are coupled.
- The factory supports a swap fee module that can be changed by the factory owner. This swap fee module allows 
fees to be dynamic. If there is no fee module, it uses the default fee for the given tick spacing.
- The factory supports an unstaked fee module that can be changed by the factory owner. This unstaked fee module 
allows fees to be levied on the fees earned by unstaked liquidity in the pool.
- Default tick spacings and fees were updated (see specification).

### Pool (contracts/core/UniswapV3Pool.sol)
- Pools are created using deterministic clones (EIP-1167 Proxies).
- Pools no longer have a fixed swap fee and dynamically fetch the swap fee from the swap fee module in the Factory.
- Pools track rewards in a manner similar to fees. These are synced whenever the gauge is notified of rewards.
- Pools track the number of seconds between swaps where there is no staked liquidity. This is used to by the gauge
to track emissions that are not unassigned to a depositor and thus can be recycled as emissions in the following epoch.
- Pools have a `stake` function, callable only by the gauge that allows the gauge to virtually assign liquidity
to either the `gauge` or `nft` depending on whether liquidity is being staked or unstaked respectively.
- Pools have an overloaded `burn` function that accepts an additional parameter `owner` (which will be 
either the `NonfungiblePositionManager` or the `gauge`). This function is callable only by the 
`NonfungiblePositionManager` and is used to update pool state for positions owned by the `nft` or the `gauge`. 
    - This function helps ensure that fees do not accrue to positions owned by the gauge.
- Pools have an overloaded `collect` function that accepts an additional parameter `owner` (which will be 
either the `NonfungiblePositionManager` or the `gauge`). This function is callable only by the 
`NonfungiblePositionManager` and is used to update pool state for positions owned by the `nft` or the `gauge`. 
    - This function helps ensure that fees do not accrue to positions owned by the gauge.
- Pools no longer have `ProtocolFees`. 
- Pools have a `collectFees` function which allows the gauge to bulk collect fees attributable to voters over the course of an epoch.
These fees accumulate every swap / flash based on % of liquidity in the current tick that is staked. 
    - These fees include fees levied on the swap fee earned by unstaked LPers.
    - These fees also include swap fees earned by staked LPers. 

### PoolDeployer (UniswapV3PoolDeployer.sol)
- Removed once fees were made dynamic.

### Fee Modules

#### Custom Swap Fee Module (contracts/fees/CustomSwapFeeModule.sol)
- A custom swap fee module implements the same logic for custom swap fees as is present in Velodrome V2. 
- This allows the factory owner to set the fee for specfic pools, allowing the pools to have a different swap fee from the default. 

#### Custom Unstaked Fee Module (contracts/fees/CustomSwapFeeModule.sol)
- A custom unstaked fee module implements a fee levied on liquidity positions that are not staked in the gauge. 
- This fee can be from 0 - 20%.
- The default custom unstaked fee is settable on the factory.

### Tests

Tests were modified to be consistent with the above, with newer tests using foundry instead of hardhat.

- The TestERC20 contract was renamed to CoreTestERC20 due to a collision with the TestERC20 contract in periphery.

## Periphery

### NonfungiblePositionManager (contracts/periphery/NonfungiblePositionManager.sol)
- Fetches pool addresses using `tickSpacing` instead of `fee`. 
- `increaseLiquidity()`, `decreaseLiquidity()` and `collect()` account for the case when the position is owned by a gauge. Under these circumstances, the fee accumulators are updated, but the underlying fees themselves (i.e. `tokensOwedX`) do not accumulate.
- `PoolInitializer` was removed. Pool creation and initialization will be handled separately.
- `tokenDescriptor` are mutable. This allows NFT artwork to be updated.

### Tests

Tests were modified to be consistent with the above, with newer tests using foundry instead of hardhat.
Places where artifacts were used from the uniswapv3 npm modules were replaced with artifacts built locally
in this repository.

## Gauge

### Concentrated Liquidity Gauge Factory
- Gauges are created atomically with pools (unlike v2).
- Gauges are created using deterministic clones (EIP-1167 Proxies).

### Concentrated Liquidity Gauge
- Support standard functions on a SNX staking gauge (e.g. `deposit`, `earned`, `withdraw`, `notifyRewardAmount` etc).
- Rewards accrue using `rewardGrowthInside` instead of a `rewardRate`. 
- Residual rewards (emissions not distributed due to no liquidity) are rolled over into the following epoch.
- Contains additional helper functions for improved UX (functions that allow staked position to be manipulated such as `increaseStakedLiquidity()`, `decreaseStakedLiquidity()`).
- Gauges contain a new function `notifyRewardWithoutClaim()` that allows for a permissioned user to add rewards
to a gauge. 
- Gauges contain accounting that can roll forward unallocated emissions from prior epochs. 