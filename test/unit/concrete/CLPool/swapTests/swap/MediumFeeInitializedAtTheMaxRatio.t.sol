pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLPoolSwapNoStakeTest} from "./CLPoolSwapNoStake.t.sol";
import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";

contract MediumFeeInitializedAtTheMaxRatioTest is CLPoolSwapNoStakeTest {
    function setUp() public override {
        super.setUp();

        int24 tickSpacing = TICK_SPACING_60;

        uint160 startingPrice = MAX_SQRT_RATIO - 1;

        string memory poolName = ".initialized_at_the_max_ratio";
        address pool = poolFactory.createPool({
            tokenA: address(token0),
            tokenB: address(token1),
            tickSpacing: tickSpacing,
            sqrtPriceX96: startingPrice
        });

        uint128 liquidity = 2e18;

        unstakedPositions.push(
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity})
        );

        clCallee.mint(
            pool,
            users.alice,
            unstakedPositions[0].tickLower,
            unstakedPositions[0].tickUpper,
            unstakedPositions[0].liquidity
        );

        uint256 poolBalance0 = token0.balanceOf(pool);
        uint256 poolBalance1 = token1.balanceOf(pool);

        (uint160 sqrtPriceX96, int24 tick,,,,) = ICLPool(pool).slot0();

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
