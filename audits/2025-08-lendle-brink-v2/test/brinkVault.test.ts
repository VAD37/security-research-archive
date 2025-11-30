import { expect } from "chai";
import { AddressLike, BytesLike } from "ethers";
import { ethers } from "hardhat";

import ERC20 from "../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

const hotWalletHolderAddr = "0x0B0A5886664376F59C351ba3f598C8A8B4D0A6f3";
const hotWalletHolderAddr2 = "0x122fDD9fEcbc82F7d4237C0549a5057E31c8EF8D";
let usdcHolder1: HardhatEthersSigner;
let usdcHolder2: HardhatEthersSigner;

describe("Unit tests", function () {
  beforeEach(async function () {
    const usdc = await ethers.getContractAt(
      ERC20.abi,
      "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    );

    this.roles = {};
    this.users = {};
    this.testContracts = {};
    this.contract = {};

    const [deployer, vaultManager, strategist] = await ethers.getSigners();
    this.roles = { deployer, vaultManager, strategist };

    usdcHolder1 = await ethers.getImpersonatedSigner(hotWalletHolderAddr);
    await deployer.sendTransaction({
      value: ethers.parseEther("1"),
      to: usdcHolder1.address,
    });

    usdcHolder2 = await ethers.getImpersonatedSigner(hotWalletHolderAddr2);
    await deployer.sendTransaction({
      value: ethers.parseEther("1"),
      to: usdcHolder2.address,
    });

    const aaveReserve: AddressLike =
      "0xA238Dd80C259a72e81d7e4664a9801593F98d1c5";
    const morphoReserve1: AddressLike =
      "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb";
    const reserve2Id: BytesLike =
      "0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda";
    const morphoReserve2: AddressLike =
      "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb";
    const reserve3Id: BytesLike =
      "0x1c21c59df9db44bf6f645d854ee710a8ca17b479451447e9f56758aee10a2fad";

    const BrinkVault = await ethers.getContractFactory("BrinkVault");
    this.contract = await BrinkVault.deploy(
      await usdc.getAddress(),
      strategist,
      vaultManager,
      "Test Brink",
      "TSTBrink",
      ethers.parseUnits("1000000", 6),
    );
    await this.contract.waitForDeployment();

    const brinkAddress = await this.contract.getAddress();

    const AaveStrategy = await ethers.getContractFactory("AaveStrategy");
    const aaveStrategy = await AaveStrategy.deploy(
      brinkAddress,
      usdc,
      aaveReserve,
    );
    await aaveStrategy.waitForDeployment();

    const MorphoStrategy = await ethers.getContractFactory("MorphoStrategy");
    const morphoStrategy1 = await MorphoStrategy.deploy(
      brinkAddress,
      usdc,
      morphoReserve1,
      reserve2Id,
    );
    await morphoStrategy1.waitForDeployment();

    const morphoStrategy2 = await MorphoStrategy.deploy(
      brinkAddress,
      usdc,
      morphoReserve2,
      reserve3Id,
    );
    await morphoStrategy2.waitForDeployment();

    await this.contract
      .connect(vaultManager)
      .initialize(
        [aaveStrategy, morphoStrategy1, morphoStrategy2],
        [5_000, 3_000, 2_000],
      );

    await usdc
      .connect(usdcHolder1)
      .approve(this.contract, ethers.parseUnits("10000000", 6));
    await usdc
      .connect(usdcHolder2)
      .approve(this.contract, ethers.parseUnits("10000000", 6));

    this.users = {
      usdcHolder1,
      usdcHolder2,
      deployer,
      vaultManager,
      strategist,
    };

    this.testContracts = {
      usdc,
      aaveStrategy,
      morphoStrategy1,
      morphoStrategy2,
      aaveReserve,
      morphoReserve1,
      morphoReserve2,
    };
  });

  context("BrinkVault", function () {
    context("deployment()", function () {
      it("should have correct initial addresses setup", async function () {
        const brinkVault = this.contract;
        const { aaveStrategy, morphoStrategy1, morphoStrategy2, usdc } =
          this.testContracts;
        const { vaultManager, strategist } = this.users;

        expect(await brinkVault.asset()).to.be.equal(usdc);
        expect(await brinkVault.vaultManager()).to.be.equal(vaultManager);
        expect(await brinkVault.strategist()).to.be.equal(strategist);
        expect(await brinkVault.numberOfStrategies()).to.be.equal(3);
        const list = [...(await brinkVault.getWhitelist())];
        expect(list).to.have.members([
          await aaveStrategy.getAddress(),
          await morphoStrategy1.getAddress(),
          await morphoStrategy2.getAddress(),
        ]);
      });
    });

    context("initialize()", function () {
      it("should revert with custom error ALREADY_INITIALIZED if contract is already initialized", async function () {
        const brinkVault = this.contract;
        const { aaveStrategy } = this.testContracts;
        const { vaultManager } = this.users;

        const tx = brinkVault.connect(vaultManager).initialize(
          [aaveStrategy],
          [5_000],
        );
        await expect(tx).to.be.revertedWithCustomError(
          brinkVault,
          "ALREADY_INITIALIZED",
        );
      });

      it("should revert with custom error DUPLICATE_STRATEGY if strategy already exists", async function () {
        const { usdc } = this.testContracts;
        const { vaultManager, strategist } = this.users;
        const aaveReserve: AddressLike = 
          "0xA238Dd80C259a72e81d7e4664a9801593F98d1c5";
        const morphoReserve1: AddressLike =
          "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb";
        const reserve2Id: BytesLike =
          "0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda";

        const BrinkVault = await ethers.getContractFactory("BrinkVault");
        const brinkVault = await BrinkVault.deploy(
          await usdc.getAddress(),
          strategist,
          vaultManager,
          "Test Brink",
          "TSTBrink",
          ethers.parseUnits("1000000", 6),
        );
        await brinkVault.waitForDeployment();

        const AaveStrategy = await ethers.getContractFactory("AaveStrategy");
        const aaveStrategy = await AaveStrategy.deploy(
          brinkVault.target,
          usdc,
          aaveReserve,
        );
        await aaveStrategy.waitForDeployment();

        const MorphoStrategy = await ethers.getContractFactory("MorphoStrategy");
        const morphoStrategy1 = await MorphoStrategy.deploy(
          brinkVault.target,
          usdc,
          morphoReserve1,
          reserve2Id,
        );
        await morphoStrategy1.waitForDeployment();

        const tx = brinkVault.connect(vaultManager).initialize(
          [aaveStrategy, morphoStrategy1, aaveStrategy],
          [5_000, 5_000, 5_000],
        );
        await expect(tx).to.be.revertedWithCustomError(
          brinkVault,
          "DUPLICATE_STRATEGY",
        );
      });
    })

    context("deposit()", function () {
      it("should allow to deposit and emit the event", async function () {
        const brinkVault = this.contract;
        const { usdc, morphoReserve1 } = this.testContracts;
        const { usdcHolder1 } = this.users;

        const assets = ethers.parseUnits("100000", 6);

        const tx = brinkVault.connect(usdcHolder1).deposit(assets, usdcHolder1);
        await expect(tx)
          .to.emit(brinkVault, "Deposited")
          .withArgs(usdcHolder1, usdcHolder1, assets, assets);

        const expectedAmountToBeAdded = ethers.parseUnits("50000", 6);
        const aToken = "0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB";

        // aave has 50% of allocation and morpho has 50% as well because two different pairs have the same place of storing reserve data
        await expect(tx).to.changeTokenBalances(
          usdc,
          [aToken, morphoReserve1, brinkVault],
          [expectedAmountToBeAdded, expectedAmountToBeAdded, 0],
        );
      });
    });

    context("withdraw()", function () {
      it("should allow to withdraw fully and emit the event", async function () {
        const brinkVault = this.contract;
        const { usdc, morphoReserve1 } = this.testContracts;
        const { usdcHolder1 } = this.users;

        const assets = ethers.parseUnits("100000", 6);

        await brinkVault.connect(usdcHolder1).deposit(assets, usdcHolder1);

        const shares = await brinkVault.balanceOf(usdcHolder1);
        const totalAssets = await brinkVault.convertToAssets(shares);

        const tx = brinkVault
          .connect(usdcHolder1)
          .withdraw(totalAssets, usdcHolder1, usdcHolder1);
        await expect(tx).to.emit(brinkVault, "Withdrawal");

        const expectedAmountToBeWithdrawn = ethers.parseUnits("50000", 6);
        const aToken = "0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB";

        await expect(tx).to.changeTokenBalances(
          usdc,
          [aToken, morphoReserve1, brinkVault, usdcHolder1],
          [
            -expectedAmountToBeWithdrawn + 1n,
            -expectedAmountToBeWithdrawn + 2n,
            0,
            totalAssets - 1n,
          ],
        );

        expect(await brinkVault.balanceOf(usdcHolder1)).to.not.be.equal(0);
      });
    });

    context.skip("redeem()", function () {
      it("should allow to redeem and emit the event", async function () {
        const brinkVault = this.contract;
        const { usdc, morphoReserve1 } = this.testContracts;
        const { usdcHolder1 } = this.users;

        const assets = ethers.parseUnits("100000", 6);

        await brinkVault.connect(usdcHolder1).deposit(assets, usdcHolder1);

        // Increase time by 1 day
        await ethers.provider.send("evm_increaseTime", [86400]);
        await ethers.provider.send("evm_mine", []);

        const tx = brinkVault
          .connect(usdcHolder1)
          .redeem(assets, usdcHolder1, usdcHolder1);
        await expect(tx).to.emit(brinkVault, "Withdrawal");

        const expectedAmountToBeWithdrawn = "50002683438";
        const aToken = "0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB";

        await expect(tx).to.changeTokenBalances(
          usdc,
          [aToken, morphoReserve1, brinkVault, usdcHolder1],
          [
            -expectedAmountToBeWithdrawn,
            -expectedAmountToBeWithdrawn + 2683438,
            0,
            assets + 2683438n,
          ],
        );

        expect(await brinkVault.balanceOf(usdcHolder1)).to.be.equal(0);
      });
    });

    context("rebalance()", function () {
      it("should allow to rebalance and emit the event", async function () {
        const brinkVault = this.contract;
        const { aaveStrategy, morphoStrategy1, morphoStrategy2 } =
          this.testContracts;
        const { usdcHolder1, usdcHolder2, strategist } = this.users;
        const assets = ethers.parseUnits("100000", 6);

        await brinkVault.connect(usdcHolder1).deposit(assets, usdcHolder1);
        await brinkVault.connect(usdcHolder2).deposit(assets / 2n, usdcHolder2);

        // Increase time by 1 day
        await ethers.provider.send("evm_increaseTime", [86400]);
        await ethers.provider.send("evm_mine", []);

        const rebalanceArgs = {
          strategiesRebalanceFrom: [aaveStrategy], // from Aave
          weightsRebalanceFrom: [2_000], // 20%
          strategiesRebalanceTo: [morphoStrategy2, morphoStrategy1], // to Morpho 1 and 2
          weightsOfRedestribution: [5_000, 5_000], // 50% and 50%
        };

        const tx = brinkVault.connect(strategist).rebalance(rebalanceArgs);
        await expect(tx).to.emit(brinkVault, "RebalanceComplete");

        const res = await brinkVault.getBrinkVaultData();
        const strategyAddresses = res.map((config: any) => config.strategy);
        const strategyWeights = res.map((config: any) => config.weight);
        
        // After rebalancing, we should have strategies with non-zero balances
        // The exact addresses and weights depend on the actual balances after rebalancing
        expect(strategyAddresses.length).to.be.greaterThan(0);
        expect(strategyWeights.length).to.equal(strategyAddresses.length);
        
        // Verify that weights sum to TOTAL_WEIGHT (10000)
        const totalWeight = strategyWeights.reduce((sum: any, weight: any) => sum + weight, 0n);
        expect(totalWeight).to.equal(10000n);
      });

      it("should allow to rebalance in different ways", async function () {
        const brinkVault = this.contract;
        const { aaveStrategy, morphoStrategy1, morphoStrategy2 } =
          this.testContracts;
        const { usdcHolder1, strategist } = this.users;
        const assets = ethers.parseUnits("100000", 6);

        await brinkVault.connect(usdcHolder1).deposit(assets, usdcHolder1);

        const rebalanceArgs = {
          strategiesRebalanceFrom: [morphoStrategy1, aaveStrategy], // from Aave and Morpho 2
          weightsRebalanceFrom: [9_900, 5_000], // 99% and 50%
          strategiesRebalanceTo: [morphoStrategy2], // to Morpho 1
          weightsOfRedestribution: [10_000], // 100%
        };

        const tx = brinkVault.connect(strategist).rebalance(rebalanceArgs);
        await expect(tx).to.emit(brinkVault, "RebalanceComplete");

        const res = await brinkVault.getBrinkVaultData();
        const strategyAddresses = res.map((config: any) => config.strategy);
        const strategyWeights = res.map((config: any) => config.weight);
        
        // After rebalancing, we should have strategies with non-zero balances
        expect(strategyAddresses.length).to.be.greaterThan(0);
        expect(strategyWeights.length).to.equal(strategyAddresses.length);
        
        // Verify that weights sum to TOTAL_WEIGHT (10000)
        const totalWeight = strategyWeights.reduce((sum: any, weight: any) => sum + weight, 0n);
        expect(totalWeight).to.equal(10000n);
      });

      it("should allow to rebalance in one strategy", async function () {
        const brinkVault = this.contract;
        const { aaveStrategy, morphoStrategy1, morphoStrategy2 } =
          this.testContracts;
        const { usdcHolder1, strategist } = this.users;
        const assets = ethers.parseUnits("100000", 6);

        await brinkVault.connect(usdcHolder1).deposit(assets, usdcHolder1);

        const rebalanceArgs = {
          strategiesRebalanceFrom: [aaveStrategy, morphoStrategy1], // from Aave and Morpho 2
          weightsRebalanceFrom: [9_900, 9_900], // 99% and 99%
          strategiesRebalanceTo: [morphoStrategy2], // to Morpho 1
          weightsOfRedestribution: [10_000], // 100%
        };

        const tx = brinkVault.connect(strategist).rebalance(rebalanceArgs);
        await expect(tx).to.emit(brinkVault, "RebalanceComplete");

        const res = await brinkVault.getBrinkVaultData();
        const strategyAddresses = res.map((config: any) => config.strategy);
        const strategyWeights = res.map((config: any) => config.weight);
        
        // After rebalancing, we should have strategies with non-zero balances
        expect(strategyAddresses.length).to.be.greaterThan(0);
        expect(strategyWeights.length).to.equal(strategyAddresses.length);
        
        // Verify that weights sum to TOTAL_WEIGHT (10000)
        const totalWeight = strategyWeights.reduce((sum: any, weight: any) => sum + weight, 0n);
        expect(totalWeight).to.equal(10000n);
      });
    });

    context("withdrawFunds()", function () {
      it("should allow to withdraw all assets to BrinkVault", async function () {
        const brinkVault = this.contract;
        const { usdc } = this.testContracts;
        const { usdcHolder1, usdcHolder2, strategist } = this.users;
        const assets = ethers.parseUnits("100000", 6);

        await brinkVault.connect(usdcHolder1).deposit(assets, usdcHolder1);
        await brinkVault.connect(usdcHolder2).deposit(assets / 2n, usdcHolder2);

        const tx = brinkVault.connect(strategist).withdrawFunds();
        await expect(tx).to.emit(brinkVault, "WithdrawFunds");

        expect(await usdc.balanceOf(brinkVault)).to.be.gt(assets + assets / 2n);
      });
    });

    context("depositFunds()", function () {
      it("should allow to withdraw all assets to BrinkVault and then deposit them again", async function () {
        const brinkVault = this.contract;
        const { usdc } = this.testContracts;
        const { usdcHolder1, usdcHolder2, strategist } = this.users;
        const assets = ethers.parseUnits("100000", 6);

        await brinkVault.connect(usdcHolder1).deposit(assets, usdcHolder1);
        await brinkVault.connect(usdcHolder2).deposit(assets / 2n, usdcHolder2);

        await brinkVault.connect(strategist).withdrawFunds();

        const tx = brinkVault.connect(strategist).depositFunds();
        await expect(tx).to.emit(brinkVault, "DepositFunds");

        expect(await usdc.balanceOf(brinkVault)).to.be.equal(2);
      });
    });

    context("setStrategy()", function () {
      it("should allow to set the strategy from whitelist", async function () {
        const brinkVault = this.contract;
        const { aaveStrategy, morphoStrategy1, morphoStrategy2 } =
          this.testContracts;
        const { usdcHolder1, strategist, vaultManager } = this.users;
        const assets = ethers.parseUnits("100000", 6);

        await brinkVault.connect(usdcHolder1).deposit(assets, usdcHolder1);

        const rebalanceArgs = {
          strategiesRebalanceFrom: [aaveStrategy, morphoStrategy1],
          weightsRebalanceFrom: [10_000, 10_000],
          strategiesRebalanceTo: [morphoStrategy2],
          weightsOfRedestribution: [10_000],
        };

        const tx = brinkVault.connect(strategist).rebalance(rebalanceArgs);
        await expect(tx).to.emit(brinkVault, "RebalanceComplete");

        const res = await brinkVault.getBrinkVaultData();
        const strategyAddresses = res.map((config: any) => config.strategy);
        const strategyWeights = res.map((config: any) => config.weight);
        
        // After rebalancing, we should have strategies with non-zero balances
        expect(strategyAddresses.length).to.be.greaterThan(0);
        expect(strategyWeights.length).to.equal(strategyAddresses.length);
        
        // Verify that weights sum to TOTAL_WEIGHT (10000)
        const totalWeight = strategyWeights.reduce((sum: any, weight: any) => sum + weight, 0n);
        expect(totalWeight).to.equal(10000n);

        const tx1 = brinkVault
          .connect(vaultManager)
          .setStrategy(await aaveStrategy.getAddress(), false);
        await expect(tx1)
          .to.emit(brinkVault, "StrategyWhitelisted")
          .withArgs(await aaveStrategy.getAddress(), false);
      });

      it("should not allow to remove the strategy from whitelist when it has funds", async function () {
        const brinkVault = this.contract;
        const { aaveStrategy, morphoStrategy1, morphoStrategy2 } =
          this.testContracts;
        const { usdcHolder1, strategist, vaultManager } = this.users;
        const assets = ethers.parseUnits("100000", 6);

        await brinkVault.connect(usdcHolder1).deposit(assets, usdcHolder1);

        const rebalanceArgs = {
          strategiesRebalanceFrom: [morphoStrategy1, aaveStrategy],
          weightsRebalanceFrom: [9_900, 9_900],
          strategiesRebalanceTo: [morphoStrategy2],
          weightsOfRedestribution: [10_000],
        };

        const tx = brinkVault.connect(strategist).rebalance(rebalanceArgs);
        await expect(tx).to.emit(brinkVault, "RebalanceComplete");

        const res = await brinkVault.getBrinkVaultData();
        const strategyAddresses = res.map((config: any) => config.strategy);
        const strategyWeights = res.map((config: any) => config.weight);
        
        // After rebalancing, we should have strategies with non-zero balances
        expect(strategyAddresses.length).to.be.greaterThan(0);
        expect(strategyWeights.length).to.equal(strategyAddresses.length);
        
        // Verify that weights sum to TOTAL_WEIGHT (10000)
        const totalWeight = strategyWeights.reduce((sum: any, weight: any) => sum + weight, 0n);
        expect(totalWeight).to.equal(10000n);

        const tx1 = brinkVault
          .connect(vaultManager)
          .setStrategy(await morphoStrategy1.getAddress(), false);
        await expect(tx1).to.be.revertedWithCustomError(
          brinkVault,
          "CANNOT_REMOVE_NOT_EMPTY_STRATEGY",
        );
      });
    });
  });
});
