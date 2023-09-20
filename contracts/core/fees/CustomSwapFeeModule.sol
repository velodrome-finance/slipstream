// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import "../interfaces/IUniswapV3Pool.sol";
import "../interfaces/fees/ICustomFeeModule.sol";

contract CustomSwapFeeModule is ICustomFeeModule {
    /// @inheritdoc IFeeModule
    IUniswapV3Factory public override factory;
    /// @inheritdoc ICustomFeeModule
    mapping(address => uint24) public override customFee;

    uint256 public constant MAX_FEE = 10_000; // 1% // TODO: is this acceptable?
    // Override to indicate there is custom 0% fee - as a 0 value in the customFee mapping indicates
    // that no custom fee rate has been set
    uint256 public constant ZERO_FEE_INDICATOR = 420;

    constructor(address _factory) {
        factory = IUniswapV3Factory(_factory);
    }

    /// @inheritdoc ICustomFeeModule
    function setCustomFee(address pool, uint24 fee) external override {
        require(msg.sender == factory.swapFeeManager());
        require(fee <= MAX_FEE || fee == ZERO_FEE_INDICATOR);
        require(factory.isPair(pool));

        customFee[pool] = fee;
        emit SetCustomFee(pool, fee);
    }

    /// @inheritdoc IFeeModule
    function getFee(address pool) external view override returns (uint24) {
        uint24 fee = customFee[pool];
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();
        return fee == ZERO_FEE_INDICATOR ? 0 : fee != 0 ? fee : factory.tickSpacingToFee(tickSpacing);
    }
}
