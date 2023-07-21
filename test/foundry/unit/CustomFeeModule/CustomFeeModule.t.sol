pragma solidity ^0.7.6;
pragma abicoder v2;

import {CustomFeeModule} from 'contracts/fees/CustomFeeModule.sol';
import '../../BaseFixture.sol';

contract CustomFeeModuleTest is BaseFixture {
    CustomFeeModule public customFeeModule;

    function setUp() public virtual override {
        super.setUp();
        customFeeModule = new CustomFeeModule({_factory: address(poolFactory)});

        vm.prank(users.feeManager);
        poolFactory.setFeeModule({_feeModule: address(customFeeModule)});

        vm.label({account: address(customFeeModule), newLabel: 'Custom Fee Module'});
    }

    function test_InitialState() public {
        assertEq(customFeeModule.MAX_FEE(), 10_000);
        assertEq(address(customFeeModule.factory()), address(poolFactory));
    }
}
