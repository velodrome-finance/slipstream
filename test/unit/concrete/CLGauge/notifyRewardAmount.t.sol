pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGauge.t.sol";

contract NotifyRewardAmountTest is CLGaugeTest {
    using stdStorage for StdStorage;
    using SafeCast for uint128;

    UniswapV3Pool public pool;
    CLGauge public gauge;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: TICK_SPACING_60})
        );
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});
        gauge = CLGauge(voter.gauges(address(pool)));

        skipToNextEpoch(0);
    }

    function test_notifyRewardAmountUpdatesGaugeStateCorrectly() public {
        skip(1 days);

        uint256 reward = TOKEN_1;

        deal(address(rewardToken), address(voter), reward);
        vm.startPrank(address(voter));

        rewardToken.approve(address(gauge), reward);

        vm.expectEmit(true, true, false, false, address(gauge));
        emit NotifyReward({from: address(voter), amount: reward});
        gauge.notifyRewardAmount(reward);

        vm.stopPrank();

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertEq(gaugeRewardTokenBalance, reward);

        assertEq(gauge.rewardRate(), reward / 6 days);
        assertEq(gauge.lastUpdateTime(), block.timestamp);
        assertEq(gauge.periodFinish(), block.timestamp + 6 days);
    }

    function test_notifyRewardAmountUpdatesGaugeStateCorrectlyOnAdditionalRewardInSameEpoch() public {
        skip(1 days);

        uint256 reward = TOKEN_1;

        deal(address(rewardToken), address(voter), reward * 2);
        vm.startPrank(address(voter));

        rewardToken.approve(address(gauge), reward * 2);

        gauge.notifyRewardAmount(reward);

        skip(1 days);

        gauge.notifyRewardAmount(reward);
        vm.stopPrank();

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertEq(gaugeRewardTokenBalance, reward * 2);

        assertEq(gauge.rewardRate(), reward / 6 days + reward / 5 days);
        assertEq(gauge.lastUpdateTime(), block.timestamp);
        assertEq(gauge.periodFinish(), block.timestamp + 5 days);
    }
}
