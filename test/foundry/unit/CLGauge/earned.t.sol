pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGauge.t.sol";

contract EarnedTest is CLGaugeTest {
    UniswapV3Pool public pool;
    CLGauge public gauge;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: TICK_SPACING_60})
        );
        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.bob);
        deal({token: address(token0), to: users.bob, give: TOKEN_1 * 10});
        deal({token: address(token1), to: users.bob, give: TOKEN_1 * 10});
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);

        changePrank(users.alice);
        deal({token: address(token0), to: users.alice, give: TOKEN_1 * 10});
        deal({token: address(token1), to: users.alice, give: TOKEN_1 * 10});
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);

        skipToNextEpoch(0);

        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});
    }

    function mintNewCustomRangePositionForUser(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper,
        address user
    ) internal returns (uint256) {
        vm.startPrank(user);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: tickLower,
            tickUpper: tickUpper,
            recipient: user,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        (uint256 tokenId,,,) = nft.mint(params);
        return tokenId;
    }

    function test_RevertIf_CallerIsNotOwner() public {
        uint256 tokenId = mintNewCustomRangePositionForUser(
            TOKEN_1, TOKEN_1, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
        );

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        vm.expectRevert(abi.encodePacked("NA"));
        gauge.earned(users.bob, tokenId);
    }

    function test_EarnedOneDepositorWithPositionInCurrentPrice() public {
        uint256 tokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        vm.startPrank(users.alice);
        uint256 aliceClaimableBalance = gauge.earned(users.alice, tokenId);

        // alice should be able to claim 2 days worth of rewards
        assertApproxEqAbs(aliceClaimableBalance, reward / 7 * 2, 1e5);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertEq(gaugeRewardTokenBalance, reward);
    }

    function test_EarnedOneDepositorWithPositionRightOfCurrentPrice() public {
        uint256 tokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, TICK_SPACING_60, 2 * TICK_SPACING_60, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        vm.startPrank(users.alice);
        uint256 aliceClaimableBalance = gauge.earned(users.alice, tokenId);

        // alice should not receive rewards
        assertEq(aliceClaimableBalance, 0);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertEq(gaugeRewardTokenBalance, reward);
    }

    function test_EarnedOneDepositorWithPositionLeftOfCurrentPrice() public {
        uint256 tokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, 2 * -TICK_SPACING_60, -TICK_SPACING_60, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        vm.startPrank(users.alice);
        uint256 aliceClaimableBalance = gauge.earned(users.alice, tokenId);

        // alice should not receive rewards
        assertEq(aliceClaimableBalance, 0);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertEq(gaugeRewardTokenBalance, reward);
    }

    function test_EarnedWithStaggeredDepositsAndWithdrawalsWithIntermediateClaims() public {
        uint256 aliceTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice);

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        // single deposit, 1/7th of epoch
        uint256 aliceBal = reward / 7;
        assertApproxEqAbs(gauge.earned(address(users.alice), aliceTokenId), aliceBal, 1e5);

        // alice collect rewards to update accumulator before bobs deposit
        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        uint256 bobTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        skip(1 days);
        // two deposits, equal in size, 1/7th of epoch
        aliceBal = (reward / 7) / 2;
        uint256 bobBal = (reward / 7) / 2;
        assertApproxEqAbs(gauge.earned(address(users.alice), aliceTokenId), aliceBal, 1e5);
        assertApproxEqAbs(gauge.earned(address(users.bob), bobTokenId), bobBal, 1e5);

        // alice withdraw then add more liquidty
        changePrank(users.alice);
        gauge.withdraw(aliceTokenId);

        // alice already claimed 1 day worth of rewards
        assertApproxEqAbs(rewardToken.balanceOf(users.alice), reward / 7 + aliceBal, 1e5);

        // alice claimed with the withdraw
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.earned(address(users.alice), aliceTokenId);

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

        // alice claimable balance should be 0
        assertEq(gauge.earned(address(users.alice), aliceTokenId), 0);

        skip(1 days);
        // two deposits, owner with twice the size of owner2, 1/7th of epoch
        aliceBal = ((reward / 7) / 3) * 2;
        bobBal += (reward / 7) / 3;
        assertApproxEqAbs(gauge.earned(address(users.alice), aliceTokenId), aliceBal, 1e5);
        assertApproxEqAbs(gauge.earned(address(users.bob), bobTokenId), bobBal, 1e5);

        // alice withdraw and add more liquidty
        changePrank(users.alice);
        gauge.withdraw(aliceTokenId);

        // add more liq to alice positon then stake it in the gauge
        nft.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: aliceTokenId,
                amount0Desired: TOKEN_1 * 2,
                amount1Desired: TOKEN_1 * 2,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        skip(1 days);
        // two deposits, owner with four times the size of owner 2, 1/7th of epoch
        aliceBal = ((reward / 7) / 5) * 4;
        bobBal += (reward / 7) / 5;
        assertApproxEqAbs(gauge.earned(address(users.alice), aliceTokenId), aliceBal, 1e5);
        assertApproxEqAbs(gauge.earned(address(users.bob), bobTokenId), bobBal, 1e5);
    }

    function test_EarnedWithLateRewards() public {
        uint256 aliceTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice);

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        uint256 bobTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        skip(WEEK / 2);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEqUint(pool.rewardRate(), reward / (WEEK / 2));

        skipToNextEpoch(0);

        // half the epoch has passed, all rewards should be accounted
        assertApproxEqAbs(gauge.earned(address(users.alice), aliceTokenId), reward / 2, 1e5);

        skip(1 days);
        uint256 reward2 = TOKEN_1 * 2;
        addRewardToGauge(address(voter), address(gauge), reward2);

        assertEqUint(pool.rewardRate(), reward2 / 6 days);

        skip(1 days);

        assertApproxEqAbs(gauge.earned(address(users.alice), aliceTokenId), reward / 2 + reward2 / 2 / 6, 1e5);

        skipToNextEpoch(0);

        assertApproxEqAbs(gauge.earned(address(users.alice), aliceTokenId), reward / 2 + reward2 / 2, 1e5);
        assertApproxEqAbs(gauge.earned(address(users.bob), bobTokenId), reward / 2 + reward2 / 2, 1e5);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        // gauge should have 3 rewards left (no reward claims)
        assertEq(gaugeRewardTokenBalance, reward + reward2);
    }

    function test_EarnedWithNonOverlappingRewards() public {
        uint256 aliceTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice);

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        uint256 bobTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEqUint(pool.rewardRate(), reward / WEEK);

        skipToNextEpoch(0);

        assertApproxEqAbs(gauge.earned(address(users.alice), aliceTokenId), reward / 2, 1e5);

        skip(1 days); // rewards distributed over 6 days intead of 7
        uint256 reward2 = TOKEN_1 * 2;

        addRewardToGauge(address(voter), address(gauge), reward2);

        assertEqUint(pool.rewardRate(), reward2 / 6 days);

        skip(1 days); // account 1/6 th of remaining rewards

        assertApproxEqAbs(gauge.earned(address(users.alice), aliceTokenId), reward / 2 + reward2 / 2 / 6, 1e5);

        skipToNextEpoch(0); // account all of remaining rewards

        assertApproxEqAbs(gauge.earned(address(users.alice), aliceTokenId), reward / 2 + reward2 / 2, 1e5);
        assertApproxEqAbs(gauge.earned(address(users.bob), bobTokenId), reward / 2 + reward2 / 2, 1e5);

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertEq(gaugeRewardTokenBalance, reward + reward2);
    }

    // FUZZ TESTS
    // TODO move these to their appropiate place once #37 is merged

    function testFuzz_EarnedReturnsSameAsGetRewardsWithMultipleDepositors(uint256 reward) public {
        reward = bound(reward, WEEK, type(uint128).max);

        uint256 aliceTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice);

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        uint256 bobTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        addRewardToGauge(address(voter), address(gauge), reward);

        skip(2 days);

        uint256 aliceClaimableFirst = gauge.earned(address(users.alice), aliceTokenId);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);

        // should be the same
        assertEq(aliceRewardBalance, aliceClaimableFirst);

        skip(5 days);

        uint256 bobClaimable = gauge.earned(address(users.bob), bobTokenId);

        changePrank(users.bob);
        gauge.getReward(bobTokenId);

        uint256 bobRewardBalance = rewardToken.balanceOf(users.bob);

        // should be the same
        assertEq(bobRewardBalance, bobClaimable);

        uint256 aliceClaimableSecond = gauge.earned(address(users.alice), aliceTokenId);

        changePrank(users.alice);
        gauge.getReward(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);

        // should be the same
        assertEq(aliceRewardBalance, aliceClaimableFirst + aliceClaimableSecond);

        // should be the same, not counting dust
        assertApproxEqAbs(reward, aliceClaimableFirst + aliceClaimableSecond + bobClaimable, 1e6);
    }

    function testFuzz_EarnedReturnsSameAsGetRewardsWithLateRewards(uint256 reward, uint256 reward2) public {
        reward = bound(reward, WEEK, type(uint128).max);
        reward2 = bound(reward, WEEK, type(uint128).max);

        uint256 aliceTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice);

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        uint256 bobTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        skip(WEEK / 2);

        addRewardToGauge(address(voter), address(gauge), reward);

        skipToNextEpoch(0);
        // half the epoch has passed, all rewards distributed
        uint256 aliceClaimableFirst = gauge.earned(address(users.alice), aliceTokenId);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // should be the same
        assertEq(aliceRewardBalance, aliceClaimableFirst);

        skip(1 days);
        addRewardToGauge(address(voter), address(gauge), reward2);

        skip(1 days);

        uint256 aliceClaimableSecond = gauge.earned(address(users.alice), aliceTokenId);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // should be the same
        assertEq(aliceRewardBalance, aliceClaimableFirst + aliceClaimableSecond);

        skipToNextEpoch(0);

        uint256 aliceClaimableThird = gauge.earned(address(users.alice), aliceTokenId);

        changePrank(users.alice);
        gauge.getReward(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // should be the same
        assertEq(aliceRewardBalance, aliceClaimableFirst + aliceClaimableSecond + aliceClaimableThird);

        uint256 bobClaimable = gauge.earned(address(users.bob), bobTokenId);

        changePrank(users.bob);
        gauge.getReward(bobTokenId);

        uint256 bobRewardBalance = rewardToken.balanceOf(users.bob);

        // should be the same
        assertEq(bobRewardBalance, bobClaimable);

        // should be the same, not counting dust
        assertApproxEqAbs(
            reward + reward2, aliceClaimableFirst + aliceClaimableSecond + aliceClaimableThird + bobClaimable, 1e6
        );
    }

    function testFuzz_EarnedReturnsSameAsGetRewardsWithStaggeredDepositsAndWithdrawals(uint256 reward) public {
        reward = bound(reward, WEEK, type(uint128).max);

        uint256 aliceTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice);

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit({tokenId: aliceTokenId});

        addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        uint256 aliceClaimableFirst = gauge.earned(address(users.alice), aliceTokenId);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.alice), aliceClaimableFirst);

        uint256 bobTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        skip(1 days);

        // two deposits, equal in size, 1/7th of epoch
        uint256 aliceClaimableSecond = gauge.earned(address(users.alice), aliceTokenId);

        changePrank(users.alice);
        // we withdraw alice position so we can add more liqudity into it and stake it back
        gauge.withdraw(aliceTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.alice), aliceClaimableFirst + aliceClaimableSecond);

        uint256 bobClaimableFirst = gauge.earned(address(users.bob), bobTokenId);

        changePrank(users.bob);
        gauge.getReward(bobTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.bob), bobClaimableFirst);

        changePrank(users.alice);
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
        uint256 aliceClaimableThird = gauge.earned(address(users.alice), aliceTokenId);

        gauge.getReward(aliceTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.alice), aliceClaimableFirst + aliceClaimableSecond + aliceClaimableThird);

        uint256 bobClaimableSecond = gauge.earned(address(users.bob), bobTokenId);

        changePrank(users.bob);
        // we withdraw for bob then mint a new position for him with half the size
        gauge.withdraw(bobTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.bob), bobClaimableFirst + bobClaimableSecond);

        bobTokenId =
            mintNewCustomRangePositionForUser(TOKEN_1 / 2, TOKEN_1 / 2, -TICK_SPACING_60, TICK_SPACING_60, users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        skip(1 days);

        // two deposits, alice with four times the size of bob, 1/7th of epoch
        uint256 aliceClaimableFourth = gauge.earned(address(users.alice), aliceTokenId);

        changePrank(users.alice);
        gauge.getReward(aliceTokenId);

        // should be the same
        assertEq(
            rewardToken.balanceOf(users.alice),
            aliceClaimableFirst + aliceClaimableSecond + aliceClaimableThird + aliceClaimableFourth
        );

        uint256 bobClaimableThird = gauge.earned(address(users.bob), bobTokenId);

        changePrank(users.bob);
        gauge.getReward(bobTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.bob), bobClaimableFirst + bobClaimableSecond + bobClaimableThird);

        // should be the same, not counting dust
        assertApproxEqAbs(
            reward / 7 * 4,
            aliceClaimableFirst + aliceClaimableSecond + aliceClaimableThird + aliceClaimableFourth + bobClaimableFirst
                + bobClaimableSecond + bobClaimableThird,
            1e6
        );
    }
}
