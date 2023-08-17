import { Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { UniswapV3Factory } from '../../typechain/UniswapV3Factory'
import { Create2Address } from '../../typechain/Create2Address'
import { expect } from './shared/expect'
import { MockVoter } from '../../typechain/MockVoter'
import { CLGaugeFactory } from '../../typechain/CLGaugeFactory'
import { CLGauge } from '../../typechain/CLGauge'
import { TestERC20 } from '../../typechain/TestERC20'
import { constants } from 'ethers'

const createFixtureLoader = waffle.createFixtureLoader

describe('UniswapV3Factory', () => {
  let wallet: Wallet, other: Wallet

  let factory: UniswapV3Factory
  let create2Address: Create2Address
  const fixture = async () => {
    const poolFactory = await ethers.getContractFactory('UniswapV3Pool')
    const poolImplementation = await poolFactory.deploy()
    const factoryFactory = await ethers.getContractFactory('UniswapV3Factory')

    const MockVoterFactory = await ethers.getContractFactory('MockVoter')
    const GaugeImplementationFactory = await ethers.getContractFactory('CLGauge')
    const GaugeFactoryFactory = await ethers.getContractFactory('CLGaugeFactory')

    // voter & gauge factory set up
    const tokenFactory = await ethers.getContractFactory('TestERC20')
    const rewardToken: TestERC20 = (await tokenFactory.deploy(constants.MaxUint256.div(2))) as TestERC20 // do not use maxu256 to avoid overflowing
    const mockVoter = (await MockVoterFactory.deploy(rewardToken.address)) as MockVoter
    const gaugeImplementation = (await GaugeImplementationFactory.deploy()) as CLGauge
    const gaugeFactory = (await GaugeFactoryFactory.deploy(
      mockVoter.address,
      gaugeImplementation.address,
      '0x0000000000000000000000000000000000000000' // nft position manager stub, unused in hardhat tests
    )) as CLGaugeFactory
    await mockVoter.setGaugeFactory(gaugeFactory.address)

    return (await factoryFactory.deploy(mockVoter.address, poolImplementation.address)) as UniswapV3Factory
  }

  let loadFixture: ReturnType<typeof createFixtureLoader>
  before('create fixture loader', async () => {
    ;[wallet, other] = await (ethers as any).getSigners()

    loadFixture = createFixtureLoader([wallet, other])
    const create2AddressFactory = await ethers.getContractFactory('Create2Address')
    create2Address = (await create2AddressFactory.deploy()) as Create2Address
  })

  beforeEach('deploy factory', async () => {
    factory = await loadFixture(fixture)
  })

  it('owner is deployer', async () => {
    expect(await factory.owner()).to.eq(wallet.address)
  })

  describe('#setOwner', () => {
    it('fails if caller is not owner', async () => {
      await expect(factory.connect(other).setOwner(wallet.address)).to.be.reverted
    })

    it('updates owner', async () => {
      await factory.setOwner(other.address)
      expect(await factory.owner()).to.eq(other.address)
    })

    it('emits event', async () => {
      await expect(factory.setOwner(other.address))
        .to.emit(factory, 'OwnerChanged')
        .withArgs(wallet.address, other.address)
    })

    it('cannot be called by original owner', async () => {
      await factory.setOwner(other.address)
      await expect(factory.setOwner(wallet.address)).to.be.reverted
    })
  })
})
