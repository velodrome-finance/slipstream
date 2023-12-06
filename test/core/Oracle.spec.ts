import { BigNumber, BigNumberish, Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { OracleTest } from '../../typechain/OracleTest'
import checkObservationEquals from './shared/checkObservationEquals'
import { expect } from './shared/expect'
import { TEST_POOL_START_TIME } from './shared/fixtures'
import snapshotGasCost from './shared/snapshotGasCost'
import { MaxUint128 } from './shared/utilities'

describe('Oracle', () => {
  let wallet: Wallet, other: Wallet

  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>
  before('create fixture loader', async () => {
    ;[wallet, other] = await (ethers as any).getSigners()
    loadFixture = waffle.createFixtureLoader([wallet, other])
  })

  const oracleFixture = async () => {
    const oracleTestFactory = await ethers.getContractFactory('OracleTest')
    return (await oracleTestFactory.deploy()) as OracleTest
  }

  const initializedOracleFixture = async () => {
    const oracle = await oracleFixture()
    await oracle.initialize({
      time: 0,
      tick: 0,
      liquidity: 0,
    })
    return oracle
  }

  describe('#initialize', () => {
    let oracle: OracleTest
    beforeEach('deploy test oracle', async () => {
      oracle = await loadFixture(oracleFixture)
    })
    it('index is 0', async () => {
      await oracle.initialize({ liquidity: 1, tick: 1, time: 1 })
      expect(await oracle.index()).to.eq(0)
    })
    it('cardinality is 1', async () => {
      await oracle.initialize({ liquidity: 1, tick: 1, time: 1 })
      expect(await oracle.cardinality()).to.eq(1)
    })
    it('cardinality next is 1', async () => {
      await oracle.initialize({ liquidity: 1, tick: 1, time: 1 })
      expect(await oracle.cardinalityNext()).to.eq(1)
    })
    it('sets first slot timestamp only', async () => {
      await oracle.initialize({ liquidity: 1, tick: 1, time: 1 })
      checkObservationEquals(await oracle.observations(0), {
        initialized: true,
        blockTimestamp: 1,
        tickCumulative: 0,
        secondsPerLiquidityCumulativeX128: 0,
      })
    })
    it('gas', async () => {
      await snapshotGasCost(oracle.initialize({ liquidity: 1, tick: 1, time: 1 }))
    })
  })

  describe('#grow', () => {
    let oracle: OracleTest
    beforeEach('deploy initialized test oracle', async () => {
      oracle = await loadFixture(initializedOracleFixture)
    })

    it('increases the cardinality next for the first call', async () => {
      await oracle.grow(5)
      expect(await oracle.index()).to.eq(0)
      expect(await oracle.cardinality()).to.eq(1)
      expect(await oracle.cardinalityNext()).to.eq(5)
    })

    it('does not touch the first slot', async () => {
      await oracle.grow(5)
      checkObservationEquals(await oracle.observations(0), {
        secondsPerLiquidityCumulativeX128: 0,
        tickCumulative: 0,
        blockTimestamp: 0,
        initialized: true,
      })
    })

    it('is no op if oracle is already gte that size', async () => {
      await oracle.grow(5)
      await oracle.grow(3)
      expect(await oracle.index()).to.eq(0)
      expect(await oracle.cardinality()).to.eq(1)
      expect(await oracle.cardinalityNext()).to.eq(5)
    })

    it('adds data to all the slots', async () => {
      await oracle.grow(5)
      for (let i = 1; i < 5; i++) {
        checkObservationEquals(await oracle.observations(i), {
          secondsPerLiquidityCumulativeX128: 0,
          tickCumulative: 0,
          blockTimestamp: 1,
          initialized: false,
        })
      }
    })

    it('grow after wrap', async () => {
      await oracle.grow(2)
      await oracle.update({ advanceTimeBy: 17, liquidity: 1, tick: 1 }) // index is now 1
      await oracle.update({ advanceTimeBy: 17, liquidity: 1, tick: 1 }) // index is now 0 again
      expect(await oracle.index()).to.eq(0)
      await oracle.grow(3)
      expect(await oracle.index()).to.eq(0)
      expect(await oracle.cardinality()).to.eq(2)
      expect(await oracle.cardinalityNext()).to.eq(3)
    })

    it('gas for growing by 1 slot when index == cardinality - 1', async () => {
      await snapshotGasCost(oracle.grow(2))
    })

    it('gas for growing by 10 slots when index == cardinality - 1', async () => {
      await snapshotGasCost(oracle.grow(11))
    })

    it('gas for growing by 1 slot when index != cardinality - 1', async () => {
      await oracle.grow(2)
      await snapshotGasCost(oracle.grow(3))
    })

    it('gas for growing by 10 slots when index != cardinality - 1', async () => {
      await oracle.grow(2)
      await snapshotGasCost(oracle.grow(12))
    })
  })

  describe('#write', () => {
    let oracle: OracleTest

    beforeEach('deploy initialized test oracle', async () => {
      oracle = await loadFixture(initializedOracleFixture)
    })

    it('single element array gets overwritten', async () => {
      await oracle.update({ advanceTimeBy: 15, tick: 2, liquidity: 5 })
      expect(await oracle.index()).to.eq(0)
      checkObservationEquals(await oracle.observations(0), {
        initialized: true,
        secondsPerLiquidityCumulativeX128: '5104235503814076951950619111476523171840',
        tickCumulative: 0,
        blockTimestamp: 15,
      })
      await oracle.update({ advanceTimeBy: 19, tick: -1, liquidity: 8 })
      expect(await oracle.index()).to.eq(0)
      checkObservationEquals(await oracle.observations(0), {
        initialized: true,
        secondsPerLiquidityCumulativeX128: '6397308498113643113111442619717242375372',
        tickCumulative: 38,
        blockTimestamp: 34,
      })
      await oracle.update({ advanceTimeBy: 17, tick: 2, liquidity: 3 })
      expect(await oracle.index()).to.eq(0)
      checkObservationEquals(await oracle.observations(0), {
        initialized: true,
        secondsPerLiquidityCumulativeX128: '7120408527820637347971113660509749824716',
        tickCumulative: 21,
        blockTimestamp: 51,
      })
    })

    it('does nothing if time has not changed', async () => {
      await oracle.grow(2)
      await oracle.update({ advanceTimeBy: 15, tick: 3, liquidity: 2 })
      expect(await oracle.index()).to.eq(1)
      await oracle.update({ advanceTimeBy: 0, tick: -5, liquidity: 9 })
      expect(await oracle.index()).to.eq(1)
    })

    it('does nothing if time has not been at least 15 seconds', async () => {
      await oracle.grow(2)
      await oracle.update({ advanceTimeBy: 15, tick: 3, liquidity: 2 })
      expect(await oracle.index()).to.eq(1)
      await oracle.update({ advanceTimeBy: 14, tick: -5, liquidity: 9 })
      expect(await oracle.index()).to.eq(1)
    })

    it('writes an index if time overflows u32 container', async () => {
      await oracle.grow(3)
      await oracle.update({ advanceTimeBy: 15, tick: 3, liquidity: 2 })
      expect(await oracle.index()).to.eq(1)
      // uint32.max: 4294967295, 4294967280 + 15 = uint32.max
      // this will hit uint32.max, in the observations.write() this will overflow
      await oracle.update({ advanceTimeBy: 4294967280, tick: -5, liquidity: 9 })
      expect(await oracle.index()).to.eq(2)
    })

    it('writes an index if time has increased by at least 15 seconds', async () => {
      await oracle.grow(3)
      await oracle.update({ advanceTimeBy: 15, tick: 3, liquidity: 2 })
      expect(await oracle.index()).to.eq(1)
      await oracle.update({ advanceTimeBy: 16, tick: -5, liquidity: 9 })

      expect(await oracle.index()).to.eq(2)
      checkObservationEquals(await oracle.observations(1), {
        tickCumulative: 0,
        secondsPerLiquidityCumulativeX128: '5104235503814076951950619111476523171840',
        initialized: true,
        blockTimestamp: 15,
      })
    })

    it('grows cardinality when writing past', async () => {
      await oracle.grow(2)
      await oracle.grow(4)
      expect(await oracle.cardinality()).to.eq(1)
      await oracle.update({ advanceTimeBy: 17, tick: 5, liquidity: 6 })
      expect(await oracle.cardinality()).to.eq(4)
      await oracle.update({ advanceTimeBy: 18, tick: 6, liquidity: 4 })
      expect(await oracle.cardinality()).to.eq(4)
      expect(await oracle.index()).to.eq(2)
      checkObservationEquals(await oracle.observations(2), {
        secondsPerLiquidityCumulativeX128: '6805647338418769269267492148635364229120',
        tickCumulative: 90,
        initialized: true,
        blockTimestamp: 35,
      })
    })

    it('wraps around', async () => {
      await oracle.grow(3)
      await oracle.update({ advanceTimeBy: 17, tick: 1, liquidity: 2 })
      await oracle.update({ advanceTimeBy: 18, tick: 2, liquidity: 3 })
      await oracle.update({ advanceTimeBy: 19, tick: 3, liquidity: 4 })

      expect(await oracle.index()).to.eq(0)

      checkObservationEquals(await oracle.observations(0), {
        secondsPerLiquidityCumulativeX128: '11002463197110343651982445640293838837077',
        tickCumulative: 56,
        initialized: true,
        blockTimestamp: 54,
      })
    })

    it('accumulates liquidity', async () => {
      await oracle.grow(4)

      await oracle.update({ advanceTimeBy: 17, tick: 3, liquidity: 2 })
      await oracle.update({ advanceTimeBy: 18, tick: -7, liquidity: 6 })
      await oracle.update({ advanceTimeBy: 19, tick: -2, liquidity: 4 })

      expect(await oracle.index()).to.eq(3)

      checkObservationEquals(await oracle.observations(1), {
        initialized: true,
        tickCumulative: 0,
        secondsPerLiquidityCumulativeX128: '5784800237655953878877368326340059594752',
        blockTimestamp: 17,
      })
      checkObservationEquals(await oracle.observations(2), {
        initialized: true,
        tickCumulative: 54,
        secondsPerLiquidityCumulativeX128: '8847341539944400050047739793225973497856',
        blockTimestamp: 35,
      })
      checkObservationEquals(await oracle.observations(3), {
        initialized: true,
        tickCumulative: -79,
        secondsPerLiquidityCumulativeX128: '9924902368527371851015092716759906167466',
        blockTimestamp: 54,
      })
      checkObservationEquals(await oracle.observations(4), {
        initialized: false,
        tickCumulative: 0,
        secondsPerLiquidityCumulativeX128: 0,
        blockTimestamp: 0,
      })
    })
  })

  describe('#observe', () => {
    describe('before initialization', async () => {
      let oracle: OracleTest
      beforeEach('deploy test oracle', async () => {
        oracle = await loadFixture(oracleFixture)
      })

      const observeSingle = async (secondsAgo: number) => {
        const {
          tickCumulatives: [tickCumulative],
          secondsPerLiquidityCumulativeX128s: [secondsPerLiquidityCumulativeX128],
        } = await oracle.observe([secondsAgo])
        return { secondsPerLiquidityCumulativeX128, tickCumulative }
      }

      it('fails before initialize', async () => {
        await expect(observeSingle(0)).to.be.revertedWith('I')
      })

      it('fails if an older observation does not exist', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        await expect(observeSingle(1)).to.be.revertedWith('OLD')
      })

      it('does not fail across overflow boundary', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 2 ** 32 - 1 })
        await oracle.advanceTime(2)
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(1)
        expect(tickCumulative).to.be.eq(2)
        expect(secondsPerLiquidityCumulativeX128).to.be.eq('85070591730234615865843651857942052864')
      })

      it('interpolates correctly at max liquidity', async () => {
        await oracle.initialize({ liquidity: MaxUint128, tick: 0, time: 0 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 27, tick: 0, liquidity: 0 })
        let { secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
        expect(secondsPerLiquidityCumulativeX128).to.eq(27)
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(6))
        expect(secondsPerLiquidityCumulativeX128).to.eq(21)
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(12))
        expect(secondsPerLiquidityCumulativeX128).to.eq(15)
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(27))
        expect(secondsPerLiquidityCumulativeX128).to.eq(0)
      })

      it('interpolates correctly at min liquidity', async () => {
        await oracle.initialize({ liquidity: 0, tick: 0, time: 0 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 27, tick: 0, liquidity: MaxUint128 })
        let { secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
        expect(secondsPerLiquidityCumulativeX128).to.eq(BigNumber.from(27).shl(128))
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(6))
        expect(secondsPerLiquidityCumulativeX128).to.eq(BigNumber.from(21).shl(128))
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(12))
        expect(secondsPerLiquidityCumulativeX128).to.eq(BigNumber.from(15).shl(128))
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(27))
        expect(secondsPerLiquidityCumulativeX128).to.eq(0)
      })

      it('interpolates the same as 0 liquidity for 1 liquidity', async () => {
        await oracle.initialize({ liquidity: 1, tick: 0, time: 0 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 27, tick: 0, liquidity: MaxUint128 })
        let { secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
        expect(secondsPerLiquidityCumulativeX128).to.eq(BigNumber.from(27).shl(128))
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(6))
        expect(secondsPerLiquidityCumulativeX128).to.eq(BigNumber.from(21).shl(128))
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(12))
        expect(secondsPerLiquidityCumulativeX128).to.eq(BigNumber.from(15).shl(128))
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(27))
        expect(secondsPerLiquidityCumulativeX128).to.eq(0)
      })

      it('interpolates correctly across uint32 seconds boundaries', async () => {
        // setup
        await oracle.initialize({ liquidity: 0, tick: 0, time: 0 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 2 ** 32 - 6, tick: 0, liquidity: 0 })
        let { secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
        expect(secondsPerLiquidityCumulativeX128).to.eq(BigNumber.from(2 ** 32 - 6).shl(128))
        await oracle.update({ advanceTimeBy: 27, tick: 0, liquidity: 0 })
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(0))
        expect(secondsPerLiquidityCumulativeX128).to.eq(BigNumber.from(21).shl(128))

        // interpolation checks
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(3))
        expect(secondsPerLiquidityCumulativeX128).to.eq(BigNumber.from(18).shl(128))
        ;({ secondsPerLiquidityCumulativeX128 } = await observeSingle(22))
        expect(secondsPerLiquidityCumulativeX128).to.eq(BigNumber.from(2 ** 32 - 1).shl(128))
      })

      it('single observation at current time', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
        expect(tickCumulative).to.eq(0)
        expect(secondsPerLiquidityCumulativeX128).to.eq(0)
      })

      it('single observation in past but not earlier than secondsAgo', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        await oracle.advanceTime(3)
        await expect(observeSingle(4)).to.be.revertedWith('OLD')
      })

      it('single observation in past at exactly seconds ago', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        await oracle.advanceTime(3)
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(3)
        expect(tickCumulative).to.eq(0)
        expect(secondsPerLiquidityCumulativeX128).to.eq(0)
      })

      it('single observation in past counterfactual in past', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        await oracle.advanceTime(3)
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(1)
        expect(tickCumulative).to.eq(4)
        expect(secondsPerLiquidityCumulativeX128).to.eq('170141183460469231731687303715884105728')
      })

      it('single observation in past counterfactual now', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        await oracle.advanceTime(3)
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
        expect(tickCumulative).to.eq(6)
        expect(secondsPerLiquidityCumulativeX128).to.eq('255211775190703847597530955573826158592')
      })

      it('two observations in chronological order 0 seconds ago exact', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 18, tick: 1, liquidity: 2 })
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
        expect(tickCumulative).to.eq(-90)
        expect(secondsPerLiquidityCumulativeX128).to.eq('1225016520915378468468148586754365561241')
      })

      it('two observations in chronological order 0 seconds ago counterfactual', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 18, tick: 1, liquidity: 2 })
        await oracle.advanceTime(7)
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
        expect(tickCumulative).to.eq(-83)
        expect(secondsPerLiquidityCumulativeX128).to.eq('2416004805138663090589959712765554301337')
      })

      it('two observations in chronological order seconds ago is exactly on first observation', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 18, tick: 1, liquidity: 2 })
        await oracle.advanceTime(7)
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(25)
        expect(tickCumulative).to.eq(0)
        expect(secondsPerLiquidityCumulativeX128).to.eq(0)
      })

      it('two observations in chronological order seconds ago is between first and second', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 18, tick: 1, liquidity: 2 })
        await oracle.advanceTime(7)
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(9)
        expect(tickCumulative).to.eq(-80)
        expect(secondsPerLiquidityCumulativeX128).to.eq('1088903574147003083082798743781658276658')
      })

      it('two observations in reverse order 0 seconds ago exact', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 18, tick: 1, liquidity: 2 })
        await oracle.update({ advanceTimeBy: 17, tick: -5, liquidity: 4 })
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
        expect(tickCumulative).to.eq(-73)
        expect(secondsPerLiquidityCumulativeX128).to.eq('4117416639743355407906832749924395358617')
      })

      it('two observations in reverse order 0 seconds ago counterfactual', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 18, tick: 1, liquidity: 2 })
        await oracle.update({ advanceTimeBy: 17, tick: -5, liquidity: 4 })
        await oracle.advanceTime(7)
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
        expect(tickCumulative).to.eq(-108)
        expect(secondsPerLiquidityCumulativeX128).to.eq('4712910781854997718967738312929989728665')
      })

      it('two observations in reverse order seconds ago is exactly on first observation', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 18, tick: 1, liquidity: 2 })
        await oracle.update({ advanceTimeBy: 17, tick: -5, liquidity: 4 })
        await oracle.advanceTime(7)
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(10)
        expect(tickCumulative).to.eq(-76)
        expect(secondsPerLiquidityCumulativeX128).to.eq('3606993089361947712711770838776743041433')
      })

      it('two observations in reverse order seconds ago is between first and second', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
        await oracle.update({ advanceTimeBy: 3, tick: -5, liquidity: 4 })
        await oracle.advanceTime(7)
        const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(9)
        expect(tickCumulative).to.eq(-25)
        expect(secondsPerLiquidityCumulativeX128).to.eq('425352958651173079329218259289710264320')
      })

      it('can fetch multiple observations', async () => {
        await oracle.initialize({ time: 5, tick: 2, liquidity: BigNumber.from(2).pow(15) })
        await oracle.grow(4)
        await oracle.update({ advanceTimeBy: 27, tick: 6, liquidity: BigNumber.from(2).pow(12) })
        await oracle.advanceTime(5)

        const { tickCumulatives, secondsPerLiquidityCumulativeX128s } = await oracle.observe([0, 3, 8, 13, 27, 32])
        expect(tickCumulatives).to.have.lengthOf(6)
        expect(tickCumulatives[0]).to.eq(84)
        expect(tickCumulatives[1]).to.eq(66)
        expect(tickCumulatives[2]).to.eq(48)
        expect(tickCumulatives[3]).to.eq(38)
        expect(tickCumulatives[4]).to.eq(10)
        expect(tickCumulatives[5]).to.eq(0)
        expect(secondsPerLiquidityCumulativeX128s).to.have.lengthOf(6)
        expect(secondsPerLiquidityCumulativeX128s[0]).to.eq('695767779043666902223086508115492864')
        expect(secondsPerLiquidityCumulativeX128s[1]).to.eq('446537529833995176053622684312928256')
        expect(secondsPerLiquidityCumulativeX128s[2]).to.eq('249230249209671726169463823802564608')
        expect(secondsPerLiquidityCumulativeX128s[3]).to.eq('197307280624323449884158860510363648')
        expect(secondsPerLiquidityCumulativeX128s[4]).to.eq('51922968585348276285304963292200960')
        expect(secondsPerLiquidityCumulativeX128s[5]).to.eq(0)
      })

      it('gas for observe since most recent', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.advanceTime(2)
        await snapshotGasCost(oracle.getGasCostOfObserve([1]))
      })

      it('gas for single observation at current time', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await snapshotGasCost(oracle.getGasCostOfObserve([0]))
      })

      it('gas for single observation at current time counterfactually computed', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.advanceTime(5)
        await snapshotGasCost(oracle.getGasCostOfObserve([0]))
      })
    })

    for (const startingTime of [5, 2 ** 32 - 5]) {
      describe(`initialized with 5 observations with starting time of ${startingTime}`, () => {
        const oracleFixture5Observations = async () => {
          const oracle = await oracleFixture()
          await oracle.initialize({ liquidity: 5, tick: -5, time: startingTime })
          await oracle.grow(5)
          await oracle.update({ advanceTimeBy: 17, tick: 1, liquidity: 2 })
          await oracle.update({ advanceTimeBy: 16, tick: -6, liquidity: 4 })
          await oracle.update({ advanceTimeBy: 19, tick: -2, liquidity: 4 })
          await oracle.update({ advanceTimeBy: 15, tick: -2, liquidity: 9 })
          await oracle.update({ advanceTimeBy: 17, tick: 4, liquidity: 2 })
          await oracle.update({ advanceTimeBy: 20, tick: 6, liquidity: 7 })
          return oracle
        }
        let oracle: OracleTest
        beforeEach('set up observations', async () => {
          oracle = await loadFixture(oracleFixture5Observations)
        })

        const observeSingle = async (secondsAgo: number) => {
          const {
            tickCumulatives: [tickCumulative],
            secondsPerLiquidityCumulativeX128s: [secondsPerLiquidityCumulativeX128],
          } = await oracle.observe([secondsAgo])
          return { secondsPerLiquidityCumulativeX128, tickCumulative }
        }

        it('index, cardinality, cardinality next', async () => {
          expect(await oracle.index()).to.eq(1)
          expect(await oracle.cardinality()).to.eq(5)
          expect(await oracle.cardinalityNext()).to.eq(5)
        })
        it('latest observation same time as latest', async () => {
          const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
          expect(tickCumulative).to.eq(-167)
          expect(secondsPerLiquidityCumulativeX128).to.eq('10817198352897832710763497242914320588617')
        })
        it('latest observation 20 seconds after latest', async () => {
          await oracle.advanceTime(20)
          const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(20)
          expect(tickCumulative).to.eq(-167)
          expect(secondsPerLiquidityCumulativeX128).to.eq('10817198352897832710763497242914320588617')
        })
        it('current observation 20 seconds after latest', async () => {
          await oracle.advanceTime(20)
          const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(0)
          expect(tickCumulative).to.eq(-47)
          expect(secondsPerLiquidityCumulativeX128).to.eq('11789433686957656892087424692719372621348')
        })
        it('between latest observation and just before latest observation at same time as latest', async () => {
          const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(3)
          expect(tickCumulative).to.eq(-179)
          expect(secondsPerLiquidityCumulativeX128).to.eq('10306774802516425015568435331766668271433')
        })
        it('between latest observation and just before latest observation after the latest observation', async () => {
          await oracle.advanceTime(20)
          const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(8)
          expect(tickCumulative).to.eq(-95)
          expect(secondsPerLiquidityCumulativeX128).to.eq('11400539553333727219557853712797351808255')
        })
        it('older than oldest reverts', async () => {
          await expect(observeSingle(105)).to.be.revertedWith('OLD')
          await oracle.advanceTime(5)
          await expect(observeSingle(110)).to.be.revertedWith('OLD')
        })
        it('oldest observation', async () => {
          const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(14)
          expect(tickCumulative).to.eq(-223)
          expect(secondsPerLiquidityCumulativeX128).to.eq('8435221784451263466519874990891943108425')
        })
        it('oldest observation after some time', async () => {
          await oracle.advanceTime(20)
          const { tickCumulative, secondsPerLiquidityCumulativeX128 } = await observeSingle(34)
          expect(tickCumulative).to.eq(-223)
          expect(secondsPerLiquidityCumulativeX128).to.eq('8435221784451263466519874990891943108425')
        })

        it('fetch many values', async () => {
          await oracle.advanceTime(20)
          const { tickCumulatives, secondsPerLiquidityCumulativeX128s } = await oracle.observe([
            20,
            17,
            13,
            10,
            5,
            1,
            0,
          ])
          expect({
            tickCumulatives: tickCumulatives.map((tc: any) => tc.toNumber()),
            secondsPerLiquidityCumulativeX128s: secondsPerLiquidityCumulativeX128s.map((lc: any) => lc.toString()),
          }).to.matchSnapshot()
        })

        it('gas all of last 20 seconds', async () => {
          await oracle.advanceTime(20)
          await snapshotGasCost(
            oracle.getGasCostOfObserve([20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0])
          )
        })

        it('gas latest equal', async () => {
          await snapshotGasCost(oracle.getGasCostOfObserve([0]))
        })
        it('gas latest transform', async () => {
          await oracle.advanceTime(19)
          await snapshotGasCost(oracle.getGasCostOfObserve([0]))
        })
        it('gas oldest', async () => {
          await snapshotGasCost(oracle.getGasCostOfObserve([14]))
        })
        it('gas between oldest and oldest + 1', async () => {
          await snapshotGasCost(oracle.getGasCostOfObserve([13]))
        })
        it('gas middle', async () => {
          await snapshotGasCost(oracle.getGasCostOfObserve([5]))
        })
      })
    }
  })

  describe.skip('full oracle', function () {
    this.timeout(1_200_000)

    let oracle: OracleTest

    const BATCH_SIZE = 300

    const STARTING_TIME = TEST_POOL_START_TIME

    const maxedOutOracleFixture = async () => {
      const oracle = await oracleFixture()
      await oracle.initialize({ liquidity: 0, tick: 0, time: STARTING_TIME })
      let cardinalityNext = await oracle.cardinalityNext()
      while (cardinalityNext < 65535) {
        const growTo = Math.min(65535, cardinalityNext + BATCH_SIZE)
        console.log('growing from', cardinalityNext, 'to', growTo)
        await oracle.grow(growTo)
        cardinalityNext = growTo
      }

      for (let i = 0; i < 65535; i += BATCH_SIZE) {
        console.log('batch update starting at', i)
        const batch = Array(BATCH_SIZE)
          .fill(null)
          .map((_, j) => ({
            advanceTimeBy: 17,
            tick: -i - j,
            liquidity: i + j,
          }))
        await oracle.batchUpdate(batch)
      }

      return oracle
    }

    beforeEach('create a full oracle', async () => {
      oracle = await loadFixture(maxedOutOracleFixture)
    })

    it('has max cardinality next', async () => {
      expect(await oracle.cardinalityNext()).to.eq(65535)
    })

    it('has max cardinality', async () => {
      expect(await oracle.cardinality()).to.eq(65535)
    })

    it('index wrapped around', async () => {
      expect(await oracle.index()).to.eq(165)
    })

    async function checkObserve(
      secondsAgo: number,
      expected?: { tickCumulative: BigNumberish; secondsPerLiquidityCumulativeX128: BigNumberish }
    ) {
      const { tickCumulatives, secondsPerLiquidityCumulativeX128s } = await oracle.observe([secondsAgo])
      const check = {
        tickCumulative: tickCumulatives[0].toString(),
        secondsPerLiquidityCumulativeX128: secondsPerLiquidityCumulativeX128s[0].toString(),
      }
      if (typeof expected === 'undefined') {
        expect(check).to.matchSnapshot()
      } else {
        expect(check).to.deep.eq({
          tickCumulative: expected.tickCumulative.toString(),
          secondsPerLiquidityCumulativeX128: expected.secondsPerLiquidityCumulativeX128.toString(),
        })
      }
    }

    it('can observe into the ordered portion with exact seconds ago', async () => {
      await checkObserve(100 * 17, {
        secondsPerLiquidityCumulativeX128: '79069679574669582764625968588458803398317',
        tickCumulative: '-36576887217',
      })
    })

    it('can observe into the ordered portion with unexact seconds ago', async () => {
      await checkObserve(100 * 17 + 5, {
        secondsPerLiquidityCumulativeX128: '79069653637722806876758696463195271600990',
        tickCumulative: '-36576559227',
      })
    })

    it('can observe at exactly the latest observation', async () => {
      await checkObserve(0, {
        secondsPerLiquidityCumulativeX128: '79078491354612917197387893183598633986685',
        tickCumulative: '-36688489667',
      })
    })

    it('can observe at exactly the latest observation after some time passes', async () => {
      await oracle.advanceTime(20)
      await checkObserve(5, {
        secondsPerLiquidityCumulativeX128: '79078569045833541774275698943490131216828',
        tickCumulative: '-36689475152',
      })
    })

    it('can observe after the latest observation counterfactual', async () => {
      await oracle.advanceTime(20)
      await checkObserve(3, {
        secondsPerLiquidityCumulativeX128: '79078579404662958384527406378142330847513',
        tickCumulative: '-36689606550',
      })
    })

    it('can observe into the unordered portion of array at exact seconds ago of observation', async () => {
      await checkObserve(200 * 17, {
        secondsPerLiquidityCumulativeX128: '79060854351575972569822251286913844738178',
        tickCumulative: '-36465454767',
      })
    })

    it('can observe into the unordered portion of array at seconds ago between observations', async () => {
      await checkObserve(200 * 17 + 5, {
        secondsPerLiquidityCumulativeX128: '79060828375029595509571292221399826617914',
        tickCumulative: '-36465127277',
      })
    })

    it('can observe the oldest observation 17*65534 seconds ago', async () => {
      await checkObserve(17 * 65534, {
        secondsPerLiquidityCumulativeX128: '44428004977301282912118530459922754996659',
        tickCumulative: '-230010',
      })
    })

    it('can observe the oldest observation 17*65534 + 5 seconds ago if time has elapsed', async () => {
      await oracle.advanceTime(5)
      await checkObserve(17 * 65534 + 5, {
        secondsPerLiquidityCumulativeX128: '44428004977301282912118530459922754996659',
        tickCumulative: '-230010',
      })
    })

    it('gas cost of observe(0)', async () => {
      await snapshotGasCost(oracle.getGasCostOfObserve([0]))
    })
    it('gas cost of observe(200 * 17)', async () => {
      await snapshotGasCost(oracle.getGasCostOfObserve([200 * 17]))
    })
    it('gas cost of observe(200 * 17 + 5)', async () => {
      await snapshotGasCost(oracle.getGasCostOfObserve([200 * 17 + 5]))
    })
    it('gas cost of observe(0) after 5 seconds', async () => {
      await oracle.advanceTime(5)
      await snapshotGasCost(oracle.getGasCostOfObserve([0]))
    })
    it('gas cost of observe(5) after 5 seconds', async () => {
      await oracle.advanceTime(5)
      await snapshotGasCost(oracle.getGasCostOfObserve([5]))
    })
    it('gas cost of observe(oldest)', async () => {
      await snapshotGasCost(oracle.getGasCostOfObserve([65534 * 17]))
    })
    it('gas cost of observe(oldest) after 5 seconds', async () => {
      await oracle.advanceTime(5)
      await snapshotGasCost(oracle.getGasCostOfObserve([65534 * 17 + 5]))
    })
  })
})
