pragma solidity ^0.7.6;
pragma abicoder v2;

abstract contract Constants {
    int24 public constant TICK_SPACING_LOW = 30;
    int24 public constant TICK_SPACING_MEDIUM = 180;
    int24 public constant TICK_SPACING_HIGH = 600;

    // taken to provide backwards compatibility with UniswapV3 tests
    int24 public constant TICK_SPACING_10 = 10;
    int24 public constant TICK_SPACING_60 = 60;
    int24 public constant TICK_SPACING_200 = 200;

    address public constant TEST_TOKEN_0 = address(1);
    address public constant TEST_TOKEN_1 = address(2);

    uint256 public constant TOKEN_1 = 1e18;
    uint256 public constant USDC_1 = 1e6;

    uint256 public constant TOKEN_2_TO_255 = 2 ** 255;

    uint160 public constant MIN_SQRT_RATIO = 4295128739;
    uint160 public constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;
    // mock addresses used for testing gauge creation
    address public forwarder = address(11);

    uint256 constant WEEK = 1 weeks;

    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
