pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLPoolSwapAllStakedNoUnstakeFeeTest, CLGauge} from "./CLPoolSwapAllStakedNoUnstakeFee.t.sol";
import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";

contract LowFee1to1Price2e18MaxRangeLiquidityAllStakedTest is CLPoolSwapAllStakedNoUnstakeFeeTest {
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
            Position({tickLower: getMinTick(tickSpacing), tickUpper: getMaxTick(tickSpacing), liquidity: liquidity})
        );

        gauge = CLGauge(voter.gauges(pool));

        vm.stopPrank();

        // set zero unstaked fee
        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(pool, 420);

        vm.startPrank(users.alice);
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWithCustomTickSpacing(
            liquidity, liquidity, tickSpacing, users.alice
        );
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

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
