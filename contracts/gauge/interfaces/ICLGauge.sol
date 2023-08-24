// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import {INonfungiblePositionManager} from "contracts/periphery/interfaces/INonfungiblePositionManager.sol";
import {IVoter} from "contracts/core/interfaces/IVoter.sol";
import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";

interface ICLGauge {
    event NotifyReward(address indexed from, uint256 amount);
    event Deposit(address indexed user, uint256 indexed tokenId, uint128 indexed liquidityToStake);
    event Withdraw(address indexed user, uint256 indexed tokenId, uint128 indexed liquidityToStake);
    event ClaimRewards(address indexed from, uint256 amount);

    /// @notice NonfungiblePositionManager used to create nfts this gauge accepts
    function nft() external view returns (INonfungiblePositionManager);

    /// @notice Voter contract gauge receives emissions from
    function voter() external view returns (IVoter);

    /// @notice Address of the UniswapV3 pool linked to the gauge
    function pool() external view returns (IUniswapV3Pool);

    /// @notice Address of the forwarder
    function forwarder() external view returns (address);

    /// @notice Address of the FeesVotingReward contract linked to the gauge
    function feesVotingReward() external view returns (address);

    /// @notice Timestamp end of current rewards period
    function periodFinish() external view returns (uint256);

    /// @notice Current reward rate of rewardToken to distribute per second
    function rewardRate() external view returns (uint256);

    /// @notice Most recent timestamp contract has updated state
    function lastUpdateTime() external view returns (uint256);

    /// @notice View to see the rewardRate given the timestamp of the start of the epoch
    function rewardRateByEpoch(uint256) external view returns (uint256);

    /// @notice Total amount of rewardToken to distribute for the current rewards period
    function left() external view returns (uint256 _left);

    /// @notice Address of the emissions token
    function rewardToken() external view returns (address);

    /// @notice Whether the attached pool is a real pool or not. Allows creation of gauges not attached to pools.
    function isPool() external view returns (bool);

    /// @notice Returns the rewardGrowthInside of the position at the last user action (deposit, withdraw, getReward)
    /// @param tokenId The tokenId of the position
    /// @return The rewardGrowthInside for the position
    function rewardGrowthInside(uint256 tokenId) external view returns (uint256);

    /// @notice Called on gauge creation by CLGaugeFactory
    /// @param _forwarder The address of the forwarder contract
    /// @param _pool The address of the pool
    /// @param _feesVotingReward The address of the feesVotingReward contract
    /// @param _rewardToken The address of the reward token
    /// @param _voter The address of the voter contract
    /// @param _nft The address of the nft position manager contract
    /// @param _isPool Whether the attached pool is a real pool or not
    function initialize(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        address _voter,
        address _nft,
        bool _isPool
    ) external;

    /// @notice Returns the claimable rewards for a given account and tokenId
    /// @dev Throws if account is not the position owner
    /// @param account The address of the user
    /// @param tokenId The tokenId of the position
    /// @return The amount of claimable reward
    function earned(address account, uint256 tokenId) external view returns (uint256);

    /// @notice Retrieve rewards for a tokenId
    /// @dev Throws if not called by the position owner
    /// @param tokenId The tokenId of the position
    function getReward(uint256 tokenId) external;

    /// @notice Notifies gauge of gauge rewards.
    function notifyRewardAmount(uint256 amount) external;

    /// @notice Used to deposit a UniswapV3 position into the gauge
    /// @notice Allows the user to receive emissions instead of fees
    /// @param tokenId The tokenId of the position
    function deposit(uint256 tokenId) external;

    /// @notice Used to withdraw a UniswapV3 position from the gauge
    /// @notice Allows the user to receive fees instead of emissions
    /// @notice Outstanding emissions will be collected on withdrawal
    /// @param tokenId The tokenId of the position
    function withdraw(uint256 tokenId) external;

    /// @notice Check whether a position is staked in the gauge by a certain user
    /// @param depositor The address of the user
    /// @param tokenId The tokenId of the position
    /// @return Whether the position is staked in the gauge
    function stakedContains(address depositor, uint256 tokenId) external view returns (bool);

    /// @notice The amount of positions staked in the gauge by a certain user
    /// @param depositor The address of the user
    /// @return The amount of positions staked in the gauge
    function stakedLength(address depositor) external view returns (uint256);
}
