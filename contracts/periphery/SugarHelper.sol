// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

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
    ) external pure returns (uint256 amount0) {
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
    ) external pure returns (uint256 amount1) {
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
}
