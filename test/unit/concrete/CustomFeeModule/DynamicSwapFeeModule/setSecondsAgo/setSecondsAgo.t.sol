pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract SetSecondsAgoTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.setSecondsAgo({_secondsAgo: 0});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_WhenSecondsAgoIsLessThanMinimumSecondsAgo() external whenCallerIsFeeManager {
        // It should revert with "ISA"
        vm.expectRevert(bytes("ISA"));
        dynamicSwapFeeModule.setSecondsAgo({_secondsAgo: 1});
    }

    function test_WhenSecondsAgoIsHigherThanMaximumSecondsAgo() external whenCallerIsFeeManager {
        // It should revert with "ISA"
        vm.expectRevert(bytes("ISA"));
        dynamicSwapFeeModule.setSecondsAgo({_secondsAgo: 65535 * 2});
    }

    function test_WhenSecondsAgoIsCorrectAmount() external whenCallerIsFeeManager {
        // It should set the new secondsAgo
        // It should emit a {SecondsAgoSet} event
        vm.expectEmit(true, false, false, false, address(dynamicSwapFeeModule));
        emit SecondsAgoSet({secondsAgo: 1800});
        dynamicSwapFeeModule.setSecondsAgo({_secondsAgo: 1800});

        assertEqUint(dynamicSwapFeeModule.secondsAgo(), 1800);
    }
}
