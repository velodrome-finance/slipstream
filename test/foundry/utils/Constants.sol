pragma solidity ^0.7.6;
pragma abicoder v2;

abstract contract Constants {
    int24 public constant TICK_SPACING_LOW = 30;
    int24 public constant TICK_SPACING_MEDIUM = 180;
    int24 public constant TICK_SPACING_HIGH = 600;

    address public constant TEST_TOKEN_0 = address(1);
    address public constant TEST_TOKEN_1 = address(2);

    uint256 public constant TOKEN_1 = 1e18;
    uint256 public constant USDC_1 = 1e6;

    // mock addresses used for testing gauge creation
    address public forwarder = address(11);
    address public feesVotingReward = address(12);
    address public rewardToken = address(13);
}
