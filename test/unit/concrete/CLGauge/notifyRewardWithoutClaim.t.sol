pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGauge.t.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";
import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";

contract NotifyRewardWithoutClaimTest is CLGaugeTest {
    UniswapV3Pool public pool;
    CLGauge public gauge;
    address public feesVotingReward;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        gauge = CLGauge(voter.gauges(address(pool)));
        feesVotingReward = voter.gaugeToFees(address(gauge));

        skipToNextEpoch(0);
    }

    function test_RevertIf_NotTeam() public {
        vm.startPrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NT"));
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
        vm.expectCall(address(pool), abi.encodeWithSelector(UniswapV3Pool.collectFees.selector), 0);
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
        uniswapV3Callee.swapExact0For1(address(pool), TOKEN_1, users.alice, MIN_SQRT_RATIO + 1);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 3e15);
        assertEq(_token1, 0);

        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, reward);
        rewardToken.approve(address(gauge), reward);
        // check collect fees not called
        vm.expectCall(address(pool), abi.encodeWithSelector(UniswapV3Pool.collectFees.selector), 0);
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
        assertEq(gauge.rewardRate(), reward / (6 days) + reward2 / (5 days));
        assertEq(gauge.rewardRateByEpoch(epochStart), reward / (6 days) + reward2 / (5 days));
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
        uniswapV3Callee.swapExact0For1(address(pool), TOKEN_1, users.alice, MIN_SQRT_RATIO + 1);

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
}
