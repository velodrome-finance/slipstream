pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract SetFeeCapTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.setFeeCap({_pool: pool, _feeCap: 1});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_RevertWhen_PoolDoesntExist() external whenCallerIsFeeManager {
        // It should revert
        vm.expectRevert();
        dynamicSwapFeeModule.setFeeCap({_pool: address(0), _feeCap: 1});
    }

    modifier whenPoolExists() {
        // already created in DynamicSwapFeeModuleTest
        _;
    }

    function test_WhenFeeCapIs0() external whenCallerIsFeeManager whenPoolExists {
        // It should revert with "MFC"
        vm.expectRevert(bytes("FC0"));
        dynamicSwapFeeModule.setFeeCap({_pool: pool, _feeCap: 0});
    }

    function test_WhenFeeCapIsHigherThanMaxFee() external whenCallerIsFeeManager whenPoolExists {
        // It should revert with "MFC"
        vm.expectRevert(bytes("MFC"));
        dynamicSwapFeeModule.setFeeCap({_pool: pool, _feeCap: 50_001});
    }

    function test_WhenFeeCapIsBiggerThan0AndLessThanOrEqualToMaxFeeCap()
        external
        whenCallerIsFeeManager
        whenPoolExists
    {
        // It should set feeCap
        // It should emit a {FeeCapSet} event
        vm.expectEmit(true, false, false, false, address(dynamicSwapFeeModule));
        emit FeeCapSet({pool: pool, feeCap: 50_000});
        dynamicSwapFeeModule.setFeeCap({_pool: pool, _feeCap: 50_000});

        (, uint24 feeCap,) = dynamicSwapFeeModule.dynamicFeeConfig(pool);
        assertEqUint(feeCap, 50_000);
    }
}
