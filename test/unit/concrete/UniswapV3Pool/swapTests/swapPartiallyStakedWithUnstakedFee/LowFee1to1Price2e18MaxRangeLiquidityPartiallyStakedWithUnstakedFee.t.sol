pragma solidity ^0.7.6;
pragma abicoder v2;

import {
    UniswapV3PoolSwapPartiallyStakedWithUnstakeFeeTest,
    CLGauge
} from "./UniswapV3PoolSwapPartiallyStakedWithUnstakeFee.t.sol";
import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";

contract LowFee1to1Price2e18MaxRangeLiquidityPartiallyStakedWithUnstakedFeeTest is
    UniswapV3PoolSwapPartiallyStakedWithUnstakeFeeTest
{
    function setUp() public override {
        super.setUp();

        int24 tickSpacing = TICK_SPACING_10;

        uint160 startingPrice = encodePriceSqrt(1, 1);

        string memory poolName = ".low_fee_1to1_price_2e18_max_range_liquidity";
        address pool = poolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: tickSpacing,
            sqrtPriceX96: startingPrice
        });

        uint128 liquidity = 2e18;

        stakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity / 2})
        );

        unstakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity / 2})
        );

        gauge = CLGauge(voter.gauges(pool));

        vm.stopPrank();

        // set zero unstaked fee
        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(pool, 125_000);

        vm.startPrank(users.alice);
        // mint staked position
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWithCustomTickSpacing(
            stakedPositions[0].liquidity, stakedPositions[0].liquidity, tickSpacing, users.alice
        );
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // mint unstaked position
        nftCallee.mintNewFullRangePositionForUserWithCustomTickSpacing(
            unstakedPositions[0].liquidity, unstakedPositions[0].liquidity, tickSpacing, users.alice
        );

        uint256 poolBalance0 = token0.balanceOf(pool);
        uint256 poolBalance1 = token1.balanceOf(pool);

        (uint160 sqrtPriceX96, int24 tick,,,,) = IUniswapV3Pool(pool).slot0();

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
