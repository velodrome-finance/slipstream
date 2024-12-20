pragma solidity ^0.7.6;
pragma abicoder v2;

import "../DynamicSwapFeeModule.t.sol";

import {console} from "forge-std/console.sol";

import {TickMath} from "contracts/core/libraries/TickMath.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";
import {ICLPoolState} from "contracts/core/interfaces/pool/ICLPoolState.sol";

/// forge-config: default.fuzz.runs = 20
contract GetFeeFuzzTest is DynamicSwapFeeModuleFuzzTest {
    Position[] public positions;

    struct Position {
        int24 tickSpacing;
        uint256 amount0;
        uint256 amount1;
        int24 tickLower;
        int24 tickUpper;
    }

    struct Swap {
        uint256 amount;
        bool zeroForOne;
    }

    mapping(int24 => bool) public validTickSpacing;

    int24[] public fixtureTickSpacing =
        [TICK_SPACING_STABLE, TICK_SPACING_LOW, TICK_SPACING_MEDIUM, TICK_SPACING_HIGH, TICK_SPACING_VOLATILE];

    function setUp() public override {
        super.setUp();

        validTickSpacing[TICK_SPACING_STABLE] = true;
        validTickSpacing[TICK_SPACING_LOW] = true;
        validTickSpacing[TICK_SPACING_MEDIUM] = true;
        validTickSpacing[TICK_SPACING_HIGH] = true;
        validTickSpacing[TICK_SPACING_VOLATILE] = true;

        ERC20 tokenA = new ERC20("", "");
        TestERC20CustomDecimals tokenB = new TestERC20CustomDecimals(6);
        (token0, token1) = tokenA < ERC20(tokenB) ? (tokenA, ERC20(tokenB)) : (ERC20(tokenB), tokenA);

        nftCallee = new NFTManagerCallee(address(token0), address(token1), address(nft));

        vm.startPrank(users.alice);
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);
        token0.approve(address(clCallee), type(uint256).max);
        token1.approve(address(clCallee), type(uint256).max);
        token0.approve(address(nftCallee), type(uint256).max);
        token1.approve(address(nftCallee), type(uint256).max);
        vm.stopPrank();

        // give some extra tokens to alice
        deal({token: address(token0), to: users.alice, give: USDC_1 * 1_000_000_000});
        deal({token: address(token1), to: users.alice, give: TOKEN_1 * 1_000_000_000});

        vm.label({account: address(token0), newLabel: "Token 0"});
        vm.label({account: address(token1), newLabel: "Token 1"});
    }

    modifier whenPoolIsSet(int24 tickSpacing) {
        vm.assume(validTickSpacing[tickSpacing]);

        pool = poolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: tickSpacing,
            sqrtPriceX96: encodePriceSqrt(1e18, 1e6)
        });

        vm.label({account: address(pool), newLabel: "Pool"});

        CLPool(pool).increaseObservationCardinalityNext(1800);
        _;
    }

    modifier whenHighLiqAroundPrice(int24 tickSpacing) {
        vm.assume(validTickSpacing[tickSpacing]);

        vm.prank(users.feeManager);
        dynamicSwapFeeModule.setCustomFee({_pool: pool, _fee: 10_000}); // 1%

        vm.startPrank({msgSender: users.alice, txOrigin: users.alice});

        (int24 tickLower, int24 tickUpper) = getTicksAtDistance(tickSpacing, 10);

        positions.push(
            Position({
                tickSpacing: tickSpacing,
                amount0: USDC_1 * 10_000,
                amount1: TOKEN_1 * 10_000,
                tickLower: tickLower,
                tickUpper: tickUpper
            })
        );

        (tickLower, tickUpper) = getTicksAtDistance(tickSpacing, 100);

        positions.push(
            Position({
                tickSpacing: tickSpacing,
                amount0: USDC_1 * 100_000,
                amount1: TOKEN_1 * 100_000,
                tickLower: tickLower,
                tickUpper: tickUpper
            })
        );

        if (tickSpacing == 2000) {
            (tickLower, tickUpper) = getTicksAtDistance(tickSpacing, 300);
            positions.push(
                Position({
                    tickSpacing: tickSpacing,
                    amount0: USDC_1 * 1_000_000,
                    amount1: TOKEN_1 * 1_000_000,
                    tickLower: tickLower,
                    tickUpper: tickUpper
                })
            );
        } else {
            (tickLower, tickUpper) = getTicksAtDistance(tickSpacing, 1000);
            positions.push(
                Position({
                    tickSpacing: tickSpacing,
                    amount0: USDC_1 * 1_000_000,
                    amount1: TOKEN_1 * 1_000_000,
                    tickLower: tickLower,
                    tickUpper: tickUpper
                })
            );
        }

        mintPositions(positions);
        _;
    }

    modifier whenObservationCardinalityIsSufficient(Swap[1800] memory swaps) {
        vm.startPrank({msgSender: users.alice, txOrigin: users.alice});
        for (uint256 i = 0; i < 1800; i++) {
            if (swaps[i].zeroForOne) {
                swaps[i].amount = bound(swaps[i].amount, USDC_1, USDC_1 * 10_000);
            } else {
                swaps[i].amount = bound(swaps[i].amount, TOKEN_1, TOKEN_1 * 10_000);
            }

            if (swaps[i].zeroForOne) {
                clCallee.swapExact0For1(address(pool), swaps[i].amount, users.alice, MIN_SQRT_RATIO + 1);
            } else {
                clCallee.swapExact1For0(address(pool), swaps[i].amount, users.alice, MAX_SQRT_RATIO - 1);
            }

            skip(2 seconds);
        }
        _;
    }

    function testFuzz_WhenTxOriginIsNotDiscounted(int24 tickSpacing, Swap[1800] memory swaps)
        external
        whenPoolIsSet(tickSpacing)
        whenHighLiqAroundPrice(tickSpacing)
        whenObservationCardinalityIsSufficient(swaps)
    {
        // It should calculate the correct dynamic fee
        // It shouldn't apply discount
        // It should return the correct total fee amount
        (, int24 currentTick,,,,) = ICLPool(pool).slot0();

        int24 twAvgTick = getTwAvgTick();

        uint256 expectedDynamicFee = getDefaultExpectedDynamicFee(currentTick, twAvgTick);

        if (10_000 + expectedDynamicFee > 20_000) {
            assertEqUint(dynamicSwapFeeModule.getFee(pool), 20_000);
        } else {
            assertEqUint(dynamicSwapFeeModule.getFee(pool), 10_000 + expectedDynamicFee);
        }
    }

    function testFuzz_WhenTxOriginIsDiscounted(int24 tickSpacing, Swap[1800] memory swaps)
        external
        whenPoolIsSet(tickSpacing)
        whenHighLiqAroundPrice(tickSpacing)
        whenObservationCardinalityIsSufficient(swaps)
    {
        // It should calculate the correct dynamic fee
        // It should apply discount
        // It should return the correct total fee amount
        vm.stopPrank();
        vm.prank(users.feeManager);
        dynamicSwapFeeModule.registerDiscounted({_discountReceiver: users.alice, _discount: 500_000});

        (, int24 currentTick,,,,) = ICLPool(pool).slot0();

        int24 twAvgTick = getTwAvgTick();

        uint256 expectedDynamicFee = getDefaultExpectedDynamicFee(currentTick, twAvgTick);

        vm.startPrank({msgSender: users.alice, txOrigin: users.alice});
        if (10_000 + expectedDynamicFee > 20_000) {
            assertEqUint(dynamicSwapFeeModule.getFee(pool), 10_000);
        } else {
            uint24 fee = dynamicSwapFeeModule.getFee(pool);
            assertEqUint(fee, (10_000 + expectedDynamicFee) / 2);
        }
    }

    /// HELPERS
    /// @dev We exclude the scaling factor from the calculation
    function getDefaultExpectedDynamicFee(int24 _currentTick, int24 _twAvgTick) internal pure returns (uint256) {
        uint24 absCurrentTick = _currentTick < 0 ? uint24(-_currentTick) : uint24(_currentTick);
        uint24 absTwAvgTick = _twAvgTick < 0 ? uint24(-_twAvgTick) : uint24(_twAvgTick);

        uint24 tickDelta = absCurrentTick > absTwAvgTick ? absCurrentTick - absTwAvgTick : absTwAvgTick - absCurrentTick;

        return tickDelta * 100;
    }

    function getTwAvgTick() public view returns (int24) {
        uint32 _twapDuration = 3600;
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = _twapDuration;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulatives,) = CLPool(pool).observe(secondsAgo);
        return int24((tickCumulatives[1] - tickCumulatives[0]) / _twapDuration);
    }

    function mintPositions(Position[] memory _positions) internal {
        for (uint256 i = 0; i < _positions.length; i++) {
            skip(1 hours);

            Position memory position = _positions[i];
            nftCallee.mintNewCustomRangePositionForUserWithCustomTickSpacing(
                position.amount0,
                position.amount1,
                position.tickLower,
                position.tickUpper,
                position.tickSpacing,
                users.alice
            );
        }
    }

    function getTicksAtDistance(int24 tickSpacing, int24 distance) internal pure returns (int24, int24) {
        // 276324 is the tick for encodePriceSqrt(1, 1) * 1e6 (79228162514264337593543950336000000)
        int24 tickLower = ((276324 - tickSpacing * distance) / tickSpacing) * tickSpacing;
        int24 tickUpper = ((276324 + tickSpacing * distance) / tickSpacing) * tickSpacing;

        return (tickLower, tickUpper);
    }
}
