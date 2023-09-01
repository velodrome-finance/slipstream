pragma solidity ^0.7.6;
pragma abicoder v2;

import {INonfungiblePositionManager} from "contracts/periphery/interfaces/INonfungiblePositionManager.sol";
import "./NonfungiblePositionManager.t.sol";

contract CollectTest is NonfungiblePositionManagerTest {
    // TODO: Use correct abstraction once #39 is merged
    function test_RevertIf_CallerIsNotGauge() public {
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

        vm.expectRevert(bytes("Not approved"));
        nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: msg.sender,
                amount0Max: uint128(TOKEN_1),
                amount1Max: uint128(TOKEN_1)
            })
        );
    }

    // TODO Check feeGrowth once #42 is done
}
