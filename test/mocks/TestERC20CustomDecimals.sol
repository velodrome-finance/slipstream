// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20CustomDecimals is ERC20 {
    constructor(uint8 decimals) ERC20("Test ERC20", "TEST") {
        _setupDecimals(decimals);
    }
}
