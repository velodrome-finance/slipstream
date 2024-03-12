// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

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
}
