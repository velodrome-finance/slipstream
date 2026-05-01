pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import {DeployCL} from "script/DeployCL.s.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {DynamicSwapFeeModule} from "contracts/core/fees/DynamicSwapFeeModule.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";
import {MixedRouteQuoterV2} from "contracts/periphery/lens/MixedRouteQuoterV2.sol";

contract DeployCLForkTest is Test {
    using stdJson for string;

    DeployCL public deployCL;

    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    address public deployerAddress = 0x4994DacdB9C57A811aFfbF878D92E00EF2E5C4C2;
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
    MixedRouteQuoterV2 public mixedQuoterV2;

    function setUp() public {
        vm.createSelectFork({urlOrAlias: "optimism", blockNumber: 109241151});
        deployCL = new DeployCL();

        string memory root = vm.projectRoot();
        string memory path = concat(root, "/script/constants/");
        path = concat(path, constantsFilename);
        jsonConstants = vm.readFile(path);

        team = abi.decode(vm.parseJson(jsonConstants, ".team"), (address));
        weth = abi.decode(vm.parseJson(jsonConstants, ".WETH"), (address));
        voter = abi.decode(vm.parseJson(jsonConstants, ".Voter"), (address));
        factoryRegistry = abi.decode(vm.parseJson(jsonConstants, ".FactoryRegistry"), (address));
        factoryV2 = abi.decode(vm.parseJson(jsonConstants, ".factoryV2"), (address));
        poolFactoryOwner = abi.decode(vm.parseJson(jsonConstants, ".poolFactoryOwner"), (address));
        feeManager = abi.decode(vm.parseJson(jsonConstants, ".feeManager"), (address));
        notifyAdmin = abi.decode(vm.parseJson(jsonConstants, ".notifyAdmin"), (address));
        gaugeStakeManager = abi.decode(vm.parseJson(jsonConstants, ".gaugeStakeManager"), (address));
        minStakeTime = abi.decode(vm.parseJson(jsonConstants, ".minStakeTime"), (uint256));
        penaltyRate = abi.decode(vm.parseJson(jsonConstants, ".penaltyRate"), (uint256));
        nftName = abi.decode(vm.parseJson(jsonConstants, ".nftName"), (string));
        nftSymbol = abi.decode(vm.parseJson(jsonConstants, ".nftSymbol"), (string));

        deal(address(deployerAddress), 10 ether);
    }

    function test_deployCL() public {
        deployCL.run();

        // preload variables for convenience
        poolImplementation = deployCL.poolImplementation();
        poolFactory = deployCL.poolFactory();
        nftDescriptor = deployCL.nftDescriptor();
        nft = deployCL.nft();
        gaugeImplementation = deployCL.gaugeImplementation();
        gaugeFactory = deployCL.gaugeFactory();
        swapFeeModule = deployCL.swapFeeModule();
        unstakedFeeModule = deployCL.unstakedFeeModule();
        mixedQuoterV2 = deployCL.mixedQuoterV2();

        assertTrue(address(poolImplementation) != address(0));
        assertTrue(address(poolFactory) != address(0));
        assertEq(address(poolFactory.voter()), voter);
        assertEq(address(poolFactory.poolImplementation()), address(poolImplementation));
        assertEq(address(poolFactory.factoryRegistry()), address(factoryRegistry));
        assertEq(address(poolFactory.owner()), poolFactoryOwner);
        assertEq(address(poolFactory.swapFeeModule()), address(swapFeeModule));
        assertEq(address(poolFactory.swapFeeManager()), feeManager);
        assertEq(address(poolFactory.unstakedFeeModule()), address(unstakedFeeModule));
        assertEq(address(poolFactory.unstakedFeeManager()), feeManager);
        assertEqUint(poolFactory.defaultUnstakedFee(), 100_000);
        assertEqUint(poolFactory.tickSpacingToFee(1), 100);
        assertEqUint(poolFactory.tickSpacingToFee(50), 500);
        assertEqUint(poolFactory.tickSpacingToFee(100), 500);
        assertEqUint(poolFactory.tickSpacingToFee(200), 3_000);
        assertEqUint(poolFactory.tickSpacingToFee(2_000), 10_000);

        assertTrue(address(nftDescriptor) != address(0));
        assertEq(nftDescriptor.WETH9(), weth);
        assertEq(nftDescriptor.nativeCurrencyLabelBytes(), bytes32("ETH"));

        assertTrue(address(nft) != address(0));
        assertEq(nft.factory(), address(poolFactory));
        assertEq(nft.WETH9(), weth);
        assertEq(nft.owner(), team);
        assertEq(nft.name(), nftName);
        assertEq(nft.symbol(), nftSymbol);

        assertTrue(address(gaugeImplementation) != address(0));
        assertTrue(address(gaugeFactory) != address(0));
        assertEq(gaugeFactory.voter(), voter);
        assertEq(gaugeFactory.implementation(), address(gaugeImplementation));
        assertEq(gaugeFactory.nft(), address(nft));
        assertEq(gaugeFactory.notifyAdmin(), notifyAdmin);
        assertEq(gaugeFactory.gaugeStakeManager(), gaugeStakeManager);
        assertEq(gaugeFactory.defaultMinStakeTime(), minStakeTime);
        assertEq(gaugeFactory.penaltyRate(), penaltyRate);
        assertTrue(gaugeFactory.gaugeStakeManager() != address(deployCL.deployerAddress()));

        assertTrue(address(swapFeeModule) != address(0));
        assertEq(swapFeeModule.MAX_BASE_FEE(), 30_000); // 3%, using pip denomination
        assertEq(address(swapFeeModule.factory()), address(poolFactory));

        assertTrue(address(unstakedFeeModule) != address(0));
        assertEq(unstakedFeeModule.MAX_FEE(), 500_000); // 50%, using pip denomination
        assertEq(address(unstakedFeeModule.factory()), address(poolFactory));

        // Check MixedRouteQuoterV2
        assertTrue(address(mixedQuoterV2) != address(0));
        assertEq(address(mixedQuoterV2.factory()), address(poolFactory));
        assertEq(address(mixedQuoterV2.factoryV2()), factoryV2);
        assertEq(mixedQuoterV2.WETH9(), weth);
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
