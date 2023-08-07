// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './IVoter.sol';

/// @title The interface for the Uniswap V3 Factory
/// @notice The Uniswap V3 Factory facilitates creation of Uniswap V3 pools and control over the protocol fees
interface IUniswapV3Factory {
    /// @notice Emitted when the owner of the factory is changed
    /// @param oldOwner The owner before the owner was changed
    /// @param newOwner The owner after the owner was changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when the feeManager of the factory is changed
    /// @param oldFeeManager The feeManager before the feeManager was changed
    /// @param newFeeManager The feeManager after the feeManager was changed
    event FeeManagerChanged(address indexed oldFeeManager, address indexed newFeeManager);

    /// @notice Emitted when the feeModule of the factory is changed
    /// @param oldFeeModule The feeModule before the feeModule was changed
    /// @param newFeeModule The feeModule after the feeModule was changed
    event FeeModuleChanged(address indexed oldFeeModule, address indexed newFeeModule);

    /// @notice Emitted when a pool is created
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param tickSpacing The minimum number of ticks between initialized ticks
    /// @param pool The address of the created pool
    event PoolCreated(address indexed token0, address indexed token1, int24 indexed tickSpacing, address pool);

    /// @notice Emitted when a new tick spacing is enabled for pool creation via the factory
    /// @param tickSpacing The minimum number of ticks between initialized ticks for pools
    /// @param fee The default fee for a pool created with a given tickSpacing
    event TickSpacingEnabled(int24 indexed tickSpacing, uint24 indexed fee);

    /// @notice The voter contract, used to create gauges
    /// @return The address of the voter contract
    function voter() external view returns (IVoter);

    /// @notice The address of the implementation contract used to deploy proxies / clones
    /// @return The address of the implementation contract
    function implementation() external view returns (address);

    /// @notice Returns the current owner of the factory
    /// @dev Can be changed by the current owner via setOwner
    /// @return The address of the factory owner
    function owner() external view returns (address);

    /// @notice Returns the current feeManager of the factory
    /// @dev Can be changed by the current fee manager via setFeeManager
    /// @return The address of the factory feeManager
    function feeManager() external view returns (address);

    /// @notice Returns the current feeModule of the factory
    /// @dev Can be changed by the current fee manager via setFeeModule
    /// @return The address of the factory feeModule
    function feeModule() external view returns (address);

    /// @notice Returns a default fee for a tick spacing.
    /// @dev Use getFee for the most up to date fee for a given pool.
    /// A tick spacing can never be removed, so this value should be hard coded or cached in the calling context
    /// @param tickSpacing The enabled tick spacing. Returns 0 if not enabled
    /// @return fee The default fee for the given tick spacing
    function tickSpacingToFee(int24 tickSpacing) external view returns (uint24 fee);

    /// @notice Returns a list of enabled tick spacings. Used to iterate through pools created by the factory
    /// @dev Tick spacings cannot be removed. Tick spacings are not ordered
    /// @return List of enabled tick spacings
    function tickSpacings() external view returns (int24[] memory);

    /// @notice Returns the pool address for a given pair of tokens and a tick spacing, or address 0 if it does not exist
    /// @dev tokenA and tokenB may be passed in either token0/token1 or token1/token0 order
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @param tickSpacing The tick spacing of the pool
    /// @return pool The pool address
    function getPool(
        address tokenA,
        address tokenB,
        int24 tickSpacing
    ) external view returns (address pool);

    /// @notice Used in VotingEscrow to determine if a contract is a valid pool of the factory
    /// @param pool The address of the pool to check
    /// @return Whether the pool is a valid pool of the factory
    function isPair(address pool) external view returns (bool);

    /// @notice Get fee for a given pool. Accounts for default and dynamic fees
    /// @dev Fee is denominated in bips.
    /// @param pool The pool to get the fee for
    /// @return The fee for the given pool
    function getFee(address pool) external view returns (uint24);

    /// @notice Creates a pool for the given two tokens and fee
    /// @param tokenA One of the two tokens in the desired pool
    /// @param tokenB The other of the two tokens in the desired pool
    /// @param tickSpacing The desired tick spacing for the pool
    /// @dev tokenA and tokenB may be passed in either order: token0/token1 or token1/token0. The call will
    /// revert if the pool already exists, the tick spacing is invalid, or the token arguments are invalid
    /// @return pool The address of the newly created pool
    function createPool(
        address tokenA,
        address tokenB,
        int24 tickSpacing
    ) external returns (address pool);

    /// @notice Updates the owner of the factory
    /// @dev Must be called by the current owner
    /// @param _owner The new owner of the factory
    function setOwner(address _owner) external;

    /// @notice Updates the feeManager of the factory
    /// @dev Must be called by the current fee manager
    /// @param _feeManager The new feeManager of the factory
    function setFeeManager(address _feeManager) external;

    /// @notice Updates the feeModule of the factory
    /// @dev Must be called by the current fee manager
    /// @param _feeModule The new feeModule of the factory
    function setFeeModule(address _feeModule) external;

    /// @notice Enables a certain tickSpacing
    /// @dev Tick spacings may never be removed once enabled
    /// @param tickSpacing The spacing between ticks to be enforced in the pool
    /// @param fee The default fee associated with a given tick spacing
    function enableTickSpacing(int24 tickSpacing, uint24 fee) external;
}
