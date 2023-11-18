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
        token0.approve(address(nftCallee), type(uint256).max);
        token1.approve(address(nftCallee), type(uint256).max);

        vm.startPrank(users.alice);

        skipToNextEpoch(0);

        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});
    }

    function testFuzz_EarnedReturnsSameAsGetRewardsWithMultipleDepositors(uint256 reward) public {
        reward = bound(reward, WEEK, type(uint128).max);

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

        vm.startPrank(users.bob);
        gauge.getReward(bobTokenId);

        uint256 bobRewardBalance = rewardToken.balanceOf(users.bob);

        // should be the same
        assertEq(bobRewardBalance, bobClaimable);

        uint256 aliceClaimableSecond = gauge.earned(address(users.alice), aliceTokenId);

        vm.startPrank(users.alice);
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

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        // should be the same
        assertEq(aliceRewardBalance, aliceClaimableFirst + aliceClaimableSecond + aliceClaimableThird);

        uint256 bobClaimable = gauge.earned(address(users.bob), bobTokenId);

        vm.startPrank(users.bob);
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

        uint256 aliceTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.alice
        );

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit({tokenId: aliceTokenId});

        addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        uint256 aliceClaimableFirst = gauge.earned(address(users.alice), aliceTokenId);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.alice), aliceClaimableFirst);

        uint256 bobTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, -TICK_SPACING_60, TICK_SPACING_60, users.bob
        );

        vm.startPrank(users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        skip(1 days);

        // two deposits, equal in size, 1/7th of epoch
        uint256 aliceClaimableSecond = gauge.earned(address(users.alice), aliceTokenId);

        vm.startPrank(users.alice);
        // we withdraw alice position so we can add more liquidity into it and stake it back
        gauge.withdraw(aliceTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.alice), aliceClaimableFirst + aliceClaimableSecond);

        uint256 bobClaimableFirst = gauge.earned(address(users.bob), bobTokenId);

        vm.startPrank(users.bob);
        gauge.getReward(bobTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.bob), bobClaimableFirst);

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
        uint256 aliceClaimableThird = gauge.earned(address(users.alice), aliceTokenId);

        gauge.getReward(aliceTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.alice), aliceClaimableFirst + aliceClaimableSecond + aliceClaimableThird);

        uint256 bobClaimableSecond = gauge.earned(address(users.bob), bobTokenId);

        vm.startPrank(users.bob);
        // we withdraw for bob then mint a new position for him with half the size
        gauge.withdraw(bobTokenId);

        // should be the same
        assertEq(rewardToken.balanceOf(users.bob), bobClaimableFirst + bobClaimableSecond);

        bobTokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1 / 2, TOKEN_1 / 2, -TICK_SPACING_60, TICK_SPACING_60, users.bob
        );

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        skip(1 days);

        // two deposits, alice with four times the size of bob, 1/7th of epoch
        uint256 aliceClaimableFourth = gauge.earned(address(users.alice), aliceTokenId);

        vm.startPrank(users.alice);
        gauge.getReward(aliceTokenId);

        // should be the same
        assertEq(
            rewardToken.balanceOf(users.alice),
            aliceClaimableFirst + aliceClaimableSecond + aliceClaimableThird + aliceClaimableFourth
        );

        uint256 bobClaimableThird = gauge.earned(address(users.bob), bobTokenId);

        vm.startPrank(users.bob);
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
