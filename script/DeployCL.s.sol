// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";

import {CLPool} from "contracts/core/CLPool.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {DynamicSwapFeeModule} from "contracts/core/fees/DynamicSwapFeeModule.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";
import {MixedRouteQuoterV1} from "contracts/periphery/lens/MixedRouteQuoterV1.sol";
import {MixedRouteQuoterV2} from "contracts/periphery/lens/MixedRouteQuoterV2.sol";
import {MixedRouteQuoterV3} from "contracts/periphery/lens/MixedRouteQuoterV3.sol";
import {QuoterV2} from "contracts/periphery/lens/QuoterV2.sol";
import {SwapRouter} from "contracts/periphery/SwapRouter.sol";
import {LpMigrator} from "contracts/periphery/LpMigrator.sol";

contract DeployCL is Script {
    using stdJson for string;

    address public constant deployerAddress = 0x4994DacdB9C57A811aFfbF878D92E00EF2E5C4C2;
    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public outputFilename = vm.envString("OUTPUT_FILENAME");
    string public jsonConstants;

    // loaded variables
    address public team;
    address public weth;
    address public voter;
    address public factoryRegistry;
    address public poolFactoryOwner;
    address public feeManager;
    address public notifyAdmin;
    address public factoryV2;
    address public legacyCLFactory;
    address public legacyCLFactory2;
    address public gaugeStakeManager;
    uint256 public minStakeTime;
    uint256 public penaltyRate;
    string public nftName;
    string public nftSymbol;

    // deployed contracts
    CLPool public poolImplementation;
    CLFactory public poolFactory;
    NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    CLGauge public gaugeImplementation;
    CLGaugeFactory public gaugeFactory;
    DynamicSwapFeeModule public swapFeeModule;
    CustomUnstakedFeeModule public unstakedFeeModule;
    MixedRouteQuoterV1 public mixedQuoter;
    MixedRouteQuoterV2 public mixedQuoterV2;
    MixedRouteQuoterV3 public mixedQuoterV3;
    QuoterV2 public quoter;
    SwapRouter public swapRouter;
    LpMigrator public lpMigrator;

    function run() public {
        string memory root = vm.projectRoot();
        string memory basePath = concat(root, "/script/constants/");
        string memory path = concat(basePath, constantsFilename);
        jsonConstants = vm.readFile(path);

        team = abi.decode(vm.parseJson(jsonConstants, ".team"), (address));
        weth = abi.decode(vm.parseJson(jsonConstants, ".WETH"), (address));
        voter = abi.decode(vm.parseJson(jsonConstants, ".Voter"), (address));
        factoryRegistry = abi.decode(vm.parseJson(jsonConstants, ".FactoryRegistry"), (address));
        poolFactoryOwner = abi.decode(vm.parseJson(jsonConstants, ".poolFactoryOwner"), (address));
        feeManager = abi.decode(vm.parseJson(jsonConstants, ".feeManager"), (address));
        notifyAdmin = abi.decode(vm.parseJson(jsonConstants, ".notifyAdmin"), (address));
        factoryV2 = abi.decode(vm.parseJson(jsonConstants, ".factoryV2"), (address));
        legacyCLFactory = abi.decode(vm.parseJson(jsonConstants, ".legacyCLFactory"), (address));
        legacyCLFactory2 = abi.decode(vm.parseJson(jsonConstants, ".legacyCLFactory2"), (address));
        gaugeStakeManager = abi.decode(vm.parseJson(jsonConstants, ".gaugeStakeManager"), (address));
        minStakeTime = abi.decode(vm.parseJson(jsonConstants, ".minStakeTime"), (uint256));
        penaltyRate = abi.decode(vm.parseJson(jsonConstants, ".penaltyRate"), (uint256));
        nftName = abi.decode(vm.parseJson(jsonConstants, ".nftName"), (string));
        nftSymbol = abi.decode(vm.parseJson(jsonConstants, ".nftSymbol"), (string));

        require(address(voter) != address(0)); // sanity check for constants file fillled out correctly

        vm.startBroadcast(deployerAddress);
        // deploy pool + factory
        poolImplementation = new CLPool();
        poolFactory = new CLFactory({
            _owner: deployerAddress,
            _swapFeeManager: deployerAddress,
            _unstakedFeeManager: deployerAddress,
            _voter: voter,
            _poolImplementation: address(poolImplementation)
        });

        // deploy nft contracts
        nftDescriptor =
            new NonfungibleTokenPositionDescriptor({_WETH9: address(weth), _nativeCurrencyLabelBytes: bytes32("ETH")});
        nft = new NonfungiblePositionManager({
            _owner: team,
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor: address(nftDescriptor),
            name: nftName,
            symbol: nftSymbol
        });

        // deploy gauges
        gaugeImplementation = new CLGauge();
        gaugeFactory = new CLGaugeFactory({
            _notifyAdmin: notifyAdmin,
            _voter: voter,
            _nft: address(nft),
            _implementation: address(gaugeImplementation)
        });

        // configure gauge factory stake parameters and transfer gaugeStakeManager
        gaugeFactory.setDefaultMinStakeTime(minStakeTime);
        gaugeFactory.setPenaltyRate(penaltyRate);
        gaugeFactory.setGaugeStakeManager(gaugeStakeManager);

        // deploy fee modules
        swapFeeModule = new DynamicSwapFeeModule({
            _factory: address(poolFactory),
            _defaultScalingFactor: 0,
            _defaultFeeCap: 30_000,
            _pools: new address[](0),
            _fees: new uint24[](0)
        });
        unstakedFeeModule = new CustomUnstakedFeeModule({_factory: address(poolFactory)});
        poolFactory.setSwapFeeModule({_swapFeeModule: address(swapFeeModule)});
        poolFactory.setUnstakedFeeModule({_unstakedFeeModule: address(unstakedFeeModule)});

        // transfer permissions
        poolFactory.setOwner(poolFactoryOwner);
        poolFactory.setSwapFeeManager(feeManager);
        poolFactory.setUnstakedFeeManager(feeManager);

        mixedQuoter = new MixedRouteQuoterV1({_factory: address(poolFactory), _factoryV2: factoryV2, _WETH9: weth});
        quoter = new QuoterV2({_factory: address(poolFactory), _WETH9: weth});
        swapRouter = new SwapRouter({_factory: address(poolFactory), _WETH9: weth});
        mixedQuoterV2 = new MixedRouteQuoterV2({_factory: address(poolFactory), _factoryV2: factoryV2, _WETH9: weth});
        mixedQuoterV3 = new MixedRouteQuoterV3({
            _factory: address(poolFactory),
            _legacyCLFactory: legacyCLFactory,
            _legacyCLFactory2: legacyCLFactory2,
            _factoryV2: factoryV2,
            _WETH9: weth
        });
        lpMigrator = new LpMigrator();
        vm.stopBroadcast();

        // write to file
        path = concat(basePath, "output/DeployCL-");
        path = concat(path, outputFilename);
        vm.writeJson(vm.serializeAddress("", "PoolImplementation", address(poolImplementation)), path);
        vm.writeJson(vm.serializeAddress("", "PoolFactory", address(poolFactory)), path);
        vm.writeJson(vm.serializeAddress("", "NonfungibleTokenPositionDescriptor", address(nftDescriptor)), path);
        vm.writeJson(vm.serializeAddress("", "NonfungiblePositionManager", address(nft)), path);
        vm.writeJson(vm.serializeAddress("", "GaugeImplementation", address(gaugeImplementation)), path);
        vm.writeJson(vm.serializeAddress("", "GaugeFactory", address(gaugeFactory)), path);
        vm.writeJson(vm.serializeAddress("", "DynamicSwapFeeModule", address(swapFeeModule)), path);
        vm.writeJson(vm.serializeAddress("", "UnstakedFeeModule", address(unstakedFeeModule)), path);
        vm.writeJson(vm.serializeAddress("", "MixedQuoter", address(mixedQuoter)), path);
        vm.writeJson(vm.serializeAddress("", "MixedQuoterV2", address(mixedQuoterV2)), path);
        vm.writeJson(vm.serializeAddress("", "MixedQuoterV3", address(mixedQuoterV3)), path);
        vm.writeJson(vm.serializeAddress("", "Quoter", address(quoter)), path);
        vm.writeJson(vm.serializeAddress("", "SwapRouter", address(swapRouter)), path);
        vm.writeJson(vm.serializeAddress("", "LpMigrator", address(lpMigrator)), path);
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
