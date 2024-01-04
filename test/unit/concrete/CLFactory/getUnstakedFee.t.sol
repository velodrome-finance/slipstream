pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {CLFactoryTest} from "./CLFactory.t.sol";

contract GetUnstakedFeeTest is CLFactoryTest {
    CLGauge public gauge;

    function test_KilledGaugeReturnsZeroUnstakedFee() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_1,
            token1: TEST_TOKEN_0,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        gauge = CLGauge(voter.gauges(pool));

        assertEq(voter.isAlive(address(gauge)), true);
        assertEq(uint256(poolFactory.getUnstakedFee(pool)), 100_000);

        voter.killGauge(address(gauge));

        assertEq(voter.isAlive(address(gauge)), false);
        assertEq(uint256(poolFactory.getUnstakedFee(pool)), 0);
    }
}
