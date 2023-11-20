pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest} from "./CLFactory.t.sol";

contract SetUnstakedFeeManagerTest is CLFactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotFeeManager() public {
        vm.expectRevert();
        vm.startPrank({msgSender: users.charlie});
        poolFactory.setUnstakedFeeManager({_unstakedFeeManager: users.charlie});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        poolFactory.setUnstakedFeeManager({_unstakedFeeManager: address(0)});
    }

    function test_SetSwapFeeManager() public {
        vm.expectEmit(true, true, false, false, address(poolFactory));
        emit UnstakedFeeManagerChanged({oldFeeManager: users.feeManager, newFeeManager: users.alice});
        poolFactory.setUnstakedFeeManager({_unstakedFeeManager: users.alice});

        assertEq(poolFactory.unstakedFeeManager(), users.alice);
    }
}
