pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLFactory.t.sol";

contract SetGaugeFactoryTest is CLFactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.owner});

        // redeploy contracts, but do not set gauge factory or nft
        poolImplementation = new CLPool();
        poolFactory = new CLFactory({
            _voter: address(voter), 
            _poolImplementation: address(poolImplementation)
        });

        gaugeImplementation = new CLGauge();
        gaugeFactory = new CLGaugeFactory({
            _voter: address(voter),
            _implementation: address(gaugeImplementation)
        });

        nftDescriptor = new NonfungibleTokenPositionDescriptor({
            _WETH9: address(weth),
            _nativeCurrencyLabelBytes: 0x4554480000000000000000000000000000000000000000000000000000000000 // 'ETH' as bytes32 string
        });
        nft = new NonfungiblePositionManager({
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor: address(nftDescriptor)
        });
        gaugeFactory.setNonfungiblePositionManager(address(nft));

        vm.stopPrank();
    }

    function test_RevertIf_AlreadyInitialized() public {
        vm.startPrank({msgSender: users.owner});
        poolFactory.setGaugeFactory({
            _gaugeFactory: address(gaugeFactory),
            _gaugeImplementation: address(gaugeImplementation)
        });

        vm.expectRevert(abi.encodePacked("AI"));
        poolFactory.setGaugeFactory({_gaugeFactory: address(1), _gaugeImplementation: address(2)});
        vm.stopPrank();
    }

    function test_RevertIf_CallerNotDeployer() public {
        vm.prank({msgSender: users.alice});
        vm.expectRevert(abi.encodePacked("AI"));
        poolFactory.setGaugeFactory({
            _gaugeFactory: address(gaugeFactory),
            _gaugeImplementation: address(gaugeImplementation)
        });
    }

    function test_RevertIf_ZeroAddress() public {
        vm.startPrank({msgSender: users.owner});
        vm.expectRevert();
        poolFactory.setGaugeFactory({_gaugeFactory: address(0), _gaugeImplementation: address(gaugeImplementation)});
        vm.expectRevert();
        poolFactory.setGaugeFactory({_gaugeFactory: address(gaugeFactory), _gaugeImplementation: address(0)});
        vm.expectRevert();
        poolFactory.setGaugeFactory({_gaugeFactory: address(0), _gaugeImplementation: address(0)});
        vm.stopPrank();
    }

    function test_SetGaugeFactory() public {
        vm.prank({msgSender: users.owner});
        poolFactory.setGaugeFactory({
            _gaugeFactory: address(gaugeFactory),
            _gaugeImplementation: address(gaugeImplementation)
        });

        assertEq(poolFactory.gaugeFactory(), address(gaugeFactory));
        assertEq(poolFactory.gaugeImplementation(), address(gaugeImplementation));
    }

    function test_InitialState() public virtual override {
        assertEq(address(poolFactory.voter()), address(voter));
        assertEq(poolFactory.poolImplementation(), address(poolImplementation));
        assertEq(poolFactory.owner(), users.owner);
        assertEq(poolFactory.swapFeeModule(), address(0));
        assertEq(poolFactory.unstakedFeeModule(), address(0));
        assertEq(poolFactory.swapFeeManager(), users.owner);
        assertEq(poolFactory.unstakedFeeManager(), users.owner);
        // skip nft, gaugeFactory, gaugeImplementation and tick spacing checks
    }
}
