// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "./TickTestBase.t.sol";

contract CrossTest is TickTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_flipGrowthVariable() public {
        Tick.Info memory tickInfo = Tick.Info({
            feeGrowthOutside0X128: 1,
            feeGrowthOutside1X128: 2,
            rewardGrowthOutsideX128: 10,
            liquidityGross: 3,
            liquidityNet: 4,
            stakedLiquidityNet: 0,
            secondsPerLiquidityOutsideX128: 5,
            tickCumulativeOutside: 6,
            secondsOutside: 7,
            initialized: true
        });

        tickTest.setTick(2, tickInfo);

        tickTest.cross(2, 7, 9, 8, 15, 10, 20);

        (
            ,
            ,
            ,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            uint256 rewardGrowthOutsideX128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
        ) = tickTest.ticks(2);

        assertEq(feeGrowthOutside0X128, 6);
        assertEq(feeGrowthOutside1X128, 7);
        assertEq(uint256(secondsPerLiquidityOutsideX128), 3);
        assertEq(int256(tickCumulativeOutside), 9);
        assertEq(uint256(secondsOutside), 3);
        assertEq(rewardGrowthOutsideX128, 10);
    }

    function test_twoFlipsAreNoOp() public {
        Tick.Info memory tickInfo = Tick.Info({
            feeGrowthOutside0X128: 1,
            feeGrowthOutside1X128: 2,
            rewardGrowthOutsideX128: 20,
            liquidityGross: 3,
            liquidityNet: 4,
            stakedLiquidityNet: 0,
            secondsPerLiquidityOutsideX128: 5,
            tickCumulativeOutside: 6,
            secondsOutside: 7,
            initialized: true
        });

        tickTest.setTick(2, tickInfo);

        tickTest.cross(2, 7, 9, 8, 15, 10, 10);
        tickTest.cross(2, 7, 9, 8, 15, 10, 10);

        (
            ,
            ,
            ,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            uint256 rewardGrowthOutsideX128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
        ) = tickTest.ticks(2);

        assertEq(feeGrowthOutside0X128, 1);
        assertEq(feeGrowthOutside1X128, 2);
        assertEq(uint256(secondsPerLiquidityOutsideX128), 5);
        assertEq(int256(tickCumulativeOutside), 6);
        assertEq(uint256(secondsOutside), 7);
        assertEq(rewardGrowthOutsideX128, 20);
    }
}
