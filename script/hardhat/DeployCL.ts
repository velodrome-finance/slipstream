import { Contract } from "@ethersproject/contracts";
import { ethers } from "hardhat";
import { Libraries } from "hardhat/types";
import { 
  UniswapV3Factory,
  UniswapV3Pool,
  NonfungibleTokenPositionDescriptor,
  NonfungiblePositionManager,
  CLGauge,
  CLGaugeFactory,
  CustomSwapFeeModule,
  CustomUnstakedFeeModule
} from "../../typechain";
import jsonConstants from "../constants/Optimism.json";

async function deployLibrary(
  typeName: string,
  ...args: any[]
): Promise<Contract> {
  const ctrFactory = await ethers.getContractFactory(typeName);

  const ctr = (await ctrFactory.deploy(...args)) as unknown as Contract;
  await ctr.deployed();
  return ctr;
}

async function deploy<Type>(
  typeName: string,
  libraries?: Libraries,
  ...args: any[]
): Promise<Type> {
  const ctrFactory = await ethers.getContractFactory(typeName, { libraries });

  const ctr = (await ctrFactory.deploy(...args)) as unknown as Type;
  await (ctr as unknown as Contract).deployed();
  return ctr;
}

async function main() {
  // deployment
  const poolImplementation = await deploy<UniswapV3Pool>("UniswapV3Pool");
  const poolFactory = await deploy<UniswapV3Factory>("UniswapV3Factory", undefined, jsonConstants.Voter, poolImplementation.address);

  const nftDescriptorLibrary = await deployLibrary("NFTDescriptor");
  const nftDescriptor = await deploy<NonfungibleTokenPositionDescriptor>("NonfungibleTokenPositionDescriptor", { NFTDescriptor: nftDescriptorLibrary.address }, jsonConstants.WETH, "0x4554480000000000000000000000000000000000000000000000000000000000");
  const nft = await deploy<NonfungiblePositionManager>("NonfungiblePositionManager", undefined, poolFactory.address, jsonConstants.WETH, nftDescriptor.address);

  const gaugeImplementation = await deploy<CLGauge>("CLGauge");
  const gaugeFactory = await deploy<CLGaugeFactory>("CLGaugeFactory", undefined, jsonConstants.Voter, gaugeImplementation.address, nft.address);

  await poolFactory.setGaugeFactoryAndNFT(gaugeFactory.address, nft.address);

  const swapFeeModule = await deploy<CustomSwapFeeModule>("CustomSwapFeeModule", undefined, poolFactory.address);
  const unstakedFeeModule = await deploy<CustomUnstakedFeeModule>("CustomUnstakedFeeModule", undefined, poolFactory.address);

  // permissions
  await poolFactory.setOwner(jsonConstants.poolFactoryOwner);
  await poolFactory.setSwapFeeManager(jsonConstants.feeManager);
  await poolFactory.setUnstakedFeeManager(jsonConstants.feeManager);
  
  console.log(`Pool Implementation deployed to: ${poolImplementation.address}`);
  console.log(`Pool Factory deployed to: ${poolFactory.address}`);
  console.log(`NFT Position Descriptor deployed to: ${nftDescriptor.address}`);
  console.log(`NFT deployed to: ${nft.address}`);
  console.log(`Gauge Implementation deployed to: ${gaugeImplementation.address}`);
  console.log(`Gauge Factory deployed to: ${gaugeFactory.address}`);
  console.log(`Swap Fee Module deployed to: ${swapFeeModule.address}`);
  console.log(`Unstaked Fee Module deployed to: ${unstakedFeeModule.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
  