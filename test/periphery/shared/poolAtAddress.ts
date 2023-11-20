import { Contract, Wallet } from 'ethers'
import { artifacts } from 'hardhat'
import { ICLPool } from '../../../typechain'

export default function poolAtAddress(address: string, wallet: Wallet): ICLPool {
  const abi = artifacts.readArtifactSync('CLPool').abi
  return new Contract(address, abi, wallet) as ICLPool
}
