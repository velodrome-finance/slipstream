// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import {UniswapV3Factory} from "contracts/core/UniswapV3Factory.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {IVoter} from "contracts/core/interfaces/IVoter.sol";
import {ICLGauge} from "contracts/gauge/interfaces/ICLGauge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockVoter is IVoter {
    address public gaugeFactory;
    // mock addresses used for testing gauge creation, a copy is stored in Constants.sol
    address public forwarder = address(11);
    address public feesVotingReward = address(12);

    // Rewards are released over 7 days
    uint256 internal constant DURATION = 7 days;

    /// @dev pool => gauge
    mapping(address => address) public override gauges;
    /// @dev gauge => isAlive
    mapping(address => bool) public override isAlive;

    IERC20 internal immutable rewardToken;

    constructor(address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
    }

    function setGaugeFactory(address _gaugeFactory) external {
        require(gaugeFactory == address(0));
        gaugeFactory = _gaugeFactory;
    }

    function createGauge(address _poolFactory, address _pool) external override returns (address) {
        address gauge =
            CLGaugeFactory(gaugeFactory).createGauge(forwarder, _pool, feesVotingReward, address(rewardToken), true);
        require(UniswapV3Factory(_poolFactory).isPair(_pool));
        isAlive[gauge] = true;
        gauges[_pool] = gauge;
        return gauge;
    }

    function distribute(address gauge) external override {
        uint256 _claimable = rewardToken.balanceOf(address(this));
        if (_claimable > ICLGauge(gauge).left() && _claimable > DURATION) {
            rewardToken.approve(gauge, _claimable);
            ICLGauge(gauge).notifyRewardAmount(rewardToken.balanceOf(address(this)));
        }
    }
}
