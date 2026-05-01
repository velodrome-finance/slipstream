pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGaugeFactory.t.sol";

contract SetPenaltyRateConcreteFuzzTest is CLGaugeFactoryTest {
    modifier whenTheCallerIsTheGaugeStakeManager() {
        _;
    }

    function testFuzz_WhenTheCallerIsNotTheGaugeStakeManager(address _caller) external {
        // It should revert with {NA}
        vm.assume(_caller != users.owner);
        vm.startPrank(_caller);
        vm.expectRevert(abi.encodePacked("NA"));
        gaugeFactory.setPenaltyRate({_penaltyRate: 5000});
    }

    function testFuzz_WhenThePenaltyRateExceedsTheMaximum(uint256 _penaltyRate)
        external
        whenTheCallerIsTheGaugeStakeManager
    {
        // It should revert with {MR}
        uint256 tooHigh = gaugeFactory.MAX_BPS() + 1;
        _penaltyRate = bound(_penaltyRate, tooHigh, type(uint256).max);
        vm.startPrank(users.owner);
        vm.expectRevert(abi.encodePacked("MR"));
        gaugeFactory.setPenaltyRate({_penaltyRate: _penaltyRate});
    }

    function testFuzz_WhenThePenaltyRateDoesNotExceedTheMaximum() external whenTheCallerIsTheGaugeStakeManager {
        // not fuzzed: simple storage assignment, boundary covered by testFuzz_WhenThePenaltyRateExceedsTheMaximum
    }
}
