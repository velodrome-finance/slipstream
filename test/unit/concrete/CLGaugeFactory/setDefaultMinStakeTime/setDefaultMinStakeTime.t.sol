pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGaugeFactory.t.sol";

contract SetDefaultMinStakeTimeConcreteUnitTest is CLGaugeFactoryTest {
    event SetDefaultMinStakeTime(uint256 _minStakeTime);

    function test_WhenTheCallerIsNotTheGaugeStakeManager() external {
        // It should revert with {NA}
        vm.prank({msgSender: users.charlie});
        vm.expectRevert(abi.encodePacked("NA"));
        gaugeFactory.setDefaultMinStakeTime({_minStakeTime: 60});
    }

    modifier whenTheCallerIsTheGaugeStakeManager() {
        _;
    }

    function test_WhenTheMinStakeTimeExceedsTheMaximum() external whenTheCallerIsTheGaugeStakeManager {
        // It should revert with {MS}
        uint256 tooHigh = gaugeFactory.MAX_MIN_STAKE_TIME() + 1;
        vm.prank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("MS"));
        gaugeFactory.setDefaultMinStakeTime({_minStakeTime: tooHigh});
    }

    function test_WhenTheMinStakeTimeDoesNotExceedTheMaximum() external whenTheCallerIsTheGaugeStakeManager {
        // It should set the default min stake time
        // It should emit a {SetDefaultMinStakeTime} event
        vm.prank({msgSender: users.owner});
        vm.expectEmit(address(gaugeFactory));
        emit SetDefaultMinStakeTime({_minStakeTime: 120});
        gaugeFactory.setDefaultMinStakeTime({_minStakeTime: 120});

        assertEq(gaugeFactory.defaultMinStakeTime(), 120);
    }
}
