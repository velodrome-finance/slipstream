pragma solidity ^0.7.6;
pragma abicoder v2;

import {INonfungiblePositionManager} from "contracts/periphery/interfaces/INonfungiblePositionManager.sol";
import {NonfungiblePositionManagerTest} from "./NonfungiblePositionManager.t.sol";

contract OwnerTest is NonfungiblePositionManagerTest {
    event TransferOwnership(address indexed owner);

    function test_SetOwner() public {
        address owner = users.owner;
        address newOwner = users.alice;
        assertNotEq(owner, newOwner);

        vm.expectEmit(true, false, false, false, address(nft));
        emit TransferOwnership(newOwner);

        vm.startPrank(owner);
        nft.setOwner(newOwner);
        vm.stopPrank();

        assertEq(nft.owner(), newOwner);
    }

    function test_RevertIf_SetOwnerCallerIsNotOwner() public {
        vm.startPrank(users.alice);
        vm.expectRevert(bytes("NO"));
        nft.setOwner(users.bob);
        vm.stopPrank();
    }

    function test_RevertIf_SetOwnerToZeroAddress() public {
        vm.startPrank(users.owner);
        vm.expectRevert(bytes("ZA"));
        nft.setOwner(address(0));
        vm.stopPrank();
    }
}
