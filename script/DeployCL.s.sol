// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";

import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {UniswapV3Factory} from "contracts/core/UniswapV3Factory.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";

contract DeployCL is Script {
    using stdJson for string;

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.rememberKey(deployPrivateKey);
    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public outputFilename = vm.envString("OUTPUT_FILENAME");
    string public jsonConstants;

    // loaded variables
    address public weth;
    address public voter;
    address public factoryRegistry;
    address public poolFactoryOwner;
    address public feeManager;

    // deployed contracts
    UniswapV3Pool public poolImplementation;
    UniswapV3Factory public poolFactory;
    NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    CLGauge public gaugeImplementation;
    CLGaugeFactory public gaugeFactory;
    CustomSwapFeeModule public swapFeeModule;
    CustomUnstakedFeeModule public unstakedFeeModule;

    function run() public {
        string memory root = vm.projectRoot();
        string memory basePath = concat(root, "/script/constants/");
        string memory path = concat(basePath, constantsFilename);
        jsonConstants = vm.readFile(path);

        weth = abi.decode(vm.parseJson(jsonConstants, ".WETH"), (address));
        voter = abi.decode(vm.parseJson(jsonConstants, ".Voter"), (address));
        factoryRegistry = abi.decode(vm.parseJson(jsonConstants, ".FactoryRegistry"), (address));
        poolFactoryOwner = abi.decode(vm.parseJson(jsonConstants, ".poolFactoryOwner"), (address));
        feeManager = abi.decode(vm.parseJson(jsonConstants, ".feeManager"), (address));

        require(address(voter) != address(0)); // sanity check for constants file fillled out correctly

        vm.startBroadcast(deployerAddress);
        // deploy pool + factory
        poolImplementation = new UniswapV3Pool();
        poolFactory = new UniswapV3Factory({
            _voter: voter,
            _poolImplementation: address(poolImplementation)
        });

        // deploy nft contracts
        nftDescriptor = new NonfungibleTokenPositionDescriptor({
            _WETH9: address(weth),
            _nativeCurrencyLabelBytes: bytes32("ETH")
        });
        nft = new NonfungiblePositionManager({
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor_: address(nftDescriptor)
        });

        // deploy gauges
        gaugeImplementation = new CLGauge();
        gaugeFactory = new CLGaugeFactory({
            _voter: voter,
            _implementation: address(gaugeImplementation),
            _nft: address(nft)
        });

        // set parameters on pool factory
        poolFactory.setGaugeFactoryAndNFT({_gaugeFactory: address(gaugeFactory), _nft: address(nft)});

        // deploy fee modules
        swapFeeModule = new CustomSwapFeeModule({
            _factory: address(poolFactory)
        });
        unstakedFeeModule = new CustomUnstakedFeeModule({
            _factory: address(poolFactory)
        });
        poolFactory.setSwapFeeModule({_swapFeeModule: address(swapFeeModule)});
        poolFactory.setUnstakedFeeModule({_unstakedFeeModule: address(unstakedFeeModule)});

        // transfer permissions
        poolFactory.setOwner(poolFactoryOwner);
        poolFactory.setSwapFeeManager(feeManager);
        poolFactory.setUnstakedFeeManager(feeManager);
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
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
