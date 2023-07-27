import { Contract, Wallet } from 'ethers'
import { artifacts } from 'hardhat'
import { IUniswapV3Pool } from '../../../typechain'

export default function poolAtAddress(address: string, wallet: Wallet): IUniswapV3Pool {
  const abi = artifacts.readArtifactSync('UniswapV3Pool').abi
  return new Contract(address, abi, wallet) as IUniswapV3Pool
}
