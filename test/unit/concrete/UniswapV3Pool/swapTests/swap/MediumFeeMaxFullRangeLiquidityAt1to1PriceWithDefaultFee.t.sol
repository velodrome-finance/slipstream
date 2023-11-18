pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3PoolSwapNoStakeTest} from "./UniswapV3PoolSwapNoStake.t.sol";
import {Tick} from "contracts/core/libraries/Tick.sol";
import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";

contract MediumFeeMaxFullRangeLiquidityAt1to1PriceWithDefaultFeeTest is UniswapV3PoolSwapNoStakeTest {
    function setUp() public override {
        super.setUp();

        int24 tickSpacing = TICK_SPACING_60;

        uint160 startingPrice = encodePriceSqrt(1, 1);

        string memory poolName = ".max_full_range_liquidity_at_1to1_price_with_default_fee";
        address pool = poolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: tickSpacing,
            sqrtPriceX96: startingPrice
        });

        uint128 liquidity = Tick.tickSpacingToMaxLiquidityPerTick(tickSpacing);

        unstakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity})
        );

        uniswapV3Callee.mint(
            pool,
            users.alice,
            unstakedPositions[0].tickLower,
            unstakedPositions[0].tickUpper,
            unstakedPositions[0].liquidity
        );

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
