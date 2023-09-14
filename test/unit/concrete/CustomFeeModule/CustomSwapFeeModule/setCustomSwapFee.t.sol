pragma solidity ^0.7.6;
pragma abicoder v2;

import {CustomSwapFeeModuleTest} from "./CustomSwapFeeModule.t.sol";

contract SetCustomSwapFeeTest is CustomSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotManager() public {
        vm.expectRevert();
        changePrank({msgSender: users.charlie});
        customSwapFeeModule.setCustomFee({pool: address(1), fee: 50});
    }

    function test_RevertIf_FeeTooHigh() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW
        });

        vm.expectRevert();
        customSwapFeeModule.setCustomFee({pool: pool, fee: 101});
    }

    function test_RevertIf_NotPool() public {
        vm.expectRevert();
        customSwapFeeModule.setCustomFee({pool: address(1), fee: 50});
    }

    function test_SetCustomFee() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW
        });

        vm.expectEmit(true, true, false, false, address(customSwapFeeModule));
        emit SetCustomFee({pool: pool, fee: 50});
        customSwapFeeModule.setCustomFee({pool: pool, fee: 50});

        assertEqUint(customSwapFeeModule.customFee(pool), 50);
        assertEqUint(customSwapFeeModule.getFee(pool), 50);
        assertEqUint(poolFactory.getSwapFee(pool), 50);

        // revert to default fee
        vm.expectEmit(true, true, false, false, address(customSwapFeeModule));
        emit SetCustomFee({pool: pool, fee: 0});
        customSwapFeeModule.setCustomFee({pool: pool, fee: 0});

        assertEqUint(customSwapFeeModule.customFee(pool), 0);
        assertEqUint(customSwapFeeModule.getFee(pool), 5);
        assertEqUint(poolFactory.getSwapFee(pool), 5);

        // zero fee
        vm.expectEmit(true, true, false, false, address(customSwapFeeModule));
        emit SetCustomFee({pool: pool, fee: 420});
        customSwapFeeModule.setCustomFee({pool: pool, fee: 420});

        assertEqUint(customSwapFeeModule.customFee(pool), 420);
        assertEqUint(customSwapFeeModule.getFee(pool), 0);
        assertEqUint(poolFactory.getSwapFee(pool), 0);
    }
}
