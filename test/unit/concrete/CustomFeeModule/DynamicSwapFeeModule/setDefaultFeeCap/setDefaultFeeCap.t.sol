pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract SetDefaultFeeCapTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.setDefaultFeeCap({_defaultFeeCap: 1});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_WhenDefaultFeeCapIsHigherThanMaxFeeCap() external whenCallerIsFeeManager {
        // It should revert with "MFC"
        vm.expectRevert(bytes("MFC"));
        dynamicSwapFeeModule.setDefaultFeeCap({_defaultFeeCap: 50_001});
    }

    function test_WhenDefaultFeeCapIsLessThanOrEqualToMaxFeeCap() external whenCallerIsFeeManager {
        // It should set defaultFeeCap
        // It should emit a {DefaultFeeCapSet} event
        vm.expectEmit(true, false, false, false, address(dynamicSwapFeeModule));
        emit DefaultFeeCapSet({defaultFeeCap: 50_000});
        dynamicSwapFeeModule.setDefaultFeeCap({_defaultFeeCap: 50_000});

        assertEq(dynamicSwapFeeModule.defaultFeeCap(), 50_000);
    }
}
