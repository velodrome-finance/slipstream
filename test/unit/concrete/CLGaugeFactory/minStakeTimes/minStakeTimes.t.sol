pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGaugeFactory.t.sol";

contract MinStakeTimesConcreteUnitTest is CLGaugeFactoryTest {
    address public pool;

    function setUp() public override {
        super.setUp();
        pool = poolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: TICK_SPACING_60,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
    }

    function test_WhenNoPerPoolOverrideIsSet() external {
        // It should return the default min stake time
        vm.prank(users.owner);
        gaugeFactory.setDefaultMinStakeTime({_minStakeTime: 300});

        assertEq(gaugeFactory.minStakeTimes(pool), 300);
    }

    function test_WhenAPerPoolOverrideIsSet() external {
        // It should return the per-pool min stake time
        vm.startPrank(users.owner);
        gaugeFactory.setDefaultMinStakeTime({_minStakeTime: 300});
        gaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: 600});
        vm.stopPrank();

        assertEq(gaugeFactory.minStakeTimes(pool), 600);
    }
}
