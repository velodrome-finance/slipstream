# Slipstream

This repository contains the smart contracts for the Slipstream Concentrated Liquidity contracts. It contains
the core concentrated liquidity contracts, adapted from UniswapV3's core contracts. It contains the higher level
periphery contracts, adapted from UniswapV3's periphery contracts. It also contains gauges designed to operate
within the Velodrome ecosystem.  

See `SPECIFICATION.md` and `CHANGELOG.md` for more information. 

## Installation

This repository is a hybrid hardhat and foundry repository.

Install hardhat dependencies with `yarn install`.
Install foundry dependencies with `forge install`.

Run hardhat tests with `yarn test`.
Run forge tests with `forge test`.

## Testing

### Invariants

To run the invariant tests, echidna must be installed. The following instructions require additional installations (e.g. of solc-select). 

```
echidna test/invariants/E2E_mint_burn.sol --config test/invariants/E2E_mint_burn.config.yaml --contract E2E_mint_burn
echidna test/invariants/E2E_swap.sol --config test/invariants/E2E_swap.config.yaml --contract E2E_swap
```

## Licensing

As this repository depends on the UniswapV3 `v3-core` and `v3-periphery` repository, the contracts in the 
`contracts/core` and  `contracts/periphery` folders are licensed under `GPL-2.0-or-later` or alternative 
licenses (as indicated in their SPDX headers).

Files in the `contracts/gauge` folder are licensed under the Business Source License 1.1 (`BUSL-1.1`).

## Bug Bounty
Velodrome has a live bug bounty hosted on ([Immunefi](https://immunefi.com/bounty/velodromefinance/)).

## Deployment

| Name               | Address                                                                                                                               |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------ |
| GaugeFactory               | [0x327147eE440252b893A771345025B41A267Ad985](https://optimistic.etherscan.io/address/0x327147eE440252b893A771345025B41A267Ad985#code) |
| GaugeImplementation               | [0x7155b84A704F0657975827c65Ff6fe42e3A962bb](https://optimistic.etherscan.io/address/0x7155b84A704F0657975827c65Ff6fe42e3A962bb#code) |
| MixedQuoter               | [0xFF79ec912bA114FD7989b9A2b90C65f0c1b44722](https://optimistic.etherscan.io/address/0xFF79ec912bA114FD7989b9A2b90C65f0c1b44722#code) |
| NonfungiblePositionManager               | [0x416b433906b1B72FA758e166e239c43d68dC6F29](https://optimistic.etherscan.io/address/0x416b433906b1B72FA758e166e239c43d68dC6F29#code) |
| NonfungibleTokenPositionDescriptor               | [0xccDf417f49a14bC2b23c71684de0304C56DEA165](https://optimistic.etherscan.io/address/0xccDf417f49a14bC2b23c71684de0304C56DEA165#code) |
| PoolFactory               | [0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F](https://optimistic.etherscan.io/address/0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F#code) |
| PoolImplementation               | [0xc28aD28853A547556780BEBF7847628501A3bCbb](https://optimistic.etherscan.io/address/0xc28aD28853A547556780BEBF7847628501A3bCbb#code) |
| QuoterV2               | [0x89D8218ed5fF1e46d8dcd33fb0bbeE3be1621466](https://optimistic.etherscan.io/address/0x89D8218ed5fF1e46d8dcd33fb0bbeE3be1621466#code) |
| CustomSwapFeeModule               | [0x7361E9079920fb75496E9764A2665d8ee5049D5f](https://optimistic.etherscan.io/address/0x7361E9079920fb75496E9764A2665d8ee5049D5f#code) |
| CustomUnstakedFeeModule               | [0xC565F7ba9c56b157Da983c4Db30e13F5f06C59D9](https://optimistic.etherscan.io/address/0xC565F7ba9c56b157Da983c4Db30e13F5f06C59D9#code) |
| Swap Router               | [0x0792a633F0c19c351081CF4B211F68F79bCc9676](http://optimistic.etherscan.io/address/0x0792a633F0c19c351081CF4B211F68F79bCc9676#code) |
| LpMigrator                | [0x3Fdb481B25b24824A2339a4A1AbD0B0BC7534e71](http://optimistic.etherscan.io/address/0x3Fdb481B25b24824A2339a4A1AbD0B0BC7534e71#code) |