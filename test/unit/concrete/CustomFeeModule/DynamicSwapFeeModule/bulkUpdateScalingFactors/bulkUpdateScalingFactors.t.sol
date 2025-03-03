pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract BulkUpdateScalingFactorsTest is DynamicSwapFeeModuleTest {
    address[] _pools;
    uint64[] _scalingFactors;
    uint64 scalingFactor1 = 1e5;
    uint64 scalingFactor2 = 100 * 1e6;
    uint64 scalingFactor3 = 1e18;

    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.bulkUpdateScalingFactors({_pools: _pools, _scalingFactors: _scalingFactors});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_WhenPoolsArrayAndScalingFactorsArrayAreNotTheSameLength() external whenCallerIsFeeManager {
        // It should revert with "LMM"
        _pools.push(address(1));
        _pools.push(address(2));
        _scalingFactors.push(scalingFactor1);

        vm.expectRevert(bytes("LMM"));
        dynamicSwapFeeModule.bulkUpdateScalingFactors({_pools: _pools, _scalingFactors: _scalingFactors});
    }

    modifier whenPoolsArrayAndScalingFactorsArrayAreTheSameLength() {
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
        _scalingFactors.push(scalingFactor1);
        _scalingFactors.push(scalingFactor2);
        _scalingFactors.push(scalingFactor3);
        _;
    }

    function test_RevertWhen_OneOfThePoolsIsInvalid()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndScalingFactorsArrayAreTheSameLength
    {
        // It should revert
        _pools[1] = address(1);

        vm.expectRevert();
        dynamicSwapFeeModule.bulkUpdateScalingFactors({_pools: _pools, _scalingFactors: _scalingFactors});
    }

    modifier whenAllPoolsAreValid() {
        _;
    }

    function test_WhenOneOfThePoolsFeeCapIsNotSet()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndScalingFactorsArrayAreTheSameLength
        whenAllPoolsAreValid
    {
        // It should revert with "ISF"
        vm.expectRevert(bytes("ISF"));
        dynamicSwapFeeModule.bulkUpdateScalingFactors({_pools: _pools, _scalingFactors: _scalingFactors});
    }

    modifier whenAllThePoolsHaveASetFeeCap() {
        dynamicSwapFeeModule.setFeeCap({_pool: _pools[0], _feeCap: 50_000});
        dynamicSwapFeeModule.setFeeCap({_pool: _pools[1], _feeCap: 50_000});
        dynamicSwapFeeModule.setFeeCap({_pool: _pools[2], _feeCap: 50_000});
        _;
    }

    function test_WhenOneOfScalingFactorIsBiggerThanMaxScalingFactor()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndScalingFactorsArrayAreTheSameLength
        whenAllPoolsAreValid
        whenAllThePoolsHaveASetFeeCap
    {
        // It should revert with "ISF"
        _scalingFactors[1] = 1e18 + 1;

        vm.expectRevert(bytes("ISF"));
        dynamicSwapFeeModule.bulkUpdateScalingFactors({_pools: _pools, _scalingFactors: _scalingFactors});
    }

    function test_WhenAllTheScalingFactorsAreBelowMaxScalingFactor()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndScalingFactorsArrayAreTheSameLength
        whenAllPoolsAreValid
        whenAllThePoolsHaveASetFeeCap
    {
        // It should update the scaling factor for all the pools
        // It should emit a {ScalingFactorSet} event for all the pools

        for (uint256 i = 0; i < pools.length; i++) {
            vm.expectEmit(address(dynamicSwapFeeModule));
            emit ScalingFactorSet({pool: _pools[i], scalingFactor: _scalingFactors[i]});
        }

        dynamicSwapFeeModule.bulkUpdateScalingFactors({_pools: _pools, _scalingFactors: _scalingFactors});

        (,, uint64 scalingFactor) = dynamicSwapFeeModule.dynamicFeeConfig(_pools[0]);
        assertEqUint(scalingFactor, scalingFactor1);
        (,, scalingFactor) = dynamicSwapFeeModule.dynamicFeeConfig(_pools[1]);
        assertEqUint(scalingFactor, scalingFactor2);
        (,, scalingFactor) = dynamicSwapFeeModule.dynamicFeeConfig(_pools[2]);
        assertEqUint(scalingFactor, scalingFactor3);
    }
}
