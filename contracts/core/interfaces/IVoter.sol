// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

interface IVoter {
    function gauges(address pool) external view returns (address);

    function createGauge(address _poolFactory, address _pool) external returns (address);
}
