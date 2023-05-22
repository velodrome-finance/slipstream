# CHANGELOG

A list of changes made to the vanilla UniswapV3 Contracts to work with Velodrome Finance.

## Factory (UniswapV3Factory.sol)

The Factory Registry has been modified in the following ways:
- Pools are now created using Clones (EIP-1167 Proxies). 
- The clones are created deterministically, using `tickSpacing` instead of `fee`. 
- The factory owner can add new tick spacings and fees similar to how it was before. 
- The factory supports a fee module that allows the fee logic to be changed by the factory owner.

## Pool (UniswapV3Pool.sol)
- Pools no longer have a fixed fee and dynamically fetch the fee from the Factory.

## PoolDeployer (UniswapV3PoolDeployer.sol)
- Removed once fees were made dynamic.

## Fee Modules

### Custom Fee Module
- A custom fee module implements the same logic for custom fees as is present in Velodrome V2. This allows the factory owner to set the fee for specfic pools, allowing the pools to have a different fee from the default. 