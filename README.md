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
| GaugeFactory               | [0x5A41a5b04e9e7cca874BDB7BA51Cff4815C289DE](https://optimistic.etherscan.io/address/0x5A41a5b04e9e7cca874BDB7BA51Cff4815C289DE#code) |
| GaugeImplementation               | [0xC9b828518a8b96fDE860F014C1B400F868AF648e](https://optimistic.etherscan.io/address/0xC9b828518a8b96fDE860F014C1B400F868AF648e#code) |
| MixedQuoter               | [0xFAA0A0C8bA31f79dc621f0d6b10F95589a4301f2](https://optimistic.etherscan.io/address/0xFAA0A0C8bA31f79dc621f0d6b10F95589a4301f2#code) |
| NonfungiblePositionManager               | [0x1D5951dFCD9D7F830a9aed6d127bBeB9F69df276](https://optimistic.etherscan.io/address/0x1D5951dFCD9D7F830a9aed6d127bBeB9F69df276#code) |
| NonfungibleTokenPositionDescriptor               | [0x0452DfdF6E6fa85E53d476434dF634b4Fd02e3C7](https://optimistic.etherscan.io/address/0x0452DfdF6E6fa85E53d476434dF634b4Fd02e3C7#code) |
| PoolFactory               | [0x61F42C56555391903dA28D35aFf8eE1362f1cdDE](https://optimistic.etherscan.io/address/0x61F42C56555391903dA28D35aFf8eE1362f1cdDE#code) |
| PoolImplementation               | [0x301E46346D39AAa66d372CB40f870510C8943a1b](https://optimistic.etherscan.io/address/0x301E46346D39AAa66d372CB40f870510C8943a1b#code) |
| QuoterV2               | [0x53cA9c0BA922390Ac64935e9E14F880D4e2611E3](https://optimistic.etherscan.io/address/0x53cA9c0BA922390Ac64935e9E14F880D4e2611E3#code) |
| CustomSwapFeeModule               | [0xa90991c28550aF1ae8d4F03cB9856CAffa3AEA73](https://optimistic.etherscan.io/address/0xa90991c28550aF1ae8d4F03cB9856CAffa3AEA73#code) |
| CustomUnstakedFeeModule               | [0xe07eaAcb21f26efE4C64314ceb6258D517eCeD54](https://optimistic.etherscan.io/address/0xe07eaAcb21f26efE4C64314ceb6258D517eCeD54#code) |
| SugarHelper               | [0x4d57877265e2565F525591BEa9D260cAF074DC40](https://optimistic.etherscan.io/address/0x4d57877265e2565F525591BEa9D260cAF074DC40#code) |