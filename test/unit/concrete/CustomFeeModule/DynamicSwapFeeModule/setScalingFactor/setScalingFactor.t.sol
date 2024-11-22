pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract SetScalingFactorTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.setScalingFactor({_pool: pool, _scalingFactor: 1});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_RevertWhen_PoolDoesntExist() external whenCallerIsFeeManager {
        // It should revert
        vm.expectRevert();
        dynamicSwapFeeModule.setScalingFactor({_pool: address(0), _scalingFactor: 1});
    }

    modifier whenPoolExists() {
        // already created in DynamicSwapFeeModuleTest
        _;
    }

    function test_WhenFeeCapIsSetTo0() external whenCallerIsFeeManager whenPoolExists {
        // It should revert with "ISF"
        vm.expectRevert(bytes("ISF"));
        dynamicSwapFeeModule.setScalingFactor({_pool: pool, _scalingFactor: 1});
    }

    modifier whenFeeCapIsNot0() {
        dynamicSwapFeeModule.setFeeCap({_pool: pool, _feeCap: 1111});
        _;
    }

    function test_WhenScalingFactorIsHigherThanMaxScalingFactorCap()
        external
        whenCallerIsFeeManager
        whenPoolExists
        whenFeeCapIsNot0
    {
        // It should revert with "ISF"
        vm.expectRevert(bytes("ISF"));
        dynamicSwapFeeModule.setScalingFactor({_pool: pool, _scalingFactor: 1e18 + 1});
    }

    function test_WhenScalingFactorIsLessThanMaxScalingFactorCap()
        external
        whenCallerIsFeeManager
        whenPoolExists
        whenFeeCapIsNot0
    {
        // It should set scaling factor
        // It should emit a {ScalingFactorSet} event

        uint64 newScalingFactor = 1e18;

        vm.expectEmit(true, true, false, false, address(dynamicSwapFeeModule));
        emit ScalingFactorSet({pool: pool, scalingFactor: newScalingFactor});
        dynamicSwapFeeModule.setScalingFactor({_pool: pool, _scalingFactor: newScalingFactor});

        (,, uint64 K) = dynamicSwapFeeModule.dynamicFeeConfig(pool);
        assertEqUint(K, newScalingFactor);
    }
}
