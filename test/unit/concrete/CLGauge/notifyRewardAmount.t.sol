pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGauge.t.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";

contract NotifyRewardAmountTest is CLGaugeTest {
    UniswapV3Pool public pool;
    CLGauge public gauge;
    address public feesVotingReward;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: TICK_SPACING_60})
        );
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);

        gauge = CLGauge(voter.gauges(address(pool)));
        feesVotingReward = voter.gaugeToFees(address(gauge));

        skipToNextEpoch(0);
    }

    function test_RevertIf_NotTeam() public {
        vm.startPrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NV"));
        gauge.notifyRewardAmount(TOKEN_1);
    }

    function test_RevertIf_ZeroAmount() public {
        vm.startPrank(address(voter));
        vm.expectRevert(abi.encodePacked("ZR"));
        gauge.notifyRewardAmount(0);
    }

    function test_NotifyRewardAmountUpdatesGaugeStateCorrectly() public {
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

    function test_NotifyRewardAmountUpdatesGaugeStateCorrectlyOnAdditionalRewardInSameEpoch() public {
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

    function test_NotifyRewardAmountCollectsFeesForAllPositionsStakedWithIntermediaryFlashCorrectly() public {
        vm.startPrank(users.alice);
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // fee is 0.003
        uint256 pay1 = TOKEN_1 + 3e15;
        // fee is 0.006
        uint256 pay2 = TOKEN_1 * 2 + 6e15;

        uniswapV3Callee.flash(address(pool), users.alice, TOKEN_1, TOKEN_1 * 2, pay1, pay2);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 3e15);
        assertEq(_token1, 6e15);

        skipToNextEpoch(0);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // in collectFees() we substract 1 from the fee for gas optimization
        assertEq(token0.balanceOf(address(feesVotingReward)), 3e15 - 1);
        assertEq(token1.balanceOf(address(feesVotingReward)), 6e15 - 1);
    }

    function test_NotifyRewardAmountCollectsFeesForPositionsPartiallyStakedWithIntermediaryFlashCorrectly() public {
        vm.startPrank(users.alice);
        nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // fee is 0.003
        uint256 pay1 = TOKEN_1 + 3e15;
        // fee is 0.006
        uint256 pay2 = TOKEN_1 * 2 + 6e15;

        uniswapV3Callee.flash(address(pool), users.alice, TOKEN_1, TOKEN_1 * 2, pay1, pay2);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 15e14);
        assertEq(_token1, 3e15);

        skipToNextEpoch(0);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // in collectFees() we substract 1 from the fee for gas optimization
        assertEq(token0.balanceOf(address(feesVotingReward)), 15e14 - 1);
        assertEq(token1.balanceOf(address(feesVotingReward)), 3e15 - 1);

        uint256 feeGrowthGlobal0X128 = FullMath.mulDiv(15e14, Q128, TOKEN_1);
        uint256 feeGrowthGlobal1X128 = FullMath.mulDiv(3e15, Q128, TOKEN_1);

        assertEq(pool.feeGrowthGlobal0X128(), feeGrowthGlobal0X128);
        assertEq(pool.feeGrowthGlobal1X128(), feeGrowthGlobal1X128);
    }

    function test_NotifyRewardAmountCollectsFeesForAllPositionsStakedWithIntermediarySwapCorrectly() public {
        vm.startPrank(users.alice);
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uniswapV3Callee.swapExact0For1(address(pool), TOKEN_1, users.alice, MIN_SQRT_RATIO + 1);
        uniswapV3Callee.swapExact1For0(address(pool), TOKEN_1 * 2, users.alice, MAX_SQRT_RATIO - 1);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 3e15);
        assertApproxEqAbs(_token1, 6e15, 1);

        skipToNextEpoch(0);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertApproxEqAbs(token0.balanceOf(address(feesVotingReward)), 3e15, 1);
        assertEq(token1.balanceOf(address(feesVotingReward)), 6e15);
    }

    function test_NotifyRewardAmountCollectsFeesForPositionsPartiallyStakedWithIntermediarySwapCorrectly() public {
        vm.startPrank(users.alice);
        nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uniswapV3Callee.swapExact0For1(address(pool), TOKEN_1, users.alice, MIN_SQRT_RATIO + 1);
        uniswapV3Callee.swapExact1For0(address(pool), TOKEN_1 * 2, users.alice, MAX_SQRT_RATIO - 1);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 15e14);
        assertEq(_token1, 3e15);

        skipToNextEpoch(0);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertApproxEqAbs(token0.balanceOf(address(feesVotingReward)), 15e14, 1);
        assertApproxEqAbs(token1.balanceOf(address(feesVotingReward)), 3e15, 1);

        uint256 feeGrowthGlobal0X128 = FullMath.mulDiv(15e14, Q128, TOKEN_1);
        uint256 feeGrowthGlobal1X128 = FullMath.mulDiv(3e15 + 1, Q128, TOKEN_1);

        assertEq(pool.feeGrowthGlobal0X128(), feeGrowthGlobal0X128);
        assertEq(pool.feeGrowthGlobal1X128(), feeGrowthGlobal1X128);
    }

    function test_NotifyRewardAmountBeforeNotifyRewardWithoutClaim() public {
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
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEq(gauge.rewardRate(), reward / (6 days));
        assertEq(gauge.rewardRateByEpoch(epochStart), reward / (6 days));
        assertEq(gauge.periodFinish(), block.timestamp + (6 days));
        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 1);
        assertEq(_token1, 0);
        // in collectFees() we substract 1 from the fee for gas optimization
        assertEq(token0.balanceOf(address(feesVotingReward)), 3e15 - 1);
        assertEq(token1.balanceOf(address(feesVotingReward)), 0);

        skip(1 days);
        vm.startPrank(users.owner);
        deal(address(rewardToken), users.owner, reward);
        rewardToken.approve(address(gauge), reward);
        gauge.notifyRewardWithoutClaim(reward);

        assertEq(gauge.rewardRate(), reward / (6 days) + reward / (5 days));
        assertEq(gauge.rewardRateByEpoch(epochStart), reward / (6 days) + reward / (5 days));
        assertEq(gauge.periodFinish(), block.timestamp + (5 days));
        (_token0, _token1) = pool.gaugeFees();
        assertEq(_token0, 1);
        assertEq(_token1, 0);
    }
}
