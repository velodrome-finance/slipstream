// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// @title Tick Lens
/// @notice Provides functions for fetching chunks of tick data for a pool
/// @dev This avoids the waterfall of fetching the tick bitmap, parsing the bitmap to know which ticks to fetch, and
/// then sending additional multicalls to fetch the tick data
interface ITickLens {
    struct PopulatedTick {
        int24 tick;
        uint160 sqrtRatioX96;
        int128 liquidityNet;
        uint128 liquidityGross;
    }

    /// @notice Get all the tick data for the populated ticks from a word of the tick bitmap of a pool
    /// @param pool The address of the pool for which to fetch populated tick data
    /// @param tickBitmapIndex The index of the word in the tick bitmap for which to parse the bitmap and
    /// fetch all the populated ticks
    /// @return populatedTicks An array of tick data for the given word in the tick bitmap
    function getPopulatedTicksInWord(address pool, int16 tickBitmapIndex)
        external
        view
        returns (PopulatedTick[] memory populatedTicks);

    /// @notice Get all the tick data for the populated ticks from multiple words, starting
    /// at the word where the given pool's tick is located
    /// @param pool The address of the pool for which to fetch populated tick data
    /// @param tick The tick from which to fetch the first tick bitmap index. The remaining bitmaps are
    /// consecutively fetched starting from the first bitmap.
    /// @param maxBitmaps Maximum number of bitmaps from which all the populated ticks will be fetched
    /// @return populatedTicks An array of tick data for the given word in the tick bitmap
    function getPopulatedTicks(address pool, int24 tick, uint256 maxBitmaps)
        external
        view
        returns (PopulatedTick[] memory populatedTicks);
}
