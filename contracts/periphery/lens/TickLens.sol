// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import {Math} from "@openzeppelin/contracts/math/Math.sol";

import "contracts/core/interfaces/ICLPool.sol";
import {TickMath} from "../../core/libraries/TickMath.sol";

import "../interfaces/ITickLens.sol";

/// @title Tick Lens contract
contract TickLens is ITickLens {
    /// @inheritdoc ITickLens
    function getPopulatedTicksInWord(address pool, int16 tickBitmapIndex)
        public
        view
        override
        returns (PopulatedTick[] memory populatedTicks)
    {
        // fetch bitmap
        uint256 bitmap = ICLPool(pool).tickBitmap(tickBitmapIndex);

        // calculate the number of populated ticks
        uint256 numberOfPopulatedTicks;
        for (uint256 i = 0; i < 256; i++) {
            if (bitmap & (1 << i) > 0) numberOfPopulatedTicks++;
        }

        // fetch populated tick data
        int24 tickSpacing = ICLPool(pool).tickSpacing();
        populatedTicks = new PopulatedTick[](numberOfPopulatedTicks);
        for (uint256 i = 0; i < 256; i++) {
            if (bitmap & (1 << i) > 0) {
                int24 populatedTick = ((int24(tickBitmapIndex) << 8) + int24(i)) * tickSpacing;
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

    /// @inheritdoc ITickLens
    function getPopulatedTicks(address pool, int24 tick, uint256 maxBitmaps)
        public
        view
        override
        returns (PopulatedTick[] memory populatedTicks)
    {
        // fetch bitmaps
        int24 tickSpacing = ICLPool(pool).tickSpacing();
        int16 bitmapIndex = int16((tick / tickSpacing) >> 8);
        maxBitmaps = Math.min(maxBitmaps, uint256(type(int16).max - bitmapIndex) + 1);

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
