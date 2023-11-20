import { Fixture } from 'ethereum-waffle'
import { v3RouterFixture } from './externalFixtures'
import {
  IWETH9,
  MockTimeNonfungiblePositionManager,
  MockTimeSwapRouter,
  NonfungibleTokenPositionDescriptor,
  TestERC20,
  ICLFactory,
} from '../../../typechain'

const completeFixture: Fixture<{
  weth9: IWETH9
  factory: ICLFactory
  router: MockTimeSwapRouter
  nft: MockTimeNonfungiblePositionManager
  nftDescriptor: NonfungibleTokenPositionDescriptor
  tokens: [TestERC20, TestERC20, TestERC20]
}> = async ([wallet], provider) => {
  const { factory, weth9, router, nft, tokens, nftDescriptor } = await v3RouterFixture([wallet], provider)

  return {
    weth9,
    factory,
    router,
    tokens,
    nft,
    nftDescriptor,
  }
}

export default completeFixture
