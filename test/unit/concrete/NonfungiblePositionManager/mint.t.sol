pragma solidity ^0.7.6;
pragma abicoder v2;

import {INonfungiblePositionManager} from "contracts/periphery/interfaces/INonfungiblePositionManager.sol";
import {NonfungiblePositionManagerTest} from "./NonfungiblePositionManager.t.sol";

contract MintTest is NonfungiblePositionManagerTest {
    function test_RevertIf_PoolAlreadyExistsWithNonZeroSqrtPriceX96() public {
        vm.expectRevert();
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: getMinTick(TICK_SPACING_60),
            tickUpper: getMaxTick(TICK_SPACING_60),
            recipient: users.alice,
            amount0Desired: 15,
            amount1Desired: 15,
            amount0Min: 0,
            amount1Min: 0,
            deadline: 10,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
        nft.mint(params);
    }

    function test_Mint() public {
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: getMinTick(TICK_SPACING_60),
            tickUpper: getMaxTick(TICK_SPACING_60),
            recipient: users.alice,
            amount0Desired: 15,
            amount1Desired: 15,
            amount0Min: 0,
            amount1Min: 0,
            deadline: 10,
            sqrtPriceX96: 0
        });
        nft.mint(params);

        assertEq(nft.balanceOf(users.alice), 1);
        assertEq(nft.tokenOfOwnerByIndex(users.alice, 0), 1);
        (
            ,
            ,
            address _token0,
            address _token1,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = nft.positions(1);
        assertEq(_token0, address(token0));
        assertEq(_token1, address(token1));
        assertEq(tickSpacing, TICK_SPACING_60);
        assertEq(tickLower, getMinTick(TICK_SPACING_60));
        assertEq(tickUpper, getMaxTick(TICK_SPACING_60));
        assertEq(uint256(liquidity), 15);
        assertEq(uint256(tokensOwed0), 0);
        assertEq(uint256(tokensOwed1), 0);
        assertEq(feeGrowthInside0LastX128, 0);
        assertEq(feeGrowthInside1LastX128, 0);
    }

    function test_MintWhenPoolDoesNotExist() public {
        assertTrue(poolFactory.getPool(address(token0), address(token1), TICK_SPACING_MEDIUM) == address(0));

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_MEDIUM,
            tickLower: getMinTick(TICK_SPACING_MEDIUM),
            tickUpper: getMaxTick(TICK_SPACING_MEDIUM),
            recipient: users.alice,
            amount0Desired: 15,
            amount1Desired: 15,
            amount0Min: 0,
            amount1Min: 0,
            deadline: 10,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
        nft.mint(params);

        assertTrue(poolFactory.getPool(address(token0), address(token1), TICK_SPACING_MEDIUM) != address(0));
        assertEq(nft.balanceOf(users.alice), 1);
        assertEq(nft.tokenOfOwnerByIndex(users.alice, 0), 1);
        (
            ,
            ,
            address _token0,
            address _token1,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = nft.positions(1);
        assertEq(_token0, address(token0));
        assertEq(_token1, address(token1));
        assertEq(tickSpacing, TICK_SPACING_MEDIUM);
        assertEq(tickLower, getMinTick(TICK_SPACING_MEDIUM));
        assertEq(tickUpper, getMaxTick(TICK_SPACING_MEDIUM));
        assertEq(uint256(liquidity), 15);
        assertEq(uint256(tokensOwed0), 0);
        assertEq(uint256(tokensOwed1), 0);
        assertEq(feeGrowthInside0LastX128, 0);
        assertEq(feeGrowthInside1LastX128, 0);
    }
}
