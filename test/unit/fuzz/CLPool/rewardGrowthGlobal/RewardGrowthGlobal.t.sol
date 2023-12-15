pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../BaseFixture.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {CLPoolTest} from "../CLPool.t.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import "contracts/core/libraries/FullMath.sol";

contract RewardGrowthGlobalFuzzTest is CLPoolTest {
    CLPool public pool;
    CLGauge public gauge;

    int24 tickSpacing = TICK_SPACING_60;

    function setUp() public override {
        super.setUp();

        pool = CLPool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: tickSpacing,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.alice);

        skipToNextEpoch(0);
    }

    function mintNewFullRangePositionAndDepositIntoGauge(uint128 _amount0, uint128 _amount1, address _user)
        internal
        returns (uint256)
    {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(_amount0, _amount1, _user);
        vm.startPrank(_user);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        return tokenId;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label({account: address(clCallee), newLabel: "Test CL Callee"});
        vm.label({account: address(pool), newLabel: "Pool"});
        vm.label({account: address(gauge), newLabel: "Gauge"});
    }

    function testFuzz_RewardGrowthGlobalUpdatesCorrectlyWithDelayedRewardDistribute(uint256 reward, uint256 delay)
        public
    {
        reward = bound(reward, WEEK, type(uint128).max);
        delay = bound(delay, 1, WEEK - 1 hours);

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 stakedLiquidity = 10e18;

        mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / (WEEK - delay));
        assertEqUint(pool.rewardReserve(), reward);

        // move one hour and mint new position and stake it as well to trigger update
        skip(1 hours);
        mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 1 hours;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / (WEEK - delay));
        assertEqUint(pool.rewardReserve(), reward - accumulatedReward);
    }

    function testFuzz_RewardGrowthGlobalUpdatesCorrectlyWithdrawPosition(uint256 reward) public {
        reward = bound(reward, WEEK, type(uint128).max);

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 stakedLiquidity = 10e18;

        uint256 tokenId = mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        // needs to be 0 since there are no rewards
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        addRewardToGauge(address(voter), address(gauge), reward);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / WEEK);
        assertEqUint(pool.rewardReserve(), reward);

        // still 0 since no action triggered update on the accumulator
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        skip(1 days);

        // withdraw to update
        vm.prank(users.alice);
        gauge.withdraw(tokenId);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 1 days;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / WEEK);
        assertEqUint(pool.rewardReserve(), reward - accumulatedReward);
    }

    function testFuzz_notifyRewardAmountUpdatesPoolStateCorrectlyOnAdditionalRewardInSameEpoch(
        uint256 reward,
        uint256 reward2
    ) public {
        reward = bound(reward, WEEK, type(uint128).max);
        reward2 = bound(reward2, WEEK, type(uint128).max);

        skip(1 days);

        addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        addRewardToGauge(address(voter), address(gauge), reward2);

        assertApproxEqAbs(pool.rewardRate(), (reward + reward2) / 5 days, 2);
        assertEqUint(pool.rewardReserve(), reward2 + (reward / 6 days) * 6 days);
        assertEqUint(pool.lastUpdated(), block.timestamp);
    }
}
