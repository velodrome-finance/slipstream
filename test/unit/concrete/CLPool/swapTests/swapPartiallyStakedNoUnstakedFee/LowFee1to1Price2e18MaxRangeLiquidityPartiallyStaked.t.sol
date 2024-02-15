pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLPoolSwapPartiallyStakedNoUnstakeFeeTest, CLGauge} from "./CLPoolSwapPartiallyStakedNoUnstakeFee.t.sol";
import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";

contract LowFee1to1Price2e18MaxRangeLiquidityPartiallyStakedTest is CLPoolSwapPartiallyStakedNoUnstakeFeeTest {
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

        gauge = CLGauge(voter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)}));

        vm.stopPrank();

        // set zero unstaked fee
        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(pool, 420);

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
