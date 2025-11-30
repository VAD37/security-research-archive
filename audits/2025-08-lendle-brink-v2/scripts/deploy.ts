import { ethers } from "hardhat";

async function main() {
  // TODO: add config file / strategies.ts update
  const asset = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"; // usdc
  const strategist = "0x83d47dcc9e5467f32a5e0e587335a11f773b887d"; // Sergii wallet
  const vaultManager = "0x62007a126BAb6BD6C3CC56896aa59080a3e55334"; // dev wallet
  const name = "Brink Base USDC";
  const symbol = "brinkBaseUSDC";
  const depositLimit = ethers.parseUnits("1000000", 6); // 1,000,000

  const BrinkVault = await ethers.getContractFactory("BrinkVault");
  const brink = await BrinkVault.deploy(
    asset,
    strategist,
    vaultManager,
    name,
    symbol,
    depositLimit,
  );
  await brink.waitForDeployment();

  const brinkAddress = await brink.getAddress();
  console.log("BrinkVault deployed to:", brinkAddress);

  const aaveReserve = "0xA238Dd80C259a72e81d7e4664a9801593F98d1c5";
  const morphoReserve = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb";
  const reserve1Id =
    "0xdb0bc9f10a174f29a345c5f30a719933f71ccea7a2a75a632a281929bba1b535"; // rETH
  const reserve2Id =
    "0x1c21c59df9db44bf6f645d854ee710a8ca17b479451447e9f56758aee10a2fad"; // cbETH
  const reserve3Id =
    "0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836"; // cbBTC

  const AaveStrategy = await ethers.getContractFactory("AaveStrategy");
  const aaveStrategy = await AaveStrategy.deploy(
    brinkAddress,
    asset,
    aaveReserve,
  );
  await aaveStrategy.waitForDeployment();

  console.log("AaveStrategy deployed to:", await aaveStrategy.getAddress());

  const MorphoStrategy = await ethers.getContractFactory("MorphoStrategy");
  const morphoStrategy1 = await MorphoStrategy.deploy(
    brinkAddress,
    asset,
    morphoReserve,
    reserve1Id,
  );
  await morphoStrategy1.waitForDeployment();

  console.log(
    "MorphoStrategy for rETH deployed to:",
    await morphoStrategy1.getAddress(),
  );

  const morphoStrategy2 = await MorphoStrategy.deploy(
    brinkAddress,
    asset,
    morphoReserve,
    reserve2Id,
  );
  await morphoStrategy2.waitForDeployment();

  console.log(
    "MorphoStrategy for cbETH deployed to:",
    await morphoStrategy2.getAddress(),
  );

  const morphoStrategy3 = await MorphoStrategy.deploy(
    brinkAddress,
    asset,
    morphoReserve,
    reserve3Id,
  );
  await morphoStrategy3.waitForDeployment();

  console.log(
    "MorphoStrategy for cbBTC deployed to:",
    await morphoStrategy3.getAddress(),
  );

  await brink.initialize(
    [aaveStrategy, morphoStrategy1, morphoStrategy2, morphoStrategy3],
    [3_000, 3_000, 2_000, 2_000],
  );

  console.log("BrinkVault initialized");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
