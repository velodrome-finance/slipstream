pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract SetCustomBaseFeeTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_RevertIf_NotManager() public {
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.setCustomFee({_pool: address(1), _fee: 5_000});
    }

    function test_RevertIf_FeeTooHigh() public whenCallerIsFeeManager {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        vm.expectRevert(bytes("MBF"));
        dynamicSwapFeeModule.setCustomFee({_pool: pool, _fee: 30_001});
    }

    function test_RevertIf_NotPool() public whenCallerIsFeeManager {
        vm.expectRevert();
        dynamicSwapFeeModule.setCustomFee({_pool: address(1), _fee: 5_000});
    }

    function test_SetCustomFee() public whenCallerIsFeeManager {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        vm.expectEmit(true, true, false, false, address(dynamicSwapFeeModule));
        emit CustomFeeSet({pool: pool, fee: 5_000});
        dynamicSwapFeeModule.setCustomFee({_pool: pool, _fee: 5_000});

        assertEqUint(dynamicSwapFeeModule.customFee(pool), 5_000);
        assertEqUint(dynamicSwapFeeModule.getFee(pool), 5_000);
        assertEqUint(poolFactory.getSwapFee(pool), 5_000);

        // revert to default fee
        vm.expectEmit(true, true, false, false, address(dynamicSwapFeeModule));
        emit CustomFeeSet({pool: pool, fee: 0});
        dynamicSwapFeeModule.setCustomFee({_pool: pool, _fee: 0});

        assertEqUint(dynamicSwapFeeModule.customFee(pool), 0);
        assertEqUint(dynamicSwapFeeModule.getFee(pool), 500);
        assertEqUint(poolFactory.getSwapFee(pool), 500);

        // zero fee
        vm.expectEmit(true, true, false, false, address(dynamicSwapFeeModule));
        emit CustomFeeSet({pool: pool, fee: 420});
        dynamicSwapFeeModule.setCustomFee({_pool: pool, _fee: 420});

        assertEqUint(dynamicSwapFeeModule.customFee(pool), 420);
        assertEqUint(dynamicSwapFeeModule.getFee(pool), 0);
        assertEqUint(poolFactory.getSwapFee(pool), 0);
    }

    function test_CannotExceedMaxSwapFee() public whenCallerIsFeeManager {
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
            address(dynamicSwapFeeModule),
            abi.encodeWithSelector(CustomSwapFeeModule.getFee.selector, pool),
            abi.encode(maxFee)
        );

        // malicious Fee module with max fees
        assertEqUint(dynamicSwapFeeModule.getFee(pool), maxFee);
        // max fee still allowed by PoolFactory
        assertEqUint(poolFactory.getSwapFee(pool), maxFee);

        vm.mockCall(
            address(dynamicSwapFeeModule),
            abi.encodeWithSelector(CustomSwapFeeModule.getFee.selector, pool),
            abi.encode(maxFee + 1)
        );

        // malicious Fee module with exceedingly large fees
        assertEqUint(dynamicSwapFeeModule.getFee(pool), maxFee + 1);
        // if fee is too large, PoolFactory returns original fee
        assertEqUint(poolFactory.getSwapFee(pool), initialFee);
    }
}
