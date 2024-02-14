pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../BaseFixture.sol";

abstract contract CustomUnstakedFeeModuleTest is BaseFixture {
    function setUp() public virtual override {
        super.setUp();
        customUnstakedFeeModule = new CustomUnstakedFeeModule({_factory: address(poolFactory)});

        vm.prank(users.feeManager);
        poolFactory.setUnstakedFeeModule({_unstakedFeeModule: address(customUnstakedFeeModule)});

        vm.label({account: address(customUnstakedFeeModule), newLabel: "Custom Unstaked Fee Module"});
    }

    function test_InitialState() public {
        assertEq(customUnstakedFeeModule.MAX_FEE(), 500_000);
        assertEq(address(customUnstakedFeeModule.factory()), address(poolFactory));
    }
}
