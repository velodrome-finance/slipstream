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
| GaugeFactory               | [0x282AC0eA96493650F1A5E5e5d20490C782F1592a](https://optimistic.etherscan.io/address/0x282AC0eA96493650F1A5E5e5d20490C782F1592a#code) |
| GaugeImplementation               | [0x6D600CC5F14B81665606Ca1985605464BA332Bad](https://optimistic.etherscan.io/address/0x6D600CC5F14B81665606Ca1985605464BA332Bad#code) |
| MixedQuoter               | [0xa4ac92a0F54f1a447c55a4082c90742F5E76Df62](https://optimistic.etherscan.io/address/0xa4ac92a0F54f1a447c55a4082c90742F5E76Df62#code) |
| NonfungiblePositionManager               | [0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4](https://optimistic.etherscan.io/address/0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4#code) |
| NonfungibleTokenPositionDescriptor               | [0x2c998811b2Af32416C8ff4c0ea85f0e7Ed834ff8](https://optimistic.etherscan.io/address/0x2c998811b2Af32416C8ff4c0ea85f0e7Ed834ff8#code) |
| PoolFactory               | [0x548118C7E0B865C2CfA94D15EC86B666468ac758](https://optimistic.etherscan.io/address/0x548118C7E0B865C2CfA94D15EC86B666468ac758#code) |
| PoolImplementation               | [0xE0A596c403E854FFb9C828aB4f07eEae04A05D37](https://optimistic.etherscan.io/address/0xE0A596c403E854FFb9C828aB4f07eEae04A05D37#code) |
| QuoterV2               | [0xA2DEcF05c16537C702779083Fe067e308463CE45](https://optimistic.etherscan.io/address/0xA2DEcF05c16537C702779083Fe067e308463CE45#code) |
| CustomSwapFeeModule               | [0xA9c319945f706dd1809819321a2e31C9A169e9c1](https://optimistic.etherscan.io/address/0xA9c319945f706dd1809819321a2e31C9A169e9c1#code) |
| CustomUnstakedFeeModule               | [0x5A993209065ea74b50E23a378ddB7068189345D0](https://optimistic.etherscan.io/address/0x5A993209065ea74b50E23a378ddB7068189345D0#code) |
| LpMigrator                | [0x3Fdb481B25b24824A2339a4A1AbD0B0BC7534e71](http://optimistic.etherscan.io/address/0x3Fdb481B25b24824A2339a4A1AbD0B0BC7534e71#code) |