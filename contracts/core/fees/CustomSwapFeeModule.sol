// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import "../interfaces/ICLPool.sol";
import "../interfaces/fees/ICustomFeeModule.sol";

contract CustomSwapFeeModule is ICustomFeeModule {
    /// @inheritdoc IFeeModule
    ICLFactory public override factory;
    /// @inheritdoc ICustomFeeModule
    mapping(address => uint24) public override customFee;

    uint256 public constant MAX_FEE = 30_000; // 3%
    // Override to indicate there is custom 0% fee - as a 0 value in the customFee mapping indicates
    // that no custom fee rate has been set
    uint256 public constant ZERO_FEE_INDICATOR = 420;

    constructor(address _factory) {
        factory = ICLFactory(_factory);
    }

    /// @inheritdoc ICustomFeeModule
    function setCustomFee(address _pool, uint24 _fee) external override {
        require(msg.sender == factory.swapFeeManager());
        require(_fee <= MAX_FEE || _fee == ZERO_FEE_INDICATOR);
        require(factory.isPair(_pool));

        customFee[_pool] = _fee;
        emit CustomFeeSet(_pool, _fee);
    }

    /// @inheritdoc IFeeModule
    function getFee(address _pool) external view override returns (uint24) {
        uint24 fee = customFee[_pool];
        int24 tickSpacing = ICLPool(_pool).tickSpacing();
        return fee == ZERO_FEE_INDICATOR ? 0 : fee != 0 ? fee : factory.tickSpacingToFee(tickSpacing);
    }
}
