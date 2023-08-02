pragma solidity ^0.7.6;
pragma abicoder v2;

import {UniswapV3FactoryTest} from "./UniswapV3Factory.t.sol";

contract SetOwner is UniswapV3FactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.owner});
    }

    function testCannotSetOwnerIfNotOwner() public {
        vm.expectRevert();
        changePrank({msgSender: users.charlie});
        poolFactory.setOwner({_owner: users.charlie});
    }

    function testCannotSetOwnerWithZeroAddress() public {
        vm.expectRevert();
        poolFactory.setOwner({_owner: address(0)});
    }

    function testSetOwner() public {
        vm.expectEmit(true, true, false, false, address(poolFactory));
        emit OwnerChanged({oldOwner: users.owner, newOwner: users.alice});
        poolFactory.setOwner({_owner: users.alice});

        assertEq(poolFactory.owner(), users.alice);
    }
}
