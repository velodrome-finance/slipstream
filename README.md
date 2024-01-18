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
