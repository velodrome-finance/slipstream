pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract BulkUpdateFeeCapsTest is DynamicSwapFeeModuleTest {
    address[] _pools;
    uint24[] _feeCaps;
    uint24 feeCap1 = 1;
    uint24 feeCap2 = 1000;
    uint24 feeCap3 = 50_000;

    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.bulkUpdateFeeCaps({_pools: _pools, _feeCaps: _feeCaps});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_WhenPoolsArrayAndFeeCapsArrayAreNotTheSameLength() external whenCallerIsFeeManager {
        // It should revert with "LMM"
        _pools.push(address(1));
        _pools.push(address(2));
        _feeCaps.push(feeCap1);

        vm.expectRevert(bytes("LMM"));
        dynamicSwapFeeModule.bulkUpdateFeeCaps({_pools: _pools, _feeCaps: _feeCaps});
    }

    modifier whenPoolsArrayAndFeeCapsArrayAreTheSameLength() {
        address pool1 = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        address pool2 = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_HIGH,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        address pool3 = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_STABLE,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        _pools.push(pool1);
        _pools.push(pool2);
        _pools.push(pool3);
        _feeCaps.push(feeCap1);
        _feeCaps.push(feeCap2);
        _feeCaps.push(feeCap3);
        _;
    }

    function test_RevertWhen_OneOfThePoolsIsInvalid()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndFeeCapsArrayAreTheSameLength
    {
        // It should revert
        _pools[1] = address(1);

        vm.expectRevert();
        dynamicSwapFeeModule.bulkUpdateFeeCaps({_pools: _pools, _feeCaps: _feeCaps});
    }

    modifier whenAllPoolsAreValid() {
        _;
    }

    function test_WhenOneOfTheFeeCapIs0()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndFeeCapsArrayAreTheSameLength
        whenAllPoolsAreValid
    {
        // It should revert with "FC0"

        _feeCaps[1] = 0;
        vm.expectRevert(bytes("FC0"));
        dynamicSwapFeeModule.bulkUpdateFeeCaps({_pools: _pools, _feeCaps: _feeCaps});
    }

    function test_WhenOneOfTheFeeCapIsBiggerThanMaxFeeCap()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndFeeCapsArrayAreTheSameLength
        whenAllPoolsAreValid
    {
        // It should revert with "MFC"
        _feeCaps[1] = 50_001;
        vm.expectRevert(bytes("MFC"));
        dynamicSwapFeeModule.bulkUpdateFeeCaps({_pools: _pools, _feeCaps: _feeCaps});
    }

    function test_WhenAllTheFeeCapsAreWithinRange()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndFeeCapsArrayAreTheSameLength
        whenAllPoolsAreValid
    {
        // It should update the fee cap for all the pools
        // It should emit a {FeeCapSet} event for all the pools

        for (uint256 i = 0; i < pools.length; i++) {
            vm.expectEmit(address(dynamicSwapFeeModule));
            emit FeeCapSet({pool: _pools[i], feeCap: _feeCaps[i]});
        }

        dynamicSwapFeeModule.bulkUpdateFeeCaps({_pools: _pools, _feeCaps: _feeCaps});

        (, uint24 feeCap,) = dynamicSwapFeeModule.dynamicFeeConfig(_pools[0]);
        assertEqUint(feeCap, feeCap1);
        (, feeCap,) = dynamicSwapFeeModule.dynamicFeeConfig(_pools[1]);
        assertEqUint(feeCap, feeCap2);
        (, feeCap,) = dynamicSwapFeeModule.dynamicFeeConfig(_pools[2]);
        assertEqUint(feeCap, feeCap3);
    }
}
