pragma solidity ^0.7.6;
pragma abicoder v2;

import {INonfungiblePositionManager} from "contracts/periphery/interfaces/INonfungiblePositionManager.sol";
import "./NonfungiblePositionManager.t.sol";

contract CollectTest is NonfungiblePositionManagerTest {
    function test_RevertIf_CallerIsNotGauge() public {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});

        vm.expectRevert(bytes("NA"));
        nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: msg.sender,
                amount0Max: uint128(TOKEN_1),
                amount1Max: uint128(TOKEN_1)
            })
        );
    }

    // TODO Check feeGrowth once #42 is done
}
