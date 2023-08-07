// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import './interfaces/ICLGaugeFactory.sol';
import './CLGauge.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';

contract CLGaugeFactory is ICLGaugeFactory {
    address public immutable voter;
    address public immutable implementation;

    constructor(address _voter, address _implementation) {
        voter = _voter;
        implementation = _implementation;
    }

    function createGauge(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        bool _isPool
    ) external override returns (address _gauge) {
        require(msg.sender == voter, 'NV');
        _gauge = Clones.clone(implementation);
        ICLGauge(_gauge).initialize(_forwarder, _pool, _feesVotingReward, _rewardToken, _isPool);
    }
}
