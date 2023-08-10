// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import "contracts/core/interfaces/IUniswapV3Pool.sol";
import "./PoolAddress.sol";

/// @notice Provides validation for callbacks from Uniswap V3 Pools
library CallbackValidation {
    /// @notice Returns the address of a valid Uniswap V3 Pool
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @param tickSpacing The tick spacing for the pool
    /// @return pool The V3 pool contract address
    function verifyCallback(address factory, address tokenA, address tokenB, int24 tickSpacing)
        internal
        view
        returns (IUniswapV3Pool pool)
    {
        return verifyCallback(factory, PoolAddress.getPoolKey(tokenA, tokenB, tickSpacing));
    }

    /// @notice Returns the address of a valid Uniswap V3 Pool
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param poolKey The identifying key of the V3 pool
    /// @return pool The V3 pool contract address
    function verifyCallback(address factory, PoolAddress.PoolKey memory poolKey)
        internal
        view
        returns (IUniswapV3Pool pool)
    {
        pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
        require(msg.sender == address(pool));
    }
}
