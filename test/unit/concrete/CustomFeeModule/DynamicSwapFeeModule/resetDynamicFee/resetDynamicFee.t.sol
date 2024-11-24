pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract ResetDynamicFeeTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.resetDynamicFee({_pool: address(0)});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_RevertWhen_ThePoolDoesntExist() external whenCallerIsFeeManager {
        // It should revert
        vm.expectRevert();
        dynamicSwapFeeModule.resetDynamicFee({_pool: address(0)});
    }

    modifier whenPoolExists() {
        // already created in DynamicSwapFeeModuleTest
        _;
    }

    function test_WhenThePoolExists() external whenCallerIsFeeManager {
        // It should set the fee cap and the scaling factor to 0
        // It should emit a {DynamicFeeReset} event
        vm.expectEmit(true, false, false, false, address(dynamicSwapFeeModule));
        emit DynamicFeeReset({pool: pool});
        dynamicSwapFeeModule.resetDynamicFee({_pool: pool});

        (uint24 baseFee, uint24 feeCap, uint64 scalingFactor) = dynamicSwapFeeModule.dynamicFeeConfig(pool);

        // should be unchanged
        assertEqUint(baseFee, 1000);
        assertEqUint(feeCap, 0);
        assertEqUint(scalingFactor, 0);
    }
}
