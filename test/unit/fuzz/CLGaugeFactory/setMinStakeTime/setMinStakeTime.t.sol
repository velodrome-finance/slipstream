pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../CLGaugeFactory/CLGaugeFactory.t.sol";

contract SetMinStakeTimeConcreteFuzzTest is CLGaugeFactoryTest {
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

    function testFuzz_WhenTheCallerIsNotTheGaugeStakeManager(address _caller) external {
        // It should revert with {NA}
        vm.assume(_caller != users.owner);
        vm.prank(_caller);
        vm.expectRevert(abi.encodePacked("NA"));
        gaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: 60});
    }

    modifier whenTheCallerIsTheGaugeStakeManager() {
        _;
    }

    function testFuzz_WhenThePoolIsTheZeroAddress() external whenTheCallerIsTheGaugeStakeManager {
        // not fuzzed: zero address is a single discrete value
    }

    modifier whenThePoolIsNotTheZeroAddress() {
        _;
    }

    function testFuzz_WhenTheMinStakeTimeExceedsTheMaximum(uint256 _minStakeTime)
        external
        whenTheCallerIsTheGaugeStakeManager
        whenThePoolIsNotTheZeroAddress
    {
        // It should revert with {MS}
        uint256 tooHigh = gaugeFactory.MAX_MIN_STAKE_TIME() + 1;
        _minStakeTime = bound(_minStakeTime, tooHigh, type(uint256).max);
        vm.prank(users.owner);
        vm.expectRevert(abi.encodePacked("MS"));
        gaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: _minStakeTime});
    }

    function testFuzz_WhenTheMinStakeTimeDoesNotExceedTheMaximum(uint256 _minStakeTime)
        external
        whenTheCallerIsTheGaugeStakeManager
        whenThePoolIsNotTheZeroAddress
    {
        // It should set the per-pool min stake time
        _minStakeTime = bound(_minStakeTime, 0, gaugeFactory.MAX_MIN_STAKE_TIME());
        vm.prank(users.owner);
        gaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: _minStakeTime});

        assertEq(
            gaugeFactory.minStakeTimes(pool), _minStakeTime == 0 ? gaugeFactory.defaultMinStakeTime() : _minStakeTime
        );
    }
}
