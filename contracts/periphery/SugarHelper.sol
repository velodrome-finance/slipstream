// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";
import {PositionValue} from "./libraries/PositionValue.sol";
import {FullMath} from "../core/libraries/FullMath.sol";
import {TickMath} from "../core/libraries/TickMath.sol";
import {FixedPoint128} from "../core/libraries/FixedPoint128.sol";
import {ICLPool} from "../core/interfaces/ICLPool.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {ISugarHelper} from "./interfaces/ISugarHelper.sol";

/// @notice Expose on-chain helpers for liquidity math
contract SugarHelper is ISugarHelper {
    /// @dev Maximum number of Bitmaps that can be processed per call
    uint256 constant MAX_BITMAPS = 5;

    ///
    /// Wrappers for LiquidityAmounts
    ///

    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) external pure override returns (uint256 amount0, uint256 amount1) {
        return LiquidityAmounts.getAmountsForLiquidity({
            sqrtRatioX96: sqrtRatioX96,
            sqrtRatioAX96: sqrtRatioAX96,
            sqrtRatioBX96: sqrtRatioBX96,
            liquidity: liquidity
        });
    }

    function getAmount0ForLiquidity(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity)
        external
        pure
        override
        returns (uint256 amount0)
    {
        return LiquidityAmounts.getAmount0ForLiquidity({
            sqrtRatioAX96: sqrtRatioAX96,
            sqrtRatioBX96: sqrtRatioBX96,
            liquidity: liquidity
        });
    }

    function getAmount1ForLiquidity(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity)
        external
        pure
        override
        returns (uint256 amount1)
    {
        return LiquidityAmounts.getAmount1ForLiquidity({
            sqrtRatioAX96: sqrtRatioAX96,
            sqrtRatioBX96: sqrtRatioBX96,
            liquidity: liquidity
        });
    }

    function getLiquidityForAmounts(
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96
    ) external pure returns (uint256 liquidity) {
        return LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1);
    }

    function estimateAmount0(
        uint256 amount1,
        uint128 liquidity,
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96
    ) external pure override returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96 && sqrtRatioX96 >= sqrtRatioBX96) {
            return 0;
        }

        if (liquidity == 0) {
            liquidity = LiquidityAmounts.getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);
        }
        amount0 = LiquidityAmounts.getAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity);
    }

    function estimateAmount1(
        uint256 amount0,
        uint128 liquidity,
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96
    ) external pure override returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96 && sqrtRatioX96 >= sqrtRatioBX96) {
            return 0;
        }

        if (liquidity == 0) {
            liquidity = LiquidityAmounts.getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
        }
        amount1 = LiquidityAmounts.getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity);
    }

    ///
    /// Wrappers for PositionValue
    ///

    function principal(INonfungiblePositionManager positionManager, uint256 tokenId, uint160 sqrtRatioX96)
        external
        view
        override
        returns (uint256 amount0, uint256 amount1)
    {
        return PositionValue.principal({positionManager: positionManager, tokenId: tokenId, sqrtRatioX96: sqrtRatioX96});
    }

    function fees(INonfungiblePositionManager positionManager, uint256 tokenId)
        external
        view
        override
        returns (uint256 amount0, uint256 amount1)
    {
        return PositionValue.fees({positionManager: positionManager, tokenId: tokenId});
    }

    ///
    /// Wrappers for TickMath
    ///

    function getSqrtRatioAtTick(int24 tick) external pure override returns (uint160 sqrtRatioX96) {
        return TickMath.getSqrtRatioAtTick(tick);
    }

    function getTickAtSqrtRatio(uint160 sqrtPriceX96) external pure override returns (int24 tick) {
        return TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    ///
    /// PoolFees Helper
    ///

    function poolFees(address pool, uint128 liquidity, int24 tickCurrent, int24 tickLower, int24 tickUpper)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (,,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,,) =
            ICLPool(pool).ticks(tickLower);
        (,,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,,) =
            ICLPool(pool).ticks(tickUpper);

        uint256 feeGrowthInside0X128;
        uint256 feeGrowthInside1X128;
        if (tickCurrent < tickLower) {
            feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
            feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
        } else if (tickCurrent < tickUpper) {
            uint256 feeGrowthGlobal0X128 = ICLPool(pool).feeGrowthGlobal0X128();
            uint256 feeGrowthGlobal1X128 = ICLPool(pool).feeGrowthGlobal1X128();
            feeGrowthInside0X128 = feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
            feeGrowthInside1X128 = feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
        } else {
            feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
            feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
        }

        amount0 = FullMath.mulDiv(feeGrowthInside0X128, liquidity, FixedPoint128.Q128);

        amount1 = FullMath.mulDiv(feeGrowthInside1X128, liquidity, FixedPoint128.Q128);
    }

    ///
    /// TickLens Helper
    ///

    /// @notice Fetches Tick Data for all populated Ticks in given bitmaps
    /// @param pool Address of the pool from which to fetch data
    /// @param startTick Tick from which the first bitmap will be fetched
    /// @dev   The number of bitmaps fetched by this function should always be `MAX_BITMAPS`,
    ///        unless there are less than `MAX_BITMAPS` left to iterate through
    /// @return populatedTicks Array of all Populated Ticks in the provided bitmaps
    function getPopulatedTicks(address pool, int24 startTick)
        external
        view
        override
        returns (PopulatedTick[] memory populatedTicks)
    {
        // fetch all bitmaps, starting at bitmap where the given `startTick` is located
        int24 tickSpacing = ICLPool(pool).tickSpacing();
        int16 bitmapIndex = int16((startTick / tickSpacing) >> 8);
        uint256 maxBitmaps = Math.min(MAX_BITMAPS, uint256(type(int16).max - bitmapIndex) + 1);

        // get all `maxBitmaps` starting from the given tick's bitmap index
        uint256 bitmap;
        uint256 numberOfPopulatedTicks;
        uint256[] memory bitmaps = new uint256[](maxBitmaps);
        for (uint256 j = 0; j < maxBitmaps; j++) {
            // calculate the number of populated ticks
            bitmap = ICLPool(pool).tickBitmap(bitmapIndex++);
            numberOfPopulatedTicks += countSetBits(bitmap);
            bitmaps[j] = bitmap;
        }

        // fetch populated tick data
        populatedTicks = new PopulatedTick[](numberOfPopulatedTicks);

        int24 populatedTick;
        int24 tickBitmapIndex;
        for (uint256 j = 0; j < maxBitmaps; j++) {
            bitmap = bitmaps[j];
            tickBitmapIndex = bitmapIndex + int16(j);
            for (uint256 i = 0; i < 256; i++) {
                if (bitmap & (1 << i) > 0) {
                    populatedTick = ((tickBitmapIndex << 8) + int24(i)) * tickSpacing;

                    (uint128 liquidityGross, int128 liquidityNet,,,,,,,,) = ICLPool(pool).ticks(populatedTick);

                    populatedTicks[--numberOfPopulatedTicks] = PopulatedTick({
                        tick: populatedTick,
                        sqrtRatioX96: TickMath.getSqrtRatioAtTick(populatedTick),
                        liquidityNet: liquidityNet,
                        liquidityGross: liquidityGross
                    });
                }
            }
        }
    }

    function countSetBits(uint256 bitmap) private pure returns (uint256 count) {
        while (bitmap != 0) {
            bitmap &= (bitmap - 1);
            count++;
        }
    }
}
