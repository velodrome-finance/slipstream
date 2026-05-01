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

This project follows the [Apache Foundation](https://infra.apache.org/licensing-howto.html)
guideline for licensing. See LICENSE and NOTICE files.


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

## Gauges V2

| Name               | Address                                                                                                                               |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------ |
| DynamicSwapFeeModule               | [0xbf571c205f45d29a99a9B5f0485E131D7E943f1c](https://optimistic.etherscan.io/address/0xbf571c205f45d29a99a9B5f0485E131D7E943f1c#code) |
| GaugeFactory               | [0x9b23957290d8e4709fb1E1512EDc29E17C17DC99](https://optimistic.etherscan.io/address/0x9b23957290d8e4709fb1E1512EDc29E17C17DC99#code) |
| GaugeImplementation               | [0xb5f7bd1C65437F789b62CBE98eF16cd9f1fc4b26](https://optimistic.etherscan.io/address/0xb5f7bd1C65437F789b62CBE98eF16cd9f1fc4b26#code) |
| LpMigrator               | [0xeE03E08107755BC34412E78377B971ECc7153590](https://optimistic.etherscan.io/address/0xeE03E08107755BC34412E78377B971ECc7153590#code) |
| MixedQuoter               | [0x21fcc0C421Ae0a5F6919535EcF000688a0413b92](https://optimistic.etherscan.io/address/0x21fcc0C421Ae0a5F6919535EcF000688a0413b92#code) |
| MixedQuoterV2               | [0xE5Db7C27a2C3DAcC1678a080aA3B4cC75F36329C](https://optimistic.etherscan.io/address/0xE5Db7C27a2C3DAcC1678a080aA3B4cC75F36329C#code) |
| MixedQuoterV3               | [0xAf6EBdf4c70061C5961994Ae9c9956fBc2bCC32E](https://optimistic.etherscan.io/address/0xAf6EBdf4c70061C5961994Ae9c9956fBc2bCC32E#code) |
| NonfungiblePositionManager               | [0xf7f8ccce99Ca2896eC75D3A399D152dB96808399](https://optimistic.etherscan.io/address/0xf7f8ccce99Ca2896eC75D3A399D152dB96808399#code) |
| NonfungibleTokenPositionDescriptor               | [0xe5e47ac4b5389cf4A2df66315d57F4f62Ae80f9f](https://optimistic.etherscan.io/address/0xe5e47ac4b5389cf4A2df66315d57F4f62Ae80f9f#code) |
| PoolFactory               | [0xe13Dd1fbA721Aa81a1826D9523AC9BC7d260c879](https://optimistic.etherscan.io/address/0xe13Dd1fbA721Aa81a1826D9523AC9BC7d260c879#code) |
| PoolImplementation               | [0x11B234946F28A3905710922138C65FBbe7496b4C](https://optimistic.etherscan.io/address/0x11B234946F28A3905710922138C65FBbe7496b4C#code) |
| Quoter               | [0xAd432b2ca49965266133F2bd4c17dc1Ec12f5DEB](https://optimistic.etherscan.io/address/0xAd432b2ca49965266133F2bd4c17dc1Ec12f5DEB#code) |
| SwapRouter               | [0xbA3aEe516399388C779463183d00bB579f5041Ca](https://optimistic.etherscan.io/address/0xbA3aEe516399388C779463183d00bB579f5041Ca#code) |
| UnstakedFeeModule               | [0x2B2A6209f813b360E0D8a006c73477D56e7a7f16](https://optimistic.etherscan.io/address/0x2B2A6209f813b360E0D8a006c73477D56e7a7f16#code) |