// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import "contracts/core/interfaces/IUniswapV3Factory.sol";
import "contracts/core/interfaces/IUniswapV3Pool.sol";

import "./PeripheryImmutableState.sol";
import "../interfaces/IPoolInitializer.sol";

/// @title Creates and initializes V3 Pools
abstract contract PoolInitializer is IPoolInitializer, PeripheryImmutableState {
    /// @inheritdoc IPoolInitializer
    function createAndInitializePoolIfNecessary(address token0, address token1, int24 tickSpacing, uint160 sqrtPriceX96)
        external
        payable
        override
        returns (address pool)
    {
        require(token0 < token1);
        pool = IUniswapV3Factory(factory).getPool(token0, token1, tickSpacing);

        if (pool == address(0)) {
            pool = IUniswapV3Factory(factory).createPool(token0, token1, tickSpacing);
            IUniswapV3Pool(pool).initialize(sqrtPriceX96);
        } else {
            (uint160 sqrtPriceX96Existing,,,,,) = IUniswapV3Pool(pool).slot0();
            if (sqrtPriceX96Existing == 0) {
                IUniswapV3Pool(pool).initialize(sqrtPriceX96);
            }
        }
    }
}
