pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLPoolSwapPartiallyStakedWithUnstakeFeeTest, CLGauge} from "./CLPoolSwapPartiallyStakedWithUnstakeFee.t.sol";
import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";
import {LiquidityAmounts} from "contracts/periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "contracts/core/libraries/TickMath.sol";

contract MediumFee1to1PriceAdditionalLiquidityAroundCurrentPricePartiallyStakedWithUnstakedFeeTest is
    CLPoolSwapPartiallyStakedWithUnstakeFeeTest
{
    function setUp() public override {
        super.setUp();

        int24 tickSpacing = TICK_SPACING_60;

        uint160 startingPrice = encodePriceSqrt(1, 1);

        string memory poolName = ".medium_fee_1to1_price_additional_liquidity_around_current_price";
        address pool = poolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: tickSpacing,
            sqrtPriceX96: startingPrice
        });

        uint128 liquidity = 2e18;

        // A |------------------ * ---------------------|
        // B |---------------|
        // C                         |------------------|

        // in the range where only the A posiiton is active the feeGrowth is always 9040182736435 so in the asserts
        // we just have to substract it from the total fees, calculate the feeGrowth for both range separately and add
        // them together.

        stakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity / 2})
        );

        stakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: -tickSpacing, liquidity: liquidity / 2})
        );

        stakedPositions.push(
            Position({tickLower: tickSpacing, tickUpper: getMaxTick(tickSpacing), liquidity: liquidity / 2})
        );

        // unstaked positions
        unstakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity / 2})
        );

        unstakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: -tickSpacing, liquidity: liquidity / 2})
        );

        unstakedPositions.push(
            Position({tickLower: tickSpacing, tickUpper: getMaxTick(tickSpacing), liquidity: liquidity / 2})
        );

        gauge = CLGauge(payable(voter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)})));

        vm.stopPrank();

        // set zero unstaked fee
        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(pool, 125_000);

        uint256 positionsLength = stakedPositions.length;

        for (uint256 i = 0; i < positionsLength; i++) {
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                startingPrice,
                TickMath.getSqrtRatioAtTick(stakedPositions[i].tickLower),
                TickMath.getSqrtRatioAtTick(stakedPositions[i].tickUpper),
                stakedPositions[i].liquidity
            );

            vm.startPrank(users.alice);
            // add one to the amounts used for the staked positions
            uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWithCustomTickSpacing(
                amount0 + 1,
                amount1 + 1,
                stakedPositions[i].tickLower,
                stakedPositions[i].tickUpper,
                tickSpacing,
                users.alice
            );

            nft.approve(address(gauge), tokenId);
            gauge.deposit(tokenId);

            nftCallee.mintNewCustomRangePositionForUserWithCustomTickSpacing(
                amount0 + 1,
                amount1 + 1,
                unstakedPositions[i].tickLower,
                unstakedPositions[i].tickUpper,
                tickSpacing,
                users.alice
            );
        }

        uint256 poolBalance0 = token0.balanceOf(pool);
        uint256 poolBalance1 = token1.balanceOf(pool);

        (uint160 sqrtPriceX96, int24 tick,,,,) = ICLPool(pool).slot0();

        poolSetup = PoolSetup({
            poolName: poolName,
            pool: pool,
            gauge: address(gauge),
            poolBalance0: poolBalance0,
            poolBalance1: poolBalance1,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick
        });
    }
}
