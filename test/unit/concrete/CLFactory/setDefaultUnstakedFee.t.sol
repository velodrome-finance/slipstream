pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest} from "./CLFactory.t.sol";

contract SetDefaultUnstakedFee is CLFactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotFeeManager() public {
        vm.expectRevert();
        vm.startPrank({msgSender: users.charlie});
        poolFactory.setDefaultUnstakedFee({_defaultUnstakedFee: 200_000});
    }

    function test_RevertIf_GreaterThanMax() public {
        vm.expectRevert();
        poolFactory.setDefaultUnstakedFee({_defaultUnstakedFee: 500_001});
    }

    function test_SetDefaultUnstakedFee() public {
        vm.expectEmit(true, true, false, false, address(poolFactory));
        emit DefaultUnstakedFeeChanged({oldUnstakedFee: 100_000, newUnstakedFee: 200_000});
        poolFactory.setDefaultUnstakedFee({_defaultUnstakedFee: 200_000});

        assertEqUint(poolFactory.defaultUnstakedFee(), 200_000);
    }
}
