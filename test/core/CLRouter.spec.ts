import { BigNumber, Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { CoreTestERC20 } from '../../typechain/CoreTestERC20'
import { CLFactory } from '../../typechain/CLFactory'
import { MockTimeCLPool } from '../../typechain/MockTimeCLPool'
import { expect } from './shared/expect'

import { poolFixture } from './shared/fixtures'

import {
  FeeAmount,
  TICK_SPACINGS,
  createPoolFunctions,
  PoolFunctions,
  createMultiPoolFunctions,
  encodePriceSqrt,
  getMinTick,
  getMaxTick,
  expandTo18Decimals,
} from './shared/utilities'
import { TestCLRouter } from '../../typechain/TestCLRouter'
import { TestCLCallee } from '../../typechain/TestCLCallee'

const feeAmount = FeeAmount.MEDIUM
const startingPrice = encodePriceSqrt(1, 1)
const tickSpacing = TICK_SPACINGS[feeAmount]

const createFixtureLoader = waffle.createFixtureLoader

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T

describe('CLPool', () => {
  let wallet: Wallet, other: Wallet

  let token0: CoreTestERC20
  let token1: CoreTestERC20
  let token2: CoreTestERC20
  let factory: CLFactory
  let pool0: MockTimeCLPool
  let pool1: MockTimeCLPool

  let pool0Functions: PoolFunctions
  let pool1Functions: PoolFunctions

  let minTick: number
  let maxTick: number

  let swapTargetCallee: TestCLCallee
  let swapTargetRouter: TestCLRouter

  let loadFixture: ReturnType<typeof createFixtureLoader>
  let createPool: ThenArg<ReturnType<typeof poolFixture>>['createPool']

  before('create fixture loader', async () => {
    ;[wallet, other] = await (ethers as any).getSigners()

    loadFixture = createFixtureLoader([wallet, other])
  })

  beforeEach('deploy first fixture', async () => {
    ;({ token0, token1, token2, factory, createPool, swapTargetCallee, swapTargetRouter } = await loadFixture(
      poolFixture
    ))

    const createPoolWrapped = async (
      amount: number,
      spacing: number,
      firstToken: CoreTestERC20,
      secondToken: CoreTestERC20,
      sqrtPriceX96: BigNumber
    ): Promise<[MockTimeCLPool, any]> => {
      const pool = await createPool(amount, spacing, firstToken, secondToken, sqrtPriceX96)
      const poolFunctions = createPoolFunctions({
        swapTarget: swapTargetCallee,
        token0: firstToken,
        token1: secondToken,
        pool,
      })
      minTick = getMinTick(spacing)
      maxTick = getMaxTick(spacing)
      return [pool, poolFunctions]
    }

    // default to the 30 bips pool
    ;[pool0, pool0Functions] = await createPoolWrapped(feeAmount, tickSpacing, token0, token1, startingPrice)
    ;[pool1, pool1Functions] = await createPoolWrapped(feeAmount, tickSpacing, token1, token2, startingPrice)
  })

  it('constructor initializes immutables', async () => {
    expect(await pool0.factory()).to.eq(factory.address)
    expect(await pool0.token0()).to.eq(token0.address)
    expect(await pool0.token1()).to.eq(token1.address)
    expect(await pool1.factory()).to.eq(factory.address)
    expect(await pool1.token0()).to.eq(token1.address)
    expect(await pool1.token1()).to.eq(token2.address)
  })

  describe('multi-swaps', () => {
    let inputToken: CoreTestERC20
    let outputToken: CoreTestERC20

    beforeEach('initialize both pools', async () => {
      inputToken = token0
      outputToken = token2

      await pool0Functions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
      await pool1Functions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
    })

    it('multi-swap', async () => {
      const token0OfPoolOutput = await pool1.token0()
      const ForExact0 = outputToken.address === token0OfPoolOutput

      const { swapForExact0Multi, swapForExact1Multi } = createMultiPoolFunctions({
        inputToken: token0,
        swapTarget: swapTargetRouter,
        poolInput: pool0,
        poolOutput: pool1,
      })

      const method = ForExact0 ? swapForExact0Multi : swapForExact1Multi

      await expect(method(100, wallet.address))
        .to.emit(outputToken, 'Transfer')
        .withArgs(pool1.address, wallet.address, 100)
        .to.emit(token1, 'Transfer')
        .withArgs(pool0.address, pool1.address, 102)
        .to.emit(inputToken, 'Transfer')
        .withArgs(wallet.address, pool0.address, 104)
    })
  })
})
