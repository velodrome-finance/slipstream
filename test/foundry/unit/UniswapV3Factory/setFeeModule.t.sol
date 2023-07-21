pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3FactoryTest} from './UniswapV3Factory.t.sol';

contract SetFeeModule is UniswapV3FactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotFeeManager() public {
        vm.expectRevert();
        changePrank({msgSender: users.charlie});
        poolFactory.setFeeModule({_feeModule: users.charlie});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        poolFactory.setFeeModule({_feeModule: address(0)});
    }

    function test_SetFeeModule() public {
        vm.expectEmit(true, true, false, false, address(poolFactory));
        emit FeeModuleChanged({oldFeeModule: address(0), newFeeModule: users.alice});
        poolFactory.setFeeModule({_feeModule: users.alice});

        assertEq(poolFactory.feeModule(), users.alice);
    }
}
