pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CustomSwapFeeModule.t.sol";

contract SetCustomSwapFeeTest is CustomSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotManager() public {
        vm.expectRevert();
        vm.startPrank({msgSender: users.charlie});
        customSwapFeeModule.setCustomFee({pool: address(1), fee: 5_000});
    }

    function test_RevertIf_FeeTooHigh() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        vm.expectRevert();
        customSwapFeeModule.setCustomFee({pool: pool, fee: 30_001});
    }

    function test_RevertIf_NotPool() public {
        vm.expectRevert();
        customSwapFeeModule.setCustomFee({pool: address(1), fee: 5_000});
    }

    function test_SetCustomFee() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        vm.expectEmit(true, true, false, false, address(customSwapFeeModule));
        emit SetCustomFee({pool: pool, fee: 5_000});
        customSwapFeeModule.setCustomFee({pool: pool, fee: 5_000});

        assertEqUint(customSwapFeeModule.customFee(pool), 5_000);
        assertEqUint(customSwapFeeModule.getFee(pool), 5_000);
        assertEqUint(poolFactory.getSwapFee(pool), 5_000);

        // revert to default fee
        vm.expectEmit(true, true, false, false, address(customSwapFeeModule));
        emit SetCustomFee({pool: pool, fee: 0});
        customSwapFeeModule.setCustomFee({pool: pool, fee: 0});

        assertEqUint(customSwapFeeModule.customFee(pool), 0);
        assertEqUint(customSwapFeeModule.getFee(pool), 500);
        assertEqUint(poolFactory.getSwapFee(pool), 500);

        // zero fee
        vm.expectEmit(true, true, false, false, address(customSwapFeeModule));
        emit SetCustomFee({pool: pool, fee: 420});
        customSwapFeeModule.setCustomFee({pool: pool, fee: 420});

        assertEqUint(customSwapFeeModule.customFee(pool), 420);
        assertEqUint(customSwapFeeModule.getFee(pool), 0);
        assertEqUint(poolFactory.getSwapFee(pool), 0);
    }

    function test_CannotExceedMaxSwapFee() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
        uint24 initialFee = poolFactory.getSwapFee(pool);
        uint24 maxFee = 100_000;

        // simulating a malicious SwapFeeModule without max fees
        vm.mockCall(
            address(customSwapFeeModule),
            abi.encodeWithSelector(CustomSwapFeeModule.getFee.selector, pool),
            abi.encode(maxFee)
        );

        // malicious Fee module with max fees
        assertEqUint(customSwapFeeModule.getFee(pool), maxFee);
        // max fee still allowed by PoolFactory
        assertEqUint(poolFactory.getSwapFee(pool), maxFee);

        vm.mockCall(
            address(customSwapFeeModule),
            abi.encodeWithSelector(CustomSwapFeeModule.getFee.selector, pool),
            abi.encode(maxFee + 1)
        );

        // malicious Fee module with exceedingly large fees
        assertEqUint(customSwapFeeModule.getFee(pool), maxFee + 1);
        // if fee is too large, PoolFactory returns original fee
        assertEqUint(poolFactory.getSwapFee(pool), initialFee);
    }
}
