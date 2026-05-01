pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGaugeFactory.t.sol";

contract SetMinStakeTimeConcreteUnitTest is CLGaugeFactoryTest {
    event SetPoolMinStakeTime(address indexed _pool, uint256 _minStakeTime);

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

    function test_WhenTheCallerIsNotTheGaugeStakeManager() external {
        // It should revert with {NA}
        vm.prank({msgSender: users.charlie});
        vm.expectRevert(abi.encodePacked("NA"));
        gaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: 60});
    }

    modifier whenTheCallerIsTheGaugeStakeManager() {
        _;
    }

    function test_WhenThePoolIsTheZeroAddress() external whenTheCallerIsTheGaugeStakeManager {
        // It should revert with {ZA}
        vm.prank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("ZA"));
        gaugeFactory.setMinStakeTime({_pool: address(0), _minStakeTime: 60});
    }

    modifier whenThePoolIsNotTheZeroAddress() {
        _;
    }

    function test_WhenTheMinStakeTimeExceedsTheMaximum()
        external
        whenTheCallerIsTheGaugeStakeManager
        whenThePoolIsNotTheZeroAddress
    {
        // It should revert with {MS}
        uint256 tooHigh = gaugeFactory.MAX_MIN_STAKE_TIME() + 1;
        vm.prank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("MS"));
        gaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: tooHigh});
    }

    function test_WhenTheMinStakeTimeDoesNotExceedTheMaximum()
        external
        whenTheCallerIsTheGaugeStakeManager
        whenThePoolIsNotTheZeroAddress
    {
        // It should set the per-pool min stake time
        // It should emit a {SetPoolMinStakeTime} event
        vm.prank({msgSender: users.owner});
        vm.expectEmit(address(gaugeFactory));
        emit SetPoolMinStakeTime({_pool: pool, _minStakeTime: 120});
        gaugeFactory.setMinStakeTime({_pool: pool, _minStakeTime: 120});

        assertEq(gaugeFactory.minStakeTimes(pool), 120);
    }
}
