// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import "./interfaces/IUniswapV3Factory.sol";
import "./interfaces/fees/IFeeModule.sol";
import "./interfaces/IVoter.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./UniswapV3Pool.sol";

/// @title Canonical Uniswap V3 factory
/// @notice Deploys Uniswap V3 pools and manages ownership and control over pool protocol fees
contract UniswapV3Factory is IUniswapV3Factory {
    /// @inheritdoc IUniswapV3Factory
    IVoter public immutable override voter;
    /// @inheritdoc IUniswapV3Factory
    address public immutable override implementation;
    /// @inheritdoc IUniswapV3Factory
    address public override owner;
    /// @inheritdoc IUniswapV3Factory
    address public override feeManager;
    /// @inheritdoc IUniswapV3Factory
    address public override feeModule;
    /// @inheritdoc IUniswapV3Factory
    mapping(int24 => uint24) public override tickSpacingToFee;
    /// @inheritdoc IUniswapV3Factory
    mapping(address => mapping(address => mapping(int24 => address))) public override getPool;
    /// @dev Used in VotingEscrow to determine if a contract is a valid pool
    mapping(address => bool) private _isPool;

    int24[] private _tickSpacings;

    constructor(address _voter, address _implementation) {
        owner = msg.sender;
        feeManager = msg.sender;
        voter = IVoter(_voter);
        implementation = _implementation;
        emit OwnerChanged(address(0), msg.sender);
        emit FeeManagerChanged(address(0), msg.sender);

        // TODO: tick spacing values are placeholders
        // currently using 3x uniswap defaults as placeholders
        tickSpacingToFee[30] = 500;
        _tickSpacings.push(30);
        emit TickSpacingEnabled(30, 500);
        tickSpacingToFee[180] = 3000;
        _tickSpacings.push(180);
        emit TickSpacingEnabled(180, 3000);
        tickSpacingToFee[600] = 10_000;
        _tickSpacings.push(600);
        emit TickSpacingEnabled(600, 10_000);
    }

    /// @inheritdoc IUniswapV3Factory
    function createPool(address tokenA, address tokenB, int24 tickSpacing) external override returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        require(tickSpacingToFee[tickSpacing] != 0);
        require(getPool[token0][token1][tickSpacing] == address(0));
        pool = Clones.cloneDeterministic(implementation, keccak256(abi.encode(token0, token1, tickSpacing)));
        _isPool[pool] = true;
        getPool[token0][token1][tickSpacing] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][tickSpacing] = pool;
        address gauge = voter.createGauge(address(this), pool);
        UniswapV3Pool(pool).init({
            _factory: address(this),
            _token0: token0,
            _token1: token1,
            _tickSpacing: tickSpacing,
            _gauge: gauge
        });
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
    function setFeeManager(address _feeManager) external override {
        require(msg.sender == feeManager);
        require(_feeManager != address(0));
        address oldFeeManager = feeManager;
        feeManager = _feeManager;
        emit FeeManagerChanged(oldFeeManager, _feeManager);
    }

    /// @inheritdoc IUniswapV3Factory
    function setFeeModule(address _feeModule) external override {
        require(msg.sender == feeManager);
        require(_feeModule != address(0));
        address oldFeeModule = feeModule;
        feeModule = _feeModule;
        emit FeeModuleChanged(oldFeeModule, _feeModule);
    }

    /// @inheritdoc IUniswapV3Factory
    function getFee(address pool) external view override returns (uint24) {
        if (feeModule != address(0)) {
            return IFeeModule(feeModule).getFee(pool);
        } else {
            return tickSpacingToFee[UniswapV3Pool(pool).tickSpacing()];
        }
    }

    /// @inheritdoc IUniswapV3Factory
    function enableTickSpacing(int24 tickSpacing, uint24 fee) public override {
        require(msg.sender == owner);
        require(fee < 1000000);
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
}
