// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./PoolAddress.sol";

/// @title Provides functions for deriving a gauge address from the factory, tokens, and the fee
library GaugeAddress {
    /// @notice Deterministically computes the gauge address given the factory, implementation and PoolKey
    /// @param factory The CL Gauge Factory contract address
    /// @param gaugeImplementation The Implementation being used to deploy Gauges
    /// @param key The PoolKey
    /// @return gauge The contract address of the V3 gauge
    function computeAddress(address factory, address gaugeImplementation, PoolAddress.PoolKey memory key)
        internal
        pure
        returns (address gauge)
    {
        require(key.token0 < key.token1);
        gauge = Clones.predictDeterministicAddress({
            master: gaugeImplementation,
            salt: keccak256(abi.encode(key.token0, key.token1, key.tickSpacing)),
            deployer: factory
        });
    }
}
