pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

import {DeployCL} from "script/DeployCL.s.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {UniswapV3Factory} from "contracts/core/UniswapV3Factory.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";

contract DeployCLTest is Test {
    using stdJson for string;

    DeployCL public deployCL;

    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.rememberKey(deployPrivateKey);
    string public jsonConstants;

    // loaded variables
    address public team;
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

    function setUp() public {
        deployCL = new DeployCL();

        string memory root = vm.projectRoot();
        string memory path = concat(root, "/script/constants/");
        path = concat(path, constantsFilename);
        jsonConstants = vm.readFile(path);

        team = abi.decode(vm.parseJson(jsonConstants, ".team"), (address));
        weth = abi.decode(vm.parseJson(jsonConstants, ".WETH"), (address));
        voter = abi.decode(vm.parseJson(jsonConstants, ".Voter"), (address));
        factoryRegistry = abi.decode(vm.parseJson(jsonConstants, ".FactoryRegistry"), (address));
        poolFactoryOwner = abi.decode(vm.parseJson(jsonConstants, ".poolFactoryOwner"), (address));
        feeManager = abi.decode(vm.parseJson(jsonConstants, ".feeManager"), (address));

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

        assertTrue(address(poolImplementation) != address(0));
        assertTrue(address(poolFactory) != address(0));
        assertEq(address(poolFactory.voter()), voter);
        assertEq(address(poolFactory.poolImplementation()), address(poolImplementation));
        assertEq(address(poolFactory.owner()), poolFactoryOwner);
        assertEq(address(poolFactory.swapFeeModule()), address(swapFeeModule));
        assertEq(address(poolFactory.swapFeeManager()), feeManager);
        assertEq(address(poolFactory.unstakedFeeModule()), address(unstakedFeeModule));
        assertEq(address(poolFactory.unstakedFeeManager()), feeManager);
        assertEq(address(poolFactory.nft()), address(nft));
        assertEq(address(poolFactory.gaugeFactory()), address(gaugeFactory));
        assertEq(address(poolFactory.gaugeImplementation()), address(gaugeImplementation));
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

        assertTrue(address(gaugeImplementation) != address(0));
        assertTrue(address(gaugeFactory) != address(0));
        assertEq(gaugeFactory.voter(), voter);
        assertEq(gaugeFactory.implementation(), address(gaugeImplementation));
        assertEq(gaugeFactory.nft(), address(nft));

        assertTrue(address(swapFeeModule) != address(0));
        assertEq(swapFeeModule.MAX_FEE(), 30_000); // 3%, using pip denomination
        assertEq(address(swapFeeModule.factory()), address(poolFactory));

        assertTrue(address(unstakedFeeModule) != address(0));
        assertEq(unstakedFeeModule.MAX_FEE(), 200_000); // 20%, using pip denomination
        assertEq(address(unstakedFeeModule.factory()), address(poolFactory));
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
