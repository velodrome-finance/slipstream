pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract SetInitialFeeTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // it should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.setInitialFee({_pool: pool, _fee: 1000});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_RevertWhen_PoolDoesNotExist() external whenCallerIsFeeManager {
        // it should revert
        vm.expectRevert();
        dynamicSwapFeeModule.setInitialFee({_pool: address(0), _fee: 1000});
    }

    modifier whenPoolExists() {
        // already created in DynamicSwapFeeModuleTest
        _;
    }

    function test_WhenFeeExceedsMAX_FEE_CAPAndIsNotZERO_FEE_INDICATOR()
        external
        whenCallerIsFeeManager
        whenPoolExists
    {
        // it should revert with "MIF"
        uint24 tooHigh = uint24(dynamicSwapFeeModule.MAX_FEE_CAP()) + 1;
        vm.expectRevert(bytes("MIF"));
        dynamicSwapFeeModule.setInitialFee({_pool: pool, _fee: tooHigh});
    }

    function test_WhenFeeIsValid() external whenCallerIsFeeManager whenPoolExists {
        // it should set initialFeeEnabled to true
        // it should set initialFee
        // it should emit an {InitialFeeSet} event
        vm.expectEmit(address(dynamicSwapFeeModule));
        emit InitialFeeSet({pool: pool, initialFee: 1000});
        dynamicSwapFeeModule.setInitialFee({_pool: pool, _fee: 1000});

        (,,, bool initialFeeEnabled, uint24 initialFee) = dynamicSwapFeeModule.dynamicFeeConfig(pool);
        assertTrue(initialFeeEnabled);
        assertEqUint(initialFee, 1000);
    }
}
