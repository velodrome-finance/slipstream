pragma solidity ^0.7.6;
pragma abicoder v2;

/// @notice Events for all contracts
abstract contract Events {
    ///
    /// Pool Factory Events
    ///
    event SwapFeeManagerChanged(address indexed oldFeeManager, address indexed newFeeManager);
    event SwapFeeModuleChanged(address indexed oldFeeModule, address indexed newFeeModule);
    event UnstakedFeeManagerChanged(address indexed oldFeeManager, address indexed newFeeManager);
    event UnstakedFeeModuleChanged(address indexed oldFeeModule, address indexed newFeeModule);
    event DefaultUnstakedFeeChanged(uint24 indexed oldUnstakedFee, uint24 indexed newUnstakedFee);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event PoolCreated(address indexed token0, address indexed token1, int24 indexed tickSpacing, address pool);
    event TickSpacingEnabled(int24 indexed tickSpacing, uint24 indexed fee);

    ///
    /// Custom Fee Module Events
    ///

    event SetCustomFee(address indexed pool, uint24 indexed fee);

    ///
    /// ERC20 Events
    ///
    event Transfer(address indexed from, address indexed to, uint256 value);

    ///
    /// CLGauge Events
    ///
    event Deposit(address indexed user, uint256 indexed tokenId, uint128 indexed liquidityToStake);
    event Withdraw(address indexed user, uint256 indexed tokenId, uint128 indexed liquidityToStake);
    event NotifyReward(address indexed from, uint256 amount);
    event ClaimRewards(address indexed from, uint256 amount);
}
