pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest} from "./CLFactory.t.sol";

contract SetSwapFeeManagerTest is CLFactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotFeeManager() public {
        vm.expectRevert();
        vm.startPrank({msgSender: users.charlie});
        poolFactory.setSwapFeeManager({_swapFeeManager: users.charlie});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        poolFactory.setSwapFeeManager({_swapFeeManager: address(0)});
    }

    function test_SetSwapFeeManager() public {
        vm.expectEmit(true, true, false, false, address(poolFactory));
        emit SwapFeeManagerChanged({oldFeeManager: users.feeManager, newFeeManager: users.alice});
        poolFactory.setSwapFeeManager({_swapFeeManager: users.alice});

        assertEq(poolFactory.swapFeeManager(), users.alice);
    }
}
