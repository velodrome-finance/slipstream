// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "contracts/periphery/base/PeripheryImmutableState.sol";
import "contracts/core/libraries/SafeCast.sol";
import "contracts/core/libraries/TickMath.sol";
import "contracts/core/libraries/TickBitmap.sol";
import "contracts/core/interfaces/ICLPool.sol";
import "contracts/core/interfaces/ICLFactory.sol";
import "contracts/core/interfaces/callback/ICLSwapCallback.sol";
import "contracts/core/interfaces/IPool.sol";
import "contracts/core/interfaces/IPoolFactory.sol";
import "contracts/periphery/libraries/Path.sol";
import "contracts/periphery/libraries/CallbackValidation.sol";

import "../interfaces/IMixedRouteQuoterV2.sol";
import "../libraries/PoolTicksCounter.sol";

/// @title Provides on chain quotes for V3, V2, and MixedRoute exact input swaps
/// @notice Allows getting the expected amount out for a given swap without executing the swap
/// @notice Supports exact output swaps for V3 pools by using the same method as QuoterV2
/// @notice Extends MixedRouteQuoterV2 with support for three CL factories
/// @dev These functions are not gas efficient and should _not_ be called on chain. Instead, optimistically execute
/// the swap and check the amounts in the callback.
contract MixedRouteQuoterV3 is IMixedRouteQuoterV2, ICLSwapCallback, PeripheryImmutableState {
    using Path for bytes;
    using SafeCast for uint256;
    using PoolTicksCounter for ICLPool;

    address public immutable legacyCLFactory;
    address public immutable legacyCLFactory2;
    address public immutable factoryV2;

    /// @dev Value to bit mask with path fee to determine if V2 or V3 route
    // max V3 tick spacing:           000000000100000000000000 (24 bits)
    // volatile mask:       1 << 22 = 010000000000000000000000 = decimal value 4194304
    // stable mask:         1 << 21 = 001000000000000000000000 = decimal value 2097152
    // cl factory mask:     1 << 20 = 000100000000000000000000 = decimal value 1048576
    // cl factory 2 mask:   1 << 19 = 000010000000000000000000 = decimal value 524288
    int24 private constant volatileBitmask = 4194304;
    int24 private constant stableBitmask = 2097152;
    int24 private constant clBitmask = 1048576;
    int24 private constant cl2Bitmask = 524288;
    int24 private constant clFactoryMask = clBitmask | cl2Bitmask;

    /// @dev Transient storage variable used to check a safety condition in exact output swaps.
    uint256 private amountOutCached;

    /// @param _factory The address of the newest CL factory (cl2Bitmask)
    /// @param _legacyCLFactory The address of the original CL factory (clBitmask)
    /// @param _legacyCLFactory2 The address of the second CL factory (no bitmask)
    /// @param _factoryV2 The address of the V2 pool factory
    /// @param _WETH9 The address of WETH9
    constructor(
        address _factory,
        address _legacyCLFactory,
        address _legacyCLFactory2,
        address _factoryV2,
        address _WETH9
    ) PeripheryImmutableState(_factory, _WETH9) {
        legacyCLFactory = _legacyCLFactory;
        legacyCLFactory2 = _legacyCLFactory2;
        factoryV2 = _factoryV2;
    }

    function _getCLFactory(int24 tickSpacing) private view returns (address) {
        if (tickSpacing & cl2Bitmask != 0) return factory;
        if (tickSpacing & clBitmask != 0) return legacyCLFactory;
        return legacyCLFactory2;
    }

    function getPool(address tokenA, address tokenB, int24 tickSpacing) private view returns (ICLPool) {
        return ICLPool(ICLFactory(_getCLFactory(tickSpacing)).getPool(tokenA, tokenB, tickSpacing & ~clFactoryMask));
    }

    /// @dev Given an amountIn, get the amountOut for the corresponding pool
    function getPairAmountOut(uint256 amountIn, address tokenIn, address tokenOut, bool stable)
        private
        view
        returns (uint256)
    {
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        address pool = IPoolFactory(factoryV2).getPool(token0, token1, stable);
        if (pool == address(0)) return 0;
        return IPool(pool).getAmountOut(amountIn, tokenIn);
    }

    /// @inheritdoc ICLSwapCallback
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes memory path)
        external
        view
        override
    {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        (address tokenIn, address tokenOut, int24 tickSpacing) = path.decodeFirstPool();
        CallbackValidation.verifyCallback(_getCLFactory(tickSpacing), tokenIn, tokenOut, tickSpacing & ~clFactoryMask);

        (bool isExactInput, uint256 amountToPay, uint256 amountReceived) = amount0Delta > 0
            ? (tokenIn < tokenOut, uint256(amount0Delta), uint256(-amount1Delta))
            : (tokenOut < tokenIn, uint256(amount1Delta), uint256(-amount0Delta));

        ICLPool pool = getPool(tokenIn, tokenOut, tickSpacing);
        (uint160 sqrtPriceX96After, int24 tickAfter,,,,) = pool.slot0();

        if (isExactInput) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountReceived)
                mstore(add(ptr, 0x20), sqrtPriceX96After)
                mstore(add(ptr, 0x40), tickAfter)
                revert(ptr, 0x60)
            }
        } else {
            // if the cache has been populated, ensure that the full output amount has been received
            if (amountOutCached != 0) require(amountReceived == amountOutCached);
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountToPay)
                mstore(add(ptr, 0x20), sqrtPriceX96After)
                mstore(add(ptr, 0x40), tickAfter)
                revert(ptr, 0x60)
            }
        }
    }

    /// @dev Parses a revert reason that should contain the numeric quote
    function parseRevertReason(bytes memory reason)
        private
        pure
        returns (uint256 amount, uint160 sqrtPriceX96After, int24 tickAfter)
    {
        if (reason.length != 0x60) {
            if (reason.length < 0x44) revert("Unexpected error");
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        return abi.decode(reason, (uint256, uint160, int24));
    }

    function handleV3Revert(bytes memory reason, ICLPool pool, uint256 gasEstimate)
        private
        view
        returns (uint256 amount, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256)
    {
        int24 tickBefore;
        int24 tickAfter;
        (, tickBefore,,,,) = pool.slot0();
        (amount, sqrtPriceX96After, tickAfter) = parseRevertReason(reason);

        initializedTicksCrossed = pool.countInitializedTicksCrossed(tickBefore, tickAfter);

        return (amount, sqrtPriceX96After, initializedTicksCrossed, gasEstimate);
    }

    /// @dev Fetch an exactIn quote for a V3 Pool on chain
    function quoteExactInputSingleV3(QuoteExactInputSingleV3Params memory params)
        public
        override
        returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)
    {
        bool zeroForOne = params.tokenIn < params.tokenOut;
        ICLPool pool = getPool(params.tokenIn, params.tokenOut, params.tickSpacing);

        uint256 gasBefore = gasleft();
        try pool.swap(
            address(this), // address(0) might cause issues with some tokens
            zeroForOne,
            params.amountIn.toInt256(),
            params.sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : params.sqrtPriceLimitX96,
            abi.encodePacked(params.tokenIn, params.tickSpacing, params.tokenOut)
        ) {} catch (bytes memory reason) {
            gasEstimate = gasBefore - gasleft();
            return handleV3Revert(reason, pool, gasEstimate);
        }
    }

    /// @dev Fetch an exactIn quote for a V2 pair on chain
    function quoteExactInputSingleV2(QuoteExactInputSingleV2Params memory params)
        public
        view
        override
        returns (uint256 amountOut)
    {
        amountOut = getPairAmountOut(params.amountIn, params.tokenIn, params.tokenOut, params.stable);
    }

    /// @notice To encode a volatile V2 pair within the path, use 0x400000 (hex value of 4194304) for the fee between the two token addresses
    /// @notice To encode a stable V2 pair within the path, use 0x200000 (hex value of 2097152) for the fee between the two token addresses
    /// @notice To encode a CL pool from legacyCLFactory (oldest), use 0x100000 | tickSpacing
    /// @notice To encode a CL pool from factory (newest), use 0x80000 | tickSpacing
    /// @notice To encode a CL pool from legacyCLFactory2, use the raw tickSpacing
    /// @dev Get the quote for an exactIn swap between an array of V2 and/or V3 pools
    /// @dev If the pool does not exist, will quietly return 0 values
    function quoteExactInput(bytes memory path, uint256 amountIn)
        public
        override
        returns (
            uint256 amountOut,
            uint160[] memory v3SqrtPriceX96AfterList,
            uint32[] memory v3InitializedTicksCrossedList,
            uint256 v3SwapGasEstimate
        )
    {
        v3SqrtPriceX96AfterList = new uint160[](path.numPools());
        v3InitializedTicksCrossedList = new uint32[](path.numPools());

        uint256 i = 0;
        while (true) {
            (address tokenIn, address tokenOut, int24 tickSpacing) = path.decodeFirstPool();

            if (tickSpacing & volatileBitmask != 0) {
                amountIn = quoteExactInputSingleV2(
                    QuoteExactInputSingleV2Params({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        amountIn: amountIn,
                        stable: false
                    })
                );
            } else if (tickSpacing & stableBitmask != 0) {
                amountIn = quoteExactInputSingleV2(
                    QuoteExactInputSingleV2Params({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        amountIn: amountIn,
                        stable: true
                    })
                );
            } else {
                /// the outputs of prior swaps become the inputs to subsequent ones
                (uint256 _amountOut, uint160 _sqrtPriceX96After, uint32 _initializedTicksCrossed, uint256 _gasEstimate)
                = quoteExactInputSingleV3(
                    QuoteExactInputSingleV3Params({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        tickSpacing: tickSpacing,
                        amountIn: amountIn,
                        sqrtPriceLimitX96: 0
                    })
                );
                v3SqrtPriceX96AfterList[i] = _sqrtPriceX96After;
                v3InitializedTicksCrossedList[i] = _initializedTicksCrossed;
                v3SwapGasEstimate += _gasEstimate;
                amountIn = _amountOut;
            }
            i++;

            /// decide whether to continue or terminate
            if (path.hasMultiplePools()) {
                path = path.skipToken();
            } else {
                return (amountIn, v3SqrtPriceX96AfterList, v3InitializedTicksCrossedList, v3SwapGasEstimate);
            }
        }
    }

    /// @dev Fetch an exactOut quote for a V3 Pool on chain
    function quoteExactOutputSingleV3(QuoteExactOutputSingleV3Params memory params)
        public
        override
        returns (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)
    {
        bool zeroForOne = params.tokenIn < params.tokenOut;
        ICLPool pool = getPool(params.tokenIn, params.tokenOut, params.tickSpacing);

        // if no price limit has been specified, cache the output amount for comparison in the swap callback
        if (params.sqrtPriceLimitX96 == 0) amountOutCached = params.amountOut;
        uint256 gasBefore = gasleft();
        try pool.swap(
            address(this), // address(0) might cause issues with some tokens
            zeroForOne,
            -params.amountOut.toInt256(),
            params.sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : params.sqrtPriceLimitX96,
            abi.encodePacked(params.tokenOut, params.tickSpacing, params.tokenIn)
        ) {} catch (bytes memory reason) {
            gasEstimate = gasBefore - gasleft();
            if (params.sqrtPriceLimitX96 == 0) delete amountOutCached; // clear cache
            return handleV3Revert(reason, pool, gasEstimate);
        }
    }

    /// @notice To encode a volatile V2 pair within the path, use 0x400000 (hex value of 4194304) for the fee between the two token addresses
    /// @notice To encode a stable V2 pair within the path, use 0x200000 (hex value of 2097152) for the fee between the two token addresses
    /// @dev Get the quote for an exactOut swap between an array of V3 pools
    /// @dev V2 pools are not supported for exactOut quotes
    /// @dev If a pool does not exist, will quietly return 0 values
    function quoteExactOutput(bytes memory path, uint256 amountOut)
        public
        override
        returns (
            uint256 amountIn,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        )
    {
        sqrtPriceX96AfterList = new uint160[](path.numPools());
        initializedTicksCrossedList = new uint32[](path.numPools());

        uint256 i = 0;
        while (true) {
            (address tokenOut, address tokenIn, int24 tickSpacing) = path.decodeFirstPool();

            // the inputs of prior swaps become the outputs of subsequent ones
            (uint256 _amountIn, uint160 _sqrtPriceX96After, uint32 _initializedTicksCrossed, uint256 _gasEstimate) =
            quoteExactOutputSingleV3(
                QuoteExactOutputSingleV3Params({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    tickSpacing: tickSpacing,
                    amountOut: amountOut,
                    sqrtPriceLimitX96: 0
                })
            );

            sqrtPriceX96AfterList[i] = _sqrtPriceX96After;
            initializedTicksCrossedList[i] = _initializedTicksCrossed;
            amountOut = _amountIn;
            gasEstimate += _gasEstimate;
            i++;

            // decide whether to continue or terminate
            if (path.hasMultiplePools()) {
                path = path.skipToken();
            } else {
                return (amountOut, sqrtPriceX96AfterList, initializedTicksCrossedList, gasEstimate);
            }
        }
    }
}
