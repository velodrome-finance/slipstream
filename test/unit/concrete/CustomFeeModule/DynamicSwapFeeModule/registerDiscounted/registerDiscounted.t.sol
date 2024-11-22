pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract RegisterDiscountedTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.registerDiscounted({_discountReceiver: users.alice, _discount: 500_001});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_WhenDiscountIsHigherThanMaxDiscountCap() external whenCallerIsFeeManager {
        // It should revert with "MDC"
        vm.expectRevert(bytes("MDC"));
        dynamicSwapFeeModule.registerDiscounted({_discountReceiver: users.alice, _discount: 500_001});
    }

    function test_WhenDiscountIsLessThanOrEqualToMaxDiscountCap() external whenCallerIsFeeManager {
        // It should set discount for the _discountReceiver parameter
        // It should emit a {DiscountedRegistered} event
        vm.expectEmit(true, true, false, false, address(dynamicSwapFeeModule));
        emit DiscountedRegistered({discountReceiver: users.alice, discount: 500_000});
        dynamicSwapFeeModule.registerDiscounted({_discountReceiver: users.alice, _discount: 500_000});

        assertEqUint(dynamicSwapFeeModule.discounted(users.alice), 500_000);
    }
}
