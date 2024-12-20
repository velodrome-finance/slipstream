pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

import {TickMath} from "contracts/core/libraries/TickMath.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";
import {ICLPoolState} from "contracts/core/interfaces/pool/ICLPoolState.sol";

contract GetFeeTest is DynamicSwapFeeModuleTest {
    function setUp() public override {
        super.setUp();

        // skip some initial time
        skip(10000 seconds);
        // add some liq
        vm.prank(users.alice);
        nftCallee.mintNewCustomRangePositionForUserWithCustomTickSpacing(
            TOKEN_1 * 100,
            TOKEN_1 * 100,
            -TICK_SPACING_LOW * 1000,
            TICK_SPACING_LOW * 1000,
            TICK_SPACING_LOW,
            users.alice
        );
    }

    function test_WhenBaseFeeIsZeroFeeIndicator() external {
        // It should return zero
        vm.prank(users.feeManager);
        dynamicSwapFeeModule.setCustomFee({_pool: pool, _fee: 420});

        assertEqUint(dynamicSwapFeeModule.getFee(pool), 0);
    }

    modifier whenBaseFeeIsNotZeroFeeIndicator() {
        vm.prank(users.feeManager);
        dynamicSwapFeeModule.setCustomFee({_pool: pool, _fee: 10_000}); // 1%
        _;
    }

    modifier whenScalingFactorIsNotSetOnThePool() {
        _;
    }

    modifier whenObservationCardinalityIsInsufficient() {
        _;
    }

    function test_WhenTxOriginIsNotDiscounted()
        external
        whenBaseFeeIsNotZeroFeeIndicator
        whenScalingFactorIsNotSetOnThePool
        whenObservationCardinalityIsInsufficient
    {
        // It should return 0 for dynamic fee
        // It shouldn't apply discount
        // It should return the correct total fee amount
        assertEqUint(dynamicSwapFeeModule.getFee(pool), 10_000);
    }

    function test_WhenTxOriginIsDiscounted()
        external
        whenBaseFeeIsNotZeroFeeIndicator
        whenScalingFactorIsNotSetOnThePool
        whenObservationCardinalityIsInsufficient
    {
        // It should return 0 for dynamic fee
        // It should apply discount
        // It should return the correct total fee amount
        vm.prank(users.feeManager);
        dynamicSwapFeeModule.registerDiscounted({_discountReceiver: users.alice, _discount: 500_000});

        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        uint24 fee = dynamicSwapFeeModule.getFee(pool);

        assertEqUint(fee, 5_000);
    }

    modifier whenObservationCardinalityIsSufficient() {
        setCardinalityNextAndDoSwaps();
        _;
    }

    modifier whenTotalFeeIsLessThanFeeCap() {
        _;
    }

    function test_WhenTxOriginIsNotDiscounted_()
        external
        whenBaseFeeIsNotZeroFeeIndicator
        whenScalingFactorIsNotSetOnThePool
        whenObservationCardinalityIsSufficient
        whenTotalFeeIsLessThanFeeCap
    {
        // It should calculate the correct dynamic fee with the default scaling factor and fee cap
        // It shouldn't apply discount
        // It should return the correct total fee amount
        (, int24 currentTick,,,,) = ICLPool(pool).slot0();

        int24 twAvgTick = getTwAvgTick();

        uint256 expectedDynamicFee =
            getExpectedDynamicFee({_scalingFactor: 100, _currentTick: currentTick, _twAvgTick: twAvgTick}); // 4700

        assertEqUint(dynamicSwapFeeModule.getFee(pool), 10_000 + expectedDynamicFee);
    }

    function test_WhenTxOriginIsDiscounted_()
        external
        whenBaseFeeIsNotZeroFeeIndicator
        whenScalingFactorIsNotSetOnThePool
        whenObservationCardinalityIsSufficient
        whenTotalFeeIsLessThanFeeCap
    {
        // It should calculate the correct dynamic fee with the default scaling factor and fee cap
        // It should apply discount on the total fee
        // It should return the correct total fee amount
        vm.prank(users.feeManager);
        dynamicSwapFeeModule.registerDiscounted({_discountReceiver: users.alice, _discount: 500_000});

        (, int24 currentTick,,,,) = ICLPool(pool).slot0();

        int24 twAvgTick = getTwAvgTick();

        uint256 expectedDynamicFee =
            getExpectedDynamicFee({_scalingFactor: 100, _currentTick: currentTick, _twAvgTick: twAvgTick}); // 4700

        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        uint24 fee = dynamicSwapFeeModule.getFee(pool);

        assertEqUint(fee, (10_000 + expectedDynamicFee) / 2);
    }

    modifier whenTotalFeeIsMoreThanFeeCap() {
        // swapping a relatively big amount of token0 to move the price by a lot
        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        clCallee.swapExact0For1(address(pool), 1e20, users.alice, MIN_SQRT_RATIO + 1);
        skip(2 seconds);
        _;
    }

    function test_WhenTxOriginIsNotDiscounted__()
        external
        whenBaseFeeIsNotZeroFeeIndicator
        whenScalingFactorIsNotSetOnThePool
        whenObservationCardinalityIsSufficient
        whenTotalFeeIsMoreThanFeeCap
    {
        // It should calculate the correct dynamic fee
        // It shouldn't apply discount
        // It should return the correct total fee amount
        assertEqUint(dynamicSwapFeeModule.getFee(pool), 20_000);
    }

    function test_WhenTxOriginIsDiscounted__()
        external
        whenBaseFeeIsNotZeroFeeIndicator
        whenScalingFactorIsNotSetOnThePool
        whenObservationCardinalityIsSufficient
        whenTotalFeeIsMoreThanFeeCap
    {
        // It should calculate the correct dynamic fee
        // It should apply discount on the total fee
        // It should return the correct total fee amount
        vm.prank(users.feeManager);
        dynamicSwapFeeModule.registerDiscounted({_discountReceiver: users.alice, _discount: 500_000});

        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        uint24 fee = dynamicSwapFeeModule.getFee(pool);

        assertEqUint(fee, 10_000);
    }

    modifier whenScalingFactorIsSetOnThePool() {
        vm.startPrank(users.feeManager);
        dynamicSwapFeeModule.setFeeCap({_pool: pool, _feeCap: 30_000});
        dynamicSwapFeeModule.setScalingFactor({
            _pool: pool,
            _scalingFactor: uint64(200 * dynamicSwapFeeModule.SCALING_PRECISION())
        });
        vm.stopPrank();
        _;
    }

    modifier whenObservationCardinalityIsSufficient_() {
        setCardinalityNextAndDoSwaps();
        _;
    }

    modifier whenTotalFeeIsLessThanFeeCap_() {
        _;
    }

    function test_WhenTxOriginIsNotDiscounted___()
        external
        whenBaseFeeIsNotZeroFeeIndicator
        whenScalingFactorIsSetOnThePool
        whenObservationCardinalityIsSufficient_
        whenTotalFeeIsLessThanFeeCap_
    {
        // It should calculate the correct dynamic fee with the pool scaling factor and fee cap
        // It shouldn't apply discount
        // It should return the correct total fee amount
        (, int24 currentTick,,,,) = ICLPool(pool).slot0();

        int24 twAvgTick = getTwAvgTick();

        uint256 expectedDynamicFee =
            getExpectedDynamicFee({_scalingFactor: 200, _currentTick: currentTick, _twAvgTick: twAvgTick}); // 9400

        assertEqUint(dynamicSwapFeeModule.getFee(pool), 10_000 + expectedDynamicFee);
    }

    function test_WhenTxOriginIsDiscounted___()
        external
        whenBaseFeeIsNotZeroFeeIndicator
        whenScalingFactorIsSetOnThePool
        whenObservationCardinalityIsSufficient_
        whenTotalFeeIsLessThanFeeCap_
    {
        // It should calculate the correct dynamic fee with the pool scaling factor and fee cap
        // It should apply discount on the total fee
        // It should return the correct total fee amount
        vm.prank(users.feeManager);
        dynamicSwapFeeModule.registerDiscounted({_discountReceiver: users.alice, _discount: 500_000});

        (, int24 currentTick,,,,) = ICLPool(pool).slot0();

        int24 twAvgTick = getTwAvgTick();

        uint256 expectedDynamicFee =
            getExpectedDynamicFee({_scalingFactor: 200, _currentTick: currentTick, _twAvgTick: twAvgTick}); // 9400

        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        uint24 fee = dynamicSwapFeeModule.getFee(pool);

        assertEqUint(fee, (10_000 + expectedDynamicFee) / 2);
    }

    modifier whenTotalFeeIsMoreThanFeeCap_() {
        // swapping a relatively big amount of token0 to move the price by a lot
        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        clCallee.swapExact0For1(address(pool), 1e20, users.alice, MIN_SQRT_RATIO + 1);
        skip(2 seconds);
        _;
    }

    function test_WhenTxOriginIsNotDiscounted____()
        external
        whenBaseFeeIsNotZeroFeeIndicator
        whenScalingFactorIsSetOnThePool
        whenObservationCardinalityIsSufficient_
        whenTotalFeeIsMoreThanFeeCap_
    {
        // It should calculate the correct dynamic fee
        // It shouldn't apply discount
        // It should return the correct total fee amount
        assertEqUint(dynamicSwapFeeModule.getFee(pool), 30_000);
    }

    function test_WhenTxOriginIsDiscounted____()
        external
        whenBaseFeeIsNotZeroFeeIndicator
        whenScalingFactorIsSetOnThePool
        whenObservationCardinalityIsSufficient_
        whenTotalFeeIsMoreThanFeeCap_
    {
        // It should calculate the correct dynamic fee
        // It should apply discount on the total fee
        // It should return the correct total fee amount
        vm.prank(users.feeManager);
        dynamicSwapFeeModule.registerDiscounted({_discountReceiver: users.alice, _discount: 500_000});

        vm.prank({msgSender: users.alice, txOrigin: users.alice});
        uint24 fee = dynamicSwapFeeModule.getFee(pool);

        assertEqUint(fee, 15_000);
    }

    /// HELPERS

    function setCardinalityNextAndDoSwaps() internal {
        CLPool(pool).increaseObservationCardinalityNext(1800);

        vm.startPrank({msgSender: users.alice, txOrigin: users.alice});

        // do one bigger swap beforhand so we move away from tick 0
        clCallee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);
        skip(2 seconds);

        for (uint256 i = 0; i < 1799; i++) {
            if (i % 2 == 0) {
                clCallee.swapExact1For0(address(pool), 1e17, users.alice, MAX_SQRT_RATIO - 1);
            } else {
                clCallee.swapExact0For1(address(pool), 1e17, users.alice, MIN_SQRT_RATIO + 1);
            }
            skip(2 seconds);
        }
        vm.stopPrank();
    }

    /// @dev We exclude the scaling factor from the calculation
    function getExpectedDynamicFee(uint256 _scalingFactor, int24 _currentTick, int24 _twAvgTick)
        internal
        pure
        returns (uint256)
    {
        uint24 absCurrentTick = _currentTick < 0 ? uint24(-_currentTick) : uint24(_currentTick);
        uint24 absTwAvgTick = _twAvgTick < 0 ? uint24(-_twAvgTick) : uint24(_twAvgTick);

        uint24 tickDelta = absCurrentTick > absTwAvgTick ? absCurrentTick - absTwAvgTick : absTwAvgTick - absCurrentTick;

        return tickDelta * _scalingFactor;
    }

    function getTwAvgTick() public view returns (int24) {
        uint32 _twapDuration = 3600;
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = _twapDuration;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulatives,) = CLPool(pool).observe(secondsAgo);
        return int24((tickCumulatives[1] - tickCumulatives[0]) / _twapDuration);
    }
}
