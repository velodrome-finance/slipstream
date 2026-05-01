pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGaugeFactory.t.sol";

contract SetGaugeStakeManagerTest is CLGaugeFactoryTest {
    event SetGaugeStakeManager(address indexed _gaugeStakeManager);

    function test_RevertIf_NotGaugeStakeManager() public {
        vm.startPrank({msgSender: users.alice});
        vm.expectRevert(abi.encodePacked("NA"));
        gaugeFactory.setGaugeStakeManager({_manager: users.alice});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.startPrank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("ZA"));
        gaugeFactory.setGaugeStakeManager({_manager: address(0)});
    }

    function test_SetGaugeStakeManager() public {
        vm.prank({msgSender: users.owner});
        vm.expectEmit(true, false, false, false, address(gaugeFactory));
        emit SetGaugeStakeManager(users.alice);
        gaugeFactory.setGaugeStakeManager({_manager: users.alice});

        assertEq(gaugeFactory.gaugeStakeManager(), users.alice);
    }

    function test_TransferredManagerCanSetNewManager() public {
        vm.prank({msgSender: users.owner});
        gaugeFactory.setGaugeStakeManager({_manager: users.alice});

        vm.prank({msgSender: users.alice});
        gaugeFactory.setGaugeStakeManager({_manager: users.bob});

        assertEq(gaugeFactory.gaugeStakeManager(), users.bob);
    }

    function test_OldManagerCannotSetAfterTransfer() public {
        vm.prank({msgSender: users.owner});
        gaugeFactory.setGaugeStakeManager({_manager: users.alice});

        vm.prank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("NA"));
        gaugeFactory.setGaugeStakeManager({_manager: users.bob});
    }
}
