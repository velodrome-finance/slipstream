pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../BaseFixture.sol";

contract DynamicSwapFeeModuleTest is BaseFixture {
    address pool;
    address[] pools;
    uint24[] fees;

    function setUp() public virtual override {
        super.setUp();

        pool = poolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        pools.push(pool);
        fees.push(1000);

        dynamicSwapFeeModule = new DynamicSwapFeeModule({
            _factory: address(poolFactory),
            _defaultScalingFactor: 100 * 1e6,
            _defaultFeeCap: 20_000,
            _pools: pools,
            _fees: fees
        });

        vm.prank(users.feeManager);
        poolFactory.setSwapFeeModule({_swapFeeModule: address(dynamicSwapFeeModule)});

        vm.label({account: address(dynamicSwapFeeModule), newLabel: "Dynamic Swap Fee Module"});
    }

    function test_InitialState() public view {
        assertEq(dynamicSwapFeeModule.MAX_BASE_FEE(), 30_000);
        assertEq(dynamicSwapFeeModule.MAX_DISCOUNT(), 500_000);
        assertEq(dynamicSwapFeeModule.MAX_FEE_CAP(), 50_000);
        assertEq(dynamicSwapFeeModule.MAX_SCALING_FACTOR(), 1e18);
        assertEq(dynamicSwapFeeModule.defaultScalingFactor(), 100 * dynamicSwapFeeModule.SCALING_PRECISION());
        assertEq(dynamicSwapFeeModule.defaultFeeCap(), 20_000);
        assertEqUint(dynamicSwapFeeModule.MIN_SECONDS_AGO(), 2);
        assertEqUint(dynamicSwapFeeModule.MAX_SECONDS_AGO(), 65535 * 2);
        assertEqUint(dynamicSwapFeeModule.customFee(pool), 1000);
        assertEq(address(dynamicSwapFeeModule.factory()), address(poolFactory));
    }

    function test_RevertIf_DefaultFeeCapIsHigherThanMaxFeeCap() public {
        vm.expectRevert(bytes("MFC"));
        new DynamicSwapFeeModule({
            _factory: address(poolFactory),
            _defaultScalingFactor: 1000,
            _defaultFeeCap: 50_001,
            _pools: pools,
            _fees: fees
        });
    }

    function test_RevertIf_DefaultScalingFactorIsHigherThanMaxScalingFactorCap() public {
        vm.expectRevert(bytes("ISF"));
        new DynamicSwapFeeModule({
            _factory: address(poolFactory),
            _defaultScalingFactor: 1e18 + 1,
            _defaultFeeCap: 20_000,
            _pools: pools,
            _fees: fees
        });
    }

    function test_DeployEmitsEvents() public {
        vm.expectEmit(true, true, false, false);
        emit CustomFeeSet({pool: pool, fee: 1000});
        vm.expectEmit(true, false, false, false);
        emit DefaultScalingFactorSet({defaultScalingFactor: 1e18});
        vm.expectEmit(true, false, false, false);
        emit DefaultFeeCapSet({defaultFeeCap: 50_000});
        new DynamicSwapFeeModule({
            _factory: address(poolFactory),
            _defaultScalingFactor: 1e18,
            _defaultFeeCap: 50_000,
            _pools: pools,
            _fees: fees
        });
    }
}
