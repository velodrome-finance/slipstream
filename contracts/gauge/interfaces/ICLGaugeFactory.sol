// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface ICLGaugeFactory {
    function createGauge(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _ve,
        bool isPool
    ) external returns (address);
}
