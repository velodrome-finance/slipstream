// pragma solidity ^0.7.6;
// pragma abicoder v2;

// import "./LiquidityManagementBase.t.sol";

// contract IncreaseStakedLiquidityTest is LiquidityManagementBase {
//     function test_RevertIf_CallerIsNotOwner() public {
//         uint256 tokenId = mintNewCustomRangePositionForUserWith60TickSpacing(
//             TOKEN_1, TOKEN_1, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
//         );

//         nft.approve(address(gauge), tokenId);
//         gauge.deposit({tokenId: tokenId});

//         changePrank(users.bob);
//         vm.expectRevert(abi.encodePacked("STF"));
//         gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);
//     }

//     function test_IncreaseLiquidity() public {
//         uint256 tokenId = mintNewCustomRangePositionForUserWith60TickSpacing(
//             TOKEN_1, TOKEN_1, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
//         );

//         nft.approve(address(gauge), tokenId);
//         gauge.deposit({tokenId: tokenId});

//         (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEq(pool.stakedLiquidity(), TOKEN_1);
//         assertEq(pool.liquidity(), TOKEN_1);
//         assertEq(positionLiquidity, TOKEN_1);

//         uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

//         gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

//         uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

//         assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);
//         assertEq(aliceBalanceBefore1 - aliceBalanceAfter1, TOKEN_1);

//         (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
//         assertEq(pool.liquidity(), TOKEN_1 * 2);
//         assertEq(positionLiquidity, TOKEN_1 * 2);
//     }

//     function test_IncreaseAndDecreaseLiquidity() public {
//         uint256 tokenId = mintNewCustomRangePositionForUserWith60TickSpacing(
//             TOKEN_1 * 2, TOKEN_1 * 2, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
//         );

//         nft.approve(address(gauge), tokenId);
//         gauge.deposit({tokenId: tokenId});

//         (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
//         assertEq(pool.liquidity(), TOKEN_1 * 2);
//         assertEq(positionLiquidity, TOKEN_1 * 2);

//         uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

//         gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

//         uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

//         assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);
//         assertEq(aliceBalanceBefore1 - aliceBalanceAfter1, TOKEN_1);

//         (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEq(pool.stakedLiquidity(), TOKEN_1 * 3);
//         assertEq(pool.liquidity(), TOKEN_1 * 3);
//         assertEq(positionLiquidity, TOKEN_1 * 3);

//         gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1) * 2, 0, 0, block.timestamp);

//         uint256 aliceBalanceFinal0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceFinal1 = token1.balanceOf(users.alice);

//         assertApproxEqAbs(aliceBalanceFinal0 - aliceBalanceAfter0, TOKEN_1 * 2, 1);
//         assertApproxEqAbs(aliceBalanceFinal1 - aliceBalanceAfter1, TOKEN_1 * 2, 1);

//         (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEq(pool.stakedLiquidity(), TOKEN_1);
//         assertEq(pool.liquidity(), TOKEN_1);
//         assertEq(positionLiquidity, TOKEN_1);
//     }

//     function test_IncreaseLiquidityNotEqualAmountsRefundSurplusToken0() public {
//         uint256 tokenId = mintNewCustomRangePositionForUserWith60TickSpacing(
//             TOKEN_1, TOKEN_1, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
//         );

//         nft.approve(address(gauge), tokenId);
//         gauge.deposit({tokenId: tokenId});

//         (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEq(pool.stakedLiquidity(), TOKEN_1);
//         assertEq(pool.liquidity(), TOKEN_1);
//         assertEq(positionLiquidity, TOKEN_1);

//         uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

//         gauge.increaseStakedLiquidity(tokenId, TOKEN_1 * 5, TOKEN_1, 0, 0, block.timestamp);

//         uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

//         assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);
//         assertEq(aliceBalanceBefore1 - aliceBalanceAfter1, TOKEN_1);

//         (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
//         assertEq(pool.liquidity(), TOKEN_1 * 2);
//         assertEq(positionLiquidity, TOKEN_1 * 2);
//     }

//     function test_IncreaseLiquidityNotEqualAmountsRefundSurplusToken1() public {
//         uint256 tokenId = mintNewCustomRangePositionForUserWith60TickSpacing(
//             TOKEN_1, TOKEN_1, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
//         );

//         nft.approve(address(gauge), tokenId);
//         gauge.deposit({tokenId: tokenId});

//         (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEq(pool.stakedLiquidity(), TOKEN_1);
//         assertEq(pool.liquidity(), TOKEN_1);
//         assertEq(positionLiquidity, TOKEN_1);

//         uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

//         gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1 * 6, 0, 0, block.timestamp);

//         uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

//         assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);
//         assertEq(aliceBalanceBefore1 - aliceBalanceAfter1, TOKEN_1);

//         (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
//         assertEq(pool.liquidity(), TOKEN_1 * 2);
//         assertEq(positionLiquidity, TOKEN_1 * 2);
//     }

//     function test_IncreaseLiquidityUpdatesFeeGrowthInsideAndTokensOwedCorrectly() public {
//         uint256 tokenId = mintNewCustomRangePositionForUserWith60TickSpacing(
//             TOKEN_1 * 10, TOKEN_1 * 10, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
//         );

//         nft.approve(address(gauge), tokenId);
//         gauge.deposit(tokenId);

//         // swap 1 token0
//         uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

//         // swap 1 token1
//         uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

//         gauge.increaseStakedLiquidity(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

//         (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1)
//         = pool.positions(
//             keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
//         );

//         (
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             uint256 feeGrowthInside0LastX128NFT,
//             uint256 feeGrowthInside1LastX128NFT,
//             uint128 tokensOwed0NFT,
//             uint128 tokensOwed1NFT
//         ) = nft.positions(tokenId);

//         assertEq(feeGrowthInside0LastX128, feeGrowthInside0LastX128NFT);
//         assertEq(feeGrowthInside1LastX128, feeGrowthInside1LastX128NFT);
//         assertEqUint(tokensOwed0NFT, 0);
//         assertEqUint(tokensOwed1NFT, 0);
//         // this check can be added once this is merged and #39 is being worked on
//         //assertEqUint(tokensOwed0, tokensOwed0NFT);
//         //assertEqUint(tokensOwed1, tokensOwed1NFT);
//     }
// }
