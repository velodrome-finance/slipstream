pragma solidity ^0.7.6;
pragma abicoder v2;

import "./LiquidityManagementBase.t.sol";

contract DecreaseStakedLiquidityTest is LiquidityManagementBase {
    // TODO: Use correct abstraction once #39 is merged
    function test_RevertIf_CallerIsNotOwner() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: getMinTick(TICK_SPACING_60),
            tickUpper: getMaxTick(TICK_SPACING_60),
            recipient: users.alice,
            amount0Desired: TOKEN_1,
            amount1Desired: TOKEN_1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        (uint256 tokenId,,,) = nft.mint(params);

        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});

        changePrank(users.bob);
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1), 0, 0, block.timestamp);
    }

    // TODO: Use correct abstraction once #39 is merged
    function test_DecreaseLiquidity() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: getMinTick(TICK_SPACING_60),
            tickUpper: getMaxTick(TICK_SPACING_60),
            recipient: users.alice,
            amount0Desired: TOKEN_1 * 2,
            amount1Desired: TOKEN_1 * 2,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        (uint256 tokenId,,,) = nft.mint(params);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});

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
    }

    function test_DecreaseLiquidityToZero() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: getMinTick(TICK_SPACING_60),
            tickUpper: getMaxTick(TICK_SPACING_60),
            recipient: users.alice,
            amount0Desired: TOKEN_1 * 2,
            amount1Desired: TOKEN_1 * 2,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        (uint256 tokenId,,,) = nft.mint(params);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});

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
}
