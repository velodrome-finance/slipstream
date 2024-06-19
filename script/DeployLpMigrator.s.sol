// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";
import {LpMigrator} from "contracts/periphery/LpMigrator.sol";
import "forge-std/console2.sol";

contract DeployLpMigrator is Script {
    using stdJson for string;

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.rememberKey(deployPrivateKey);

    LpMigrator public lpMigrator;

    function run() public {
        vm.startBroadcast(deployerAddress);
        lpMigrator = new LpMigrator();
        console2.log("LpMigrator deployed to: ", address(lpMigrator));
        vm.stopBroadcast();
    }
}
