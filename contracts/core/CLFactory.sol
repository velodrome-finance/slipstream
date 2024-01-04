// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import "./interfaces/ICLFactory.sol";
import "./interfaces/fees/IFeeModule.sol";
import "./interfaces/IVoter.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./CLPool.sol";

/// @title Canonical CL factory
/// @notice Deploys CL pools and manages ownership and control over pool protocol fees
contract CLFactory is ICLFactory {
    /// @inheritdoc ICLFactory
    IVoter public immutable override voter;
    /// @inheritdoc ICLFactory
    address public immutable override poolImplementation;
    /// @inheritdoc ICLFactory
    address public override owner;
    /// @inheritdoc ICLFactory
    address public override swapFeeManager;
    /// @inheritdoc ICLFactory
    address public override swapFeeModule;
    /// @inheritdoc ICLFactory
    address public override unstakedFeeManager;
    /// @inheritdoc ICLFactory
    address public override unstakedFeeModule;
    /// @inheritdoc ICLFactory
    address public override nft;
    /// @inheritdoc ICLFactory
    address public override gaugeFactory;
    /// @inheritdoc ICLFactory
    address public override gaugeImplementation;
    /// @inheritdoc ICLFactory
    mapping(int24 => uint24) public override tickSpacingToFee;
    /// @inheritdoc ICLFactory
    mapping(address => mapping(address => mapping(int24 => address))) public override getPool;
    /// @dev Used in VotingEscrow to determine if a contract is a valid pool
    mapping(address => bool) private _isPool;

    int24[] private _tickSpacings;

    constructor(address _voter, address _poolImplementation) {
        nft = msg.sender;
        owner = msg.sender;
        gaugeFactory = msg.sender;
        swapFeeManager = msg.sender;
        unstakedFeeManager = msg.sender;
        voter = IVoter(_voter);
        poolImplementation = _poolImplementation;
        emit OwnerChanged(address(0), msg.sender);
        emit SwapFeeManagerChanged(address(0), msg.sender);
        emit UnstakedFeeManagerChanged(address(0), msg.sender);

        tickSpacingToFee[1] = 100;
        _tickSpacings.push(1);
        emit TickSpacingEnabled(1, 100);
        tickSpacingToFee[50] = 500;
        _tickSpacings.push(50);
        emit TickSpacingEnabled(50, 500);
        tickSpacingToFee[100] = 500;
        _tickSpacings.push(100);
        emit TickSpacingEnabled(100, 500);
        tickSpacingToFee[200] = 3_000;
        _tickSpacings.push(200);
        emit TickSpacingEnabled(200, 3_000);
        tickSpacingToFee[2_000] = 10_000;
        _tickSpacings.push(2_000);
        emit TickSpacingEnabled(2_000, 10_000);
    }

    /// @inheritdoc ICLFactory
    function createPool(address tokenA, address tokenB, int24 tickSpacing, uint160 sqrtPriceX96)
        external
        override
        returns (address pool)
    {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        require(tickSpacingToFee[tickSpacing] != 0);
        require(getPool[token0][token1][tickSpacing] == address(0));
        bytes32 _salt = keccak256(abi.encode(token0, token1, tickSpacing));
        pool = Clones.cloneDeterministic({master: poolImplementation, salt: _salt});
        address gauge =
            Clones.predictDeterministicAddress({master: gaugeImplementation, salt: _salt, deployer: gaugeFactory});
        CLPool(pool).initialize({
            _factory: address(this),
            _token0: token0,
            _token1: token1,
            _tickSpacing: tickSpacing,
            _gauge: gauge,
            _nft: nft,
            _sqrtPriceX96: sqrtPriceX96
        });
        _isPool[pool] = true;
        getPool[token0][token1][tickSpacing] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][tickSpacing] = pool;
        voter.createGauge(address(this), pool);
        emit PoolCreated(token0, token1, tickSpacing, pool);
    }

    /// @inheritdoc ICLFactory
    function setOwner(address _owner) external override {
        address cachedOwner = owner;
        require(msg.sender == cachedOwner);
        require(_owner != address(0));
        emit OwnerChanged(cachedOwner, _owner);
        owner = _owner;
    }

    /// @inheritdoc ICLFactory
    function setSwapFeeManager(address _swapFeeManager) external override {
        address cachedSwapFeeManager = swapFeeManager;
        require(msg.sender == cachedSwapFeeManager);
        require(_swapFeeManager != address(0));
        swapFeeManager = _swapFeeManager;
        emit SwapFeeManagerChanged(cachedSwapFeeManager, _swapFeeManager);
    }

    /// @inheritdoc ICLFactory
    function setUnstakedFeeManager(address _unstakedFeeManager) external override {
        address cachedUnstakedFeeManager = unstakedFeeManager;
        require(msg.sender == cachedUnstakedFeeManager);
        require(_unstakedFeeManager != address(0));
        unstakedFeeManager = _unstakedFeeManager;
        emit UnstakedFeeManagerChanged(cachedUnstakedFeeManager, _unstakedFeeManager);
    }

    /// @inheritdoc ICLFactory
    function setSwapFeeModule(address _swapFeeModule) external override {
        require(msg.sender == swapFeeManager);
        require(_swapFeeModule != address(0));
        address oldFeeModule = swapFeeModule;
        swapFeeModule = _swapFeeModule;
        emit SwapFeeModuleChanged(oldFeeModule, _swapFeeModule);
    }

    /// @inheritdoc ICLFactory
    function setUnstakedFeeModule(address _unstakedFeeModule) external override {
        require(msg.sender == unstakedFeeManager);
        require(_unstakedFeeModule != address(0));
        address oldFeeModule = unstakedFeeModule;
        unstakedFeeModule = _unstakedFeeModule;
        emit UnstakedFeeModuleChanged(oldFeeModule, _unstakedFeeModule);
    }

    /// @inheritdoc ICLFactory
    function getSwapFee(address pool) external view override returns (uint24) {
        if (swapFeeModule != address(0)) {
            return IFeeModule(swapFeeModule).getFee(pool);
        } else {
            return tickSpacingToFee[CLPool(pool).tickSpacing()];
        }
    }

    /// @inheritdoc ICLFactory
    function getUnstakedFee(address pool) external view override returns (uint24) {
        if (!IVoter(voter).isAlive(ICLPool(pool).gauge())) {
            return 0;
        }
        if (unstakedFeeModule != address(0)) {
            return IFeeModule(unstakedFeeModule).getFee(pool);
        } else {
            // Default unstaked fee is 10%
            return 100_000;
        }
    }

    /// @inheritdoc ICLFactory
    function enableTickSpacing(int24 tickSpacing, uint24 fee) public override {
        require(msg.sender == owner);
        require(fee <= 100_000);
        // tick spacing is capped at 16384 to prevent the situation where tickSpacing is so large that
        // TickBitmap#nextInitializedTickWithinOneWord overflows int24 container from a valid tick
        // 16384 ticks represents a >5x price change with ticks of 1 bips
        require(tickSpacing > 0 && tickSpacing < 16384);
        require(tickSpacingToFee[tickSpacing] == 0);

        tickSpacingToFee[tickSpacing] = fee;
        _tickSpacings.push(tickSpacing);
        emit TickSpacingEnabled(tickSpacing, fee);
    }

    /// @inheritdoc ICLFactory
    function tickSpacings() external view override returns (int24[] memory) {
        return _tickSpacings;
    }

    /// @inheritdoc ICLFactory
    function isPair(address pool) external view override returns (bool) {
        return _isPool[pool];
    }

    /// @inheritdoc ICLFactory
    function setGaugeFactory(address _gaugeFactory, address _gaugeImplementation) external override {
        require(gaugeFactory == msg.sender, "AI");
        require(_gaugeFactory != address(0) && _gaugeImplementation != address(0));
        gaugeFactory = _gaugeFactory;
        gaugeImplementation = _gaugeImplementation;
    }

    /// @inheritdoc ICLFactory
    function setNonfungiblePositionManager(address _nft) external override {
        require(nft == msg.sender, "AI");
        require(_nft != address(0));
        nft = _nft;
    }
}
