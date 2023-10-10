// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import {INonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Need to prank to user before
contract NFTManagerCallee {
    int24 public constant TICK_SPACING_60 = 60;
    address token0;
    address token1;
    address nft;

    constructor(address _token0, address _token1, address _nft) {
        token0 = _token0;
        token1 = _token1;
        nft = _nft;
        ERC20(token0).approve(address(_nft), type(uint256).max);
        ERC20(token1).approve(address(_nft), type(uint256).max);
    }

    function mintNewCustomRangePositionForUserWith60TickSpacing(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper,
        address user
    ) public returns (uint256) {
        ERC20(token0).transferFrom(user, address(this), amount0);
        ERC20(token1).transferFrom(user, address(this), amount1);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: tickLower,
            tickUpper: tickUpper,
            recipient: user,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        (uint256 tokenId,,,) = INonfungiblePositionManager(nft).mint(params);
        return tokenId;
    }

    function mintNewFullRangePositionForUserWith60TickSpacing(uint256 amount0, uint256 amount1, address user)
        external
        returns (uint256)
    {
        return mintNewCustomRangePositionForUserWith60TickSpacing(
            amount0, amount1, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), user
        );
    }

    function mintNewCustomRangePositionForUserWithCustomTickSpacing(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper,
        int24 tickSpacing,
        address user
    ) public returns (uint256) {
        ERC20(token0).transferFrom(user, address(this), amount0);
        ERC20(token1).transferFrom(user, address(this), amount1);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: tickSpacing,
            tickLower: tickLower,
            tickUpper: tickUpper,
            recipient: user,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        (uint256 tokenId,,,) = INonfungiblePositionManager(nft).mint(params);
        return tokenId;
    }

    function mintNewFullRangePositionForUserWithCustomTickSpacing(
        uint256 amount0,
        uint256 amount1,
        int24 tickSpacing,
        address user
    ) external returns (uint256) {
        return mintNewCustomRangePositionForUserWithCustomTickSpacing(
            amount0, amount1, getMinTick(tickSpacing), getMaxTick(tickSpacing), tickSpacing, user
        );
    }

    function collectAllForTokenId(uint256 tokenId, address recipient) external returns (uint256, uint256) {
        return INonfungiblePositionManager(nft).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
    }

    function collectOneAndOneForTokenId(uint256 tokenId, address recipient) external returns (uint256, uint256) {
        return INonfungiblePositionManager(nft).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: recipient,
                amount0Max: 1,
                amount1Max: 1
            })
        );
    }

    // HELPERS
    function getMinTick(int24 tickSpacing) internal pure returns (int24) {
        return (-887272 / tickSpacing) * tickSpacing;
    }

    function getMaxTick(int24 tickSpacing) internal pure returns (int24) {
        return (887272 / tickSpacing) * tickSpacing;
    }
}
