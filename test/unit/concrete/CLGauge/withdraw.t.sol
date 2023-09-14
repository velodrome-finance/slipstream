pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGauge.t.sol";

contract WithdrawTest is CLGaugeTest {
    using stdStorage for StdStorage;
    using SafeCast for uint128;

    UniswapV3Pool public pool;
    CLGauge public gauge;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: TICK_SPACING_60})
        );

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);

        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.alice);
    }

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
            deadline: 10
        });
        (uint256 tokenId,,,) = nft.mint(params);

        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});

        changePrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.withdraw({tokenId: tokenId});
    }

    function test_WithdrawWithPositionInCurrentPrice() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: -TICK_SPACING_60,
            tickUpper: TICK_SPACING_60,
            recipient: users.alice,
            amount0Desired: TOKEN_1,
            amount1Desired: TOKEN_1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: 10
        });
        (uint256 tokenId, uint128 liquidity,,) = nft.mint(params);
        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});

        vm.expectEmit(true, true, true, false, address(gauge));
        emit Withdraw({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.withdraw({tokenId: tokenId});

        assertEq(nft.balanceOf(address(gauge)), 0);
        assertEq(nft.balanceOf(users.alice), 1);
        assertEq(nft.ownerOf(tokenId), address(users.alice));
        assertEq(gauge.stakedLength(users.alice), 0);
        assertEq(gauge.stakedContains(users.alice, 1), false);
        assertEq(gauge.rewardGrowthInside(tokenId), 0);
        assertEqUint(pool.liquidity(), liquidity);
        assertEqUint(pool.stakedLiquidity(), 0);
        (,, int128 stakedLiquidityNet,,,,,,,) = pool.ticks(-TICK_SPACING_60);
        assertEq(stakedLiquidityNet, 0);
        (,, stakedLiquidityNet,,,,,,,) = pool.ticks(TICK_SPACING_60);
        assertEq(stakedLiquidityNet, 0);
    }

    function test_WithdrawWithPositionRightOfCurrentPrice() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: TICK_SPACING_60,
            tickUpper: 2 * TICK_SPACING_60,
            recipient: users.alice,
            amount0Desired: TOKEN_1,
            amount1Desired: TOKEN_1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: 10
        });
        (uint256 tokenId, uint128 liquidity,,) = nft.mint(params);
        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});

        vm.expectEmit(true, true, true, false, address(gauge));
        emit Withdraw({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.withdraw({tokenId: tokenId});

        assertEq(nft.balanceOf(address(gauge)), 0);
        assertEq(nft.balanceOf(users.alice), 1);
        assertEq(nft.ownerOf(tokenId), address(users.alice));
        assertEq(gauge.stakedLength(users.alice), 0);
        assertEq(gauge.stakedContains(users.alice, 1), false);
        assertEq(gauge.rewardGrowthInside(tokenId), 0);
        assertEqUint(pool.liquidity(), 0);
        assertEqUint(pool.stakedLiquidity(), 0);
        (,, int128 stakedLiquidityNet,,,,,,,) = pool.ticks(TICK_SPACING_60);
        assertEq(stakedLiquidityNet, 0);
        (,, stakedLiquidityNet,,,,,,,) = pool.ticks(2 * TICK_SPACING_60);
        assertEq(stakedLiquidityNet, 0);
    }

    function test_WithdrawWithPositionLeftOfCurrentPrice() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: -2 * TICK_SPACING_60,
            tickUpper: -TICK_SPACING_60,
            recipient: users.alice,
            amount0Desired: TOKEN_1,
            amount1Desired: TOKEN_1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: 10
        });
        (uint256 tokenId, uint128 liquidity,,) = nft.mint(params);
        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});

        vm.expectEmit(true, true, true, false, address(gauge));
        emit Withdraw({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.withdraw({tokenId: tokenId});

        assertEq(nft.balanceOf(address(gauge)), 0);
        assertEq(nft.balanceOf(users.alice), 1);
        assertEq(nft.ownerOf(tokenId), address(users.alice));
        assertEq(gauge.stakedLength(users.alice), 0);
        assertEq(gauge.stakedContains(users.alice, 1), false);
        assertEq(gauge.rewardGrowthInside(tokenId), 0);
        assertEqUint(pool.liquidity(), 0);
        assertEqUint(pool.stakedLiquidity(), 0);
        (,, int128 stakedLiquidityNet,,,,,,,) = pool.ticks(-2 * TICK_SPACING_60);
        assertEq(stakedLiquidityNet, 0);
        (,, stakedLiquidityNet,,,,,,,) = pool.ticks(-TICK_SPACING_60);
        assertEq(stakedLiquidityNet, 0);
    }

    function test_WithdrawCollectsRewards() public {
        skipToNextEpoch(0);
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: -TICK_SPACING_60,
            tickUpper: TICK_SPACING_60,
            recipient: users.alice,
            amount0Desired: TOKEN_1,
            amount1Desired: TOKEN_1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        (uint256 tokenId, uint128 liquidity,,) = nft.mint(params);
        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        vm.startPrank(users.alice);

        skip(2 days);

        vm.expectEmit(true, true, true, false, address(gauge));
        emit Withdraw({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.withdraw({tokenId: tokenId});

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 7 * 2, 1e5);

        assertEq(nft.balanceOf(address(gauge)), 0);
        assertEq(nft.balanceOf(users.alice), 1);
        assertEq(nft.ownerOf(tokenId), address(users.alice));
        assertEq(gauge.stakedLength(users.alice), 0);
        assertEq(gauge.stakedContains(users.alice, 1), false);
        // we know that at this point the rewardGrowthInside will be the rewardGrowthGlobalX128
        assertEq(gauge.rewardGrowthInside(tokenId), pool.rewardGrowthGlobalX128());
        assertEqUint(pool.liquidity(), liquidity);
        assertEqUint(pool.stakedLiquidity(), 0);
        (,, int128 stakedLiquidityNet,,,,,,,) = pool.ticks(-TICK_SPACING_60);
        assertEq(stakedLiquidityNet, 0);
        (,, stakedLiquidityNet,,,,,,,) = pool.ticks(TICK_SPACING_60);
        assertEq(stakedLiquidityNet, 0);
    }

    function test_WithdrawUpdatesPositionCorrectly() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        // swap 1 token1
        uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

        gauge.withdraw(tokenId);

        nft.approve(address(nftCallee), tokenId);
        // call collect to trigger update on the nft position
        nftCallee.collectOneAndOneForTokenId(tokenId, users.alice);

        (
            ,
            uint256 feeGrowthInside0LastX128Gauge,
            uint256 feeGrowthInside1LastX128Gauge,
            uint128 tokensOwed0Gauge,
            uint128 tokensOwed1Gauge
        ) = pool.positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );

        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1)
        = pool.positions(
            keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
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
            uint256 feeGrowthInside0LastX128NFT,
            uint256 feeGrowthInside1LastX128NFT,
            uint128 tokensOwed0NFT,
            uint128 tokensOwed1NFT
        ) = nft.positions(tokenId);

        assertEq(feeGrowthInside0LastX128, feeGrowthInside0LastX128NFT);
        assertEq(feeGrowthInside1LastX128, feeGrowthInside1LastX128NFT);
        assertEq(feeGrowthInside0LastX128Gauge, feeGrowthInside0LastX128NFT);
        assertEq(feeGrowthInside1LastX128Gauge, feeGrowthInside1LastX128NFT);
        assertEqUint(tokensOwed0NFT, 0);
        assertEqUint(tokensOwed1NFT, 0);
        assertEqUint(tokensOwed0, 0);
        assertEqUint(tokensOwed1, 0);
        // tokensOwed should be 0 in all cases for gauge
        assertEqUint(tokensOwed0Gauge, 0);
        assertEqUint(tokensOwed1Gauge, 0);
    }

    function test_WithdrawUpdatesPositionCorrectlyWithUnstakedPositions() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        // call collect to trigger update on the nft position
        nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: users.alice,
                amount0Max: 1, // don't actually collect it all
                amount1Max: 1
            })
        );

        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1)
        = pool.positions(
            keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );
        {
            // check tokenId
            (
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                uint256 feeGrowthInside0LastX128NFT,
                uint256 feeGrowthInside1LastX128NFT,
                uint128 tokensOwed0NFT,
                uint128 tokensOwed1NFT
            ) = nft.positions(tokenId);

            assertEq(feeGrowthInside0LastX128, feeGrowthInside0LastX128NFT);
            assertEq(feeGrowthInside1LastX128, feeGrowthInside1LastX128NFT);
            assertApproxEqAbs(uint256(tokensOwed0NFT), 15e14, 2);
            assertEqUint(tokensOwed1NFT, 0);
            assertApproxEqAbs(uint256(tokensOwed0), 3e15, 2);
            assertEqUint(tokensOwed1, 0);
        }
    }

    function test_WithdrawUpdatesPositionCorrectlyWithStakedAndUnstakedButStakedTriggersUpdate() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        // two identical nfts, deposit one of them
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        // staked triggers withdraw
        // triggers call to burn => position.update(staked=true)
        gauge.withdraw(tokenId);

        uint256 pre0Bal = token0.balanceOf(users.alice);
        nft.approve(address(nftCallee), tokenId);
        // call collect to trigger update on the nft position
        nftCallee.collectOneAndOneForTokenId(tokenId, users.alice);

        assertEq(token0.balanceOf(users.alice), pre0Bal); // values should be equal

        // gauge position in the pool (staked)
        (
            ,
            uint256 feeGrowthInside0LastX128Gauge,
            uint256 feeGrowthInside1LastX128Gauge,
            uint128 tokensOwed0Gauge,
            uint128 tokensOwed1Gauge
        ) = pool.positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );

        // check tokenId
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

            assertEq(feeGrowthInside0LastX128Gauge, feeGrowthInside0LastX128Position);
            assertEq(feeGrowthInside1LastX128Gauge, feeGrowthInside1LastX128Position);
            assertEqUint(tokensOwed0Position, 0);
            assertEqUint(tokensOwed1Position, 0);
            // tokensOwed should be 0 in all cases for gauge
            assertEqUint(tokensOwed0Gauge, 0);
            assertEqUint(tokensOwed1Gauge, 0);
        }

        pre0Bal = token0.balanceOf(users.alice);
        nft.approve(address(nftCallee), tokenId2);
        nftCallee.collectOneAndOneForTokenId(tokenId2, users.alice);

        assertEq(token0.balanceOf(users.alice), pre0Bal + 1); // should collect 1 for tokenId2

        // nft position in the pool (unstaked)
        (
            ,
            uint256 feeGrowthInside0LastX128Nft,
            uint256 feeGrowthInside1LastX128Nft,
            uint128 tokensOwed0Nft,
            uint128 tokensOwed1Nft
        ) = pool.positions(
            keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );
        // check tokenId2
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

            assertEq(feeGrowthInside0LastX128Nft, feeGrowthInside0LastX128Position);
            assertEq(feeGrowthInside1LastX128Nft, feeGrowthInside1LastX128Position);
            assertApproxEqAbs(uint256(tokensOwed0Position), 15e14, 2);
            assertEqUint(tokensOwed1Position, 0);
            assertApproxEqAbs(uint256(tokensOwed0Nft), 15e14, 2);
            assertEqUint(tokensOwed1Nft, 0);
        }

        // feeGrowthInsideXLastX128 should be the same for staked and unstaked in all cases
        assertEq(feeGrowthInside0LastX128Gauge, feeGrowthInside0LastX128Nft);
        assertEq(feeGrowthInside1LastX128Gauge, feeGrowthInside1LastX128Nft);
    }

    function test_WithdrawUpdatesPositionCorrectlyWithStakedAndUnstakedButUnstakedTriggersUpdate() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        // two identical nfts, deposit one of them
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        // call collect to trigger update on the nft position
        // triggers call to burn => position.update(staked=false)
        uint256 pre0Bal = token0.balanceOf(users.alice);
        nft.approve(address(nftCallee), tokenId2);
        nftCallee.collectOneAndOneForTokenId(tokenId2, users.alice);

        assertEq(token0.balanceOf(users.alice), pre0Bal + 1); // should collect 1 for unstaked position

        gauge.withdraw(tokenId);

        pre0Bal = token0.balanceOf(users.alice);
        nft.approve(address(nftCallee), tokenId);
        nftCallee.collectOneAndOneForTokenId(tokenId, users.alice); // should be equal

        assertEq(token0.balanceOf(users.alice), pre0Bal);
        // gauge position in the pool (staked)
        (
            ,
            uint256 feeGrowthInside0LastX128Gauge,
            uint256 feeGrowthInside1LastX128Gauge,
            uint128 tokensOwed0Gauge,
            uint128 tokensOwed1Gauge
        ) = pool.positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );

        // check tokenId
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

            assertEq(feeGrowthInside0LastX128Gauge, feeGrowthInside0LastX128Position);
            assertEq(feeGrowthInside1LastX128Gauge, feeGrowthInside1LastX128Position);
            assertEqUint(tokensOwed0Position, 0);
            assertEqUint(tokensOwed1Position, 0);
            // tokensOwed should be 0 in all cases for gauge
            assertEqUint(tokensOwed0Gauge, 0);
            assertEqUint(tokensOwed1Gauge, 0);
        }

        // nft position in the pool (unstaked)
        (
            ,
            uint256 feeGrowthInside0LastX128Nft,
            uint256 feeGrowthInside1LastX128Nft,
            uint128 tokensOwed0Nft,
            uint128 tokensOwed1Nft
        ) = pool.positions(
            keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );
        // check tokenId2
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

            assertEq(feeGrowthInside0LastX128Nft, feeGrowthInside0LastX128Position);
            assertEq(feeGrowthInside1LastX128Nft, feeGrowthInside1LastX128Position);
            assertApproxEqAbs(uint256(tokensOwed0Position), 15e14, 2);
            assertEqUint(tokensOwed1Position, 0);
            assertApproxEqAbs(uint256(tokensOwed0Nft), 15e14, 2);
            assertEqUint(tokensOwed1Nft, 0);
        }

        // feeGrowthInsideXLastX128 should be the same for staked and unstaked in all cases
        assertEq(feeGrowthInside0LastX128Gauge, feeGrowthInside0LastX128Nft);
        assertEq(feeGrowthInside1LastX128Gauge, feeGrowthInside1LastX128Nft);
    }
}
