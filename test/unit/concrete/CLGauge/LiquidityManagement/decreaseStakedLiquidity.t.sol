// pragma solidity ^0.7.6;
// pragma abicoder v2;

// import "./LiquidityManagementBase.t.sol";

// contract DecreaseStakedLiquidityTest is LiquidityManagementBase {
//     function test_RevertIf_CallerIsNotOwner() public {
//         uint256 tokenId = mintNewCustomRangePositionForUserWith60TickSpacing(
//             TOKEN_1, TOKEN_1, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
//         );

//         nft.approve(address(gauge), tokenId);
//         gauge.deposit({tokenId: tokenId});

//         changePrank(users.bob);
//         vm.expectRevert(abi.encodePacked("NA"));
//         gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1), 0, 0, block.timestamp);
//     }

//     function test_DecreaseLiquidity() public {
//         uint256 tokenId = mintNewCustomRangePositionForUserWith60TickSpacing(
//             TOKEN_1 * 2, TOKEN_1 * 2, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
//         );

//         (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

//         nft.approve(address(gauge), tokenId);
//         gauge.deposit({tokenId: tokenId});

//         assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
//         assertEq(pool.liquidity(), TOKEN_1 * 2);
//         assertEq(positionLiquidity, TOKEN_1 * 2);

//         uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

//         gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1), 0, 0, block.timestamp);

//         uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

//         assertApproxEqAbs(aliceBalanceAfter0 - aliceBalanceBefore0, TOKEN_1, 1);
//         assertApproxEqAbs(aliceBalanceAfter1 - aliceBalanceBefore1, TOKEN_1, 1);

//         (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEq(pool.stakedLiquidity(), TOKEN_1);
//         assertEq(pool.liquidity(), TOKEN_1);
//         assertEq(positionLiquidity, TOKEN_1);
//     }

//     function test_DecreaseLiquidityToZero() public {
//         INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
//             token0: address(token0),
//             token1: address(token1),
//             tickSpacing: TICK_SPACING_60,
//             tickLower: getMinTick(TICK_SPACING_60),
//             tickUpper: getMaxTick(TICK_SPACING_60),
//             recipient: users.alice,
//             amount0Desired: TOKEN_1 * 2,
//             amount1Desired: TOKEN_1 * 2,
//             amount0Min: 0,
//             amount1Min: 0,
//             deadline: block.timestamp
//         });
//         (uint256 tokenId,,,) = nft.mint(params);

//         (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

//         nft.approve(address(gauge), tokenId);
//         gauge.deposit({tokenId: tokenId});

//         assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
//         assertEq(pool.liquidity(), TOKEN_1 * 2);
//         assertEq(positionLiquidity, TOKEN_1 * 2);

//         uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

//         gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1 * 2), 0, 0, block.timestamp);

//         uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
//         uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

//         assertApproxEqAbs(aliceBalanceAfter0 - aliceBalanceBefore0, TOKEN_1 * 2, 1);
//         assertApproxEqAbs(aliceBalanceAfter1 - aliceBalanceBefore1, TOKEN_1 * 2, 1);

//         (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

//         assertEqUint(pool.stakedLiquidity(), 0);
//         assertEqUint(pool.liquidity(), 0);
//         assertEqUint(positionLiquidity, 0);
//     }

//     // function test_DecreaseLiquidityUpdatesFeeGrowthInsideAndTokensOwedCorrectly() public {
//     //     uint256 tokenId = mintNewCustomRangePositionForUserWith60TickSpacing(
//     //         TOKEN_1 * 10, TOKEN_1 * 10, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
//     //     );

//     //     nft.approve(address(gauge), tokenId);
//     //     gauge.deposit(tokenId);

//     //     // swap 1 token0
//     //     uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

//     //     // swap 1 token1
//     //     uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

//     //     gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1), 0, 0, block.timestamp);

//     //     (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1)
//     //     = pool.positions(
//     //         keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
//     //     );

//     //     (
//     //         ,
//     //         ,
//     //         ,
//     //         ,
//     //         ,
//     //         ,
//     //         ,
//     //         ,
//     //         uint256 feeGrowthInside0LastX128NFT,
//     //         uint256 feeGrowthInside1LastX128NFT,
//     //         uint128 tokensOwed0NFT,
//     //         uint128 tokensOwed1NFT
//     //     ) = nft.positions(tokenId);

//     //     assertEq(feeGrowthInside0LastX128, feeGrowthInside0LastX128NFT);
//     //     assertEq(feeGrowthInside1LastX128, feeGrowthInside1LastX128NFT);
//     //     assertEqUint(tokensOwed0NFT, 0);
//     //     assertEqUint(tokensOwed1NFT, 0);
//     //     // this check can be added once this is merged and #39 is being worked on
//     //     //assertEqUint(tokensOwed0, tokensOwed0NFT);
//     //     //assertEqUint(tokensOwed1, tokensOwed1NFT);
//     // }
// }
