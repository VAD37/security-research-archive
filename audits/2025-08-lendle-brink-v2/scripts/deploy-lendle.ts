import { ethers } from "hardhat";
import { STRATEGY_PARAMS } from "../config/reserves";

async function main() {
  const assetName = "MNT";
  const strategyToDeploy = "LendleStrategy";
  const strategist = "0x83d47dcc9e5467f32a5e0e587335a11f773b887d"; // Sergii wallet
  const vaultManager = "0x62007a126BAb6BD6C3CC56896aa59080a3e55334"; // dev wallet

  const name = "Lendle ";
  const symbol = "lendle";
  const depositLimit = ethers.parseUnits("1000000", 18); // 1,000,000 with 18 decimals

  const assetParams = STRATEGY_PARAMS[assetName];
  if (!assetParams) {
    throw new Error(
      `Strategy parameters for asset ${assetName} are undefined.`,
    );
  }
  const asset = assetParams[0].asset;

  const BrinkVault = await ethers.getContractFactory("BrinkVault");
  const brink = await BrinkVault.deploy(
    asset,
    strategist,
    vaultManager,
    `${name}${assetName}`,
    `${symbol}${assetName}`,
    depositLimit,
  );
  await brink.waitForDeployment();

  const brinkAddress = await brink.getAddress();
  console.log("BrinkVault deployed to:", brinkAddress);

  const strategyFactory = await ethers.getContractFactory(strategyToDeploy);

  const strategies = [];
  for (const params of assetParams) {
    const strategy = await strategyFactory.deploy(
      brinkAddress,
      asset,
      params.reserve,
    );
    await strategy.waitForDeployment();
    console.log(
      `${strategyToDeploy}:`,
      await strategy.getAddress(),
    );
    strategies.push(await strategy.getAddress());
  }

  await brink.initialize(
    strategies,
    [6000, 4000], // TODO: fix weights to strategies 1:1
  );

  console.log("BrinkVault initialized");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
