pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseFixture.sol";

contract UniswapV3FactoryTest is BaseFixture {
    function test_InitialState() public virtual {
        assertEq(address(poolFactory.voter()), address(voter));
        assertEq(poolFactory.poolImplementation(), address(poolImplementation));
        assertEq(poolFactory.owner(), users.owner);
        assertEq(poolFactory.swapFeeModule(), address(customSwapFeeModule));
        assertEq(poolFactory.unstakedFeeModule(), address(customUnstakedFeeModule));
        assertEq(poolFactory.swapFeeManager(), users.feeManager);
        assertEq(poolFactory.unstakedFeeManager(), users.feeManager);
        assertEq(poolFactory.nft(), address(nft));
        assertEq(poolFactory.gaugeFactory(), address(gaugeFactory));
        assertEq(poolFactory.gaugeImplementation(), address(gaugeImplementation));

        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_STABLE), 100);
        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_LOW), 500);
        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_MEDIUM), 500);
        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_HIGH), 3_000);
        assertEqUint(poolFactory.tickSpacingToFee(TICK_SPACING_VOLATILE), 10_000);
    }
}
