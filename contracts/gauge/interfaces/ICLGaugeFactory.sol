// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

interface ICLGaugeFactory {
    event SetNotifyAdmin(address indexed _notifyAdmin);
    event SetGaugeStakeManager(address indexed _gaugeStakeManager);
    event SetDefaultMinStakeTime(uint256 _minStakeTime);
    event SetPoolMinStakeTime(address indexed _pool, uint256 _minStakeTime);
    event SetPenaltyRate(uint256 _penaltyRate);

    /// @notice Denominator for emission calculations (as basis points)
    function MAX_BPS() external view returns (uint256);

    /// @notice Maximum value for minStakeTime (1 week)
    function MAX_MIN_STAKE_TIME() external view returns (uint256);

    /// @notice Address of the voter contract
    function voter() external view returns (address);

    /// @notice Minter contract used to mint emissions
    function minter() external view returns (address);

    /// @notice Address of the gauge implementation contract
    function implementation() external view returns (address);

    /// @notice Address of the NonfungiblePositionManager used to create nfts that gauges will accept
    function nft() external view returns (address);

    /// @notice Administrator that can call `notifyRewardWithoutClaim` on gauges
    function notifyAdmin() external view returns (address);

    /// @notice Administrator that can manage stake time and penalty parameters
    function gaugeStakeManager() external view returns (address);

    /// @notice Default minimum time (in seconds) a position must be staked before claiming or withdrawing without penalty
    function defaultMinStakeTime() external view returns (uint256);

    /// @notice Returns the effective minimum stake time for a pool
    /// @dev Returns the per-pool override if set (> 0), otherwise returns defaultMinStakeTime
    /// @param _pool The pool address to query
    function minStakeTimes(address _pool) external view returns (uint256);

    /// @notice Penalty rate (in basis points) applied to rewards on early claim or withdrawal
    function penaltyRate() external view returns (uint256);

    /// @notice Set notifyAdmin value on gauge factory
    /// @param _admin New administrator that will be able to call `notifyRewardWithoutClaim` on gauges.
    function setNotifyAdmin(address _admin) external;

    /// @notice Set gaugeStakeManager value on gauge factory
    /// @param _manager New administrator that will be able to manage stake time and penalty parameters
    function setGaugeStakeManager(address _manager) external;

    /// @notice Sets the default minimum stake time before claiming or withdrawing without penalty
    /// @param _minStakeTime The minimum stake time in seconds
    function setDefaultMinStakeTime(uint256 _minStakeTime) external;

    /// @notice Sets a per-pool minimum stake time override before claiming or withdrawing without penalty
    /// @dev Setting to 0 resets the pool to use defaultMinStakeTime
    /// @param _pool The pool address to configure
    /// @param _minStakeTime The minimum stake time in seconds
    function setMinStakeTime(address _pool, uint256 _minStakeTime) external;

    /// @notice Sets the penalty rate for early claim or withdrawal
    /// @param _penaltyRate The penalty rate in basis points
    function setPenaltyRate(uint256 _penaltyRate) external;

    /// @notice Called by the voter contract via factory.createPool
    /// @param _forwarder The address of the forwarder contract
    /// @param _pool The address of the pool
    /// @param _feesVotingReward The address of the feesVotingReward contract
    /// @param _rewardToken The address of the reward token
    /// @param _isPool Whether the attached pool is a real pool or not
    /// @return The address of the created gauge
    function createGauge(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        bool _isPool
    ) external returns (address);
}
