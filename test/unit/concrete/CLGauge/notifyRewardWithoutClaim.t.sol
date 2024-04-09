pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGauge.t.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";
import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";

contract NotifyRewardWithoutClaimTest is CLGaugeTest {
    CLPool public pool;
    CLGauge public gauge;
    address public feesVotingReward;

    function setUp() public override {
        super.setUp();

        pool = CLPool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        gauge = CLGauge(payable(voter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)})));
        feesVotingReward = voter.gaugeToFees(address(gauge));

        skipToNextEpoch(0);
    }

    function test_RevertIf_NotNotifyAdmin() public {
        vm.startPrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.notifyRewardWithoutClaim(TOKEN_1);
    }

    function test_RevertIf_ZeroAmount() public {
        vm.startPrank(users.owner);
        vm.expectRevert(abi.encodePacked("ZR"));
        gauge.notifyRewardWithoutClaim(0);
    }

    function test_NotifyRewardWithoutClaimWithNonZeroAmount() public {
        uint256 reward = TOKEN_1;

        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, reward);
        rewardToken.approve(address(gauge), reward);
        // check collect fees not called
        vm.expectCall(address(pool), abi.encodeWithSelector(CLPool.collectFees.selector), 0);
        gauge.notifyRewardWithoutClaim(reward);

        assertEq(gauge.rewardRate(), reward / WEEK);
        assertEq(gauge.rewardRateByEpoch(block.timestamp), reward / WEEK);
        assertEq(gauge.periodFinish(), block.timestamp + WEEK);
        assertEq(token0.balanceOf(address(feesVotingReward)), 0);
        assertEq(token1.balanceOf(address(feesVotingReward)), 0);
    }

    function test_NotifyRewardWithoutClaimWithExistingFees() public {
        uint256 reward = TOKEN_1;

        // generate gauge fees
        vm.startPrank(users.alice);
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        clCallee.swapExact0For1(address(pool), TOKEN_1, users.alice, MIN_SQRT_RATIO + 1);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 3e15);
        assertEq(_token1, 0);

        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, reward);
        rewardToken.approve(address(gauge), reward);
        // check collect fees not called
        vm.expectCall(address(pool), abi.encodeWithSelector(CLPool.collectFees.selector), 0);
        gauge.notifyRewardWithoutClaim(reward);

        assertEq(gauge.rewardRate(), reward / WEEK);
        assertEq(gauge.rewardRateByEpoch(block.timestamp), reward / WEEK);
        assertEq(gauge.periodFinish(), block.timestamp + WEEK);
        (_token0, _token1) = pool.gaugeFees();
        assertEq(_token0, 3e15);
        assertEq(_token1, 0);
        assertEq(token0.balanceOf(address(feesVotingReward)), 0);
        assertEq(token1.balanceOf(address(feesVotingReward)), 0);
    }

    function test_NotifyRewardWithoutClaimUpdatesGaugeStateCorrectlyOnAdditionalRewardInSameEpoch() public {
        uint256 epochStart = block.timestamp;
        skip(1 days);
        uint256 reward = TOKEN_1;
        deal(address(rewardToken), users.owner, reward * 3);

        vm.startPrank(users.owner);
        rewardToken.approve(address(gauge), reward * 3);
        gauge.notifyRewardWithoutClaim(reward);

        assertEq(gauge.rewardRate(), reward / (6 days));
        assertEq(gauge.rewardRateByEpoch(epochStart), reward / (6 days));
        assertEq(gauge.periodFinish(), block.timestamp + (6 days));

        uint256 reward2 = TOKEN_1 * 2;
        skip(1 days);
        gauge.notifyRewardWithoutClaim(reward2);

        assertEq(rewardToken.balanceOf(address(gauge)), reward + reward2);
        assertEq(gauge.rewardRate(), (reward + reward2) / (5 days));
        assertEq(gauge.rewardRateByEpoch(epochStart), (reward + reward2) / (5 days));
        assertEq(gauge.periodFinish(), block.timestamp + (5 days));
        assertEq(token0.balanceOf(address(feesVotingReward)), 0);
        assertEq(token1.balanceOf(address(feesVotingReward)), 0);
    }

    function test_NotifyRewardWithoutClaimBeforeNotifyRewardAmount() public {
        uint256 reward = TOKEN_1;
        uint256 epochStart = block.timestamp;

        // generate gauge fees
        vm.startPrank(users.alice);
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        clCallee.swapExact0For1(address(pool), TOKEN_1, users.alice, MIN_SQRT_RATIO + 1);

        skip(1 days);
        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, reward);
        rewardToken.approve(address(gauge), reward);
        gauge.notifyRewardWithoutClaim(reward);

        assertEq(gauge.rewardRate(), reward / (6 days));
        assertEq(gauge.rewardRateByEpoch(epochStart), reward / (6 days));
        assertEq(gauge.periodFinish(), block.timestamp + (6 days));
        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 3e15);
        assertEq(_token1, 0);
        assertEq(token0.balanceOf(address(feesVotingReward)), 0);
        assertEq(token1.balanceOf(address(feesVotingReward)), 0);

        skip(1 days);
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEq(gauge.rewardRate(), reward / (6 days) + reward / (5 days));
        assertEq(gauge.rewardRateByEpoch(epochStart), reward / (6 days) + reward / (5 days));
        assertEq(gauge.periodFinish(), block.timestamp + (5 days));
        (_token0, _token1) = pool.gaugeFees();
        assertEq(_token0, 1);
        assertEq(_token1, 0);
        assertEq(token0.balanceOf(address(feesVotingReward)), 3e15 - 1);
        assertEq(token1.balanceOf(address(feesVotingReward)), 0);
    }

    function test_NotifyRewardWithoutClaimAfterNotifyRewardAmountWithRewardRollover() public {
        uint256 reward = TOKEN_1;
        uint256 reward2 = TOKEN_1 * 2;
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        // add initial rewards
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);
        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / WEEK);
        uint256 rollover = reward / WEEK * 2 days;
        assertEqUint(pool.rewardReserve(), reward - rollover);
        assertEqUint(pool.rollover(), rollover);

        skip(4 days);

        // add additional rewards in the same epoch
        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, reward2);
        rewardToken.approve(address(gauge), reward2);
        gauge.notifyRewardWithoutClaim(reward2);

        assertEqUint(pool.lastUpdated(), block.timestamp);
        rollover = reward * (2 days) / WEEK; // amount to rollover (i.e. time with no staked liquidity)
        uint256 remaining = reward * (1 days) / WEEK; // remaining rewards for the week
        assertEqUint(pool.rewardRate(), (rollover + remaining + reward2) / (1 days));
        assertEqUint(pool.rollover(), 0);

        skipToNextEpoch(0);

        // alice claims her rewards
        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        assertApproxEqAbs(rewardToken.balanceOf(users.alice), reward * 3, 1e6);
        assertLe(rewardToken.balanceOf(address(gauge)), 1e6);
    }

    function test_NotifyRewardWithoutClaimBeforeNotifyRewardAmountWithRewardRollover() public {
        uint256 reward = TOKEN_1;
        uint256 reward2 = TOKEN_1 * 2;
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        // add initial rewards
        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, reward2);
        rewardToken.approve(address(gauge), reward2);
        gauge.notifyRewardWithoutClaim(reward2);

        skip(2 days);
        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward2 / WEEK);
        uint256 rollover = reward2 / WEEK * 2 days;
        assertEqUint(pool.rewardReserve(), reward2 - rollover);
        assertEqUint(pool.rollover(), rollover);

        skip(4 days);

        // add additional rewards in the same epoch
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEqUint(pool.lastUpdated(), block.timestamp);
        rollover = reward2 * (2 days) / WEEK; // amount to rollover (i.e. time with no staked liquidity)
        uint256 remaining = reward2 * (1 days) / WEEK; // remaining rewards for the week
        assertEqUint(pool.rewardRate(), (rollover + remaining + reward) / (1 days));
        assertEqUint(pool.rollover(), 0);

        skipToNextEpoch(0);

        // alice claims her rewards
        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        assertApproxEqAbs(rewardToken.balanceOf(users.alice), reward * 3, 1e6);
        assertLe(rewardToken.balanceOf(address(gauge)), 1e6);
    }
}
