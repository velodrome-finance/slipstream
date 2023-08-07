// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import {UniswapV3Factory} from 'contracts/core/UniswapV3Factory.sol';
import {CLGaugeFactory} from 'contracts/gauge/CLGaugeFactory.sol';
import {IVoter} from 'contracts/core/interfaces/IVoter.sol';

contract MockVoter is IVoter {
    address public gaugeFactory;
    // mock addresses used for testing gauge creation, a copy is stored in Constants.sol
    address public forwarder = address(11);
    address public feesVotingReward = address(12);
    address public rewardToken = address(13);

    mapping(address => address) public override gauges;

    function setGaugeFactory(address _gaugeFactory) external {
        require(gaugeFactory == address(0));
        gaugeFactory = _gaugeFactory;
    }

    function createGauge(
        address _poolFactory,
        address _pool
    ) external override returns (address) {
        address gauge = CLGaugeFactory(gaugeFactory).createGauge(forwarder, _pool, feesVotingReward, rewardToken, true);
        require(UniswapV3Factory(_poolFactory).isPair(_pool));
        gauges[_pool] = gauge;
        return gauge;
    }
}
