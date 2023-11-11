// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import "./interfaces/IUniswapV3Factory.sol";
import "./interfaces/fees/IFeeModule.sol";
import "./interfaces/IVoter.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./UniswapV3Pool.sol";
import "contracts/gauge/interfaces/ICLGaugeFactory.sol";

/// @title Canonical Uniswap V3 factory
/// @notice Deploys Uniswap V3 pools and manages ownership and control over pool protocol fees
contract UniswapV3Factory is IUniswapV3Factory {
    /// @inheritdoc IUniswapV3Factory
    IVoter public immutable override voter;
    /// @inheritdoc IUniswapV3Factory
    address public immutable override poolImplementation;
    /// @inheritdoc IUniswapV3Factory
    address public override owner;
    /// @inheritdoc IUniswapV3Factory
    address public override swapFeeManager;
    /// @inheritdoc IUniswapV3Factory
    address public override swapFeeModule;
    /// @inheritdoc IUniswapV3Factory
    address public override unstakedFeeManager;
    /// @inheritdoc IUniswapV3Factory
    address public override unstakedFeeModule;
    /// @inheritdoc IUniswapV3Factory
    address public override nft;
    /// @inheritdoc IUniswapV3Factory
    address public override gaugeFactory;
    /// @inheritdoc IUniswapV3Factory
    address public override gaugeImplementation;
    /// @inheritdoc IUniswapV3Factory
    mapping(int24 => uint24) public override tickSpacingToFee;
    /// @inheritdoc IUniswapV3Factory
    mapping(address => mapping(address => mapping(int24 => address))) public override getPool;
    /// @dev Used in VotingEscrow to determine if a contract is a valid pool
    mapping(address => bool) private _isPool;

    int24[] private _tickSpacings;

    constructor(address _voter, address _poolImplementation) {
        owner = msg.sender;
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

    /// @inheritdoc IUniswapV3Factory
    function createPool(address tokenA, address tokenB, int24 tickSpacing) external override returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        require(tickSpacingToFee[tickSpacing] != 0);
        require(getPool[token0][token1][tickSpacing] == address(0));
        bytes32 _salt = keccak256(abi.encode(token0, token1, tickSpacing));
        pool = Clones.cloneDeterministic({master: poolImplementation, salt: _salt});
        address gauge =
            Clones.predictDeterministicAddress({master: gaugeImplementation, salt: _salt, deployer: gaugeFactory});
        UniswapV3Pool(pool).init({
            _factory: address(this),
            _token0: token0,
            _token1: token1,
            _tickSpacing: tickSpacing,
            _gauge: gauge,
            _nft: nft
        });
        _isPool[pool] = true;
        getPool[token0][token1][tickSpacing] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][tickSpacing] = pool;
        voter.createGauge(address(this), pool);
        emit PoolCreated(token0, token1, tickSpacing, pool);
    }

    /// @inheritdoc IUniswapV3Factory
    function setOwner(address _owner) external override {
        // TODO: should this be voter.governor()?
        require(msg.sender == owner);
        require(_owner != address(0));
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IUniswapV3Factory
    function setSwapFeeManager(address _swapFeeManager) external override {
        require(msg.sender == swapFeeManager);
        require(_swapFeeManager != address(0));
        address oldFeeManager = swapFeeManager;
        swapFeeManager = _swapFeeManager;
        emit SwapFeeManagerChanged(oldFeeManager, _swapFeeManager);
    }

    /// @inheritdoc IUniswapV3Factory
    function setUnstakedFeeManager(address _unstakedFeeManager) external override {
        require(msg.sender == unstakedFeeManager);
        require(_unstakedFeeManager != address(0));
        address oldFeeManager = unstakedFeeManager;
        unstakedFeeManager = _unstakedFeeManager;
        emit UnstakedFeeManagerChanged(oldFeeManager, _unstakedFeeManager);
    }

    /// @inheritdoc IUniswapV3Factory
    function setSwapFeeModule(address _swapFeeModule) external override {
        require(msg.sender == swapFeeManager);
        require(_swapFeeModule != address(0));
        address oldFeeModule = swapFeeModule;
        swapFeeModule = _swapFeeModule;
        emit SwapFeeModuleChanged(oldFeeModule, _swapFeeModule);
    }

    /// @inheritdoc IUniswapV3Factory
    function setUnstakedFeeModule(address _unstakedFeeModule) external override {
        require(msg.sender == unstakedFeeManager);
        require(_unstakedFeeModule != address(0));
        address oldFeeModule = unstakedFeeModule;
        unstakedFeeModule = _unstakedFeeModule;
        emit UnstakedFeeModuleChanged(oldFeeModule, _unstakedFeeModule);
    }

    /// @inheritdoc IUniswapV3Factory
    function getSwapFee(address pool) external view override returns (uint24) {
        if (swapFeeModule != address(0)) {
            return IFeeModule(swapFeeModule).getFee(pool);
        } else {
            return tickSpacingToFee[UniswapV3Pool(pool).tickSpacing()];
        }
    }

    /// @inheritdoc IUniswapV3Factory
    function getUnstakedFee(address pool) external view override returns (uint24) {
        if (unstakedFeeModule != address(0)) {
            return IFeeModule(unstakedFeeModule).getFee(pool);
        } else {
            // Default unstaked fee is 10%
            return 100_000;
        }
    }

    /// @inheritdoc IUniswapV3Factory
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

    /// @inheritdoc IUniswapV3Factory
    function tickSpacings() external view override returns (int24[] memory) {
        return _tickSpacings;
    }

    /// @inheritdoc IUniswapV3Factory
    function isPair(address pool) external view override returns (bool) {
        return _isPool[pool];
    }

    /// @inheritdoc IUniswapV3Factory
    function setGaugeFactoryAndNFT(address _gaugeFactory, address _nft) external override {
        require(gaugeFactory == address(0), "AI");
        gaugeFactory = _gaugeFactory;
        gaugeImplementation = ICLGaugeFactory(gaugeFactory).implementation();
        nft = _nft;
    }
}
