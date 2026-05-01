pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../CLGaugeFactory/CLGaugeFactory.t.sol";

contract MinStakeTimesConcreteFuzzTest is CLGaugeFactoryTest {
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

    function testFuzz_WhenNoPerPoolOverrideIsSet(uint256 _defaultMinStakeTime) external {
        // It should return the default min stake time
        _defaultMinStakeTime = bound(_defaultMinStakeTime, 0, gaugeFactory.MAX_MIN_STAKE_TIME());
        vm.prank(users.owner);
        gaugeFactory.setDefaultMinStakeTime({_minStakeTime: _defaultMinStakeTime});

        assertEq(gaugeFactory.minStakeTimes(pool), _defaultMinStakeTime);
    }

    function testFuzz_WhenAPerPoolOverrideIsSet(uint256 _defaultMinStakeTime, uint256 _poolMinStakeTime) external {
        // It should return the per-pool min stake time
        _defaultMinStakeTime = bound(_defaultMinStakeTime, 0, gaugeFactory.MAX_MIN_STAKE_TIME());
        _poolMinStakeTime = bound(_poolMinStakeTime, 1, gaugeFactory.MAX_MIN_STAKE_TIME());

        vm.startPrank(users.owner);
        gaugeFactory.setDefaultMinStakeTime({_minStakeTime: _defaultMinStakeTime});
        gaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: _poolMinStakeTime});
        vm.stopPrank();

        assertEq(gaugeFactory.minStakeTimes(pool), _poolMinStakeTime);
    }
}
