pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3PoolTest} from "../UniswapV3Pool.t.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";
import {UnsafeMath} from "contracts/core/libraries/UnsafeMath.sol";
import {TickMath} from "contracts/core/libraries/TickMath.sol";
import {INonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";

import "forge-std/console.sol";

// calculate fees is an internal function but we test the correct functionality here
contract CalculateFeesFuzzTest is UniswapV3PoolTest {
    UniswapV3Pool public pool;
    CLGauge public gauge;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: TICK_SPACING_60})
        );

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);

        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.alice);

        skipToNextEpoch(0);

        // give some extra tokens to alice
        deal({token: address(token0), to: users.alice, give: TOKEN_1 * 1000000});
        deal({token: address(token1), to: users.alice, give: TOKEN_1 * 1000000});

        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});
    }

    function assertFees(uint256 t0, uint256 t1, uint256 fg0, uint256 fg1) internal {
        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertApproxEqAbs(_token0, t0, 2);
        assertApproxEqAbs(_token1, t1, 2);
        // 34028236692093846347 ~ this signifies 1 unit in token value, because a difference of 1 in fee value results
        // in a difference of ~ 34028236692093846347 => 1 * Q128 / unstakedLiquidity
        assertApproxEqAbs(pool.feeGrowthGlobal0X128(), fg0, 34028236692093846347);
        assertApproxEqAbs(pool.feeGrowthGlobal1X128(), fg1, 34028236692093846347);
    }

    function calculateFeeGrowthX128(uint256 feeAmount, uint256 unstakedLiquidity) internal pure returns (uint256) {
        return FullMath.mulDiv(feeAmount, Q128, unstakedLiquidity);
    }

    function testFuzz_FeesCalculatedCorrectlyDuringSwapsFullRangePositionsIntermediaryUnstakeAndStake(
        uint256 liquidity1,
        uint256 liquidity2
    ) public {
        liquidity1 = bound(liquidity1, TOKEN_1 * 10, type(uint64).max);
        liquidity2 = bound(liquidity2, TOKEN_1 * 10, type(uint64).max);

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(liquidity1, liquidity1, users.alice);

        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(liquidity2, liquidity2, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        uint256 feeDuringSwap = FullMath.mulDiv(3e15, liquidity2, (liquidity1 + liquidity2));

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(feeDuringSwap, liquidity2);
        assertFees(3e15 - feeDuringSwap, 0, feeGrowthGlobal0X128, 0);

        gauge.withdraw(tokenId);

        // swap 3 token0
        uniswapV3Callee.swapExact0For1(address(pool), 3e18, users.alice, MIN_SQRT_RATIO + 1);

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(9e15, (liquidity1 + liquidity2));
        assertFees(3e15 - feeDuringSwap, 0, feeGrowthGlobal0X128, 0);

        // swap 1 token1
        uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

        feeGrowthGlobal1X128 += calculateFeeGrowthX128(3e15, (liquidity1 + liquidity2));
        assertFees(3e15 - feeDuringSwap, 0, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        {
            uint256 pre0BalTokenId = token0.balanceOf(users.alice);
            uint256 pre1BalTokenId = token1.balanceOf(users.alice);

            nft.approve(address(gauge), tokenId);
            gauge.deposit(tokenId);

            uint256 token0FeeDuringSwapForTokenId = FullMath.mulDiv(9e15, liquidity1, (liquidity1 + liquidity2));
            uint256 token1FeeDuringSwapForTokenId = FullMath.mulDiv(3e15, liquidity1, (liquidity1 + liquidity2));
            // deposit should collect already accumulated fees
            assertApproxEqAbs(token0.balanceOf(users.alice), pre0BalTokenId + token0FeeDuringSwapForTokenId, 1);
            assertApproxEqAbs(token1.balanceOf(users.alice), pre1BalTokenId + token1FeeDuringSwapForTokenId, 1);
        }

        // swap 2 token1
        uniswapV3Callee.swapExact1For0(address(pool), 2e18, users.alice, MAX_SQRT_RATIO - 1);
        uint256 feeDuringSwap2 = FullMath.mulDiv(6e15, liquidity2, (liquidity1 + liquidity2));

        feeGrowthGlobal1X128 += calculateFeeGrowthX128(feeDuringSwap2, liquidity2);

        assertFees(3e15 - feeDuringSwap, 6e15 - feeDuringSwap2, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        {
            nft.approve(address(nftCallee), tokenId2);
            (uint256 amount0TokenId2, uint256 amountTtokenId2) = nftCallee.collectAllForTokenId(tokenId2, users.alice);

            uint256 token0FeeDuringSwapForTokenId2 = FullMath.mulDiv(9e15, liquidity2, (liquidity1 + liquidity2));
            uint256 token1FeeDuringSwapForTokenId2 = FullMath.mulDiv(3e15, liquidity2, (liquidity1 + liquidity2));

            assertApproxEqAbs(amount0TokenId2, feeDuringSwap + token0FeeDuringSwapForTokenId2, 1);
            assertApproxEqAbs(amountTtokenId2, feeDuringSwap2 + token1FeeDuringSwapForTokenId2, 1);
        }
    }

    function testFuzz_FeesCalculatedCorrectlyDuringSwapsFullRangePositionsIntermediaryUnstakeAndStake(
        uint256 swapAmount1,
        uint256 swapAmount2,
        uint256 swapAmount3,
        uint256 swapAmount4
    ) public {
        swapAmount1 = bound(swapAmount1, TOKEN_1, TOKEN_1 * 1_000);
        swapAmount2 = bound(swapAmount2, TOKEN_1, TOKEN_1 * 1_000);
        swapAmount3 = bound(swapAmount3, TOKEN_1, TOKEN_1 * 1_000);
        swapAmount4 = bound(swapAmount4, TOKEN_1, TOKEN_1 * 1_000);

        uint256 liquidity = TOKEN_1 * 10_000;

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(liquidity, liquidity, users.alice);

        uint256 tokenId2 = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(liquidity, liquidity, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;

        // swap token0
        uniswapV3Callee.swapExact0For1(address(pool), swapAmount1, users.alice, MIN_SQRT_RATIO + 1);

        uint256 fee = FullMath.mulDiv(swapAmount1, 3_000, 1e6);

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(fee / 2, liquidity);
        assertFees(fee / 2, 0, feeGrowthGlobal0X128, 0);

        gauge.withdraw(tokenId);

        // swap token0
        uniswapV3Callee.swapExact0For1(address(pool), swapAmount2, users.alice, MIN_SQRT_RATIO + 1);

        uint256 fee2 = FullMath.mulDiv(swapAmount2, 3_000, 1e6);

        feeGrowthGlobal0X128 += calculateFeeGrowthX128(fee2, liquidity * 2);
        assertFees(fee / 2, 0, feeGrowthGlobal0X128, 0);

        // swap token1
        uniswapV3Callee.swapExact1For0(address(pool), swapAmount3, users.alice, MAX_SQRT_RATIO - 1);

        uint256 fee3 = FullMath.mulDiv(swapAmount3, 3_000, 1e6);

        feeGrowthGlobal1X128 += calculateFeeGrowthX128(fee3, liquidity * 2);
        assertFees(fee / 2, 0, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        {
            uint256 pre0BalTokenId = token0.balanceOf(users.alice);
            uint256 pre1BalTokenId = token1.balanceOf(users.alice);

            nft.approve(address(gauge), tokenId);
            gauge.deposit(tokenId);

            // deposit should collect already accumulated fees
            assertApproxEqAbs(token0.balanceOf(users.alice), pre0BalTokenId + fee2 / 2, 1);
            assertApproxEqAbs(token1.balanceOf(users.alice), pre1BalTokenId + fee3 / 2, 1);
        }

        // swap token1
        uniswapV3Callee.swapExact1For0(address(pool), swapAmount4, users.alice, MAX_SQRT_RATIO - 1);

        uint256 fee4 = FullMath.mulDiv(swapAmount4, 3_000, 1e6);

        feeGrowthGlobal1X128 += calculateFeeGrowthX128(fee4 / 2, liquidity);

        assertFees(fee / 2, fee4 / 2, feeGrowthGlobal0X128, feeGrowthGlobal1X128);

        {
            nft.approve(address(nftCallee), tokenId2);
            (uint256 amount0TokenId2, uint256 amount1TokenId2) = nftCallee.collectAllForTokenId(tokenId2, users.alice);

            // tokenId2 always receives half of the fees no matter what the other position is doing
            // since they 50%-50% liqudity amount
            assertApproxEqAbs(amount0TokenId2, fee / 2 + fee2 / 2, 1);
            assertApproxEqAbs(amount1TokenId2, fee3 / 2 + fee4 / 2, 2);
        }
    }

    struct Fees {
        uint256 fee1;
        uint256 fee2;
        uint256 fee3;
        uint256 fee4;
    }

    struct FeeGrowth {
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
    }

    struct FuzzData {
        uint256 liquidity1;
        uint256 liquidity2;
        uint256 swapAmount1;
        uint256 swapAmount2;
        uint256 swapAmount3;
        uint256 swapAmount4;
    }

    // TODO: fine tune this test
    function testFuzz_FeesCalculatedCorrectlyDuringSwapsFullRangePositionsIntermediaryUnstakeAndStake(
        uint256 liquidity1,
        uint256 liquidity2,
        uint256 swapAmount1,
        uint256 swapAmount2,
        uint256 swapAmount3,
        uint256 swapAmount4
    ) public {
        FuzzData memory fd = FuzzData(0, 0, 0, 0, 0, 0);
        fd.liquidity1 = bound(liquidity1, TOKEN_1 * 10, type(uint64).max);
        fd.liquidity2 = bound(liquidity2, TOKEN_1 * 10, type(uint64).max);
        fd.swapAmount1 = bound(swapAmount1, 10_000, 100_000);
        fd.swapAmount2 = bound(swapAmount2, 10_000, 100_000);
        fd.swapAmount3 = bound(swapAmount3, 10_000, 100_000);
        fd.swapAmount4 = bound(swapAmount4, 10_000, 100_000);

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(fd.liquidity1, fd.liquidity1, users.alice);

        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(fd.liquidity2, fd.liquidity2, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        FeeGrowth memory fg = FeeGrowth(0, 0);

        Fees memory fees = Fees(0, 0, 0, 0);
        fees.fee1 = FullMath.mulDivRoundingUp(fd.swapAmount1, 3_000, 1e6 - 3_000);
        fees.fee2 = FullMath.mulDivRoundingUp(fd.swapAmount2, 3_000, 1e6 - 3_000);
        fees.fee3 = FullMath.mulDivRoundingUp(fd.swapAmount3, 3_000, 1e6 - 3_000);
        fees.fee4 = FullMath.mulDivRoundingUp(fd.swapAmount4, 3_000, 1e6 - 3_000);

        // swap token0
        uniswapV3Callee.swapExact0For1(address(pool), fd.swapAmount1, users.alice, MIN_SQRT_RATIO + 1);

        uint256 unstakedFeeDuringSwap = FullMath.mulDiv(fees.fee1, fd.liquidity2, fd.liquidity1 + fd.liquidity2);

        fg.feeGrowthGlobal0X128 += calculateFeeGrowthX128(unstakedFeeDuringSwap, fd.liquidity2);
        assertFees(fees.fee1 - unstakedFeeDuringSwap, 0, fg.feeGrowthGlobal0X128, 0);

        gauge.withdraw(tokenId);

        // swap token0
        uniswapV3Callee.swapExact0For1(address(pool), fd.swapAmount2, users.alice, MIN_SQRT_RATIO + 1);

        fg.feeGrowthGlobal0X128 += calculateFeeGrowthX128(fees.fee2, fd.liquidity1 + fd.liquidity2);
        assertFees(fees.fee1 - unstakedFeeDuringSwap, 0, fg.feeGrowthGlobal0X128, 0);

        // swap token1
        uniswapV3Callee.swapExact1For0(address(pool), fd.swapAmount3, users.alice, MAX_SQRT_RATIO - 1);

        fg.feeGrowthGlobal1X128 += calculateFeeGrowthX128(fees.fee3, fd.liquidity1 + fd.liquidity2);
        assertFees(fees.fee1 - unstakedFeeDuringSwap, 0, fg.feeGrowthGlobal0X128, fg.feeGrowthGlobal1X128);

        {
            uint256 pre0BalTokenId = token0.balanceOf(users.alice);
            uint256 pre1BalTokenId = token1.balanceOf(users.alice);

            nft.approve(address(gauge), tokenId);
            gauge.deposit(tokenId);

            // deposit should collect already accumulated fees
            assertApproxEqAbs(
                token0.balanceOf(users.alice),
                pre0BalTokenId + FullMath.mulDiv(fees.fee2, fd.liquidity1, (fd.liquidity1 + fd.liquidity2)),
                1
            );
            assertApproxEqAbs(
                token1.balanceOf(users.alice),
                pre1BalTokenId + FullMath.mulDiv(fees.fee3, fd.liquidity1, (fd.liquidity1 + fd.liquidity2)),
                1
            );
        }

        // swap token1
        uniswapV3Callee.swapExact1For0(address(pool), fd.swapAmount4, users.alice, MAX_SQRT_RATIO - 1);

        uint256 unstakedFeeDuringSwap2 = FullMath.mulDiv(fees.fee4, fd.liquidity2, (fd.liquidity1 + fd.liquidity2));

        fg.feeGrowthGlobal1X128 += calculateFeeGrowthX128(unstakedFeeDuringSwap2, fd.liquidity2);

        assertFees(
            fees.fee1 - unstakedFeeDuringSwap,
            fees.fee4 - unstakedFeeDuringSwap2,
            fg.feeGrowthGlobal0X128,
            fg.feeGrowthGlobal1X128
        );

        {
            nft.approve(address(nftCallee), tokenId2);
            (uint256 amount0TokenId2, uint256 amountTtokenId2) = nftCallee.collectAllForTokenId(tokenId2, users.alice);

            uint256 token0FeeDuringSwapForTokenId2 =
                FullMath.mulDiv(fees.fee2, fd.liquidity2, (fd.liquidity1 + fd.liquidity2));
            uint256 token1FeeDuringSwapForTokenId2 =
                FullMath.mulDiv(fees.fee3, fd.liquidity2, (fd.liquidity1 + fd.liquidity2));

            assertApproxEqAbs(amount0TokenId2, unstakedFeeDuringSwap + token0FeeDuringSwapForTokenId2, 2);
            assertApproxEqAbs(amountTtokenId2, unstakedFeeDuringSwap2 + token1FeeDuringSwapForTokenId2, 2);
        }
    }
}
