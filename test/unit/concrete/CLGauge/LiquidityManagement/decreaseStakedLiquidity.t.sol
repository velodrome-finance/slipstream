pragma solidity ^0.7.6;
pragma abicoder v2;

import "./LiquidityManagementBase.t.sol";

contract DecreaseStakedLiquidityTest is LiquidityManagementBase {
    function test_RevertIf_CallerIsNotOwner() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        vm.startPrank(users.bob);
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1), 0, 0, block.timestamp);
    }

    function test_DecreaseStakedLiquidity() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
        assertEq(pool.liquidity(), TOKEN_1 * 2);
        assertEq(positionLiquidity, TOKEN_1 * 2);

        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

        gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1), 0, 0, block.timestamp);

        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

        assertApproxEqAbs(aliceBalanceAfter0 - aliceBalanceBefore0, TOKEN_1, 1);
        assertApproxEqAbs(aliceBalanceAfter1 - aliceBalanceBefore1, TOKEN_1, 1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1);
        assertEq(pool.liquidity(), TOKEN_1);
        assertEq(positionLiquidity, TOKEN_1);
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 604800);
    }

    function test_DecreaseStakedLiquidityToZero() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
        assertEq(pool.liquidity(), TOKEN_1 * 2);
        assertEq(positionLiquidity, TOKEN_1 * 2);

        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

        gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1 * 2), 0, 0, block.timestamp);

        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

        assertApproxEqAbs(aliceBalanceAfter0 - aliceBalanceBefore0, TOKEN_1 * 2, 1);
        assertApproxEqAbs(aliceBalanceAfter1 - aliceBalanceBefore1, TOKEN_1 * 2, 1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEqUint(pool.stakedLiquidity(), 0);
        assertEqUint(pool.liquidity(), 0);
        assertEqUint(positionLiquidity, 0);
    }

    function test_DecreaseStakedLiquidityUpdatesFeeGrowthInsideAndTokensOwedCorrectlyAllPositionStaked() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        // swap 1 token1
        uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

        gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1), 0, 0, block.timestamp);

        (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128Gauge,
            uint256 feeGrowthInside1LastX128Gauge,
            uint128 tokensOwed0Gauge,
            uint128 tokensOwed1Gauge
        ) = pool.positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );

        assertEqUint(liquidity, TOKEN_1 * 9);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 feeGrowthInside0LastX128Position,
            uint256 feeGrowthInside1LastX128Position,
            uint128 tokensOwed0Position,
            uint128 tokensOwed1Position
        ) = nft.positions(tokenId);

        assertEq(feeGrowthInside0LastX128Gauge, 0);
        assertEq(feeGrowthInside1LastX128Gauge, 0);
        assertEqUint(tokensOwed0Gauge, 0);
        assertEqUint(tokensOwed1Gauge, 0);
        assertEq(feeGrowthInside0LastX128Position, 0);
        assertEq(feeGrowthInside1LastX128Position, 0);
        assertEqUint(tokensOwed0Position, 0);
        assertEqUint(tokensOwed1Position, 0);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 3e15);
        assertApproxEqAbs(_token1, 3e15, 1);
    }

    function test_DecreaseStakedLiquidityUpdatesFeeGrowthInsideAndTokensOwedCorrectlyWithSwapPositionsPartiallyStaked()
        public
    {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        // swap 1 token1
        uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

        gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1), 0, 0, block.timestamp);

        Position.Info memory gp = Position.Info(0, 0, 0, 0, 0);
        // check tokenId
        (gp.liquidity, gp.feeGrowthInside0LastX128, gp.feeGrowthInside1LastX128, gp.tokensOwed0, gp.tokensOwed1) = pool
            .positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );

        assertEqUint(gp.liquidity, TOKEN_1 * 9);

        {
            (
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                uint256 feeGrowthInside0LastX128Position,
                uint256 feeGrowthInside1LastX128Position,
                uint128 tokensOwed0Position,
                uint128 tokensOwed1Position
            ) = nft.positions(tokenId);

            assertEq(gp.feeGrowthInside0LastX128, feeGrowthInside0LastX128Position);
            assertEq(gp.feeGrowthInside1LastX128, feeGrowthInside1LastX128Position);
            assertEqUint(gp.tokensOwed0, 0);
            assertEqUint(gp.tokensOwed1, 0);
            assertEqUint(tokensOwed0Position, 0);
            assertEqUint(tokensOwed1Position, 0);
        }

        // check TokenId2

        uint256 pre0Bal = token0.balanceOf(users.alice);
        nft.approve(address(nftCallee), tokenId2);
        nftCallee.collectOneAndOneForTokenId(tokenId2, users.alice);

        assertEq(token0.balanceOf(users.alice), pre0Bal + 1); // should collect 1 for unstaked position

        Position.Info memory np = Position.Info(0, 0, 0, 0, 0);

        (np.liquidity, np.feeGrowthInside0LastX128, np.feeGrowthInside1LastX128, np.tokensOwed0, np.tokensOwed1) = pool
            .positions(keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60))));

        assertEqUint(np.liquidity, TOKEN_1 * 10);

        {
            (
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                uint256 feeGrowthInside0LastX128Position,
                uint256 feeGrowthInside1LastX128Position,
                uint128 tokensOwed0Position,
                uint128 tokensOwed1Position
            ) = nft.positions(tokenId2);

            assertEq(np.feeGrowthInside0LastX128, feeGrowthInside0LastX128Position);
            assertEq(np.feeGrowthInside1LastX128, feeGrowthInside1LastX128Position);
            assertApproxEqAbs(uint256(tokensOwed0Position), 15e14, 2);
            assertApproxEqAbs(uint256(tokensOwed1Position), 15e14, 2);
            assertApproxEqAbs(uint256(np.tokensOwed0), 15e14, 2);
            assertApproxEqAbs(uint256(np.tokensOwed1), 15e14, 2);
        }

        // feeGrowthInsideXLastX128 should be the same for staked and unstaked in all cases
        assertEq(gp.feeGrowthInside0LastX128, np.feeGrowthInside0LastX128);
        assertEq(gp.feeGrowthInside1LastX128, np.feeGrowthInside1LastX128);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertApproxEqAbs(_token0, 15e14, 1);
        assertApproxEqAbs(_token1, 15e14, 1);
    }

    function test_DecreaseStakedLiquidityUpdatesFeeGrowthInsideAndTokensOwedCorrectlyWithFlashLoanPositionsPartiallyStaked(
    ) public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        {
            // fee is 0.003
            uint256 pay = TOKEN_1 + 3e15;

            uniswapV3Callee.flash(address(pool), users.alice, TOKEN_1, TOKEN_1, pay, pay);
        }

        gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1), 0, 0, block.timestamp);

        Position.Info memory gp = Position.Info(0, 0, 0, 0, 0);
        // check tokenId
        (gp.liquidity, gp.feeGrowthInside0LastX128, gp.feeGrowthInside1LastX128, gp.tokensOwed0, gp.tokensOwed1) = pool
            .positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );

        assertEqUint(gp.liquidity, TOKEN_1 * 9);

        {
            (
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                uint256 feeGrowthInside0LastX128Position,
                uint256 feeGrowthInside1LastX128Position,
                uint128 tokensOwed0Position,
                uint128 tokensOwed1Position
            ) = nft.positions(tokenId);

            assertEq(gp.feeGrowthInside0LastX128, feeGrowthInside0LastX128Position);
            assertEq(gp.feeGrowthInside1LastX128, feeGrowthInside1LastX128Position);
            assertEqUint(gp.tokensOwed0, 0);
            assertEqUint(gp.tokensOwed1, 0);
            assertEqUint(tokensOwed0Position, 0);
            assertEqUint(tokensOwed1Position, 0);
        }

        // check TokenId2

        uint256 pre0Bal = token0.balanceOf(users.alice);
        nft.approve(address(nftCallee), tokenId2);
        nftCallee.collectOneAndOneForTokenId(tokenId2, users.alice);

        assertEq(token0.balanceOf(users.alice), pre0Bal + 1); // should collect 1 for unstaked position

        Position.Info memory np = Position.Info(0, 0, 0, 0, 0);

        (np.liquidity, np.feeGrowthInside0LastX128, np.feeGrowthInside1LastX128, np.tokensOwed0, np.tokensOwed1) = pool
            .positions(keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60))));

        assertEqUint(np.liquidity, TOKEN_1 * 10);

        {
            (
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                uint256 feeGrowthInside0LastX128Position,
                uint256 feeGrowthInside1LastX128Position,
                uint128 tokensOwed0Position,
                uint128 tokensOwed1Position
            ) = nft.positions(tokenId2);

            assertEq(np.feeGrowthInside0LastX128, feeGrowthInside0LastX128Position);
            assertEq(np.feeGrowthInside1LastX128, feeGrowthInside1LastX128Position);
            assertApproxEqAbs(uint256(tokensOwed0Position), 15e14, 2);
            assertApproxEqAbs(uint256(tokensOwed1Position), 15e14, 2);
            assertApproxEqAbs(uint256(np.tokensOwed0), 15e14, 2);
            assertApproxEqAbs(uint256(np.tokensOwed1), 15e14, 2);
        }

        // feeGrowthInsideXLastX128 should be the same for staked and unstaked in all cases
        assertEq(gp.feeGrowthInside0LastX128, np.feeGrowthInside0LastX128);
        assertEq(gp.feeGrowthInside1LastX128, np.feeGrowthInside1LastX128);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 15e14);
        assertEq(_token1, 15e14);
    }

    function test_DecreaseStakedLiquidityUpdatesCollectableRewards() public {
        uint256 aliceTokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(aliceTokenId);

        nft.approve(address(gauge), aliceTokenId);
        gauge.deposit(aliceTokenId);

        vm.startPrank(users.bob);
        uint256 bobTokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.bob);

        nft.approve(address(gauge), bobTokenId);
        gauge.deposit(bobTokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skipToNextEpoch(0);

        uint256 aliceBalanceBefore = rewardToken.balanceOf(users.alice);
        uint256 bobBalanceBefore = rewardToken.balanceOf(users.bob);

        vm.prank(users.alice);
        gauge.decreaseStakedLiquidity(aliceTokenId, positionLiquidity - 10, 0, 0, block.timestamp);

        vm.prank(users.alice);
        gauge.getReward(aliceTokenId);

        vm.prank(users.bob);
        gauge.getReward(bobTokenId);

        uint256 aliceBalanceAfter = rewardToken.balanceOf(users.alice);
        uint256 bobBalanceAfter = rewardToken.balanceOf(users.bob);

        assertApproxEqAbs(aliceBalanceAfter - aliceBalanceBefore, TOKEN_1 / 2, 1e5);
        assertApproxEqAbs(bobBalanceAfter - bobBalanceBefore, TOKEN_1 / 2, 1e5);
    }
}
