// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {SugarHelper} from "contracts/periphery/SugarHelper.sol";

contract DeploySugarHelper is Script {
    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.rememberKey(deployPrivateKey);

    SugarHelper public sugarHelper;

    function run() public {
        vm.startBroadcast(deployerAddress);
        sugarHelper = new SugarHelper();
        console2.log("Sugar Helper contract deployed at: ", address(sugarHelper));
        vm.stopBroadcast();
    }
}
