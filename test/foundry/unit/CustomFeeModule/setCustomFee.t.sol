pragma solidity ^0.7.6;
pragma abicoder v2;

import {CustomFeeModuleTest} from './CustomFeeModule.t.sol';

contract SetCustomFeeTest is CustomFeeModuleTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotManager() public {
        vm.expectRevert();
        changePrank({msgSender: users.charlie});
        customFeeModule.setCustomFee({pool: address(1), fee: 5_000});
    }

    function test_RevertIf_FeeTooHigh() public {
        address pool =
            createAndCheckPool({
                factory: poolFactory,
                token0: TEST_TOKEN_0,
                token1: TEST_TOKEN_1,
                tickSpacing: TICK_SPACING_LOW
            });

        vm.expectRevert();
        customFeeModule.setCustomFee({pool: pool, fee: 10_001});
    }

    function test_RevertIf_NotPool() public {
        vm.expectRevert();
        customFeeModule.setCustomFee({pool: address(1), fee: 5_000});
    }

    function test_SetCustomFee() public {
        address pool =
            createAndCheckPool({
                factory: poolFactory,
                token0: TEST_TOKEN_0,
                token1: TEST_TOKEN_1,
                tickSpacing: TICK_SPACING_LOW
            });

        vm.expectEmit(true, true, false, false, address(customFeeModule));
        emit SetCustomFee({pool: pool, fee: 5_000});
        customFeeModule.setCustomFee({pool: pool, fee: 5_000});

        assertEqUint(customFeeModule.customFee(pool), 5_000);
        assertEqUint(customFeeModule.getFee(pool), 5_000);
        assertEqUint(poolFactory.getFee(pool), 5_000);

        // revert to default fee
        vm.expectEmit(true, true, false, false, address(customFeeModule));
        emit SetCustomFee({pool: pool, fee: 0});
        customFeeModule.setCustomFee({pool: pool, fee: 0});

        assertEqUint(customFeeModule.customFee(pool), 0);
        assertEqUint(customFeeModule.getFee(pool), 500);
        assertEqUint(poolFactory.getFee(pool), 500);

        // zero fee
        vm.expectEmit(true, true, false, false, address(customFeeModule));
        emit SetCustomFee({pool: pool, fee: 420});
        customFeeModule.setCustomFee({pool: pool, fee: 420});

        assertEqUint(customFeeModule.customFee(pool), 420);
        assertEqUint(customFeeModule.getFee(pool), 0);
        assertEqUint(poolFactory.getFee(pool), 0);
    }
}
