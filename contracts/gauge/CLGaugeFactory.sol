// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "contracts/core/interfaces/IUniswapV3Pool.sol";
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
        address token0 = IUniswapV3Pool(_pool).token0();
        address token1 = IUniswapV3Pool(_pool).token1();
        int24 tickSpacing = IUniswapV3Pool(_pool).tickSpacing();
        _gauge = Clones.cloneDeterministic({
            master: implementation,
            salt: keccak256(abi.encode(token0, token1, tickSpacing))
        });
        ICLGauge(_gauge).initialize({
            _forwarder: _forwarder,
            _pool: _pool,
            _feesVotingReward: _feesVotingReward,
            _rewardToken: _rewardToken,
            _voter: voter,
            _nft: nft,
            _token0: token0,
            _token1: token1,
            _isPool: _isPool
        });
    }
}
