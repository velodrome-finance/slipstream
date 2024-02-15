pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLFactory.t.sol";

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

        gauge = CLGauge(voter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)}));

        assertEq(voter.isAlive(address(gauge)), true);
        assertEq(uint256(poolFactory.getUnstakedFee(pool)), 100_000);

        voter.killGauge(address(gauge));

        assertEq(voter.isAlive(address(gauge)), false);
        assertEq(uint256(poolFactory.getUnstakedFee(pool)), 0);
    }

    function test_NoGaugeReturnsZeroUnstakedFee() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_1,
            token1: TEST_TOKEN_0,
            tickSpacing: TICK_SPACING_LOW,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });

        assertEq(uint256(poolFactory.getUnstakedFee(pool)), 0);
    }
}
