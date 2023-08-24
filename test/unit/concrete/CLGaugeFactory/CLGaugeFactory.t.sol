pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseFixture.sol";

contract CLGaugeFactoryTest is BaseFixture {
    function test_InitialState() public {
        assertEq(gaugeFactory.voter(), address(voter));
        assertEq(gaugeFactory.implementation(), address(gaugeImplementation));
    }
}
