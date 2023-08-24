pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3FactoryTest} from "./UniswapV3Factory.t.sol";

contract SetFeeManagerTest is UniswapV3FactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotFeeManager() public {
        vm.expectRevert();
        changePrank({msgSender: users.charlie});
        poolFactory.setFeeManager({_feeManager: users.charlie});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        poolFactory.setFeeManager({_feeManager: address(0)});
    }

    function test_SetFeeManager() public {
        vm.expectEmit(true, true, false, false, address(poolFactory));
        emit FeeManagerChanged({oldFeeManager: users.feeManager, newFeeManager: users.alice});
        poolFactory.setFeeManager({_feeManager: users.alice});

        assertEq(poolFactory.feeManager(), users.alice);
    }
}
