pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3PoolSwapNoStakeTest} from "./UniswapV3PoolSwapNoStake.t.sol";
import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";

contract MediumFee1to1Price0LiquidityAllLiquidityAroundCurrentPriceTest is UniswapV3PoolSwapNoStakeTest {
    function setUp() public override {
        super.setUp();

        int24 tickSpacing = TICK_SPACING_60;

        uint160 startingPrice = encodePriceSqrt(1, 1);

        string memory poolName = ".medium_fee_1to1_price_0_liquidity_all_liquidity_around_current_price";
        address pool = poolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: tickSpacing,
            sqrtPriceX96: startingPrice
        });

        uint128 liquidity = 2e18;

        unstakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: -tickSpacing, liquidity: liquidity})
        );

        unstakedPositions.push(
            Position({tickLower: tickSpacing, tickUpper: getMaxTick(tickSpacing), liquidity: liquidity})
        );

        uint256 unstakedPositionsLength = unstakedPositions.length;

        for (uint256 i = 0; i < unstakedPositionsLength; i++) {
            uniswapV3Callee.mint(
                pool,
                users.alice,
                unstakedPositions[i].tickLower,
                unstakedPositions[i].tickUpper,
                unstakedPositions[i].liquidity
            );
        }

        uint256 poolBalance0 = token0.balanceOf(pool);
        uint256 poolBalance1 = token1.balanceOf(pool);

        (uint160 sqrtPriceX96, int24 tick,,,,) = IUniswapV3Pool(pool).slot0();

        poolSetup = PoolSetup({
            poolName: poolName,
            pool: pool,
            gauge: address(0), // not required
            poolBalance0: poolBalance0,
            poolBalance1: poolBalance1,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick
        });

        vm.startPrank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);
        vm.startPrank(users.alice);
    }
}
