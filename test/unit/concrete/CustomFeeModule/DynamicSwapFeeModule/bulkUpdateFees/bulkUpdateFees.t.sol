pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

contract BulkUpdateFeesTest is DynamicSwapFeeModuleTest {
    address[] _pools;
    uint24[] _fees;
    uint24 fee1 = 1000;
    uint24 fee2 = 1111;
    uint24 fee3 = 420;

    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotFeeManager() external {
        // It should revert with "NFM"
        vm.expectRevert(bytes("NFM"));
        vm.startPrank({msgSender: users.charlie});
        dynamicSwapFeeModule.bulkUpdateFees({_pools: _pools, _fees: _fees});
    }

    modifier whenCallerIsFeeManager() {
        vm.startPrank({msgSender: users.feeManager});
        _;
    }

    function test_WhenPoolsArrayAndFeesArrayAreNotTheSameLength() external whenCallerIsFeeManager {
        // It should revert with "LMM"
        _pools.push(address(1));
        _pools.push(address(2));
        _fees.push(1);

        vm.expectRevert(bytes("LMM"));
        dynamicSwapFeeModule.bulkUpdateFees({_pools: _pools, _fees: _fees});
    }

    modifier whenPoolsArrayAndFeesArrayAreTheSameLength() {
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
        _fees.push(fee1);
        _fees.push(fee2);
        _fees.push(fee3);
        _;
    }

    function test_WhenOneOfTheFeeIsBiggerThanMaxFee()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndFeesArrayAreTheSameLength
    {
        // It should revert with "MBF"
        _fees[1] = 30_001;
        vm.expectRevert(bytes("MBF"));
        dynamicSwapFeeModule.bulkUpdateFees({_pools: _pools, _fees: _fees});
    }

    modifier whenAllTheFeesAreSmallerThanMaxFee() {
        _;
    }

    function test_RevertWhen_ThePoolIsInvalid()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndFeesArrayAreTheSameLength
        whenAllTheFeesAreSmallerThanMaxFee
    {
        // It should revert
        _pools[1] = address(3);

        vm.expectRevert();
        dynamicSwapFeeModule.bulkUpdateFees({_pools: _pools, _fees: _fees});
    }

    function test_WhenThePoolIsValid()
        external
        whenCallerIsFeeManager
        whenPoolsArrayAndFeesArrayAreTheSameLength
        whenAllTheFeesAreSmallerThanMaxFee
    {
        // It should update the fee for the pool
        // It should emit a {CustomFeeSet} event for all three pools
        for (uint256 i = 0; i < pools.length; i++) {
            vm.expectEmit(true, true, false, false, address(dynamicSwapFeeModule));
            emit CustomFeeSet({pool: _pools[i], fee: _fees[i]});
        }

        dynamicSwapFeeModule.bulkUpdateFees({_pools: _pools, _fees: _fees});

        assertEqUint(dynamicSwapFeeModule.customFee(_pools[0]), fee1);
        assertEqUint(dynamicSwapFeeModule.customFee(_pools[1]), fee2);
        assertEqUint(dynamicSwapFeeModule.customFee(_pools[2]), fee3);
    }
}
