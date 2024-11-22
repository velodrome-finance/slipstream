pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract SetDefaultScalingFactorTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.setDefaultScalingFactor({_defaultScalingFactor: 1});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_WhenDefaultScalingFactorIsHigherThanMaxScalingFactorCap() external whenCallerIsFeeManager {
        // It should revert with "ISF"
        vm.expectRevert(bytes("ISF"));
        dynamicSwapFeeModule.setDefaultScalingFactor({_defaultScalingFactor: 1e18 + 1});
    }

    function test_WhenDefaultScalingFactorIsLessThanMaxScalingFactorCap() external whenCallerIsFeeManager {
        // It should set default scaling factor
        // It should emit a {DefaultScalingFactorSet} event

        uint256 newScalingFactor = 1e18;

        vm.expectEmit(true, false, false, false, address(dynamicSwapFeeModule));
        emit DefaultScalingFactorSet({defaultScalingFactor: newScalingFactor});
        dynamicSwapFeeModule.setDefaultScalingFactor({_defaultScalingFactor: newScalingFactor});

        assertEqUint(dynamicSwapFeeModule.defaultScalingFactor(), newScalingFactor);
    }
}
