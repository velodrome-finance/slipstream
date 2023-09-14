pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3FactoryTest} from "./UniswapV3Factory.t.sol";

contract SetUnstakedFeeModule is UniswapV3FactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotFeeManager() public {
        vm.expectRevert();
        changePrank({msgSender: users.charlie});
        poolFactory.setUnstakedFeeModule({_unstakedFeeModule: users.charlie});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        poolFactory.setUnstakedFeeModule({_unstakedFeeModule: address(0)});
    }

    function test_SetSwapFeeModule() public {
        vm.expectEmit(true, true, false, false, address(poolFactory));
        emit UnstakedFeeModuleChanged({oldFeeModule: address(customUnstakedFeeModule), newFeeModule: users.alice});
        poolFactory.setUnstakedFeeModule({_unstakedFeeModule: users.alice});

        assertEq(poolFactory.unstakedFeeModule(), users.alice);
    }
}
