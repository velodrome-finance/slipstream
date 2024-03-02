pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLGaugeFactory.t.sol";

contract SetNFTManagerTest is CLGaugeFactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.owner});
        gaugeFactory = new CLGaugeFactory({_voter: address(voter), _implementation: address(gaugeImplementation)});

        nft = new NonfungiblePositionManager({
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor: address(nftDescriptor),
            name: nftName,
            symbol: nftSymbol
        });
        vm.stopPrank();
    }

    function test_RevertIf_AlreadyInitialized() public {
        vm.startPrank({msgSender: users.owner});
        gaugeFactory.setNonfungiblePositionManager({_nft: address(nft)});

        vm.expectRevert(abi.encodePacked("AI"));
        gaugeFactory.setNonfungiblePositionManager({_nft: address(3)});
        vm.stopPrank();
    }

    function test_RevertIf_CallerNotDeployer() public {
        vm.prank({msgSender: users.alice});
        vm.expectRevert(abi.encodePacked("NA"));
        gaugeFactory.setNonfungiblePositionManager({_nft: address(nft)});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.prank({msgSender: users.owner});
        vm.expectRevert(abi.encodePacked("ZA"));
        gaugeFactory.setNonfungiblePositionManager({_nft: address(0)});
    }

    function test_SetNonfungiblePositionManager() public {
        vm.prank({msgSender: users.owner});
        gaugeFactory.setNonfungiblePositionManager({_nft: address(nft)});

        assertEq(gaugeFactory.nft(), address(nft));
    }
}
