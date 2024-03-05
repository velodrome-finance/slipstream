// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
import {IUniswapV3Factory} from "script/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "script/interfaces/IUniswapV3Pool.sol";
import "forge-std/console2.sol";

contract DeployPools is Script {
    using stdJson for string;

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.rememberKey(deployPrivateKey);
    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public jsonConstants;
    string public jsonOutput;

    mapping(uint24 => int24) public feeToTickSpacing;
    IUniswapV3Factory public immutable v3Factory;

    CLFactory public factory;

    constructor() {
        // slipstream tick spacings
        feeToTickSpacing[100] = 1;
        // feeToTickSpacing[500] = 50; // duplicate
        feeToTickSpacing[500] = 100;
        feeToTickSpacing[3000] = 200;
        feeToTickSpacing[10_000] = 2_000;

        v3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    }

    function run() public {
        string memory root = vm.projectRoot();
        string memory basePath = concat(root, "/script/constants/");
        string memory path = concat(basePath, constantsFilename);

        // load in vars
        jsonConstants = vm.readFile(path);
        address[] memory tokenAs = abi.decode(jsonConstants.parseRaw(".tokenA"), (address[]));
        address[] memory tokenBs = abi.decode(jsonConstants.parseRaw(".tokenB"), (address[]));
        uint24[] memory fees = abi.decode(jsonConstants.parseRaw(".fees"), (uint24[]));

        path = concat(basePath, "output/DeployCL-");
        path = concat(path, constantsFilename);
        jsonOutput = vm.readFile(path);
        factory = CLFactory(abi.decode(jsonOutput.parseRaw(".PoolFactory"), (address)));

        vm.startBroadcast(deployerAddress);
        address pool;
        address newPool;
        for (uint256 i = 0; i < tokenAs.length; i++) {
            pool = v3Factory.getPool({tokenA: tokenAs[i], tokenB: tokenBs[i], fee: fees[i]});
            (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
            newPool = factory.createPool({
                tokenA: tokenAs[i],
                tokenB: tokenBs[i],
                tickSpacing: feeToTickSpacing[fees[i]],
                sqrtPriceX96: sqrtPriceX96
            });
            console2.log(newPool);
        }
        vm.stopBroadcast();
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
