pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CLPool.t.sol";

contract SetGaugeAndPositionManagerTest is CLPoolTest {
    CLPool public pool;

    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: users.owner});

        // redeploy contracts
        factoryRegistry = IFactoryRegistry(new MockFactoryRegistry());
        voter = IVoter(
            new MockVoter({
                _rewardToken: address(rewardToken),
                _factoryRegistry: address(factoryRegistry),
                _ve: address(escrow)
            })
        );

        poolImplementation = new CLPool();
        poolFactory = new CLFactory({
            _owner: users.owner,
            _swapFeeManager: address(this),
            _unstakedFeeManager: address(this),
            _voter: address(voter),
            _poolImplementation: address(poolImplementation)
        });

        nftDescriptor = new NonfungibleTokenPositionDescriptor({
            _WETH9: address(weth),
            _nativeCurrencyLabelBytes: 0x4554480000000000000000000000000000000000000000000000000000000000 // 'ETH' as bytes32 string
        });
        nft = new NonfungiblePositionManager({
            _owner: users.owner,
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor: address(nftDescriptor),
            name: nftName,
            symbol: nftSymbol
        });

        gaugeImplementation = new CLGauge();
        gaugeFactory = new CLGaugeFactory({
            _notifyAdmin: users.owner,
            _voter: address(voter),
            _nft: address(nft),
            _implementation: address(gaugeImplementation)
        });

        factoryRegistry.approve({
            poolFactory: address(poolFactory),
            votingRewardsFactory: address(votingRewardsFactory),
            gaugeFactory: address(gaugeFactory)
        });
        vm.stopPrank();

        pool = CLPool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_LOW,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );

        vm.label(address(gaugeFactory), "GF");
        vm.label(address(factoryRegistry), "FR");
    }

    function test_RevertIf_AlreadyInitialized() public {
        vm.prank(address(gaugeFactory));
        pool.setGaugeAndPositionManager({_gauge: address(1), _nft: address(nft)});

        vm.prank(address(gaugeFactory));
        vm.expectRevert();
        pool.setGaugeAndPositionManager({_gauge: address(1), _nft: address(nft)});
    }

    function test_RevertIf_NotGaugeFactory() public {
        vm.expectRevert(abi.encodePacked("NGF"));
        pool.setGaugeAndPositionManager({_gauge: address(1), _nft: address(nft)});
    }

    function test_SetGaugeAndPositionManager() public {
        address gauge = voter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)});

        assertEq(pool.gauge(), address(gauge));
        assertEq(pool.nft(), address(nft));
    }
}
