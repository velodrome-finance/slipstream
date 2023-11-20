pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {
    INonfungiblePositionManager, NonfungiblePositionManager
} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {MockWETH} from "contracts/test/MockWETH.sol";
import {IVoter, MockVoter} from "contracts/test/MockVoter.sol";
import {IVotingEscrow, MockVotingEscrow} from "contracts/test/MockVotingEscrow.sol";
import {IFactoryRegistry, MockFactoryRegistry} from "contracts/test/MockFactoryRegistry.sol";
import {IVotingRewardsFactory, MockVotingRewardsFactory} from "contracts/test/MockVotingRewardsFactory.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Constants} from "./utils/Constants.sol";
import {Events} from "./utils/Events.sol";
import {PoolUtils} from "./utils/PoolUtils.sol";
import {Users} from "./utils/Users.sol";
import {SafeCast} from "contracts/gauge/libraries/SafeCast.sol";
import {TestCLCallee} from "contracts/core/test/TestCLCallee.sol";
import {NFTManagerCallee} from "contracts/periphery/test/NFTManagerCallee.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";
import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";

abstract contract BaseFixture is Test, Constants, Events, PoolUtils {
    CLFactory public poolFactory;
    CLPool public poolImplementation;
    NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    CLGaugeFactory public gaugeFactory;
    CLGauge public gaugeImplementation;

    /// @dev mocks
    IFactoryRegistry public factoryRegistry;
    IVoter public voter;
    IVotingEscrow public escrow;
    IERC20 public weth;
    IVotingRewardsFactory public votingRewardsFactory;

    ERC20 public rewardToken;

    ERC20 public token0;
    ERC20 public token1;

    Users internal users;

    TestCLCallee public clCallee;
    NFTManagerCallee public nftCallee;

    CustomSwapFeeModule public customSwapFeeModule;
    CustomUnstakedFeeModule public customUnstakedFeeModule;

    function setUp() public virtual {
        users = Users({
            owner: createUser("Owner"),
            feeManager: createUser("FeeManager"),
            alice: createUser("Alice"),
            bob: createUser("Bob"),
            charlie: createUser("Charlie")
        });

        vm.startPrank(users.owner);
        rewardToken = new ERC20("", "");

        deployDependencies();

        // deploy pool and associated contracts
        poolImplementation = new CLPool();
        poolFactory = new CLFactory({
            _voter: address(voter), 
            _poolImplementation: address(poolImplementation)
        });
        // backward compatibility with the original uniV3 fee structure and tick spacing
        poolFactory.enableTickSpacing(10, 500);
        poolFactory.enableTickSpacing(60, 3_000);
        // 200 tick spacing fee is manually overriden in tests as it is part of default settings

        // deploy gauges and associated contracts
        gaugeImplementation = new CLGauge();
        gaugeFactory = new CLGaugeFactory({
            _voter: address(voter),
            _implementation: address(gaugeImplementation)
        });
        poolFactory.setGaugeFactory({
            _gaugeFactory: address(gaugeFactory),
            _gaugeImplementation: address(gaugeImplementation)
        });

        // deploy nft manager and descriptor
        nftDescriptor = new NonfungibleTokenPositionDescriptor({
            _WETH9: address(weth),
            _nativeCurrencyLabelBytes: 0x4554480000000000000000000000000000000000000000000000000000000000 // 'ETH' as bytes32 string
        });
        nft = new NonfungiblePositionManager({
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor: address(nftDescriptor)
        });

        // set nftmanager in the factories
        gaugeFactory.setNonfungiblePositionManager(address(nft));
        poolFactory.setNonfungiblePositionManager(address(nft));
        vm.stopPrank();

        // approve gauge in factory registry
        vm.prank(Ownable(address(factoryRegistry)).owner());
        factoryRegistry.approve({
            poolFactory: address(poolFactory),
            votingRewardsFactory: address(votingRewardsFactory),
            gaugeFactory: address(gaugeFactory)
        });

        // transfer residual permissions
        vm.startPrank(users.owner);
        poolFactory.setOwner(users.owner);
        poolFactory.setSwapFeeManager(users.feeManager);
        poolFactory.setUnstakedFeeManager(users.feeManager);
        vm.stopPrank();

        customSwapFeeModule = new CustomSwapFeeModule(address(poolFactory));
        customUnstakedFeeModule = new CustomUnstakedFeeModule(address(poolFactory));
        vm.startPrank(users.feeManager);
        poolFactory.setSwapFeeModule(address(customSwapFeeModule));
        poolFactory.setUnstakedFeeModule(address(customUnstakedFeeModule));
        vm.stopPrank();

        ERC20 tokenA = new ERC20("", "");
        ERC20 tokenB = new ERC20("", "");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        clCallee = new TestCLCallee();
        nftCallee = new NFTManagerCallee(address(token0), address(token1), address(nft));

        // Setting up alice for the tests since she's the default test user
        deal({token: address(token0), to: users.alice, give: TOKEN_1 * 100});
        deal({token: address(token1), to: users.alice, give: TOKEN_1 * 100});

        vm.startPrank(users.alice);
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);
        token0.approve(address(clCallee), type(uint256).max);
        token1.approve(address(clCallee), type(uint256).max);
        token0.approve(address(nftCallee), type(uint256).max);
        token1.approve(address(nftCallee), type(uint256).max);
        vm.stopPrank();

        labelContracts();
    }

    /// @dev Deploys mocks of external dependencies
    ///      Override if using a fork test
    function deployDependencies() public virtual {
        factoryRegistry = IFactoryRegistry(new MockFactoryRegistry());
        votingRewardsFactory = IVotingRewardsFactory(new MockVotingRewardsFactory());
        weth = IERC20(address(new MockWETH()));
        escrow = IVotingEscrow(new MockVotingEscrow(users.owner));
        voter = IVoter(
            new MockVoter({
            _rewardToken: address(rewardToken),
            _factoryRegistry: address(factoryRegistry),
            _ve: address(escrow)
            })
        );
    }

    /// @dev Helper utility to forward time to next week
    ///      note epoch requires at least one second to have
    ///      passed into the new epoch
    function skipToNextEpoch(uint256 offset) public {
        uint256 ts = block.timestamp;
        uint256 nextEpoch = ts - (ts % (1 weeks)) + (1 weeks);
        vm.warp(nextEpoch + offset);
        vm.roll(block.number + 1);
    }

    /// @dev Helper function to add rewards to gauge from voter
    function addRewardToGauge(address _voter, address _gauge, uint256 _amount) internal {
        deal(address(rewardToken), _voter, _amount);
        vm.startPrank(_voter);
        // do not overwrite approvals if already set
        if (rewardToken.allowance(_voter, _gauge) < _amount) {
            rewardToken.approve(_gauge, _amount);
        }
        CLGauge(_gauge).notifyRewardAmount(_amount);
        vm.stopPrank();
    }

    function labelContracts() internal virtual {
        vm.label({account: address(weth), newLabel: "WETH"});
        vm.label({account: address(voter), newLabel: "Voter"});
        vm.label({account: address(nftDescriptor), newLabel: "NFT Descriptor"});
        vm.label({account: address(nft), newLabel: "NFT Manager"});
        vm.label({account: address(poolImplementation), newLabel: "Pool Implementation"});
        vm.label({account: address(poolFactory), newLabel: "Pool Factory"});
        vm.label({account: address(token0), newLabel: "Token 0"});
        vm.label({account: address(token1), newLabel: "Token 1"});
        vm.label({account: address(rewardToken), newLabel: "Reward Token"});
        vm.label({account: address(gaugeFactory), newLabel: "Gauge Factory"});
        vm.label({account: address(customSwapFeeModule), newLabel: "Custom Swap FeeModule"});
        vm.label({account: address(customUnstakedFeeModule), newLabel: "Custom Unstaked Fee Module"});
    }

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr({name: name}));
        vm.deal({account: user, newBalance: TOKEN_1 * 1_000});
    }
}
