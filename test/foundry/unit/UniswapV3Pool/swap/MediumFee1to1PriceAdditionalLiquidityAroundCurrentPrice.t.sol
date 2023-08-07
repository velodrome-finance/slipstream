pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3PoolSwapTest} from "./UniswapV3PoolSwap.t.sol";
import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";

contract MediumFee1to1PriceAdditionalLiquidityAroundCurrentPriceTest is UniswapV3PoolSwapTest {
    function setUp() public override {
        super.setUp();

        int24 tickSpacing = TICK_SPACING_60;

        string memory poolName = ".medium_fee_1to1_price_additional_liquidity_around_current_price";
        address pool =
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: tickSpacing});

        uint160 startingPrice = encodePriceSqrt(1, 1);
        IUniswapV3Pool(pool).initialize(startingPrice);

        uint128 liquidity = 2e18;

        positions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity})
        );

        positions.push(Position({tickLower: getMinTick(tickSpacing), tickUpper: -tickSpacing, liquidity: liquidity}));

        positions.push(Position({tickLower: tickSpacing, tickUpper: getMaxTick(tickSpacing), liquidity: liquidity}));

        uint256 positionsLength = positions.length;

        for (uint256 i = 0; i < positionsLength; i++) {
            uniswapV3Callee.mint(
                pool, users.alice, positions[i].tickLower, positions[i].tickUpper, positions[i].liquidity
            );
        }

        uint256 poolBalance0 = token0.balanceOf(pool);
        uint256 poolBalance1 = token1.balanceOf(pool);

        (uint160 sqrtPriceX96, int24 tick,,,,,) = IUniswapV3Pool(pool).slot0();

        poolSetup = PoolSetup({
            poolName: poolName,
            pool: pool,
            poolBalance0: poolBalance0,
            poolBalance1: poolBalance1,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick
        });
    }
}
