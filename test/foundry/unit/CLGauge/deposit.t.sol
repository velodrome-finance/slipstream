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
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: TICK_SPACING_60})
        );
        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.alice);
        deal({token: address(token0), to: users.alice, give: TOKEN_1});
        deal({token: address(token1), to: users.alice, give: TOKEN_1});
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);
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

        changePrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.deposit({tokenId: tokenId});
    }

    function test_RevertIf_GaugeNotAlive() public {
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

        // write directly to storage to kill gauge in the mock contract
        stdstore.target({_target: address(voter)}).sig({_sig: voter.isAlive.selector}).with_key({who: address(gauge)})
            .checked_write({write: false});

        vm.expectRevert(abi.encodePacked("GK"));
        gauge.deposit({tokenId: tokenId});
    }

    function test_DepositWithPositionInCurrentPrice() public {
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
    }

    function test_DepositWithPositionRightOfCurrentPrice() public {
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
    }

    function test_DepositWithPositionLeftOfCurrentPrice() public {
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
    }
}
