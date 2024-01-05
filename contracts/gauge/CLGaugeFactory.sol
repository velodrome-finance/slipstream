// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import "contracts/core/interfaces/ICLPool.sol";
import "./interfaces/ICLGaugeFactory.sol";
import "./CLGauge.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract CLGaugeFactory is ICLGaugeFactory {
    /// @inheritdoc ICLGaugeFactory
    address public immutable override voter;
    /// @inheritdoc ICLGaugeFactory
    address public immutable override implementation;
    /// @inheritdoc ICLGaugeFactory
    address public override nft;
    address private owner;

    constructor(address _voter, address _implementation) {
        voter = _voter;
        owner = msg.sender;
        implementation = _implementation;
    }

    /// @inheritdoc ICLGaugeFactory
    function setNonfungiblePositionManager(address _nft) external override {
        require(nft == address(0), "AI");
        require(owner == msg.sender, "NA");
        require(_nft != address(0), "ZA");
        nft = _nft;
        delete owner;
    }

    /// @inheritdoc ICLGaugeFactory
    function createGauge(
        address, /* _forwarder */
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        bool _isPool
    ) external override returns (address _gauge) {
        require(msg.sender == voter, "NV");
        address token0 = ICLPool(_pool).token0();
        address token1 = ICLPool(_pool).token1();
        int24 tickSpacing = ICLPool(_pool).tickSpacing();
        _gauge = Clones.cloneDeterministic({
            master: implementation,
            salt: keccak256(abi.encode(token0, token1, tickSpacing))
        });
        ICLGauge(_gauge).initialize({
            _pool: _pool,
            _feesVotingReward: _feesVotingReward,
            _rewardToken: _rewardToken,
            _voter: voter,
            _nft: nft,
            _token0: token0,
            _token1: token1,
            _tickSpacing: tickSpacing,
            _isPool: _isPool
        });
    }
}
