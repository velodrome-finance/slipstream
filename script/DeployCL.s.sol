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
import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";
import {MixedRouteQuoterV1} from "contracts/periphery/lens/MixedRouteQuoterV1.sol";
import {QuoterV2} from "contracts/periphery/lens/QuoterV2.sol";

contract DeployCL is Script {
    using stdJson for string;

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.rememberKey(deployPrivateKey);
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
    string public nftName;
    string public nftSymbol;

    // deployed contracts
    CLPool public poolImplementation;
    CLFactory public poolFactory;
    NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    CLGauge public gaugeImplementation;
    CLGaugeFactory public gaugeFactory;
    CustomSwapFeeModule public swapFeeModule;
    CustomUnstakedFeeModule public unstakedFeeModule;
    MixedRouteQuoterV1 public mixedQuoter;
    QuoterV2 public quoter;

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
        nftName = abi.decode(vm.parseJson(jsonConstants, ".nftName"), (string));
        nftSymbol = abi.decode(vm.parseJson(jsonConstants, ".nftSymbol"), (string));

        require(address(voter) != address(0)); // sanity check for constants file fillled out correctly

        vm.startBroadcast(deployerAddress);
        // deploy pool + factory
        poolImplementation = new CLPool();
        poolFactory = new CLFactory({_voter: voter, _poolImplementation: address(poolImplementation)});

        // deploy gauges
        gaugeImplementation = new CLGauge();
        gaugeFactory = new CLGaugeFactory({_voter: voter, _implementation: address(gaugeImplementation)});

        // deploy nft contracts
        nftDescriptor =
            new NonfungibleTokenPositionDescriptor({_WETH9: address(weth), _nativeCurrencyLabelBytes: bytes32("ETH")});
        nft = new NonfungiblePositionManager({
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor: address(nftDescriptor),
            name: nftName,
            symbol: nftSymbol
        });

        // set nft manager in the factories
        gaugeFactory.setNonfungiblePositionManager(address(nft));
        gaugeFactory.setNotifyAdmin(notifyAdmin);

        // deploy fee modules
        swapFeeModule = new CustomSwapFeeModule({_factory: address(poolFactory)});
        unstakedFeeModule = new CustomUnstakedFeeModule({_factory: address(poolFactory)});
        poolFactory.setSwapFeeModule({_swapFeeModule: address(swapFeeModule)});
        poolFactory.setUnstakedFeeModule({_unstakedFeeModule: address(unstakedFeeModule)});

        // transfer permissionsx
        nft.setOwner(team);
        poolFactory.setOwner(poolFactoryOwner);
        poolFactory.setSwapFeeManager(feeManager);
        poolFactory.setUnstakedFeeManager(feeManager);

        mixedQuoter = new MixedRouteQuoterV1({_factory: address(poolFactory), _factoryV2: factoryV2, _WETH9: weth});
        quoter = new QuoterV2({_factory: address(poolFactory), _WETH9: weth});
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
        vm.writeJson(vm.serializeAddress("", "SwapFeeModule", address(swapFeeModule)), path);
        vm.writeJson(vm.serializeAddress("", "UnstakedFeeModule", address(unstakedFeeModule)), path);
        vm.writeJson(vm.serializeAddress("", "MixedQuoter", address(mixedQuoter)), path);
        vm.writeJson(vm.serializeAddress("", "Quoter", address(quoter)), path);
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
