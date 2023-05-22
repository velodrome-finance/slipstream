pragma solidity ^0.7.6;
pragma abicoder v2;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';
import {IUniswapV3Factory, UniswapV3Factory} from 'contracts/UniswapV3Factory.sol';
import {IUniswapV3Pool, UniswapV3Pool} from 'contracts/UniswapV3Pool.sol';
import {CustomFeeModule} from 'contracts/fees/CustomFeeModule.sol';
import {IFeeModule} from 'contracts/fees/CustomFeeModule.sol';
import {Clones} from 'contracts/libraries/Clones.sol';

contract BaseFixture is Test {
    bytes32 public constant INIT_CODE = keccak256(type(UniswapV3Pool).creationCode);

    UniswapV3Factory public factory;
    UniswapV3Pool public poolImplementation;

    int24 public constant TICK_SPACING_LOW = 30;
    int24 public constant TICK_SPACING_MEDIUM = 180;
    int24 public constant TICK_SPACING_HIGH = 600;

    address public constant TEST_TOKEN_0 = address(1);
    address public constant TEST_TOKEN_1 = address(2);

    function setUp() public virtual {
        poolImplementation = new UniswapV3Pool();
        factory = new UniswapV3Factory(address(poolImplementation));

        vm.label(address(poolImplementation), 'Pool Implementation');
        vm.label(address(factory), 'Pool Factory');
    }

    function _computeAddress(
        address _factory,
        address _tokenA,
        address _tokenB,
        int24 _tickSpacing
    ) internal view returns (address pool) {
        (address _token0, address _token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        address _implementation = UniswapV3Factory(_factory).implementation();
        return
            Clones.predictDeterministicAddress(
                address(_implementation),
                keccak256(abi.encode(_token0, _token1, _tickSpacing)),
                address(_factory)
            );
    }

    /// @dev Use only with test addresses
    function _createAndCheckPool(
        address _token0,
        address _token1,
        int24 _tickSpacing
    ) internal returns (address) {
        address create2Addr = _computeAddress(address(factory), _token0, _token1, _tickSpacing);

        vm.expectEmit(true, true, true, true, address(factory));
        emit PoolCreated(TEST_TOKEN_0, TEST_TOKEN_1, _tickSpacing, create2Addr);
        UniswapV3Pool pool = UniswapV3Pool(factory.createPool(_token0, _token1, _tickSpacing));

        assertEq(factory.getPool(_token0, _token1, _tickSpacing), create2Addr);
        assertEq(factory.getPool(_token1, _token0, _tickSpacing), create2Addr);
        assertEq(factory.isPair(create2Addr), true);
        assertEq(pool.factory(), address(factory));
        assertEq(pool.token0(), TEST_TOKEN_0);
        assertEq(pool.token1(), TEST_TOKEN_1);
        assertEq(pool.tickSpacing(), _tickSpacing);

        return address(pool);
    }

    event PoolCreated(address indexed token0, address indexed token1, int24 indexed tickSpacing, address pool);
}
