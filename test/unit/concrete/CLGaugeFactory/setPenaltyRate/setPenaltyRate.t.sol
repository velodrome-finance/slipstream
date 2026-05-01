pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGaugeFactory.t.sol";

contract SetPenaltyRateConcreteUnitTest is CLGaugeFactoryTest {
    event SetPenaltyRate(uint256 _penaltyRate);

    function test_WhenTheCallerIsNotTheGaugeStakeManager() external {
        // It should revert with {NA}
        vm.startPrank({msgSender: users.charlie});
        vm.expectRevert(abi.encodePacked("NA"));
        gaugeFactory.setPenaltyRate({_penaltyRate: 5000});
    }

    modifier whenTheCallerIsTheGaugeStakeManager() {
        _;
    }

    function test_WhenThePenaltyRateExceedsTheMaximum() external whenTheCallerIsTheGaugeStakeManager {
        // It should revert with {MR}
        uint256 tooHigh = gaugeFactory.MAX_BPS() + 1;
        vm.startPrank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("MR"));
        gaugeFactory.setPenaltyRate({_penaltyRate: tooHigh});
    }

    function test_WhenThePenaltyRateDoesNotExceedTheMaximum() external whenTheCallerIsTheGaugeStakeManager {
        // It should set the penalty rate
        // It should emit a {SetPenaltyRate} event
        vm.prank({msgSender: users.owner});
        vm.expectEmit(address(gaugeFactory));
        emit SetPenaltyRate({_penaltyRate: 5000});
        gaugeFactory.setPenaltyRate({_penaltyRate: 5000});

        assertEq(gaugeFactory.penaltyRate(), 5000);
    }
}
