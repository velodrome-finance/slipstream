// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ICLPool} from "../core/interfaces/ICLPool.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {ILpMigrator} from "./interfaces/ILpMigrator.sol";

import {PoolAddress} from "./libraries/PoolAddress.sol";

contract LpMigrator is ILpMigrator, ERC721Holder {
    using SafeERC20 for IERC20;

    /// @inheritdoc ILpMigrator
    function migrateSlipstreamToSlipstream(FromParams memory fromParams, ToParams memory toParams)
        external
        override
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        INonfungiblePositionManager fromNFT = INonfungiblePositionManager(fromParams.nft);
        INonfungiblePositionManager toNFT = INonfungiblePositionManager(toParams.nft);

        // collect all tokens from existing positions
        address token0;
        address token1;

        (,, token0, token1,,,, liquidity,,,,) = fromNFT.positions(fromParams.tokenId);

        fromNFT.safeTransferFrom(msg.sender, address(this), fromParams.tokenId);

        fromNFT.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: fromParams.tokenId,
                liquidity: liquidity,
                amount0Min: fromParams.amount0Min,
                amount1Min: fromParams.amount1Min,
                deadline: block.timestamp
            })
        );

        (uint256 amountToDeposit0, uint256 amountToDeposit1) = fromNFT.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: fromParams.tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        fromNFT.burn(fromParams.tokenId);

        uint160 sqrtPriceX96;
        if (toParams.pool == address(0)) {
            sqrtPriceX96 = getPrice({from: fromNFT, token0: token0, token1: token1, tickSpacing: toParams.tickSpacing});
        }

        // fetch additional funds from user
        if (fromParams.amount0Extra > 0) {
            IERC20(token0).safeTransferFrom(msg.sender, address(this), fromParams.amount0Extra);
            amountToDeposit0 += fromParams.amount0Extra;
        }
        if (fromParams.amount1Extra > 0) {
            IERC20(token1).safeTransferFrom(msg.sender, address(this), fromParams.amount1Extra);
            amountToDeposit1 += fromParams.amount1Extra;
        }

        // approve token transfer to nft
        IERC20(token0).safeApprove(address(toNFT), amountToDeposit0);
        IERC20(token1).safeApprove(address(toNFT), amountToDeposit1);

        // create new position
        (tokenId, liquidity, amount0, amount1) = toNFT.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                tickSpacing: toParams.tickSpacing,
                tickLower: toParams.tickLower,
                tickUpper: toParams.tickUpper,
                amount0Desired: amountToDeposit0,
                amount1Desired: amountToDeposit1,
                amount0Min: toParams.amount0Min,
                amount1Min: toParams.amount1Min,
                recipient: toParams.recipient,
                deadline: toParams.deadline,
                sqrtPriceX96: sqrtPriceX96
            })
        );

        // refund remaining funds to user & clear dangling approvals
        uint256 residual0 = amountToDeposit0 - amount0;
        uint256 residual1 = amountToDeposit1 - amount1;

        if (residual0 > 0) {
            IERC20(token0).safeTransfer(msg.sender, residual0);
            IERC20(token0).safeApprove(address(toNFT), 0);
        }
        if (residual1 > 0) {
            IERC20(token1).safeTransfer(msg.sender, residual1);
            IERC20(token1).safeApprove(address(toNFT), 0);
        }

        emit MigratedSlipstreamToSliptream(msg.sender, fromParams.tokenId, tokenId);
    }

    /// @dev Fetches current price of existing pool
    function getPrice(INonfungiblePositionManager from, address token0, address token1, int24 tickSpacing)
        internal
        view
        returns (uint160 sqrtPriceX96)
    {
        ICLPool pool = ICLPool(
            PoolAddress.computeAddress({
                factory: from.factory(),
                key: PoolAddress.PoolKey({token0: token0, token1: token1, tickSpacing: tickSpacing})
            })
        );

        (sqrtPriceX96,,,,,) = pool.slot0();
    }
}
