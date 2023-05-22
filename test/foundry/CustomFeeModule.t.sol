pragma solidity ^0.7.6;
pragma abicoder v2;

import './BaseFixture.sol';

contract CustomFeeModuleTest is BaseFixture {
    event SetCustomFee(address indexed pool, uint24 indexed fee);

    CustomFeeModule public customFeeModule;
    address public constant token0 = address(1);
    address public constant token1 = address(2);

    function setUp() public override {
        super.setUp();
        customFeeModule = new CustomFeeModule(address(factory));

        factory.setFeeModule(address(customFeeModule));

        vm.label(address(customFeeModule), 'Custom Fee Module');
    }

    function testCannotSetCustomFeeIfNotFeeManager() public {
        vm.expectRevert();
        vm.prank(address(1));
        customFeeModule.setCustomFee(address(1), 5_000);
    }

    function testCannotSetCustomFeeIfFeeTooHigh() public {
        address pool = _createAndCheckPool(token0, token1, TICK_SPACING_LOW);

        vm.expectRevert();
        customFeeModule.setCustomFee(pool, 10_001);
    }

    function testCannotSetCustomFeeIfNotPool() public {
        vm.expectRevert();
        customFeeModule.setCustomFee(address(1), 5_000);
    }

    function testSetCustomFee() public {
        address pool = _createAndCheckPool(token0, token1, TICK_SPACING_LOW);

        vm.expectEmit(true, true, false, false, address(customFeeModule));
        emit SetCustomFee(pool, 5_000);
        customFeeModule.setCustomFee(pool, 5_000);

        assertEqUint(customFeeModule.customFee(pool), 5_000);
        assertEqUint(customFeeModule.getFee(pool), 5_000);
        assertEqUint(factory.getFee(pool), 5_000);

        // revert to default fee
        vm.expectEmit(true, true, false, false, address(customFeeModule));
        emit SetCustomFee(pool, 0);
        customFeeModule.setCustomFee(pool, 0);

        assertEqUint(customFeeModule.customFee(pool), 0);
        assertEqUint(customFeeModule.getFee(pool), 500);
        assertEqUint(factory.getFee(pool), 500);

        // zero fee
        vm.expectEmit(true, true, false, false, address(customFeeModule));
        emit SetCustomFee(pool, 420);
        customFeeModule.setCustomFee(pool, 420);

        assertEqUint(customFeeModule.customFee(pool), 420);
        assertEqUint(customFeeModule.getFee(pool), 0);
        assertEqUint(factory.getFee(pool), 0);
    }
}
