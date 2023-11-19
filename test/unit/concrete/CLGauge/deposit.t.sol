pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGauge.t.sol";

contract DepositTest is CLGaugeTest {
    using stdStorage for StdStorage;
    using SafeCast for uint128;

    UniswapV3Pool public pool;
    CLGauge public gauge;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);
        vm.startPrank(users.alice);
    }

    function test_RevertIf_CallerIsNotOwner() public {
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

        vm.startPrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.deposit({tokenId: tokenId});
    }

    function test_RevertIf_GaugeNotAlive() public {
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

        // write directly to storage to kill gauge in the mock contract
        stdstore.target({_target: address(voter)}).sig({_sig: voter.isAlive.selector}).with_key({who: address(gauge)})
            .checked_write({write: false});

        vm.expectRevert(abi.encodePacked("GK"));
        gauge.deposit({tokenId: tokenId});
    }

    function test_DepositWithPositionInCurrentPrice() public {
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
        vm.expectEmit(true, true, true, false, address(gauge));
        emit Deposit({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.deposit({tokenId: tokenId});

        assertEq(nft.balanceOf(address(gauge)), 1);
        assertEq(nft.balanceOf(users.alice), 0);
        assertEq(nft.ownerOf(tokenId), address(gauge));
        assertEq(gauge.stakedLength(users.alice), 1);
        assertEq(gauge.stakedContains(users.alice, 1), true);
        assertEq(gauge.rewardGrowthInside(tokenId), 0);
        assertEqUint(pool.liquidity(), liquidity);
        assertEqUint(pool.stakedLiquidity(), liquidity);
        (,, int128 stakedLiquidityNet,,,,,,,) = pool.ticks(-TICK_SPACING_60);
        assertEq(stakedLiquidityNet, liquidity.toInt128());
        (,, stakedLiquidityNet,,,,,,,) = pool.ticks(TICK_SPACING_60);
        assertEq(stakedLiquidityNet, -1 * liquidity.toInt128());
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 1);

        (uint128 gaugeLiquidity,,,,) =
            pool.positions(keccak256(abi.encodePacked(address(gauge), -TICK_SPACING_60, TICK_SPACING_60)));
        assertEqUint(gaugeLiquidity, liquidity);

        (uint128 nftLiquidity,,,,) =
            pool.positions(keccak256(abi.encodePacked(address(nft), -TICK_SPACING_60, TICK_SPACING_60)));
        assertEqUint(nftLiquidity, 0);
    }

    function test_DepositWithPositionRightOfCurrentPrice() public {
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
        vm.expectEmit(true, true, true, false, address(gauge));
        emit Deposit({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.deposit({tokenId: tokenId});

        assertEq(nft.balanceOf(address(gauge)), 1);
        assertEq(nft.balanceOf(users.alice), 0);
        assertEq(nft.ownerOf(tokenId), address(gauge));
        assertEq(gauge.stakedLength(users.alice), 1);
        assertEq(gauge.stakedContains(users.alice, 1), true);
        assertEq(gauge.rewardGrowthInside(tokenId), 0);
        assertEqUint(pool.liquidity(), 0);
        assertEqUint(pool.stakedLiquidity(), 0);
        (,, int128 stakedLiquidityNet,,,,,,,) = pool.ticks(TICK_SPACING_60);
        assertEq(stakedLiquidityNet, liquidity.toInt128());
        (,, stakedLiquidityNet,,,,,,,) = pool.ticks(2 * TICK_SPACING_60);
        assertEq(stakedLiquidityNet, -1 * liquidity.toInt128());
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 1);

        (uint128 gaugeLiquidity,,,,) =
            pool.positions(keccak256(abi.encodePacked(address(gauge), TICK_SPACING_60, 2 * TICK_SPACING_60)));
        assertEqUint(gaugeLiquidity, liquidity);

        (uint128 nftLiquidity,,,,) =
            pool.positions(keccak256(abi.encodePacked(address(nft), TICK_SPACING_60, 2 * TICK_SPACING_60)));
        assertEqUint(nftLiquidity, 0);
    }

    function test_DepositWithPositionLeftOfCurrentPrice() public {
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
        vm.expectEmit(true, true, true, false, address(gauge));
        emit Deposit({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.deposit({tokenId: tokenId});

        assertEq(nft.balanceOf(address(gauge)), 1);
        assertEq(nft.balanceOf(users.alice), 0);
        assertEq(nft.ownerOf(tokenId), address(gauge));
        assertEq(gauge.stakedLength(users.alice), 1);
        assertEq(gauge.stakedContains(users.alice, 1), true);
        assertEq(gauge.rewardGrowthInside(tokenId), 0);
        assertEqUint(pool.liquidity(), 0);
        assertEqUint(pool.stakedLiquidity(), 0);
        (,, int128 stakedLiquidityNet,,,,,,,) = pool.ticks(-2 * TICK_SPACING_60);
        assertEq(stakedLiquidityNet, liquidity.toInt128());
        (,, stakedLiquidityNet,,,,,,,) = pool.ticks(-TICK_SPACING_60);
        assertEq(stakedLiquidityNet, -1 * liquidity.toInt128());
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 1);

        (uint128 gaugeLiquidity,,,,) =
            pool.positions(keccak256(abi.encodePacked(address(gauge), -2 * TICK_SPACING_60, -TICK_SPACING_60)));
        assertEqUint(gaugeLiquidity, liquidity);

        (uint128 nftLiquidity,,,,) =
            pool.positions(keccak256(abi.encodePacked(address(nft), -2 * TICK_SPACING_60, -TICK_SPACING_60)));
        assertEqUint(nftLiquidity, 0);
    }

    function test_DepositCollectsAlreadyAccumulatedFees() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        // swap 1 token0
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        // swap 1 token1
        uniswapV3Callee.swapExact1For0(address(pool), 1e18, users.alice, MAX_SQRT_RATIO - 1);

        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBefore1 = token1.balanceOf(users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceAfter1 = token1.balanceOf(users.alice);

        assertApproxEqAbs(aliceBalanceAfter0 - aliceBalanceBefore0, 3e15, 1);
        assertApproxEqAbs(aliceBalanceAfter1 - aliceBalanceBefore1, 3e15, 1);

        (uint128 gaugeLiquidity,,,,) = pool.positions(
            keccak256(abi.encodePacked(address(gauge), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );
        assertEqUint(gaugeLiquidity, TOKEN_1 * 10);

        (uint128 nftLiquidity,,,,) = pool.positions(
            keccak256(abi.encodePacked(address(nft), getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60)))
        );
        assertEqUint(nftLiquidity, 0);
    }
}
