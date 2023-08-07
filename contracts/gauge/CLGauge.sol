// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import {ICLGauge} from './interfaces/ICLGauge.sol';

contract CLGauge is ICLGauge {
    address public override forwarder;
    address public override pool;
    address public override feesVotingReward;
    address public override rewardToken;
    bool public override isPool;

    function initialize(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        bool _isPool
    ) external override {
        require(pool == address(0), 'AI');
        forwarder = _forwarder;
        pool = _pool;
        feesVotingReward = _feesVotingReward;
        rewardToken = _rewardToken;
        isPool = _isPool;
    }
}
