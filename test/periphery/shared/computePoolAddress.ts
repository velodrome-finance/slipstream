import { utils } from 'ethers'
import { ethers } from 'hardhat'

export async function computePoolAddress(
  factoryAddress: string,
  [tokenA, tokenB]: [string, string],
  tickSpacing: number
): Promise<string> {
  const [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() ? [tokenA, tokenB] : [tokenB, tokenA]
  const constructorArgumentsEncoded = utils.defaultAbiCoder.encode(
    ['address', 'address', 'int24'],
    [token0, token1, tickSpacing]
  )
  const poolFactory = await ethers.getContractAt('CLFactory', factoryAddress)
  const implementationAddress = (await poolFactory.poolImplementation()).toString()
  const initCode = `0x3d602d80600a3d3981f3363d3d373d3d3d363d73${implementationAddress.replace(
    '0x',
    ''
  )}5af43d82803e903d91602b57fd5bf3`
  const initCodeHash = utils.keccak256(initCode)

  const create2Inputs = [
    '0xff',
    factoryAddress,
    // salt
    utils.keccak256(constructorArgumentsEncoded),
    // init code hash
    initCodeHash,
  ]
  const sanitizedInputs = `0x${create2Inputs.map((i) => i.slice(2)).join('')}`
  return utils.getAddress(`0x${utils.keccak256(sanitizedInputs).slice(-40)}`)
}
