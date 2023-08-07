// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface ICLGauge {
    function forwarder() external view returns (address);

    function pool() external view returns (address);

    function feesVotingReward() external view returns (address);

    function rewardToken() external view returns (address);

    function isPool() external view returns (bool);

    function initialize(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        bool _isPool
    ) external;
}
