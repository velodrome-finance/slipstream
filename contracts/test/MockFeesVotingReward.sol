// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import {IReward} from "contracts/gauge/interfaces/IReward.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract MockFeesVotingReward is IReward {
    using SafeERC20 for IERC20;

    /// @inheritdoc IReward
    function notifyRewardAmount(address token, uint256 amount) external override {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit NotifyReward(msg.sender, token, amount);
    }

    function earned(address token, uint256 tokenId) external view override returns (uint256) {
        return 0;
    }

    function getReward(uint256 tokenId, address[] memory tokens) external override {}
}
