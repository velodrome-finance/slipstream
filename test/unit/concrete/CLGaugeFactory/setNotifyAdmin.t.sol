pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGaugeFactory.t.sol";

contract SetNotifyAdminTest is CLGaugeFactoryTest {
    event SetNotifyAdmin(address indexed notifyAdmin);

    function test_RevertIf_NotNotifyAdmin() public {
        vm.startPrank({msgSender: users.alice});
        vm.expectRevert(abi.encodePacked("NA"));
        gaugeFactory.setNotifyAdmin({_admin: users.alice});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.startPrank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("ZA"));
        gaugeFactory.setNotifyAdmin({_admin: address(0)});
    }

    function test_SetNotifyAdmin() public {
        vm.prank({msgSender: users.owner});
        vm.expectEmit(true, false, false, false, address(gaugeFactory));
        emit SetNotifyAdmin(users.alice);
        gaugeFactory.setNotifyAdmin({_admin: users.alice});

        assertEq(gaugeFactory.notifyAdmin(), address(users.alice));
    }
}
