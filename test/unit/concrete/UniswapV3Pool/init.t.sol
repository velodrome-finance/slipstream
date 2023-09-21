pragma solidity ^0.7.6;
pragma abicoder v2;

import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";
import {UniswapV3PoolTest} from "./UniswapV3Pool.t.sol";

contract InitTest is UniswapV3PoolTest {
    function test_RevertIf_AlreadyInit() public {
        address pool =
            poolFactory.createPool({tokenA: TEST_TOKEN_0, tokenB: TEST_TOKEN_1, tickSpacing: TICK_SPACING_LOW});
        address gauge = voter.gauges(pool);

        vm.expectRevert();
        IUniswapV3Pool(pool).init({
            _factory: address(poolFactory),
            _token0: TEST_TOKEN_0,
            _token1: TEST_TOKEN_1,
            _tickSpacing: TICK_SPACING_MEDIUM,
            _gauge: gauge,
            _nft: address(nft)
        });
    }
}
