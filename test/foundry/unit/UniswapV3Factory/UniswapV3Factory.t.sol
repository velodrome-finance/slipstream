pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../BaseFixture.sol";

contract UniswapV3FactoryTest is BaseFixture {
    function test_InitialState() public {
        assertEq(poolFactory.owner(), users.owner);
        assertEq(poolFactory.feeManager(), users.feeManager);

        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_LOW), 500);
        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_MEDIUM), 3_000);
        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_HIGH), 10_000);
    }
}
