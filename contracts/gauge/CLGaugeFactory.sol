// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./interfaces/ICLGaugeFactory.sol";
import "./CLGauge.sol";
import {IVoter} from "contracts/core/interfaces/IVoter.sol";

contract CLGaugeFactory is ICLGaugeFactory {
    /// @inheritdoc ICLGaugeFactory
    uint256 public constant override MAX_BPS = 10_000;
    /// @inheritdoc ICLGaugeFactory
    uint256 public constant override MAX_MIN_STAKE_TIME = 1 weeks;

    /// @inheritdoc ICLGaugeFactory
    address public immutable override voter;
    /// @inheritdoc ICLGaugeFactory
    address public immutable override implementation;
    /// @inheritdoc ICLGaugeFactory
    address public immutable override nft;
    /// @inheritdoc ICLGaugeFactory
    address public immutable override minter;
    /// @inheritdoc ICLGaugeFactory
    address public override notifyAdmin;
    /// @inheritdoc ICLGaugeFactory
    address public override gaugeStakeManager;
    /// @inheritdoc ICLGaugeFactory
    uint256 public override defaultMinStakeTime;
    /// @inheritdoc ICLGaugeFactory
    uint256 public override penaltyRate;

    /// @dev Per-pool minimum stake time override (0 = not set, use defaultMinStakeTime)
    mapping(address => uint256) internal _minStakeTimes;

    constructor(address _notifyAdmin, address _voter, address _nft, address _implementation) {
        notifyAdmin = _notifyAdmin;
        voter = _voter;
        nft = _nft;
        implementation = _implementation;
        minter = IVoter(_voter).minter();
        gaugeStakeManager = msg.sender;
    }

    /// @inheritdoc ICLGaugeFactory
    function setNotifyAdmin(address _admin) external override {
        require(notifyAdmin == msg.sender, "NA");
        require(_admin != address(0), "ZA");
        notifyAdmin = _admin;
        emit SetNotifyAdmin(_admin);
    }

    /// @inheritdoc ICLGaugeFactory
    function minStakeTimes(address _pool) public view override returns (uint256) {
        uint256 poolMinStakeTime = _minStakeTimes[_pool];
        return poolMinStakeTime == 0 ? defaultMinStakeTime : poolMinStakeTime;
    }

    /// @inheritdoc ICLGaugeFactory
    function setGaugeStakeManager(address _manager) external override {
        require(msg.sender == gaugeStakeManager, "NA");
        require(_manager != address(0), "ZA");
        gaugeStakeManager = _manager;
        emit SetGaugeStakeManager({_gaugeStakeManager: _manager});
    }

    /// @inheritdoc ICLGaugeFactory
    function setDefaultMinStakeTime(uint256 _minStakeTime) external override {
        require(msg.sender == gaugeStakeManager, "NA");
        require(_minStakeTime <= MAX_MIN_STAKE_TIME, "MS");
        defaultMinStakeTime = _minStakeTime;
        emit SetDefaultMinStakeTime({_minStakeTime: _minStakeTime});
    }

    /// @inheritdoc ICLGaugeFactory
    function setMinStakeTime(address _pool, uint256 _minStakeTime) external override {
        require(msg.sender == gaugeStakeManager, "NA");
        require(_pool != address(0), "ZA");
        require(_minStakeTime <= MAX_MIN_STAKE_TIME, "MS");
        _minStakeTimes[_pool] = _minStakeTime;
        emit SetPoolMinStakeTime({_pool: _pool, _minStakeTime: _minStakeTime});
    }

    /// @inheritdoc ICLGaugeFactory
    function setPenaltyRate(uint256 _penaltyRate) external override {
        require(msg.sender == gaugeStakeManager, "NA");
        require(_penaltyRate <= MAX_BPS, "MR");
        penaltyRate = _penaltyRate;
        emit SetPenaltyRate({_penaltyRate: _penaltyRate});
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
        _gauge = Clones.clone({master: implementation});
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
        ICLPool(_pool).setGaugeAndPositionManager({_gauge: _gauge, _nft: nft});
    }
}
