// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface IReward {
    event NotifyReward(address indexed from, address indexed reward, uint256 amount);

    /// @notice Add rewards for stakers to earn
    /// @param token    Address of token to reward
    /// @param amount   Amount of token to transfer to rewards
    function notifyRewardAmount(address token, uint256 amount) external;
}
