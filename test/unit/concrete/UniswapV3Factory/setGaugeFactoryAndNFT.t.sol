pragma solidity ^0.7.6;
pragma abicoder v2;

import "./UniswapV3Factory.t.sol";

contract SetGaugeFactoryAndNFTTest is UniswapV3FactoryTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.owner});

        // redeploy contracts, but do not set gauge factory or nft
        poolImplementation = new UniswapV3Pool();
        poolFactory = new UniswapV3Factory({
            _voter: address(voter), 
            _poolImplementation: address(poolImplementation)
        });

        nftDescriptor = new NonfungibleTokenPositionDescriptor({
            _WETH9: address(weth),
            _nativeCurrencyLabelBytes: 0x4554480000000000000000000000000000000000000000000000000000000000 // 'ETH' as bytes32 string
        });
        nft = new NonfungiblePositionManager({
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor_: address(nftDescriptor)
        });

        gaugeImplementation = new CLGauge();
        gaugeFactory = new CLGaugeFactory({
            _voter: address(voter),
            _implementation: address(gaugeImplementation),
            _nft: address(nft)
        });
    }

    function test_RevertIf_AlreadyInitialized() public {
        poolFactory.setGaugeFactoryAndNFT({_gaugeFactory: address(gaugeFactory), _nft: address(nft)});

        vm.expectRevert(abi.encodePacked("AI"));
        poolFactory.setGaugeFactoryAndNFT({_gaugeFactory: address(1), _nft: address(2)});
    }

    function test_SetGaugeFactoryAndNFT() public {
        poolFactory.setGaugeFactoryAndNFT({_gaugeFactory: address(gaugeFactory), _nft: address(nft)});

        assertEq(poolFactory.gaugeFactory(), address(gaugeFactory));
        assertEq(poolFactory.gaugeImplementation(), address(gaugeImplementation));
        assertEq(poolFactory.nft(), address(nft));
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
