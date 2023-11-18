pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3PoolTest} from "../UniswapV3Pool.t.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";
import {UnsafeMath} from "contracts/core/libraries/UnsafeMath.sol";
import {TickMath} from "contracts/core/libraries/TickMath.sol";
import {INonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";

// calculate fees is an internal function but we test the correct functionality here
contract CalculateFeesTest is UniswapV3PoolTest {
    UniswapV3Pool public pool;
    CLGauge public gauge;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);

        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.alice);

        skipToNextEpoch(0);
    }

    function assertFees(uint256 t0, uint256 t1, uint256 fg0, uint256 fg1) internal {
        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertApproxEqAbs(_token0, t0, 2);
        assertApproxEqAbs(_token1, t1, 2);
        assertApproxEqAbs(pool.feeGrowthGlobal0X128(), fg0, 2);
        assertApproxEqAbs(pool.feeGrowthGlobal1X128(), fg1, 2);
    }

    function calculateFeeGrowthX128(uint256 feeAmount, uint256 unstakedLiquidity) internal pure returns (uint256) {
        return FullMath.mulDiv(feeAmount, Q128, unstakedLiquidity);
    }

    function test_FeesCalculatedCorrectlyDuringSwapsAllFullRangePositionsStaked() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);
        assertFees(3e15, 0, 0, 0);

        // swap 3 token0
        uniswapV3Callee.swapExact0For1(address(pool), 3e18, users.alice, MIN_SQRT_RATIO + 1);
        assertFees(12e15, 0, 0, 0);

        // swap 1 token1
        uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);
        assertFees(12e15, 3e15, 0, 0);

        // swap 2 token1
        uniswapV3Callee.swapExact1For0(address(pool), 2e18, users.alice, MAX_SQRT_RATIO - 1);
        // we have to add 1 to pass the assert, probably some precision loss during swap
        assertFees(12e15, 9e15 + 1, 0, 0);

        gauge.withdraw(tokenId);

        nft.approve(address(nftCallee), tokenId);
        (uint256 amount0TokenId, uint256 amountTtokenId) = nftCallee.collectAllForTokenId(tokenId, users.alice);
        assertEq(amount0TokenId, 0);
        assertEq(amountTtokenId, 0);
    }

    function test_FeesCalculatedCorrectlyDuringSwapsFullRangePositionsPartiallyStaked() public {
        uint256 liquidity = TOKEN_1 * 10;

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(15e14, liquidity);
        assertFees(15e14, 0, feeGrowthGlobal0X128, 0);

        // swap 3 token0
        uniswapV3Callee.swapExact0For1(address(pool), 3e18, users.alice, MIN_SQRT_RATIO + 1);

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(45e14, liquidity);
        assertFees(15e14 + 45e14, 0, feeGrowthGlobal0X128, 0);

        // swap 1 token1
        uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

        feeGrowthGlobal1X128 += calculateFeeGrowthX128(15e14, liquidity);
        assertFees(15e14 + 45e14, 15e14, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        // swap 2 token1
        uniswapV3Callee.swapExact1For0(address(pool), 2e18, users.alice, MAX_SQRT_RATIO - 1);
        feeGrowthGlobal1X128 += calculateFeeGrowthX128(3e15, liquidity);

        assertFees(15e14 + 45e14, 15e14 + 3e15, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        gauge.withdraw(tokenId);

        {
            nft.approve(address(nftCallee), tokenId);
            (uint256 amount0TokenId, uint256 amountTtokenId) = nftCallee.collectAllForTokenId(tokenId, users.alice);
            assertEq(amount0TokenId, 0);
            assertEq(amountTtokenId, 0);

            nft.approve(address(nftCallee), tokenId2);
            (uint256 amount0TokenId2, uint256 amountTtokenId2) = nftCallee.collectAllForTokenId(tokenId2, users.alice);
            assertApproxEqAbs(amount0TokenId2, 6e15, 1);
            assertApproxEqAbs(amountTtokenId2, 45e14, 1);
        }
    }

    function test_FeesCalculatedCorrectlyDuringSwapsFullRangePositionsPartiallyStakedWithIntermediaryFlashLoan()
        public
    {
        uint256 liquidity = TOKEN_1 * 10;

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(15e14, liquidity);
        assertFees(15e14, 0, feeGrowthGlobal0X128, 0);

        // swap 3 token0
        uniswapV3Callee.swapExact0For1(address(pool), 3e18, users.alice, MIN_SQRT_RATIO + 1);

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(45e14, liquidity);
        assertFees(15e14 + 45e14, 0, feeGrowthGlobal0X128, 0);

        // fee is 0.006
        uint256 pay = TOKEN_1 * 2 + 6e15;
        uniswapV3Callee.flash(address(pool), users.alice, TOKEN_1 * 2, TOKEN_1 * 2, pay, pay);

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(3e15, liquidity);
        feeGrowthGlobal1X128 += calculateFeeGrowthX128(3e15, liquidity);
        assertFees(15e14 + 45e14 + 3e15, 3e15, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        // swap 1 token1
        uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

        feeGrowthGlobal1X128 += calculateFeeGrowthX128(15e14, liquidity);
        assertFees(9e15, 3e15 + 15e14, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        // swap 2 token1
        uniswapV3Callee.swapExact1For0(address(pool), 2e18, users.alice, MAX_SQRT_RATIO - 1);

        feeGrowthGlobal1X128 += calculateFeeGrowthX128(3e15, liquidity);
        assertFees(9e15, 3e15 + 15e14 + 3e15, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        gauge.withdraw(tokenId);

        {
            nft.approve(address(nftCallee), tokenId);
            (uint256 amount0TokenId, uint256 amountTtokenId) = nftCallee.collectAllForTokenId(tokenId, users.alice);
            assertEq(amount0TokenId, 0);
            assertEq(amountTtokenId, 0);

            nft.approve(address(nftCallee), tokenId2);
            (uint256 amount0TokenId2, uint256 amountTtokenId2) = nftCallee.collectAllForTokenId(tokenId2, users.alice);
            assertApproxEqAbs(amount0TokenId2, 9e15, 1);
            assertApproxEqAbs(amountTtokenId2, 75e14, 1);
        }
    }

    function test_FeesCalculatedCorrectlyDuringSwapsFullRangePositionsIntermediaryUnstakeAndStake() public {
        uint256 liquidity = TOKEN_1 * 10;

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(15e14, liquidity);
        assertFees(15e14, 0, feeGrowthGlobal0X128, 0);

        gauge.withdraw(tokenId);

        // swap 3 token0
        uniswapV3Callee.swapExact0For1(address(pool), 3e18, users.alice, MIN_SQRT_RATIO + 1);

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(9e15, liquidity * 2);
        assertFees(15e14, 0, feeGrowthGlobal0X128, 0);

        // swap 1 token1
        uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

        feeGrowthGlobal1X128 += calculateFeeGrowthX128(3e15, liquidity * 2);
        assertFees(15e14, 0, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        uint256 pre0BalTokenId = token0.balanceOf(users.alice);
        uint256 pre1BalTokenId = token1.balanceOf(users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // deposit should collect already accumulated fees
        assertApproxEqAbs(token0.balanceOf(users.alice), pre0BalTokenId + (9e15 / 2), 1);
        assertApproxEqAbs(token1.balanceOf(users.alice), pre1BalTokenId + (3e15 / 2), 1);

        // swap 2 token1
        uniswapV3Callee.swapExact1For0(address(pool), 2e18, users.alice, MAX_SQRT_RATIO - 1);
        feeGrowthGlobal1X128 += calculateFeeGrowthX128(3e15, liquidity);

        assertFees(15e14, 3e15, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        {
            nft.approve(address(nftCallee), tokenId2);
            (uint256 amount0TokenId2, uint256 amountTtokenId2) = nftCallee.collectAllForTokenId(tokenId2, users.alice);
            assertApproxEqAbs(amount0TokenId2, 15e14 + (9e15 / 2), 1);
            assertApproxEqAbs(amountTtokenId2, 3e15 + (3e15 / 2), 1);
        }
    }

    function test_FeesCalculatedCorrectlySwappingOutAndIntoStakedRangePosition() public {
        uint256 liquidity = TOKEN_1 * 10;

        // adding 29953549559107810 as amount0 and amount1 will be equal to ~10 liquidity
        uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            29953549559107810, 29953549559107810, -TICK_SPACING_60, TICK_SPACING_60, users.alice
        );

        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        assertApproxEqAbs(uint256(pool.stakedLiquidity()), 10e18, 1e3);

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        assertEqUint(pool.stakedLiquidity(), 0);

        //calculate amountIn for the range where both staked and unstaked liq is present

        // sqrtPriceNextX96
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(-TICK_SPACING_60);
        // sqrtPriceStartX96
        uint160 sqrtRatioBX96 = encodePriceSqrt(1, 1);
        // liquidity * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
        uint256 amountIn = UnsafeMath.divRoundingUp(
            FullMath.mulDivRoundingUp(uint256(liquidity * 2) << 96, sqrtRatioBX96 - sqrtRatioAX96, sqrtRatioBX96),
            sqrtRatioAX96
        );

        uint256 feeInStakedRange = FullMath.mulDivRoundingUp(amountIn, 3_000, 1e6 - 3_000);

        uint256 feeGrowthGlobal0X128InStakedRange = calculateFeeGrowthX128(feeInStakedRange / 2, liquidity);

        // add 1 to get full precision
        uint256 feeGrowthGlobal0X128UnstakedRange = calculateFeeGrowthX128(3e15 - feeInStakedRange, liquidity);

        assertFees(feeInStakedRange / 2, 0, feeGrowthGlobal0X128UnstakedRange + feeGrowthGlobal0X128InStakedRange, 0);

        // sqrtPriceStartX96
        (sqrtRatioAX96,,,,,) = pool.slot0();

        // add 1 to get full precision
        uint256 totalFeeOnSwap = FullMath.mulDivRoundingUp(86e16, 3_000, 1e6);

        // // swapping 86e16 puts back the price into the range where both positions are active
        uniswapV3Callee.swapExact1For0(address(pool), 86e16, users.alice, MAX_SQRT_RATIO - 1);

        // sqrtPriceNextX96
        sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(-TICK_SPACING_60);

        //calculate amountIn for the range where only unstaked liq is present
        // liquidity * (sqrt(upper) - sqrt(lower))
        amountIn = FullMath.mulDivRoundingUp(liquidity, sqrtRatioBX96 - sqrtRatioAX96, Q96);

        uint256 feeInUnStakedRange = FullMath.mulDivRoundingUp(amountIn, 3_000, 1e6 - 3_000);

        uint256 feeGrowthGlobal1X128InUnStakedRange = calculateFeeGrowthX128(feeInUnStakedRange, liquidity);

        uint256 feeGrowthGlobal1X128StakedRange =
            calculateFeeGrowthX128((totalFeeOnSwap - feeInUnStakedRange) / 2, liquidity);

        assertFees(
            feeInStakedRange / 2,
            (totalFeeOnSwap - feeInUnStakedRange) / 2,
            feeGrowthGlobal0X128UnstakedRange + feeGrowthGlobal0X128InStakedRange,
            feeGrowthGlobal1X128InUnStakedRange + feeGrowthGlobal1X128StakedRange
        );

        gauge.withdraw(tokenId);

        {
            nft.approve(address(nftCallee), tokenId);
            (uint256 amount0, uint256 amount1) = nftCallee.collectAllForTokenId(tokenId, users.alice);
            assertEq(amount0, 0);
            assertEq(amount1, 0);

            nft.approve(address(nftCallee), tokenId2);
            (amount0, amount1) = nftCallee.collectAllForTokenId(tokenId2, users.alice);
            assertApproxEqAbs(amount0, 3e15 - feeInStakedRange / 2, 1);
            assertApproxEqAbs(amount1, feeInUnStakedRange + ((totalFeeOnSwap - feeInUnStakedRange) / 2), 1);
        }
    }
}
