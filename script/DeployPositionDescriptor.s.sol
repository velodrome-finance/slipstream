// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {NonfungibleTokenPositionDescriptor} from "contracts/periphery/NonfungibleTokenPositionDescriptor.sol";

contract DeployPositionDescriptor is Script {
    using stdJson for string;

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.rememberKey(deployPrivateKey);
    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public jsonConstants;

    address public weth;
    NonfungibleTokenPositionDescriptor public nftDescriptor;

    function run() public {
        string memory root = vm.projectRoot();
        string memory basePath = concat(root, "/script/constants/");
        string memory path = concat(basePath, constantsFilename);
        jsonConstants = vm.readFile(path);
        weth = abi.decode(vm.parseJson(jsonConstants, ".WETH"), (address));

        vm.startBroadcast(deployerAddress);
        nftDescriptor = new NonfungibleTokenPositionDescriptor({
            _WETH9: address(weth),
            _nativeCurrencyLabelBytes: 0x4554480000000000000000000000000000000000000000000000000000000000 // 'ETH' as bytes32 string
        });
        console2.log("Nonfungible Position Descriptor contract deployed at: ", address(nftDescriptor));
        vm.stopBroadcast();
    }

    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
}
