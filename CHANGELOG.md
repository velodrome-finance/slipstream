# CHANGELOG

A list of changes made to the vanilla UniswapV3 Contracts to work with Velodrome Finance.

The core concentrated liquidity contracts have been taken from v3-core at commit [d8b1c63](https://github.com/Uniswap/v3-core/commit/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb).
The periphery contracts have been taken from v3-periphery at commit [6cce88e](https://github.com/Uniswap/v3-periphery/commit/6cce88e63e176af1ddb6cc56e029110289622317).

Certain mock files (located in `contracts/core/test` or `contracts/core/periphery`) and test files have
been renamed or removed. 

## Core

### All Contracts
- NoDelegateCall was removed from all contracts.

### Factory (UniswapV3Factory.sol)

The Factory has been modified in the following ways:
- Pools are now created using Clones (EIP-1167 Proxies). 
- The clones are created deterministically, using `tickSpacing` instead of `fee`. 
- Creating a pool automatically creates a gauge as the two are coupled.
- The factory supports a fee module that can be changed by the factory owner. This fee module allows fees to be dynamic.

### Pool (UniswapV3Pool.sol)
- Pools no longer have a fixed fee and dynamically fetch the fee from the fee module in the Factory.

### PoolDeployer (UniswapV3PoolDeployer.sol)
- Removed once fees were made dynamic.

### Fee Modules

#### Custom Fee Module
- A custom fee module implements the same logic for custom fees as is present in Velodrome V2. This allows the factory owner to set the fee for specfic pools, allowing the pools to have a different fee from the default. 

### Tests

Tests were modified to be consistent with the above, with newer tests using foundry instead of hardhat.

- The TestERC20 contract was renamed to CoreTestERC20 due to a collision with the TestERC20 contract in periphery.

## Periphery

### Tests

Tests were modified to be consistent with the above, with newer tests using foundry instead of hardhat.
Places where artifacts were used from the uniswapv3 npm modules were replaced with artifacts built locally
in this repository.

## Gauge

### Concentrated Liquidity Gauge Factory
- Gauges are now created using Clones (EIP-1167 Proxies). 
- Gauges are created atomically with pools (unlike v2).

### Concentrated Liquidity Gauge
