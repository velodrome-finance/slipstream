// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "../libraries/CallbackValidation.sol";

contract TestCallbackValidation {
    function verifyCallback(address factory, address tokenA, address tokenB, int24 tickSpacing)
        external
        view
        returns (ICLPool pool)
    {
        return CallbackValidation.verifyCallback(factory, tokenA, tokenB, tickSpacing);
    }
}
