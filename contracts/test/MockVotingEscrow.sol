// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import {IVotingEscrow} from "contracts/core/interfaces/IVotingEscrow.sol";

contract MockVotingEscrow is IVotingEscrow {
    address public immutable override team;

    constructor(address _team) {
        team = _team;
    }

    function createLock(uint256 _value, uint256 _lockDuration) external override returns (uint256) {
        return 0;
    }
}
