pragma solidity ^0.7.6;
pragma abicoder v2;

import './BaseFixture.sol';

contract UniswapV3FactoryTest is BaseFixture {
    event TickSpacingEnabled(int24 indexed tickSpacing, uint24 indexed fee);
    event FeeManagerChanged(address indexed oldFeeManager, address indexed newFeeManager);
    event FeeModuleChanged(address indexed oldFeeModule, address indexed newFeeModule);

    function testContractDeployment() public {
        assertEq(factory.owner(), address(this));
        assertEq(factory.feeManager(), address(this));

        assertEqUint(factory.tickSpacingToFee(TICK_SPACING_LOW), 500);
        assertEqUint(factory.tickSpacingToFee(TICK_SPACING_MEDIUM), 3_000);
        assertEqUint(factory.tickSpacingToFee(TICK_SPACING_HIGH), 10_000);
    }

    function testCreatePoolWithTickSpacingLow() public {
        address pool = _createAndCheckPool(TEST_TOKEN_0, TEST_TOKEN_1, TICK_SPACING_LOW);
        assertEqUint(factory.getFee(pool), 500);
    }

    function testCreatePoolWithTickSpacingMedium() public {
        address pool = _createAndCheckPool(TEST_TOKEN_0, TEST_TOKEN_1, TICK_SPACING_MEDIUM);
        assertEqUint(factory.getFee(pool), 3_000);
    }

    function testCreatePoolWithTickSpacingHigh() public {
        address pool = _createAndCheckPool(TEST_TOKEN_0, TEST_TOKEN_1, TICK_SPACING_HIGH);
        assertEqUint(factory.getFee(pool), 10_000);
    }

    function testCannotCreatePoolWithSameTokens() public {
        vm.expectRevert();
        factory.createPool(TEST_TOKEN_0, TEST_TOKEN_0, TICK_SPACING_LOW);
    }

    function testCannotCreatePoolWithZeroAddress() public {
        vm.expectRevert();
        factory.createPool(TEST_TOKEN_0, address(0), TICK_SPACING_LOW);

        vm.expectRevert();
        factory.createPool(address(0), TEST_TOKEN_0, TICK_SPACING_LOW);

        vm.expectRevert();
        factory.createPool(address(0), address(0), TICK_SPACING_LOW);
    }

    function testCreatePoolWithReversedTokens() public {
        _createAndCheckPool(TEST_TOKEN_1, TEST_TOKEN_0, TICK_SPACING_LOW);
    }

    function testCannotCreatePoolWithTickSpacingNotEnabled() public {
        vm.expectRevert();
        factory.createPool(TEST_TOKEN_0, TEST_TOKEN_1, 250);
    }

    function testCannotEnableTickSpacingIfNotOwner() public {
        vm.expectRevert();
        vm.prank(address(1));
        factory.enableTickSpacing(250, 5_000);
    }

    function testCannotEnableTickSpacingIfTooSmall() public {
        vm.expectRevert();
        factory.enableTickSpacing(0, 5_000);
    }

    function testCannotEnableTickSpacingIfTooLarge() public {
        vm.expectRevert();
        factory.enableTickSpacing(16834, 5_000);
    }

    function testCannotEnableTickSpacingIfAlreadyEnabled() public {
        factory.enableTickSpacing(250, 5_000);
        vm.expectRevert();
        factory.enableTickSpacing(250, 5_001);
    }

    function testCannotEnableTickSpacingIfFeeTooHigh() public {
        vm.expectRevert();
        factory.enableTickSpacing(250, 1_000_000);
    }

    function testEnableTickSpacing() public {
        vm.expectEmit(true, false, false, false, address(factory));
        emit TickSpacingEnabled(250, 5_000);
        factory.enableTickSpacing(250, 5_000);

        assertEqUint(factory.tickSpacingToFee(250), 5_000);
        assertEq(factory.tickSpacings().length, 4);
        assertEq(factory.tickSpacings()[3], 250);

        _createAndCheckPool(TEST_TOKEN_0, TEST_TOKEN_1, 250);
    }

    function testCannotSetFeeManagerIfNotFeeManager() public {
        vm.expectRevert();
        vm.prank(address(1));
        factory.setFeeManager(address(1));
    }

    function testCannotSetFeeManagerWithZeroAddress() public {
        vm.expectRevert();
        factory.setFeeManager(address(0));
    }

    function testCannotSetFeeModuleIfNotFeeManager() public {
        vm.expectRevert();
        vm.prank(address(1));
        factory.setFeeModule(address(1));
    }

    function testSetFeeModule() public {
        vm.expectEmit(true, true, false, false, address(factory));
        emit FeeModuleChanged(address(0), address(1));
        factory.setFeeModule(address(1));

        assertEq(factory.feeModule(), address(1));
    }

    function testSetFeeManager() public {
        vm.expectEmit(true, true, false, false, address(factory));
        emit FeeManagerChanged(address(this), address(1));
        factory.setFeeManager(address(1));

        assertEq(factory.feeManager(), address(1));
    }
}
