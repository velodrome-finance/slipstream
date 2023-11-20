pragma solidity ^0.7.6;
pragma abicoder v2;

import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";
import {CLPoolTest} from "./CLPool.t.sol";

contract InitTest is CLPoolTest {
    function test_RevertIf_AlreadyInitialized() public {
        address pool = poolFactory.createPool({
            tokenA: TEST_TOKEN_0,
            tokenB: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
        address gauge = voter.gauges(pool);

        vm.expectRevert();
        ICLPool(pool).initialize({
            _factory: address(poolFactory),
            _token0: TEST_TOKEN_0,
            _token1: TEST_TOKEN_1,
            _tickSpacing: TICK_SPACING_MEDIUM,
            _gauge: gauge,
            _nft: address(nft),
            _sqrtPriceX96: encodePriceSqrt(1, 1)
        });
    }
}
