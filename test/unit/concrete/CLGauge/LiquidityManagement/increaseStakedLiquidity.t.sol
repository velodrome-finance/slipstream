pragma solidity ^0.7.6;
pragma abicoder v2;

import "./LiquidityManagementBase.t.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";

contract IncreaseStakedLiquidityTest is LiquidityManagementBase {
    function test_RevertIf_CallerIsNotOwner() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        vm.startPrank(users.bob);
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);
    }

    function test_IncreaseStakedLiquidity() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1);
        assertEq(pool.liquidity(), TOKEN_1);
        assertEq(positionLiquidity, TOKEN_1);

        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

        gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

        assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);
        assertEq(aliceBalanceBefore1 - aliceBalanceAfter1, TOKEN_1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
        assertEq(pool.liquidity(), TOKEN_1 * 2);
        assertEq(positionLiquidity, TOKEN_1 * 2);

        (uint128 gaugeLiquidity,,,,) = pool.positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );
        assertEqUint(gaugeLiquidity, TOKEN_1 * 2);

        (uint128 nftLiquidity,,,,) = pool.positions(
            keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );
        assertEqUint(nftLiquidity, 0);
    }

    function test_IncreaseAndDecreaseStakedLiquidity() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
        assertEq(pool.liquidity(), TOKEN_1 * 2);
        assertEq(positionLiquidity, TOKEN_1 * 2);

        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

        gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

        assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);
        assertEq(aliceBalanceBefore1 - aliceBalanceAfter1, TOKEN_1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 3);
        assertEq(pool.liquidity(), TOKEN_1 * 3);
        assertEq(positionLiquidity, TOKEN_1 * 3);

        gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1) * 2, 0, 0, block.timestamp);

        uint256 aliceBalanceFinal0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceFinal1 = token1.balanceOf(users.alice);

        assertApproxEqAbs(aliceBalanceFinal0 - aliceBalanceAfter0, TOKEN_1 * 2, 1);
        assertApproxEqAbs(aliceBalanceFinal1 - aliceBalanceAfter1, TOKEN_1 * 2, 1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1);
        assertEq(pool.liquidity(), TOKEN_1);
        assertEq(positionLiquidity, TOKEN_1);
    }

    function test_IncreaseStakedLiquidityNotEqualAmountsRefundSurplusToken0() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1);
        assertEq(pool.liquidity(), TOKEN_1);
        assertEq(positionLiquidity, TOKEN_1);

        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

        gauge.increaseStakedLiquidity(tokenId, TOKEN_1 * 5, TOKEN_1, 0, 0, block.timestamp);

        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

        assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);
        assertEq(aliceBalanceBefore1 - aliceBalanceAfter1, TOKEN_1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
        assertEq(pool.liquidity(), TOKEN_1 * 2);
        assertEq(positionLiquidity, TOKEN_1 * 2);
    }

    function test_IncreaseStakedLiquidityNotEqualAmountsRefundSurplusToken1() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1);
        assertEq(pool.liquidity(), TOKEN_1);
        assertEq(positionLiquidity, TOKEN_1);

        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

        gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1 * 6, 0, 0, block.timestamp);

        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

        assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);
        assertEq(aliceBalanceBefore1 - aliceBalanceAfter1, TOKEN_1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
        assertEq(pool.liquidity(), TOKEN_1 * 2);
        assertEq(positionLiquidity, TOKEN_1 * 2);
    }

    function test_IncreaseStakedLiquidityUpdatesFeeGrowthInsideAndTokensOwedCorrectlyAllPositionStaked() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        // swap 1 token1
        uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

        gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

        (
            ,
            uint256 feeGrowthInside0LastX128Gauge,
            uint256 feeGrowthInside1LastX128Gauge,
            uint128 tokensOwed0Gauge,
            uint128 tokensOwed1Gauge
        ) = pool.positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );

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

    function test_IncreaseStakedLiquidityUpdatesFeeGrowthInsideAndTokensOwedCorrectlyWithSwapPositionsPartiallyStaked()
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

        gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

        Position.Info memory gp = Position.Info(0, 0, 0, 0, 0);
        // check tokenId
        (gp.liquidity, gp.feeGrowthInside0LastX128, gp.feeGrowthInside1LastX128, gp.tokensOwed0, gp.tokensOwed1) = pool
            .positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );

        // amount1 / (sqrt(upper) - sqrt(lower))
        (uint160 sqrtPriceX96,,,,,) = pool.slot0();
        // MIN_SQRT_RATIO since we use full range positions
        // (price is not moving back to exactly 1 so we have to calculate the liq being used)
        uint256 liq = FullMath.mulDiv(TOKEN_1, Q96, sqrtPriceX96 - MIN_SQRT_RATIO);

        assertEqUint(gp.liquidity, TOKEN_1 * 10 + liq);

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

    function test_IncreaseStakedLiquidityUpdatesFeeGrowthInsideAndTokensOwedCorrectlyWithFlashLoanPositionsPartiallyStaked(
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

        gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

        Position.Info memory gp = Position.Info(0, 0, 0, 0, 0);
        // check tokenId
        (gp.liquidity, gp.feeGrowthInside0LastX128, gp.feeGrowthInside1LastX128, gp.tokensOwed0, gp.tokensOwed1) = pool
            .positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );

        assertEqUint(gp.liquidity, TOKEN_1 * 11);

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

    function test_IncreaseStakedLiquidityUpdatesCollectableRewards() public {
        uint256 aliceTokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

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
        gauge.increaseStakedLiquidity(aliceTokenId, TOKEN_1 * 1, TOKEN_1 * 1, 0, 0, block.timestamp);

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
