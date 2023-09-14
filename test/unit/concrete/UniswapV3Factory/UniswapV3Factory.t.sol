pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseFixture.sol";

contract UniswapV3FactoryTest is BaseFixture {
    function test_InitialState() public {
        assertEq(poolFactory.owner(), users.owner);
        assertEq(poolFactory.swapFeeManager(), users.feeManager);

        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_LOW), 5);
        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_MEDIUM), 30);
        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_HIGH), 100);
    }
}
