// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "./ICustomFeeModule.sol";

interface IDynamicFeeModule is ICustomFeeModule {
    event ScalingFactorSet(address indexed pool, uint256 indexed scalingFactor);
    event FeeCapSet(address indexed pool, uint256 indexed feeCap);
    event DynamicFeeReset(address indexed pool);
    event DefaultScalingFactorSet(uint256 indexed defaultScalingFactor);
    event DefaultFeeCapSet(uint256 indexed defaultFeeCap);
    event DiscountedRegistered(address indexed discountReceiver, uint24 indexed discount);
    event DiscountedDeregistered(address indexed discountOver);
    event SecondsAgoSet(uint32 indexed secondsAgo);

    /// @notice Returns the dynamic fee config for the pool
    /// @param _pool The pool address
    /// @return The baseFee, feeCap and scalingFactor set for the pool
    function dynamicFeeConfig(address _pool) external view returns (uint24, uint24, uint64);

    /// @notice The current default scaling factor
    function defaultScalingFactor() external view returns (uint256);

    /// @notice The current default fee cap
    function defaultFeeCap() external view returns (uint256);

    /// @notice The amount of time used to calculate price change
    function secondsAgo() external view returns (uint32);

    /// @notice Returns the discount in fees
    /// @param _sender The address to check if it's discounted
    /// @return The amount of discount the _sender eligible for
    function discounted(address _sender) external view returns (uint24);

    /// @notice Sets the new default scaling factor
    /// @dev Must be called by the current fee manager
    /// @param _defaultScalingFactor The new default scaling factor for dynamic fees
    function setDefaultScalingFactor(uint256 _defaultScalingFactor) external;

    /// @notice Sets the new default fee cap
    /// @dev Must be called by the current fee manager
    /// @param _defaultFeeCap The new default fee cap for dynamic fees
    function setDefaultFeeCap(uint256 _defaultFeeCap) external;

    /// @notice Sets the new scaling factor on the passed pool
    /// @dev Must be called by the current fee manager
    /// @dev Pool must exist
    /// @dev Must set feeCap first
    /// @param _pool The pool address
    /// @param _scalingFactor The new scaling factor for dynamic fees
    function setScalingFactor(address _pool, uint64 _scalingFactor) external;

    /// @notice Sets the new fee cap on the passed pool
    /// @dev Must be called by the current fee manager
    /// @dev Pool must exist
    /// @param _pool The pool address
    /// @param _feeCap The new fee cap for dynamic fees
    function setFeeCap(address _pool, uint24 _feeCap) external;

    /// @notice Resets the dynamic fee for a given pool
    /// @dev Must be called by the current fee manager
    /// @dev Pool must exist
    /// @param _pool The address of the pool for which the dynamic fee is being reset
    function resetDynamicFee(address _pool) external;

    /// @notice Sets the new secondsAgo
    /// @dev Must be called by the current fee manager
    /// @param _secondsAgo The new secondsAgo for price change calculation
    function setSecondsAgo(uint32 _secondsAgo) external;

    /// @notice Registers a new address to receive fee discount
    /// @dev Must be called by the current fee manager
    /// @param _discountReceiver Address to register for fee discount
    /// @param _discount The amount of discount in basis points
    function registerDiscounted(address _discountReceiver, uint24 _discount) external;

    /// @notice Deregisters address to receive fee discount
    /// @dev Must be called by the current fee manager
    /// @param _discountOver Address to deregister from fee discount
    function deregisterDiscounted(address _discountOver) external;

    /// @notice Bulk updates the fee for the passed in pools
    /// @dev Must be called by the current fee manager
    /// @param _pools The pool addresses which are going to be updated (must be a valid pool)
    /// @param _fees The fees to be set on the pools
    function bulkUpdateFees(address[] calldata _pools, uint24[] calldata _fees) external;
}
