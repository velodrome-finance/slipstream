pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3FactoryTest} from "./UniswapV3Factory.t.sol";

contract SetSwapFeeModule is UniswapV3FactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.feeManager});
    }

    function test_RevertIf_NotFeeManager() public {
        vm.expectRevert();
        vm.startPrank({msgSender: users.charlie});
        poolFactory.setSwapFeeModule({_swapFeeModule: users.charlie});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        poolFactory.setSwapFeeModule({_swapFeeModule: address(0)});
    }

    function test_SetSwapFeeModule() public {
        vm.expectEmit(true, true, false, false, address(poolFactory));
        emit SwapFeeModuleChanged({oldFeeModule: address(customSwapFeeModule), newFeeModule: users.alice});
        poolFactory.setSwapFeeModule({_swapFeeModule: users.alice});

        assertEq(poolFactory.swapFeeModule(), users.alice);
    }
}
