import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import { MockTimeUniswapV3Pool } from '../../../typechain/MockTimeUniswapV3Pool'
import { CoreTestERC20 } from '../../../typechain/CoreTestERC20'
import { UniswapV3Factory } from '../../../typechain/UniswapV3Factory'
import { TestUniswapV3Callee } from '../../../typechain/TestUniswapV3Callee'
import { TestUniswapV3Router } from '../../../typechain/TestUniswapV3Router'
import { MockVoter } from '../../../typechain/MockVoter'
import { CLGaugeFactory } from '../../../typechain/CLGaugeFactory'
import { CLGauge } from '../../../typechain/CLGauge'

import { Fixture } from 'ethereum-waffle'

interface FactoryFixture {
  factory: UniswapV3Factory
}
interface TokensFixture {
  token0: CoreTestERC20
  token1: CoreTestERC20
  token2: CoreTestERC20
}

async function tokensFixture(): Promise<TokensFixture> {
  const tokenFactory = await ethers.getContractFactory('CoreTestERC20')
  const tokenA = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as CoreTestERC20
  const tokenB = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as CoreTestERC20
  const tokenC = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as CoreTestERC20

  const [token0, token1, token2] = [tokenA, tokenB, tokenC].sort((tokenA, tokenB) =>
    tokenA.address.toLowerCase() < tokenB.address.toLowerCase() ? -1 : 1
  )

  return { token0, token1, token2 }
}

type TokensAndFactoryFixture = FactoryFixture & TokensFixture

interface PoolFixture extends TokensAndFactoryFixture {
  swapTargetCallee: TestUniswapV3Callee
  swapTargetRouter: TestUniswapV3Router
  createPool(
    fee: number,
    tickSpacing: number,
    firstToken?: CoreTestERC20,
    secondToken?: CoreTestERC20
  ): Promise<MockTimeUniswapV3Pool>
}
// Monday, October 5, 2020 9:00:00 AM GMT-05:00
export const TEST_POOL_START_TIME = 1601906400

export const poolFixture: Fixture<PoolFixture> = async function (): Promise<PoolFixture> {
  const { token0, token1, token2 } = await tokensFixture()

  const MockTimeUniswapV3PoolDeployerFactory = await ethers.getContractFactory('UniswapV3Factory')
  const MockTimeUniswapV3PoolFactory = await ethers.getContractFactory('MockTimeUniswapV3Pool')
  const MockVoterFactory = await ethers.getContractFactory('MockVoter')
  const GaugeImplementationFactory = await ethers.getContractFactory('CLGauge')
  const GaugeFactoryFactory = await ethers.getContractFactory('CLGaugeFactory')

  // voter & gauge factory set up
  const mockVoter = (await MockVoterFactory.deploy(
    token2.address,
    '0x0000000000000000000000000000000000000000' // fees voting manager stub, unused in hardhat tests
  )) as MockVoter
  const gaugeImplementation = (await GaugeImplementationFactory.deploy()) as CLGauge
  const gaugeFactory = (await GaugeFactoryFactory.deploy(
    mockVoter.address,
    gaugeImplementation.address,
    '0x0000000000000000000000000000000000000000' // nft position manager stub, unused in hardhat tests
  )) as CLGaugeFactory
  await mockVoter.setGaugeFactory(gaugeFactory.address)

  const mockTimePool = (await MockTimeUniswapV3PoolFactory.deploy()) as MockTimeUniswapV3Pool
  const mockTimePoolDeployer = (await MockTimeUniswapV3PoolDeployerFactory.deploy(
    mockVoter.address,
    mockTimePool.address
  )) as UniswapV3Factory

  const calleeContractFactory = await ethers.getContractFactory('TestUniswapV3Callee')
  const routerContractFactory = await ethers.getContractFactory('TestUniswapV3Router')

  const swapTargetCallee = (await calleeContractFactory.deploy()) as TestUniswapV3Callee
  const swapTargetRouter = (await routerContractFactory.deploy()) as TestUniswapV3Router
  return {
    token0,
    token1,
    token2,
    factory: mockTimePoolDeployer,
    swapTargetCallee,
    swapTargetRouter,
    createPool: async (fee, tickSpacing, firstToken = token0, secondToken = token1) => {
      // add tick spacing if not already added, backwards compatible with uniswapv3 tests
      const tickSpacingFee = await mockTimePoolDeployer.tickSpacingToFee(tickSpacing)
      if (tickSpacingFee == 0) await mockTimePoolDeployer['enableTickSpacing(int24,uint24)'](tickSpacing, fee)
      const tx = await mockTimePoolDeployer.createPool(firstToken.address, secondToken.address, tickSpacing)
      const receipt = await tx.wait()
      const poolAddress = receipt.events?.[0].args?.pool as string
      const pool = MockTimeUniswapV3PoolFactory.attach(poolAddress) as MockTimeUniswapV3Pool
      await pool.advanceTime(TEST_POOL_START_TIME)
      return pool
    },
  }
}
