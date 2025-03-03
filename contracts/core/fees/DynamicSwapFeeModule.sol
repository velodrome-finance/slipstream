// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import "../interfaces/ICLPool.sol";
import "../interfaces/fees/IDynamicFeeModule.sol";
import "../libraries/FullMath.sol";

contract DynamicSwapFeeModule is IDynamicFeeModule {
    struct DynamicFeeConfig {
        uint24 baseFee;
        uint24 feeCap;
        uint64 scalingFactor; // K
    }

    uint32 public constant MIN_SECONDS_AGO = 2; // it must be set to the block time
    uint32 public constant MAX_SECONDS_AGO = 65535 * MIN_SECONDS_AGO; // 65535 is the maximum number of slots available in the oracle

    uint256 public constant MAX_BASE_FEE = 30_000; // 3%
    uint256 public constant MAX_DISCOUNT = 500_000; // 50%
    // Override to indicate there is custom 0% fee - as a 0 value in the customFee mapping indicates
    // that no custom fee rate has been set
    uint256 public constant ZERO_FEE_INDICATOR = 420;

    uint256 public constant MAX_SCALING_FACTOR = 1e18;
    uint256 public constant SCALING_PRECISION = 1e6;
    uint256 public constant MAX_FEE_CAP = 50_000; // 5%

    /// @inheritdoc IDynamicFeeModule
    uint256 public override defaultScalingFactor; // default K
    /// @inheritdoc IDynamicFeeModule
    uint256 public override defaultFeeCap;
    /// @inheritdoc IDynamicFeeModule
    uint32 public override secondsAgo = 3600; // 1 hour

    /// @inheritdoc IFeeModule
    ICLFactory public immutable override factory;
    /// @inheritdoc IDynamicFeeModule
    mapping(address => uint24) public override discounted;
    /// @inheritdoc IDynamicFeeModule
    mapping(address => DynamicFeeConfig) public override dynamicFeeConfig;

    constructor(
        address _factory,
        uint256 _defaultScalingFactor,
        uint256 _defaultFeeCap,
        address[] memory _pools,
        uint24[] memory _fees
    ) {
        require(_defaultScalingFactor <= MAX_SCALING_FACTOR, "ISF");
        require(_defaultFeeCap <= MAX_FEE_CAP, "MFC");

        factory = ICLFactory(_factory);
        defaultScalingFactor = _defaultScalingFactor;
        defaultFeeCap = _defaultFeeCap;
        _bulkUpdateFees({_factory: ICLFactory(_factory), _pools: _pools, _fees: _fees});

        emit DefaultScalingFactorSet({defaultScalingFactor: _defaultScalingFactor});
        emit DefaultFeeCapSet({defaultFeeCap: _defaultFeeCap});
    }

    modifier onlySwapFeeManager() {
        require(msg.sender == factory.swapFeeManager(), "NFM");
        _;
    }

    /// @inheritdoc ICustomFeeModule
    function customFee(address _pool) external view override returns (uint24) {
        return dynamicFeeConfig[_pool].baseFee;
    }

    /// @inheritdoc ICustomFeeModule
    function setCustomFee(address _pool, uint24 _fee) external override onlySwapFeeManager {
        require(_fee <= MAX_BASE_FEE || _fee == ZERO_FEE_INDICATOR, "MBF");
        require(factory.isPair({pool: _pool}));

        dynamicFeeConfig[_pool].baseFee = _fee;
        emit CustomFeeSet({pool: _pool, fee: _fee});
    }

    /// @inheritdoc IDynamicFeeModule
    function setDefaultScalingFactor(uint256 _defaultScalingFactor) external override onlySwapFeeManager {
        require(_defaultScalingFactor <= MAX_SCALING_FACTOR, "ISF");

        defaultScalingFactor = _defaultScalingFactor;
        emit DefaultScalingFactorSet({defaultScalingFactor: _defaultScalingFactor});
    }

    /// @inheritdoc IDynamicFeeModule
    function setDefaultFeeCap(uint256 _defaultFeeCap) external override onlySwapFeeManager {
        require(_defaultFeeCap <= MAX_FEE_CAP, "MFC");

        defaultFeeCap = _defaultFeeCap;
        emit DefaultFeeCapSet({defaultFeeCap: _defaultFeeCap});
    }

    /// @inheritdoc IDynamicFeeModule
    function setScalingFactor(address _pool, uint64 _scalingFactor) external override onlySwapFeeManager {
        require(factory.isPair({pool: _pool}));
        require(dynamicFeeConfig[_pool].feeCap != 0 && _scalingFactor <= MAX_SCALING_FACTOR, "ISF");

        dynamicFeeConfig[_pool].scalingFactor = _scalingFactor;
        emit ScalingFactorSet({pool: _pool, scalingFactor: _scalingFactor});
    }

    /// @inheritdoc IDynamicFeeModule
    function setFeeCap(address _pool, uint24 _feeCap) external override onlySwapFeeManager {
        require(factory.isPair({pool: _pool}));
        require(_feeCap > 0, "FC0");
        require(_feeCap <= MAX_FEE_CAP, "MFC");

        dynamicFeeConfig[_pool].feeCap = _feeCap;
        emit FeeCapSet({pool: _pool, feeCap: _feeCap});
    }

    /// @inheritdoc IDynamicFeeModule
    function resetDynamicFee(address _pool) external override onlySwapFeeManager {
        require(factory.isPair({pool: _pool}));

        delete dynamicFeeConfig[_pool].feeCap;
        delete dynamicFeeConfig[_pool].scalingFactor;
        emit DynamicFeeReset({pool: _pool});
    }

    /// @inheritdoc IDynamicFeeModule
    function setSecondsAgo(uint32 _secondsAgo) external override onlySwapFeeManager {
        require(_secondsAgo >= MIN_SECONDS_AGO && _secondsAgo < MAX_SECONDS_AGO, "ISA");

        secondsAgo = _secondsAgo;
        emit SecondsAgoSet({secondsAgo: _secondsAgo});
    }

    /// @inheritdoc IDynamicFeeModule
    function registerDiscounted(address _discountReceiver, uint24 _discount) external override onlySwapFeeManager {
        require(_discount <= MAX_DISCOUNT, "MDC");

        discounted[_discountReceiver] = _discount;
        emit DiscountedRegistered({discountReceiver: _discountReceiver, discount: _discount});
    }

    /// @inheritdoc IDynamicFeeModule
    function deregisterDiscounted(address _discountOver) external override onlySwapFeeManager {
        delete discounted[_discountOver];
        emit DiscountedDeregistered({discountOver: _discountOver});
    }

    /// @inheritdoc IDynamicFeeModule
    function bulkUpdateFees(address[] calldata _pools, uint24[] calldata _fees) external override onlySwapFeeManager {
        _bulkUpdateFees({_factory: factory, _pools: _pools, _fees: _fees});
    }

    /// @inheritdoc IDynamicFeeModule
    function bulkUpdateFeeCaps(address[] calldata _pools, uint24[] calldata _feeCaps)
        external
        override
        onlySwapFeeManager
    {
        uint256 poolsLength = _pools.length;
        require(poolsLength == _feeCaps.length, "LMM");

        address pool;
        uint24 feeCap;
        for (uint256 i = 0; i < poolsLength; i++) {
            pool = _pools[i];
            require(factory.isPair({pool: pool}));
            feeCap = _feeCaps[i];
            require(feeCap > 0, "FC0");
            require(feeCap <= MAX_FEE_CAP, "MFC");

            dynamicFeeConfig[pool].feeCap = feeCap;
            emit FeeCapSet({pool: pool, feeCap: feeCap});
        }
    }

    /// @inheritdoc IDynamicFeeModule
    function bulkUpdateScalingFactors(address[] calldata _pools, uint64[] calldata _scalingFactors)
        external
        override
        onlySwapFeeManager
    {
        uint256 poolsLength = _pools.length;
        require(poolsLength == _scalingFactors.length, "LMM");

        address pool;
        uint64 scalingFactor;
        for (uint256 i = 0; i < poolsLength; i++) {
            pool = _pools[i];
            require(factory.isPair({pool: pool}));
            scalingFactor = _scalingFactors[i];
            require(dynamicFeeConfig[pool].feeCap != 0 && scalingFactor <= MAX_SCALING_FACTOR, "ISF");

            dynamicFeeConfig[pool].scalingFactor = scalingFactor;
            emit ScalingFactorSet({pool: pool, scalingFactor: scalingFactor});
        }
    }

    /// @inheritdoc IFeeModule
    function getFee(address _pool) external view override returns (uint24) {
        DynamicFeeConfig storage dfc = dynamicFeeConfig[_pool];
        uint256 baseFee = dfc.baseFee;
        uint256 scalingFactor = dfc.scalingFactor;
        uint256 feeCap = dfc.feeCap;

        if (baseFee == ZERO_FEE_INDICATOR) return 0;
        baseFee = baseFee != 0 ? baseFee : factory.tickSpacingToFee(ICLPool(_pool).tickSpacing());

        if (scalingFactor == 0) {
            scalingFactor = defaultScalingFactor;
            feeCap = defaultFeeCap;
        }
        uint256 totalFee = baseFee + _getDynamicFee({_pool: _pool, _scalingFactor: scalingFactor});
        totalFee = totalFee < feeCap ? totalFee : feeCap;

        // apply discount if any
        if (discounted[tx.origin] > 0) {
            uint256 discount = FullMath.mulDivRoundingUp(totalFee, discounted[tx.origin], 1_000_000);
            totalFee = totalFee - discount;
        }

        return uint24(totalFee);
    }

    function _getDynamicFee(address _pool, uint256 _scalingFactor) internal view returns (uint256) {
        (, int24 currentTick,, uint16 observationCardinality,,) = ICLPool(_pool).slot0();
        uint32 _secondsAgo = secondsAgo;

        if (observationCardinality < _secondsAgo / MIN_SECONDS_AGO) return 0;

        uint32[] memory sa = new uint32[](2);
        sa[0] = _secondsAgo;
        // sa[1] = 0; default is 0

        int24 twAvgTick;
        try ICLPool(_pool).observe({secondsAgos: sa}) returns (int56[] memory tickCumulatives, uint160[] memory) {
            twAvgTick = int24((tickCumulatives[1] - tickCumulatives[0]) / _secondsAgo);
        } catch {
            return 0;
        }

        int24 tickDelta = currentTick - twAvgTick;
        uint24 absTickDelta = tickDelta < 0 ? uint24(-tickDelta) : uint24(tickDelta);
        return absTickDelta * _scalingFactor / SCALING_PRECISION;
    }

    function _bulkUpdateFees(ICLFactory _factory, address[] memory _pools, uint24[] memory _fees) internal {
        uint256 poolsLength = _pools.length;
        require(poolsLength == _fees.length, "LMM");

        uint24 fee;
        address pool;
        for (uint256 i = 0; i < poolsLength; i++) {
            fee = _fees[i];
            require(fee <= MAX_BASE_FEE || fee == ZERO_FEE_INDICATOR, "MBF");
            pool = _pools[i];
            require(_factory.isPair({pool: pool}));
            dynamicFeeConfig[pool].baseFee = fee;
            emit CustomFeeSet({pool: pool, fee: fee});
        }
    }
}
