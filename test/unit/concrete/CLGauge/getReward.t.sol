pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGauge.t.sol";

contract GetRewardTest is CLGaugeTest {
    CLPool public pool;
    CLGauge public gauge;

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
        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.bob);
        deal({token: address(token0), to: users.bob, give: TOKEN_1 * 10});
        deal({token: address(token1), to: users.bob, give: TOKEN_1 * 10});
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);
        token0.approve(address(nftCallee), type(uint256).max);
        token1.approve(address(nftCallee), type(uint256).max);

        vm.startPrank(users.alice);

        skipToNextEpoch(0);
    }

    function labelContracts() internal override {
        super.labelContracts();

        vm.label({account: address(pool), newLabel: "Pool"});
        vm.label({account: address(gauge), newLabel: "Gauge"});
    }

    function test_RevertIf_CallerIsNotOwner() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        vm.startPrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.getReward(tokenId);
    }

    function test_GetReward() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        vm.startPrank(users.alice);

        vm.expectEmit(true, true, false, true, address(gauge));
        emit ClaimRewards(users.alice, 285714285714259199);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // alice should have 2 days worth of rewards
        assertApproxEqAbs(aliceRewardBalance, reward / 7 * 2, 1e5);
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 777600);
    }

    function test_GetRewardOneDepositorWithPositionInCurrentPrice() public {
        uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice
        );

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // alice should have 2 days worth of rewards
        assertApproxEqAbs(aliceRewardBalance, reward / 7 * 2, 1e5);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, reward / 7 * 5, 1e5);
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 777600);
    }

    function test_GetRewardOneDepositorWithPositionRightOfCurrentPrice() public {
        uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, TICK_SPACING_60, 2 * TICK_SPACING_60, users.alice
        );

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // alice should not receive rewards
        assertEq(aliceRewardBalance, 0);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertEq(gaugeRewardTokenBalance, reward);
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 777600);
    }

    function test_GetRewardOneDepositorWithPositionLeftOfCurrentPrice() public {
        uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, 2 * -TICK_SPACING_60, -TICK_SPACING_60, users.alice
        );

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // alice should not receive rewards
        assertEq(aliceRewardBalance, 0);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertEq(gaugeRewardTokenBalance, reward);
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 777600);
    }

    function test_GetRewardWithMultipleDepositors() public {
        uint256 aliceTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice
        );

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        uint256 bobTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob
        );

        vm.startPrank(users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);
        assertEq(gauge.rewards(aliceTokenId), 0);
        assertEq(gauge.lastUpdateTime(aliceTokenId), 777600);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // alice should have 1 day worth of rewards
        assertApproxEqAbs(aliceRewardBalance, reward / 7, 1e5);

        skip(5 days);

        vm.startPrank(users.bob);
        gauge.getReward(bobTokenId);
        assertEq(gauge.rewards(bobTokenId), 0);
        assertEq(gauge.lastUpdateTime(bobTokenId), 1209600);

        uint256 bobRewardBalance = rewardToken.balanceOf(users.bob);
        // bob should have half an epoch worth of rewards
        assertApproxEqAbs(bobRewardBalance, reward / 2, 1e5);

        // gauge should have alice rewards as a balance minus the 1 day worth of already claimed rewards
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, reward / 2 - reward / 7, 1e5);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);
        assertEq(gauge.rewards(aliceTokenId), 0);
        assertEq(gauge.lastUpdateTime(aliceTokenId), 1209600);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // alice should have half of the rewards
        assertApproxEqAbs(aliceRewardBalance, reward / 2, 1e5);

        gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        // gauge should have 0 rewards left (not counting dust)
        assertLe(gaugeRewardTokenBalance, 1e5);
    }

    function test_GetRewardWithMultipleDepositorsAndEarlyWithdrawal() public {
        uint256 aliceTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice
        );

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        uint256 bobTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob
        );

        vm.startPrank(users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(WEEK / 2);

        vm.startPrank(users.alice);
        // withdraw should collect the rewards
        gauge.withdraw(aliceTokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 4, 1e5);

        skip(WEEK / 2);

        vm.startPrank(users.alice);
        // alice no longer staked
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.getReward(aliceTokenId);

        vm.startPrank(users.bob);
        gauge.getReward(bobTokenId);

        uint256 bobRewardBalance = rewardToken.balanceOf(users.bob);
        assertApproxEqAbs(bobRewardBalance, reward / 2 + reward / 4, 1e5);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        // gauge should have 0 rewards left (not counting dust)
        assertLe(gaugeRewardTokenBalance, 1e5);
    }

    function test_GetRewardWithStaggeredDepositsAndWithdrawals() public {
        uint256 aliceTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice
        );

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit({tokenId: aliceTokenId});

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        uint256 firstExpectedReward = reward / 7;

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, firstExpectedReward, 1e5);

        uint256 bobTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob
        );

        vm.startPrank(users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        skip(1 days);

        // two deposits, equal in size, 1/7th of epoch
        uint256 secondExpectedReward = reward / 7 / 2;

        vm.startPrank(users.alice);
        // we withdraw alice position so we can add more liquidity into it and stake it back
        gauge.withdraw(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // alice already claimed 1 day worth of reward
        assertApproxEqAbs(aliceRewardBalance, firstExpectedReward + secondExpectedReward, 1e5);

        vm.startPrank(users.bob);
        gauge.getReward(bobTokenId);

        uint256 bobRewardBalance = rewardToken.balanceOf(users.bob);
        assertApproxEqAbs(bobRewardBalance, secondExpectedReward, 1e5);

        vm.startPrank(users.alice);
        // add more liq to alice positon then stake it in the gauge
        nft.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: aliceTokenId,
                amount0Desired: TOKEN_1,
                amount1Desired: TOKEN_1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        skip(1 days);

        // two deposits, alice with twice the size of bob, 1/7th of epoch
        uint256 thirdExpectedReward = reward / 7 / 3;

        gauge.getReward(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // alice: first claim + second claim + third claim
        assertApproxEqAbs(aliceRewardBalance, firstExpectedReward + secondExpectedReward + thirdExpectedReward * 2, 1e5);

        vm.startPrank(users.bob);
        // we withdraw for bob then mint a new position for him with half the size
        gauge.withdraw(bobTokenId);

        bobRewardBalance = rewardToken.balanceOf(users.bob);
        // bob: first claim + second claim + third claim
        assertApproxEqAbs(bobRewardBalance, secondExpectedReward + thirdExpectedReward, 1e5);

        bobTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1 / 2, TOKEN_1 / 2, -TICK_SPACING_60, TICK_SPACING_60, users.bob
        );

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        skip(1 days);

        // two deposits, alice with four times the size of bob, 1/7th of epoch
        uint256 fourthExpectedReward = reward / 7 / 5;

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(
            aliceRewardBalance,
            firstExpectedReward + secondExpectedReward + thirdExpectedReward * 2 + fourthExpectedReward * 4,
            1e5
        );

        vm.startPrank(users.bob);
        gauge.getReward(bobTokenId);

        bobRewardBalance = rewardToken.balanceOf(users.bob);
        assertApproxEqAbs(bobRewardBalance, secondExpectedReward + thirdExpectedReward + fourthExpectedReward, 1e5);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        // gauge should have 3 days worth of rewards left
        assertApproxEqAbs(gaugeRewardTokenBalance, reward / 7 * 3, 1e5);
    }

    function test_GetRewardWithLateRewards() public {
        uint256 aliceTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice
        );

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        uint256 bobTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob
        );

        vm.startPrank(users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        skip(WEEK / 2);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEqUint(pool.rewardRate(), reward / (WEEK / 2));

        skipToNextEpoch(0);
        // half the epoch has passed, all rewards distributed

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 2, 1e5);

        skip(1 days);
        uint256 reward2 = TOKEN_1 * 2;
        addRewardToGauge(address(voter), address(gauge), reward2);

        assertEqUint(pool.rewardRate(), reward2 / 6 days);

        skip(1 days);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 2 + reward2 / 2 / 6, 1e5);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 2 + reward2 / 2, 1e5);

        vm.startPrank(users.bob);
        gauge.getReward(bobTokenId);

        uint256 bobRewardBalance = rewardToken.balanceOf(users.bob);
        assertApproxEqAbs(bobRewardBalance, reward / 2 + reward2 / 2, 1e5);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        // gauge should have 0 rewards left (not counting dust)
        assertLe(gaugeRewardTokenBalance, 1e6);
    }

    function test_GetRewardWithNonOverlappingRewards() public {
        uint256 aliceTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice
        );

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        uint256 bobTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob
        );

        vm.startPrank(users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEqUint(pool.rewardRate(), reward / WEEK);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 2, 1e5);

        skip(1 days); // rewards distributed over 6 days intead of 7
        uint256 reward2 = TOKEN_1 * 2;

        addRewardToGauge(address(voter), address(gauge), reward2);

        assertEqUint(pool.rewardRate(), reward2 / 6 days);

        skip(1 days); // accrue 1/6 th of remaining rewards

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 2 + reward2 / 2 / 6, 1e5);

        skipToNextEpoch(0); // accrue all of remaining rewards

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 2 + reward2 / 2, 1e5);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        // bob not claimed yet
        assertApproxEqAbs(gaugeRewardTokenBalance, reward / 2 + reward2 / 2, 1e5);

        vm.startPrank(users.bob);
        gauge.getReward(bobTokenId);

        uint256 bobRewardBalance = rewardToken.balanceOf(users.bob);
        assertApproxEqAbs(bobRewardBalance, reward / 2 + reward2 / 2, 1e5);

        gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        // gauge should have 0 rewards left (not counting dust)
        assertLe(gaugeRewardTokenBalance, 1e6);
    }

    function test_RevertIf_CallerIsNotVoter() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        vm.startPrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NV"));
        gauge.getReward(users.alice);
    }

    function test_GetRewardAsVoterWithSingleDeposit() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        vm.startPrank(users.alice);

        address[] memory gauges = new address[](1);
        gauges[0] = address(gauge);

        vm.expectEmit(true, true, false, true, address(gauge));
        emit ClaimRewards(users.alice, 285714285714259199);
        voter.claimRewards(gauges);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // alice should have 2 days worth of rewards
        assertApproxEqAbs(aliceRewardBalance, reward / 7 * 2, 1e5);
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 777600);
    }

    function test_GetRewardAsVoterWithMultipleDeposits() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);
        uint256 tokenId2 = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        nft.approve(address(gauge), tokenId2);
        gauge.deposit(tokenId2);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        vm.startPrank(users.alice);

        address[] memory gauges = new address[](1);
        gauges[0] = address(gauge);

        vm.expectEmit(true, true, false, true, address(gauge));
        emit ClaimRewards(users.alice, 142857142857129599);
        emit ClaimRewards(users.alice, 142857142857129599);
        voter.claimRewards(gauges);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // alice should have 2 days worth of rewards
        assertApproxEqAbs(aliceRewardBalance, reward / 7 * 2, 1e5);
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 777600);
        assertEq(gauge.rewards(tokenId2), 0);
        assertEq(gauge.lastUpdateTime(tokenId2), 777600);
    }
}
