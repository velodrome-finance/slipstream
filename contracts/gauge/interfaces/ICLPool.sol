// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

/// @title Minimal CLPool interface
/// @notice Used to support the integration with the core implementation
/// @dev For full context, please review the Uniswap implementation under GPL license.
interface ICLPool {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function tickSpacing() external view returns (int24);

    /// @notice The reward growth as a Q128.128 rewards of emission collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function rewardGrowthGlobalX128() external view returns (uint256);

    /// @notice acts as a virtual reserve that holds information on how many rewards are yet to be distributed
    function rewardReserve() external view returns (uint256);

    /// @notice last time the rewardReserve and rewardRate were updated
    function lastUpdated() external view returns (uint32);

    /// @notice tracks total rewards distributed when no staked liquidity in active tick for epoch ending at periodFinish
    /// @notice this amount is rolled over on the next call to notifyRewardAmount
    /// @dev rollover will always be smaller than the rewards distributed that epoch
    function rollover() external view returns (uint256);

    /// @notice The currently in range staked liquidity available to the pool
    /// @dev This value has no relationship to the total staked liquidity across all ticks
    function stakedLiquidity() external view returns (uint128);

    /// @notice Returns data about reward growth within a tick range.
    /// RewardGrowthGlobalX128 can be supplied as a parameter for claimable reward calculations.
    /// @dev Used in gauge reward/earned calculations
    /// @param tickLower The lower tick of the range
    /// @param tickUpper The upper tick of the range
    /// @param _rewardGrowthGlobalX128 a calculated rewardGrowthGlobalX128 or 0 (in case of 0 it means we use the rewardGrowthGlobalX128 from state)
    /// @return rewardGrowthInsideX128 The reward growth in the range
    function getRewardGrowthInside(int24 tickLower, int24 tickUpper, uint256 _rewardGrowthGlobalX128)
        external
        view
        returns (uint256 rewardGrowthInsideX128);

    /// @notice Initialize gauge and nft manager
    /// @dev Callable only once, by the gauge factory
    /// @param _gauge The gauge corresponding to this pool
    /// @param _nft The position manager used for position management
    function setGaugeAndPositionManager(address _gauge, address _nft) external;

    /// @notice Convert existing liquidity into staked liquidity
    /// @notice Only callable by the gauge associated with this pool
    /// @param stakedLiquidityDelta The amount by which to increase or decrease the staked liquidity
    /// @param tickLower The lower tick of the position for which to stake liquidity
    /// @param tickUpper The upper tick of the position for which to stake liquidity
    function stake(int128 stakedLiquidityDelta, int24 tickLower, int24 tickUpper) external;

    /// @notice Updates rewardGrowthGlobalX128 every time when any tick is crossed,
    /// or when any position is staked/unstaked from the gauge
    function updateRewardsGrowthGlobal() external;

    /// @notice Syncs rewards with gauge
    /// @param rewardRate the rate rewards being distributed during the epoch
    /// @param rewardReserve the available rewards to be distributed during the epoch
    /// @param periodFinish the end of the current period of rewards, updated once per epoch
    function syncReward(uint256 rewardRate, uint256 rewardReserve, uint256 periodFinish) external;

    /// @notice Collect the gauge fee accrued to the pool
    /// @return amount0 The gauge fee collected in token0
    /// @return amount1 The gauge fee collected in token1
    function collectFees() external returns (uint128 amount0, uint128 amount1);
}
