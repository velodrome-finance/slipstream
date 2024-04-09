pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGauge.t.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";

contract IncreaseStakedLiquidityTest is CLGaugeTest {
    CLPool public pool;
    CLGauge public gauge;

    event MetadataUpdate(uint256 _tokenId);

    function setUp() public override {
        super.setUp();
        _createGaugeWithTokens(token0, weth);
    }

    function _createGaugeWithTokens(IERC20 _token0, IERC20 _token1) internal {
        pool = CLPool(
            poolFactory.createPool({
                tokenA: address(_token0),
                tokenB: address(_token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );

        vm.startPrank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);

        gauge = CLGauge(payable(voter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)})));

        nftCallee = new NFTManagerCallee(address(_token0), address(_token1), address(nft));

        vm.startPrank(users.alice);
        _token1.approve(address(gauge), type(uint256).max);
        _token0.approve(address(gauge), type(uint256).max);
        _token1.approve(address(nftCallee), type(uint256).max);
        _token0.approve(address(nftCallee), type(uint256).max);
        deal({token: address(_token1), to: users.alice, give: TOKEN_1 * 100});

        vm.label({account: address(gauge), newLabel: "Gauge"});
        vm.label({account: address(pool), newLabel: "Pool"});

        skipToNextEpoch(0);
    }

    function test_RevertIf_IncreaseStakedLiquidityWithNativeToken_InGaugeWithNoWETH() public {
        // @dev create pool with no weth
        _createGaugeWithTokens(token0, token1);
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        vm.expectRevert(abi.encodePacked("NP"));
        gauge.increaseStakedLiquidity{value: 5 * TOKEN_1}(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);
    }

    function test_IncreaseStakedLiquidityWithNativeToken() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        vm.expectEmit(false, false, false, true, address(nft));
        emit MetadataUpdate(tokenId);
        gauge.deposit(tokenId);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1);
        assertEq(pool.liquidity(), TOKEN_1);
        assertEq(positionLiquidity, TOKEN_1);

        uint256 aliceBalanceBeforeETH = users.alice.balance;
        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBeforeWETH = weth.balanceOf(users.alice);

        gauge.increaseStakedLiquidity{value: TOKEN_1}(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

        uint256 aliceBalanceAfterETH = users.alice.balance;
        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);

        assertEq(aliceBalanceBeforeWETH, weth.balanceOf(users.alice));
        assertEq(aliceBalanceBeforeETH - aliceBalanceAfterETH, TOKEN_1);
        assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);

        assertEq(weth.allowance(address(gauge), address(nft)), 0);
        assertEq(token0.allowance(address(gauge), address(nft)), 0);

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
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 604800);
    }

    function test_IncreaseStakedLiquidityWithNativeRefundsETH() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        vm.expectEmit(false, false, false, true, address(nft));
        emit MetadataUpdate(tokenId);
        gauge.deposit(tokenId);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1);
        assertEq(pool.liquidity(), TOKEN_1);
        assertEq(positionLiquidity, TOKEN_1);

        deal({to: users.alice, give: 10 * TOKEN_1});

        uint256 aliceBalanceBeforeETH = users.alice.balance;
        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBeforeWETH = weth.balanceOf(users.alice);

        // send 5 native tokens in TX, should only spend 1
        gauge.increaseStakedLiquidity{value: 5 * TOKEN_1}(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

        uint256 aliceBalanceAfterETH = users.alice.balance;
        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);

        assertEq(aliceBalanceBeforeWETH, weth.balanceOf(users.alice));
        assertEq(aliceBalanceBeforeETH - aliceBalanceAfterETH, TOKEN_1);
        assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);

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
        assertEq(gauge.rewards(tokenId), 0);
        assertEq(gauge.lastUpdateTime(tokenId), 604800);
    }

    function test_IncreaseAndDecreaseStakedLiquidityWithNative() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
        assertEq(pool.liquidity(), TOKEN_1 * 2);
        assertEq(positionLiquidity, TOKEN_1 * 2);

        uint256 aliceBalanceBeforeETH = users.alice.balance;
        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBeforeWETH = weth.balanceOf(users.alice);

        gauge.increaseStakedLiquidity{value: TOKEN_1}(tokenId, TOKEN_1, TOKEN_1, 0, 0, block.timestamp);

        uint256 aliceBalanceAfterETH = users.alice.balance;
        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);

        assertEq(aliceBalanceBeforeWETH, weth.balanceOf(users.alice));
        assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);
        assertEq(aliceBalanceBeforeETH - aliceBalanceAfterETH, TOKEN_1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 3);
        assertEq(pool.liquidity(), TOKEN_1 * 3);
        assertEq(positionLiquidity, TOKEN_1 * 3);

        gauge.decreaseStakedLiquidity(tokenId, uint128(TOKEN_1) * 2, 0, 0, block.timestamp);

        uint256 aliceBalanceFinal0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceFinalWETH = weth.balanceOf(users.alice);

        assertEq(aliceBalanceAfterETH, users.alice.balance);
        assertApproxEqAbs(aliceBalanceFinal0 - aliceBalanceAfter0, TOKEN_1 * 2, 1);
        // after liquidity is decreased balance should be in WETH
        assertApproxEqAbs(aliceBalanceFinalWETH - aliceBalanceBeforeWETH, TOKEN_1 * 2, 1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1);
        assertEq(pool.liquidity(), TOKEN_1);
        assertEq(positionLiquidity, TOKEN_1);
    }

    function test_IncreaseStakedLiquidityNativeNotEqualAmountsRefundSurplusToken0() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1);
        assertEq(pool.liquidity(), TOKEN_1);
        assertEq(positionLiquidity, TOKEN_1);

        uint256 aliceBalanceBeforeETH = users.alice.balance;
        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBeforeWETH = weth.balanceOf(users.alice);

        gauge.increaseStakedLiquidity{value: TOKEN_1}(tokenId, TOKEN_1 * 5, TOKEN_1, 0, 0, block.timestamp);

        uint256 aliceBalanceAfterETH = users.alice.balance;
        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);

        assertEq(aliceBalanceBeforeWETH, weth.balanceOf(users.alice));
        assertEq(aliceBalanceBeforeETH - aliceBalanceAfterETH, TOKEN_1);
        assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
        assertEq(pool.liquidity(), TOKEN_1 * 2);
        assertEq(positionLiquidity, TOKEN_1 * 2);
    }

    function test_IncreaseStakedLiquidityNotEqualAmountsRefundSurplusNativeToken() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        (,,,,,,, uint128 positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1);
        assertEq(pool.liquidity(), TOKEN_1);
        assertEq(positionLiquidity, TOKEN_1);

        uint256 aliceBalanceBeforeETH = users.alice.balance;
        uint256 aliceBalanceBefore0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceBeforeWETH = weth.balanceOf(users.alice);

        gauge.increaseStakedLiquidity{value: TOKEN_1 * 6}(tokenId, TOKEN_1, TOKEN_1 * 6, 0, 0, block.timestamp);

        uint256 aliceBalanceAfter0 = token0.balanceOf(users.alice);
        uint256 aliceBalanceAfterETH = users.alice.balance;

        assertEq(aliceBalanceBeforeWETH, weth.balanceOf(users.alice));
        assertEq(aliceBalanceBefore0 - aliceBalanceAfter0, TOKEN_1);
        assertEq(aliceBalanceBeforeETH - aliceBalanceAfterETH, TOKEN_1);

        (,,,,,,, positionLiquidity,,,,) = nft.positions(tokenId);

        assertEq(pool.stakedLiquidity(), TOKEN_1 * 2);
        assertEq(pool.liquidity(), TOKEN_1 * 2);
        assertEq(positionLiquidity, TOKEN_1 * 2);
    }
}
