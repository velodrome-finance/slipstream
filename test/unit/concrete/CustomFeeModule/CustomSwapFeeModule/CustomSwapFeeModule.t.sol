pragma solidity ^0.7.6;
pragma abicoder v2;

import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
import "../../../../BaseFixture.sol";

contract CustomSwapFeeModuleTest is BaseFixture {
    CustomSwapFeeModule public customSwapFeeModule;

    function setUp() public virtual override {
        super.setUp();
        customSwapFeeModule = new CustomSwapFeeModule({_factory: address(poolFactory)});

        vm.prank(users.feeManager);
        poolFactory.setSwapFeeModule({_swapFeeModule: address(customSwapFeeModule)});

        vm.label({account: address(customSwapFeeModule), newLabel: "Custom Swap Fee Module"});
    }

    function test_InitialState() public {
        assertEq(customSwapFeeModule.MAX_FEE(), 100);
        assertEq(address(customSwapFeeModule.factory()), address(poolFactory));
    }
}
