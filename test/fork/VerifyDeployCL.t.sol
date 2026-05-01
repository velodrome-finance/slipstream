// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

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

/// @notice Post-deploy verification test for the CL system on Optimism.
///         Reads deployed addresses from script/constants/output/DeployCL-Optimism.json
///         and params from script/constants/Optimism.json, then verifies:
///         1. On-chain state/immutables match the declared params
///         2. Runtime bytecode matches a fresh local compilation (CBOR metadata stripped)
///
///         Run against the release commit used for deploy so users can reproduce verification.
contract VerifyDeployCLForkTest is Test {
    using stdJson for string;

    // ===== loaded deployed addresses =====
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

    // ===== loaded constants =====
    address public team;
    address public weth;
    address public voter;
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

    function setUp() public {
        vm.createSelectFork({urlOrAlias: "optimism"});

        string memory root = vm.projectRoot();

        // deployed addresses
        string memory outPath = concat(root, "/script/constants/output/DeployCL-Optimism.json");
        string memory outJson = vm.readFile(outPath);
        poolImplementation = CLPool(abi.decode(vm.parseJson(outJson, ".PoolImplementation"), (address)));
        poolFactory = CLFactory(abi.decode(vm.parseJson(outJson, ".PoolFactory"), (address)));
        nftDescriptor = NonfungibleTokenPositionDescriptor(
            abi.decode(vm.parseJson(outJson, ".NonfungibleTokenPositionDescriptor"), (address))
        );
        nft = NonfungiblePositionManager(
            payable(abi.decode(vm.parseJson(outJson, ".NonfungiblePositionManager"), (address)))
        );
        gaugeImplementation = CLGauge(payable(abi.decode(vm.parseJson(outJson, ".GaugeImplementation"), (address))));
        gaugeFactory = CLGaugeFactory(abi.decode(vm.parseJson(outJson, ".GaugeFactory"), (address)));
        swapFeeModule = DynamicSwapFeeModule(abi.decode(vm.parseJson(outJson, ".DynamicSwapFeeModule"), (address)));
        unstakedFeeModule = CustomUnstakedFeeModule(abi.decode(vm.parseJson(outJson, ".UnstakedFeeModule"), (address)));
        mixedQuoter = MixedRouteQuoterV1(abi.decode(vm.parseJson(outJson, ".MixedQuoter"), (address)));
        mixedQuoterV2 = MixedRouteQuoterV2(abi.decode(vm.parseJson(outJson, ".MixedQuoterV2"), (address)));
        mixedQuoterV3 = MixedRouteQuoterV3(abi.decode(vm.parseJson(outJson, ".MixedQuoterV3"), (address)));
        quoter = QuoterV2(abi.decode(vm.parseJson(outJson, ".Quoter"), (address)));
        swapRouter = SwapRouter(payable(abi.decode(vm.parseJson(outJson, ".SwapRouter"), (address))));
        lpMigrator = LpMigrator(abi.decode(vm.parseJson(outJson, ".LpMigrator"), (address)));

        // constants
        string memory constantsPath = concat(root, "/script/constants/Optimism.json");
        string memory c = vm.readFile(constantsPath);
        team = abi.decode(vm.parseJson(c, ".team"), (address));
        weth = abi.decode(vm.parseJson(c, ".WETH"), (address));
        voter = abi.decode(vm.parseJson(c, ".Voter"), (address));
        poolFactoryOwner = abi.decode(vm.parseJson(c, ".poolFactoryOwner"), (address));
        feeManager = abi.decode(vm.parseJson(c, ".feeManager"), (address));
        notifyAdmin = abi.decode(vm.parseJson(c, ".notifyAdmin"), (address));
        factoryV2 = abi.decode(vm.parseJson(c, ".factoryV2"), (address));
        legacyCLFactory = abi.decode(vm.parseJson(c, ".legacyCLFactory"), (address));
        legacyCLFactory2 = abi.decode(vm.parseJson(c, ".legacyCLFactory2"), (address));
        gaugeStakeManager = abi.decode(vm.parseJson(c, ".gaugeStakeManager"), (address));
        minStakeTime = abi.decode(vm.parseJson(c, ".minStakeTime"), (uint256));
        penaltyRate = abi.decode(vm.parseJson(c, ".penaltyRate"), (uint256));
        nftName = abi.decode(vm.parseJson(c, ".nftName"), (string));
        nftSymbol = abi.decode(vm.parseJson(c, ".nftSymbol"), (string));
    }

    // =========================================================================
    // State / immutable verification
    // =========================================================================

    function test_verifyPoolFactoryState() public {
        assertEq(address(poolFactory.voter()), voter, "voter");
        assertEq(address(poolFactory.poolImplementation()), address(poolImplementation), "poolImplementation");
        assertEq(poolFactory.owner(), poolFactoryOwner, "owner");
        assertEq(address(poolFactory.swapFeeModule()), address(swapFeeModule), "swapFeeModule");
        assertEq(poolFactory.swapFeeManager(), feeManager, "swapFeeManager");
        assertEq(address(poolFactory.unstakedFeeModule()), address(unstakedFeeModule), "unstakedFeeModule");
        assertEq(poolFactory.unstakedFeeManager(), feeManager, "unstakedFeeManager");
    }

    function test_verifyNftDescriptorState() public {
        assertEq(nftDescriptor.WETH9(), weth, "WETH9");
        assertEq(nftDescriptor.nativeCurrencyLabelBytes(), bytes32("ETH"), "nativeCurrencyLabelBytes");
    }

    function test_verifyNftState() public {
        assertEq(nft.factory(), address(poolFactory), "factory");
        assertEq(nft.WETH9(), weth, "WETH9");
        assertEq(nft.owner(), team, "owner");
        assertEq(nft.name(), nftName, "name");
        assertEq(nft.symbol(), nftSymbol, "symbol");
    }

    function test_verifyGaugeFactoryState() public {
        assertEq(gaugeFactory.voter(), voter, "voter");
        assertEq(gaugeFactory.implementation(), address(gaugeImplementation), "implementation");
        assertEq(gaugeFactory.nft(), address(nft), "nft");
        assertEq(gaugeFactory.notifyAdmin(), notifyAdmin, "notifyAdmin");
        assertEq(gaugeFactory.gaugeStakeManager(), gaugeStakeManager, "gaugeStakeManager");
        assertEq(gaugeFactory.defaultMinStakeTime(), minStakeTime, "defaultMinStakeTime");
        assertEq(gaugeFactory.penaltyRate(), penaltyRate, "penaltyRate");
    }

    function test_verifySwapFeeModuleState() public {
        assertEq(address(swapFeeModule.factory()), address(poolFactory), "factory");
    }

    function test_verifyUnstakedFeeModuleState() public {
        assertEq(address(unstakedFeeModule.factory()), address(poolFactory), "factory");
    }

    function test_verifyMixedQuoterState() public {
        assertEq(mixedQuoter.factory(), address(poolFactory), "factory");
        assertEq(mixedQuoter.factoryV2(), factoryV2, "factoryV2");
        assertEq(mixedQuoter.WETH9(), weth, "WETH9");
    }

    function test_verifyMixedQuoterV2State() public {
        assertEq(address(mixedQuoterV2.factory()), address(poolFactory), "factory");
        assertEq(address(mixedQuoterV2.factoryV2()), factoryV2, "factoryV2");
        assertEq(mixedQuoterV2.WETH9(), weth, "WETH9");
    }

    function test_verifyMixedQuoterV3State() public {
        assertEq(address(mixedQuoterV3.factory()), address(poolFactory), "factory");
        assertEq(mixedQuoterV3.factoryV2(), factoryV2, "factoryV2");
        assertEq(mixedQuoterV3.WETH9(), weth, "WETH9");
        assertEq(mixedQuoterV3.legacyCLFactory(), legacyCLFactory, "legacyCLFactory");
        assertEq(mixedQuoterV3.legacyCLFactory2(), legacyCLFactory2, "legacyCLFactory2");
    }

    function test_verifyQuoterState() public {
        assertEq(quoter.factory(), address(poolFactory), "factory");
        assertEq(quoter.WETH9(), weth, "WETH9");
    }

    function test_verifySwapRouterState() public {
        assertEq(swapRouter.factory(), address(poolFactory), "factory");
        assertEq(swapRouter.WETH9(), weth, "WETH9");
    }

    // =========================================================================
    // Bytecode verification
    // =========================================================================

    function _getCode(address _addr) internal view returns (bytes memory code) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        code = new bytes(size);
        assembly {
            extcodecopy(_addr, add(code, 0x20), 0, size)
        }
    }

    /// @dev Strip the CBOR-encoded metadata appended by solc.
    ///      Layout: <runtime bytecode><CBOR metadata><2-byte big-endian metadata length>.
    function _stripMetadata(bytes memory code) internal pure returns (bytes memory) {
        require(code.length >= 2, "code too short");
        uint256 metaLen = (uint256(uint8(code[code.length - 2])) << 8) | uint256(uint8(code[code.length - 1]));
        require(code.length >= metaLen + 2, "bad metadata length");
        uint256 codeLen = code.length - metaLen - 2;
        bytes memory stripped = new bytes(codeLen);
        for (uint256 i = 0; i < codeLen; i++) {
            stripped[i] = code[i];
        }
        return stripped;
    }

    function _assertBytecodeMatch(address _deployed, address _fresh, string memory _label) internal {
        bytes memory actual = _stripMetadata(_getCode(_deployed));
        bytes memory expected = _stripMetadata(_getCode(_fresh));
        assertEq(keccak256(actual), keccak256(expected), _label);
    }

    function test_verifyBytecode_PoolImplementation() public {
        CLPool fresh = new CLPool();
        _assertBytecodeMatch(address(poolImplementation), address(fresh), "CLPool");
    }

    function test_verifyBytecode_PoolFactory() public {
        // Non-immutable args (owner/fee managers) don't affect runtime bytecode;
        // pass any address. Immutable args (voter, poolImplementation) must match.
        CLFactory fresh = new CLFactory({
            _owner: address(this),
            _swapFeeManager: address(this),
            _unstakedFeeManager: address(this),
            _voter: voter,
            _poolImplementation: address(poolImplementation)
        });
        _assertBytecodeMatch(address(poolFactory), address(fresh), "CLFactory");
    }

    function test_verifyBytecode_Nft() public {
        NonfungiblePositionManager fresh = new NonfungiblePositionManager({
            _owner: team,
            _factory: address(poolFactory),
            _WETH9: weth,
            _tokenDescriptor: address(nftDescriptor),
            name: nftName,
            symbol: nftSymbol
        });
        _assertBytecodeMatch(address(nft), address(fresh), "NonfungiblePositionManager");
    }

    function test_verifyBytecode_GaugeImplementation() public {
        CLGauge fresh = new CLGauge();
        _assertBytecodeMatch(address(gaugeImplementation), address(fresh), "CLGauge");
    }

    function test_verifyBytecode_GaugeFactory() public {
        CLGaugeFactory fresh = new CLGaugeFactory({
            _notifyAdmin: notifyAdmin,
            _voter: voter,
            _nft: address(nft),
            _implementation: address(gaugeImplementation)
        });
        _assertBytecodeMatch(address(gaugeFactory), address(fresh), "CLGaugeFactory");
    }

    function test_verifyBytecode_SwapFeeModule() public {
        DynamicSwapFeeModule fresh = new DynamicSwapFeeModule({
            _factory: address(poolFactory),
            _defaultScalingFactor: 0,
            _defaultFeeCap: 30_000,
            _pools: new address[](0),
            _fees: new uint24[](0)
        });
        _assertBytecodeMatch(address(swapFeeModule), address(fresh), "DynamicSwapFeeModule");
    }

    function test_verifyBytecode_UnstakedFeeModule() public {
        CustomUnstakedFeeModule fresh = new CustomUnstakedFeeModule({_factory: address(poolFactory)});
        _assertBytecodeMatch(address(unstakedFeeModule), address(fresh), "CustomUnstakedFeeModule");
    }

    function test_verifyBytecode_MixedQuoter() public {
        MixedRouteQuoterV1 fresh =
            new MixedRouteQuoterV1({_factory: address(poolFactory), _factoryV2: factoryV2, _WETH9: weth});
        _assertBytecodeMatch(address(mixedQuoter), address(fresh), "MixedRouteQuoterV1");
    }

    function test_verifyBytecode_MixedQuoterV2() public {
        MixedRouteQuoterV2 fresh =
            new MixedRouteQuoterV2({_factory: address(poolFactory), _factoryV2: factoryV2, _WETH9: weth});
        _assertBytecodeMatch(address(mixedQuoterV2), address(fresh), "MixedRouteQuoterV2");
    }

    function test_verifyBytecode_MixedQuoterV3() public {
        MixedRouteQuoterV3 fresh = new MixedRouteQuoterV3({
            _factory: address(poolFactory),
            _legacyCLFactory: legacyCLFactory,
            _legacyCLFactory2: legacyCLFactory2,
            _factoryV2: factoryV2,
            _WETH9: weth
        });
        _assertBytecodeMatch(address(mixedQuoterV3), address(fresh), "MixedRouteQuoterV3");
    }

    function test_verifyBytecode_Quoter() public {
        QuoterV2 fresh = new QuoterV2({_factory: address(poolFactory), _WETH9: weth});
        _assertBytecodeMatch(address(quoter), address(fresh), "QuoterV2");
    }

    function test_verifyBytecode_SwapRouter() public {
        SwapRouter fresh = new SwapRouter({_factory: address(poolFactory), _WETH9: weth});
        _assertBytecodeMatch(address(swapRouter), address(fresh), "SwapRouter");
    }

    function test_verifyBytecode_LpMigrator() public {
        LpMigrator fresh = new LpMigrator();
        _assertBytecodeMatch(address(lpMigrator), address(fresh), "LpMigrator");
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
