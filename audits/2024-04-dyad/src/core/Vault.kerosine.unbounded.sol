// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {KerosineVault}        from "./Vault.kerosine.sol";
import {IVaultManager}        from "../interfaces/IVaultManager.sol";
import {Vault}                from "./Vault.sol";
import {Dyad}                 from "./Dyad.sol";
import {KerosineManager}      from "./KerosineManager.sol";
import {BoundedKerosineVault} from "./Vault.kerosine.bounded.sol";
import {KerosineDenominator}  from "../staking/KerosineDenominator.sol";

import {ERC20}           from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/src/utils/SafeTransferLib.sol";
import {console} from "forge-std/console.sol";
contract UnboundedKerosineVault is KerosineVault {
  using SafeTransferLib for ERC20;
//@note unbounded Kerosene vault allow deposit/withdraw KEROSINE token. AssetPrice = TVL - DYAD.totalSupply() / KerosineDenominator.denominator()
  Dyad                 public immutable dyad;
  KerosineDenominator  public kerosineDenominator;

  constructor(
      IVaultManager   _vaultManager,//VaultManagerV2
      ERC20           _asset, //MAINNET_KEROSENE
      Dyad            _dyad, //DYAD
      KerosineManager _kerosineManager//KerosineManager include new ethVault and new wstEthVault
  ) KerosineVault(_vaultManager, _asset, _kerosineManager) {
      dyad = _dyad;
  }

  function withdraw(//@e63697c8
    uint    id,
    address to,
    uint    amount
  ) 
    external 
      onlyVaultManager
  {
    id2asset[id] -= amount;
    asset.safeTransfer(to, amount); 
    emit Withdraw(id, to, amount);
  }

  function setDenominator(KerosineDenominator _kerosineDenominator) 
    external 
      onlyOwner
  {
    kerosineDenominator = _kerosineDenominator; //@audit-ok as designed R why allow change denimination? this allow infinite minting of DYAD
  }//@ deno can only go down. with donation attack. then assetprice of KEROSINE will rise. 

  function assetPrice() //1 eth = 98,000 KERO = 3.24k USD or 1 USD = 28.6 KERO or 28.6e18 KERO = 1e18 USD/DYAD
    public 
    view 
    override
    returns (uint) {
      uint tvl;//@unbounded Kerosinevault TVL = sum of all vaults TVL. this should be VaultManagerV2 all nonKerosine licensed vaults. not kerosineManager vaults
      address[] memory vaults = kerosineManager.getVaults();//@audit-ok kerosine unbounded price is depend on other vault
      uint numberOfVaults = vaults.length;
      for (uint i = 0; i < numberOfVaults; i++) {
        Vault vault = Vault(vaults[i]);
        tvl += vault.asset().balanceOf(address(vault)) 
                * vault.assetPrice() * 1e18
                / (10**vault.asset().decimals()) 
                / (10**vault.oracle().decimals());
      }//@audit-ok H07 new kerosine unbounded vault only read collateral total value from V2Vault. but use total minted DYAD from both v1,v2. This underflow due to not enough deposit to vault2
      uint numerator   = tvl - dyad.totalSupply();//2,335,049e18 - 632,967e18 DYAD     @DYAD supply can be minted by using KEROSINE as collateral.
      uint denominator = kerosineDenominator.denominator();//4.915e25  =kerosine.totalSupply() - kerosine.balanceOf(MAINNET_OWNER)
      console.log("unbounded TVL: %e", tvl);//@ numerator controlled by flashloan WETH and KERO deposit.
      console.log("DYAD totalSupply: %e", dyad.totalSupply());
      return numerator * 1e8 / denominator;//3,462,469 or 3.4e6   @ denominator ~= 50M or 49,000,000e18 = 4.915e25 //@ best uniswap reduce 20% value of denominator value
  }//@invariant rule TVL > DYAD total supply. This can be broken by have enough KEROSENE.
}//@audit H because assetPrice depend on vault V2 only and when deploy. No vault have enough token allow attacker to self deposit to manipulate numerator price to just right amount allow infinite minting.
//@ reference design outline rule is broken https://dyadstable.notion.site/DYAD-design-outline-v6-3fa96f99425e458abbe574f67b795145
//@ the more user mint DYAD. KERO price drop. it can drop to zero directly