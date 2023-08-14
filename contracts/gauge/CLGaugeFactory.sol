// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "./interfaces/ICLGaugeFactory.sol";
import "./CLGauge.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract CLGaugeFactory is ICLGaugeFactory {
    /// @inheritdoc ICLGaugeFactory
    address public immutable override voter;
    /// @inheritdoc ICLGaugeFactory
    address public immutable override implementation;
    /// @inheritdoc ICLGaugeFactory
    address public immutable override nft;

    constructor(address _voter, address _implementation, address _nft) {
        voter = _voter;
        implementation = _implementation;
        nft = _nft;
    }

    function createGauge(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        bool _isPool
    ) external override returns (address _gauge) {
        require(msg.sender == voter, "NV");
        _gauge = Clones.clone(implementation);
        ICLGauge(_gauge).initialize({
            _forwarder: _forwarder,
            _pool: _pool,
            _feesVotingReward: _feesVotingReward,
            _rewardToken: _rewardToken,
            _voter: voter,
            _nft: nft,
            _isPool: _isPool
        });
    }
}
