pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract DeregisterDiscountedTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.deregisterDiscounted({_discountOver: users.alice});
    }

    function test_WhenCallerIsFeeManager() external {
        // It should set the discount to 0 for the _discountOver param
        // It should emit a {DiscountedDeregistered} event
        vm.startPrank({msgSender: users.feeManager});

        // first register and validate
        dynamicSwapFeeModule.registerDiscounted({_discountReceiver: users.alice, _discount: 499_999});
        assertEq(uint256(dynamicSwapFeeModule.discounted(users.alice)), 499_999);

        vm.expectEmit(true, false, false, false, address(dynamicSwapFeeModule));
        emit DiscountedDeregistered({discountOver: users.alice});
        dynamicSwapFeeModule.deregisterDiscounted({_discountOver: users.alice});

        assertEq(uint256(dynamicSwapFeeModule.discounted(users.alice)), 0);
    }
}
