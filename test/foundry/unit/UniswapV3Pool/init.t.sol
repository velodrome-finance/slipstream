pragma solidity ^0.7.6;
pragma abicoder v2;

import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";
import {UniswapV3PoolTest} from "./UniswapV3Pool.t.sol";

contract InitTest is UniswapV3PoolTest {
    function test_RevertIf_AlreadyInit() public {
        address pool =
            poolFactory.createPool({tokenA: TEST_TOKEN_0, tokenB: TEST_TOKEN_1, tickSpacing: TICK_SPACING_LOW});

        vm.expectRevert();
        IUniswapV3Pool(pool).init();
    }
}
