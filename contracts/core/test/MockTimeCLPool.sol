// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "../CLPool.sol";

// used for testing time dependent behavior
contract MockTimeCLPool is CLPool {
    // Monday, October 5, 2020 9:00:00 AM GMT-05:00 (1601906400)
    uint256 public time;

    function setFeeGrowthGlobal0X128(uint256 _feeGrowthGlobal0X128) external {
        feeGrowthGlobal0X128 = _feeGrowthGlobal0X128;
    }

    function setFeeGrowthGlobal1X128(uint256 _feeGrowthGlobal1X128) external {
        feeGrowthGlobal1X128 = _feeGrowthGlobal1X128;
    }

    function uninitialize() external {
        slot0.sqrtPriceX96 = 0;
        slot0.unlocked = false;
        factory = address(0);
    }

    function advanceTime(uint256 by) external {
        time += by;
    }

    function _blockTimestamp() internal view override returns (uint32) {
        return uint32(time);
    }
}
