// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import {Math} from "@openzeppelin/contracts/math/Math.sol";

import {TickMath} from "../../core/libraries/TickMath.sol";
import "contracts/core/interfaces/ICLPool.sol";
import "../lens/TickLens.sol";

/// @title Tick Lens contract
contract TickLensTest is TickLens {
    function getGasCostOfGetPopulatedTicksInWord(address pool, int16 tickBitmapIndex) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        getPopulatedTicksInWord(pool, tickBitmapIndex);
        return gasBefore - gasleft();
    }

    function getGasCostOfGetPopulatedTicks(address pool, int24 tick, uint256 maxCount)
        external
        view
        returns (uint256)
    {
        uint256 gasBefore = gasleft();
        getPopulatedTicks(pool, tick, maxCount);
        return gasBefore - gasleft();
    }

    /// @notice Get all the tick data for the populated ticks from multiple words, starting
    /// at the word where the given pool's tick is located
    /// @dev    Helper function used to estimate max number of bitmaps to be fetched
    /// @param pool The address of the pool for which to fetch populated tick data
    /// @param tick The tick from which to fetch the first tick bitmap index. The remaining bitmaps are
    /// consecutively fetched starting from the first bitmap.
    /// @param maxBitmaps Maximum number of bitmaps from which all the populated ticks will be fetched
    /// @return populatedTicks An array of tick data for the given word in the tick bitmap
    function getPopulatedTicks(address pool, int24 tick, uint256 maxBitmaps)
        public
        view
        returns (PopulatedTick[] memory populatedTicks)
    {
        // fetch bitmaps
        int24 tickSpacing = ICLPool(pool).tickSpacing();
        int16 startBitmapIndex = int16((tick / tickSpacing) >> 8);
        maxBitmaps = Math.min(maxBitmaps, uint256(type(int16).max - startBitmapIndex) + 1);

        // get all `maxBitmaps` starting from the given tick's bitmap index
        uint256 bitmap;
        uint256 numberOfPopulatedTicks;
        uint256[] memory bitmaps = new uint256[](maxBitmaps);
        for (uint256 j = 0; j < maxBitmaps; j++) {
            // calculate the number of populated ticks
            bitmap = ICLPool(pool).tickBitmap(startBitmapIndex + int16(j));
            numberOfPopulatedTicks += countSetBits(bitmap);
            bitmaps[j] = bitmap;
        }

        // fetch populated tick data
        populatedTicks = new PopulatedTick[](numberOfPopulatedTicks);

        int24 populatedTick;
        int24 tickBitmapIndex;
        for (uint256 j = 0; j < maxBitmaps; j++) {
            bitmap = bitmaps[j];
            tickBitmapIndex = startBitmapIndex + int16(j);
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
