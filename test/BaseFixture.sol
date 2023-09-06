pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import {UniswapV3Factory} from "contracts/core/UniswapV3Factory.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {
    INonfungiblePositionManager, NonfungiblePositionManager
} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {MockWETH} from "contracts/test/MockWETH.sol";
import {MockVoter} from "contracts/test/MockVoter.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Constants} from "./utils/Constants.sol";
import {Events} from "./utils/Events.sol";
import {PoolUtils} from "./utils/PoolUtils.sol";
import {Users} from "./utils/Users.sol";
import {SafeCast} from "contracts/gauge/libraries/SafeCast.sol";
import {TestUniswapV3Callee} from "contracts/core/test/TestUniswapV3Callee.sol";

contract BaseFixture is Test, Constants, Events, PoolUtils {
    UniswapV3Factory public poolFactory;
    UniswapV3Pool public poolImplementation;
    NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    CLGaugeFactory public gaugeFactory;
    CLGauge public gaugeImplementation;

    MockVoter public voter;
    MockWETH public weth;

    ERC20 public rewardToken;

    ERC20 public token0;
    ERC20 public token1;

    Users internal users;

    TestUniswapV3Callee public uniswapV3Callee;

    function setUp() public virtual {
        users = Users({
            owner: createUser("Owner"),
            feeManager: createUser("FeeManager"),
            alice: createUser("Alice"),
            bob: createUser("Bob"),
            charlie: createUser("Charlie")
        });

        uniswapV3Callee = new TestUniswapV3Callee();

        rewardToken = new ERC20("", "");

        weth = new MockWETH();
        voter = new MockVoter(address(rewardToken));

        poolImplementation = new UniswapV3Pool();
        poolFactory = new UniswapV3Factory({
            _voter: address(voter), 
            _implementation: address(poolImplementation)
        });
        // backward compatibility with the original uniV3 fee structure and tick spacing
        poolFactory.enableTickSpacing(10, 500);
        poolFactory.enableTickSpacing(60, 3000);
        poolFactory.enableTickSpacing(200, 10000);

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

        voter.setGaugeFactory(address(gaugeFactory));

        poolFactory.setOwner(users.owner);
        poolFactory.setFeeManager(users.feeManager);

        ERC20 tokenA = new ERC20("", "");
        ERC20 tokenB = new ERC20("", "");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        labelContracts();
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

    function mintNewCustomRangePositionForUserWith60TickSpacing(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper,
        address user
    ) internal returns (uint256) {
        vm.startPrank(user);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: tickLower,
            tickUpper: tickUpper,
            recipient: user,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        (uint256 tokenId,,,) = nft.mint(params);
        return tokenId;
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
    }

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr({name: name}));
        vm.deal({account: user, newBalance: TOKEN_1 * 1000});
    }
}
