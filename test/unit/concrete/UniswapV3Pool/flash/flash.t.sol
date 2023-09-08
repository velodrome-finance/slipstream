pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../BaseFixture.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {UniswapV3PoolTest} from "../UniswapV3Pool.t.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import "contracts/core/libraries/FullMath.sol";

contract FlashTest is UniswapV3PoolTest {
    UniswapV3Pool public pool;
    CLGauge public gauge;

    int24 tickSpacing = TICK_SPACING_60;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: tickSpacing})
        );
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.alice);

        skipToNextEpoch(0);
    }

    function mintNewFullRangePositionAndDepositIntoGauge(uint128 _amount0, uint128 _amount1, address _user)
        internal
        returns (uint256)
    {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(_amount0, _amount1, _user);
        vm.startPrank(_user);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        return tokenId;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label({account: address(uniswapV3Callee), newLabel: "Test UniswapV3 Callee"});
        vm.label({account: address(pool), newLabel: "Pool"});
        vm.label({account: address(gauge), newLabel: "Gauge"});
    }

    // All position staked tests

    function test_FlashIncreasesGaugeFeesByExpectedAmountAllPositionsStaked() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // fee is 0.003
        uint256 pay1 = 1001 + 4;
        // fee is 0.006
        uint256 pay2 = 2002 + 7;

        uniswapV3Callee.flash(address(pool), users.alice, 1001, 2002, pay1, pay2);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 4);
        assertEq(_token1, 7);

        assertEq(pool.feeGrowthGlobal0X128(), 0);
        assertEq(pool.feeGrowthGlobal1X128(), 0);
    }

    function test_FlashAllowsDonatingToken0AllPositionsStaked() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 pay1 = 567;

        uniswapV3Callee.flash(address(pool), users.alice, 0, 0, pay1, 0);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 567);
        assertEq(_token1, 0);

        assertEq(pool.feeGrowthGlobal0X128(), 0);
        assertEq(pool.feeGrowthGlobal1X128(), 0);
    }

    function test_FlashAllowsDonatingToken1AllPositionsStaked() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 pay2 = 765;

        uniswapV3Callee.flash(address(pool), users.alice, 0, 0, 0, pay2);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 0);
        assertEq(_token1, 765);

        assertEq(pool.feeGrowthGlobal0X128(), 0);
        assertEq(pool.feeGrowthGlobal1X128(), 0);
    }

    function test_FlashAllowsDonatingToken0AndToken1AllPositionsStaked() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 2, TOKEN_1 * 2, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 pay1 = 567;
        uint256 pay2 = 765;

        uniswapV3Callee.flash(address(pool), users.alice, 0, 0, pay1, pay2);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 567);
        assertEq(_token1, 765);

        assertEq(pool.feeGrowthGlobal0X128(), 0);
        assertEq(pool.feeGrowthGlobal1X128(), 0);
    }

    // Positions are partially staked

    function test_FlashIncreasesGaugeFeesByExpectedAmountPositionsPartiallyStaked() public {
        nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // fee is 0.003
        uint256 pay1 = 1001 + 4;
        // fee is 0.006
        uint256 pay2 = 2002 + 7;

        uniswapV3Callee.flash(address(pool), users.alice, 1001, 2002, pay1, pay2);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 2);
        assertEq(_token1, 3); // since we first calculate staked amount in splitFees() this is going to be lower

        uint256 feeGrowthGlobal0X128 = FullMath.mulDiv(2, Q128, TOKEN_1);
        uint256 feeGrowthGlobal1X128 = FullMath.mulDiv(4, Q128, TOKEN_1);

        assertEq(pool.feeGrowthGlobal0X128(), feeGrowthGlobal0X128);
        assertEq(pool.feeGrowthGlobal1X128(), feeGrowthGlobal1X128);
    }

    function test_FlashAllowsDonatingToken0PositionsPartiallyStaked() public {
        nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 pay1 = 100;

        uniswapV3Callee.flash(address(pool), users.alice, 0, 0, pay1, 0);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 50);
        assertEq(_token1, 0);

        uint256 feeGrowthGlobal0X128 = FullMath.mulDiv(50, Q128, TOKEN_1);

        assertEq(pool.feeGrowthGlobal0X128(), feeGrowthGlobal0X128);
        assertEq(pool.feeGrowthGlobal1X128(), 0);
    }

    function test_FlashAllowsDonatingToken1PositionsPartiallyStaked() public {
        nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 pay2 = 900;

        uniswapV3Callee.flash(address(pool), users.alice, 0, 0, 0, pay2);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 0);
        assertEq(_token1, 450);

        uint256 feeGrowthGlobal1X128 = FullMath.mulDiv(450, Q128, TOKEN_1);

        assertEq(pool.feeGrowthGlobal0X128(), 0);
        assertEq(pool.feeGrowthGlobal1X128(), feeGrowthGlobal1X128);
    }

    function test_FlashAllowsDonatingToken0AndToken1PositionsPartiallyStaked() public {
        nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 pay1 = 4000;
        uint256 pay2 = 8844;

        uniswapV3Callee.flash(address(pool), users.alice, 0, 0, pay1, pay2);

        (uint256 _token0, uint256 _token1) = pool.gaugeFees();
        assertEq(_token0, 2000);
        assertEq(_token1, 4422);

        uint256 feeGrowthGlobal0X128 = FullMath.mulDiv(2000, Q128, TOKEN_1);
        uint256 feeGrowthGlobal1X128 = FullMath.mulDiv(4422, Q128, TOKEN_1);

        assertEq(pool.feeGrowthGlobal0X128(), feeGrowthGlobal0X128);
        assertEq(pool.feeGrowthGlobal1X128(), feeGrowthGlobal1X128);
    }
}
