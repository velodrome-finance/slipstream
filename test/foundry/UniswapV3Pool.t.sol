pragma solidity ^0.7.6;
pragma abicoder v2;

import './BaseFixture.sol';

contract UniswapV3PoolTest is BaseFixture {
    address public constant token0 = address(1);
    address public constant token1 = address(2);

    function testInitialize() public {
        address pool = factory.createPool(token0, token1, TICK_SPACING_LOW);

        vm.expectRevert();
        UniswapV3Pool(pool).init();
    }
}
