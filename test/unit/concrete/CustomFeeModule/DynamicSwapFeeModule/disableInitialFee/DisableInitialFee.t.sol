pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract DisableInitialFeeTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();

        vm.prank(users.feeManager);
        dynamicSwapFeeModule.setInitialFee({_pool: pool, _fee: 1000});
    }

    function test_WhenCallerIsNotFeeManager() external {
        // it should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.disableInitialFee({_pool: pool});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_RevertWhen_PoolDoesNotExist() external whenCallerIsFeeManager {
        // it should revert
        vm.expectRevert();
        dynamicSwapFeeModule.disableInitialFee({_pool: address(0)});
    }

    function test_WhenPoolExists() external whenCallerIsFeeManager {
        // it should set initialFeeEnabled to false
        // it should clear initialFee
        // it should emit an {InitialFeeDisabled} event
        vm.expectEmit(address(dynamicSwapFeeModule));
        emit InitialFeeDisabled({pool: pool});
        dynamicSwapFeeModule.disableInitialFee({_pool: pool});

        (,,, bool initialFeeEnabled, uint24 initialFee) = dynamicSwapFeeModule.dynamicFeeConfig(pool);
        assertFalse(initialFeeEnabled);
        assertEqUint(initialFee, 0);
    }
}
