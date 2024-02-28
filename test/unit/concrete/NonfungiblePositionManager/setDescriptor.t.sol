pragma solidity ^0.7.6;
pragma abicoder v2;

import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {INonfungiblePositionManager} from "contracts/periphery/interfaces/INonfungiblePositionManager.sol";
import {NonfungiblePositionManagerTest} from "./NonfungiblePositionManager.t.sol";

contract SetDescriptorTest is NonfungiblePositionManagerTest {
    event TokenDescriptorChanged(address indexed tokenDescriptor);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    function test_SetTokenDescriptor() public {
        address tokenDescriptor = nft.tokenDescriptor();
        address newTokenDescriptor = address(
            new NonfungibleTokenPositionDescriptor({
                _WETH9: address(weth),
                _nativeCurrencyLabelBytes: 0x4554480000000000000000000000000000000000000000000000000000000000
            })
        ); // 'ETH' as bytes32 string
        assertNotEq(tokenDescriptor, newTokenDescriptor);

        vm.expectEmit(false, false, false, true, address(nft));
        emit BatchMetadataUpdate(0, type(uint256).max);
        vm.expectEmit(true, false, false, false, address(nft));
        emit TokenDescriptorChanged(newTokenDescriptor);

        vm.startPrank(users.owner);
        nft.setTokenDescriptor(newTokenDescriptor);
        vm.stopPrank();

        assertEq(nft.tokenDescriptor(), newTokenDescriptor);
    }

    function test_RevertIf_SetTokenDescriptorCallerIsNotOwner() public {
        vm.startPrank(users.alice);
        vm.expectRevert();
        nft.setOwner(users.bob);
        vm.stopPrank();
    }

    function test_RevertIf_SetTokenDescriptorToZeroAddress() public {
        vm.startPrank(users.owner);
        vm.expectRevert();
        nft.setOwner(address(0));
        vm.stopPrank();
    }
}
