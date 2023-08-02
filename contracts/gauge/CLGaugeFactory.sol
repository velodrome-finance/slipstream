// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import '../core/interfaces/IUniswapV3Pool.sol';
import './interfaces/ICLGaugeFactory.sol';
import './CLGauge.sol';

contract CLGaugeFactory is ICLGaugeFactory {
    function createGauge(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        bool isPool
    ) external override returns (address _gauge) {
        _gauge = address(new CLGauge(_forwarder, _pool, _feesVotingReward, _rewardToken, isPool));
    }
}
