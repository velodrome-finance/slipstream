// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

// Used to predict the address of a CL pool
contract Create2Address {
    function predictDeterministicAddress(address factory, bytes32 salt, address deployer)
        external
        pure
        returns (address)
    {
        return Clones.predictDeterministicAddress(factory, salt, deployer);
    }
}
