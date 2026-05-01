pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../BaseFixture.sol";
import {Position} from "contracts/core/libraries/Position.sol";

contract CLGaugeTest is BaseFixture {
    CLPool public pool;
    CLGauge public gauge;

    function setUp() public virtual override {
        super.setUp();

        pool = CLPool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        gauge = CLGauge(voter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)}));
    }
}
