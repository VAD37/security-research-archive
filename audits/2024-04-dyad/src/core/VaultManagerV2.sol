// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
import "forge-std/console.sol";
import {DNft}            from "./DNft.sol";
import {Dyad}            from "./Dyad.sol";
import {Licenser}        from "./Licenser.sol";
import {Vault}           from "./Vault.sol";
import {IVaultManager}   from "../interfaces/IVaultManager.sol";
import {KerosineManager} from "../../src/core/KerosineManager.sol";

import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";
import {ERC20}             from "@solmate/src/tokens/ERC20.sol";
import {SafeTransferLib}   from "@solmate/src/utils/SafeTransferLib.sol";
import {EnumerableSet}     from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Initializable}     from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract VaultManagerV2 is IVaultManager, Initializable {
  using EnumerableSet     for EnumerableSet.AddressSet;
  using FixedPointMathLib for uint;
  using SafeTransferLib   for ERC20;

  uint public constant MAX_VAULTS          = 5;
  uint public constant MAX_VAULTS_KEROSENE = 5;

  uint public constant MIN_COLLATERIZATION_RATIO = 1.5e18; // 150%
  uint public constant LIQUIDATION_REWARD        = 0.2e18; //  20%

  DNft     public immutable dNft;
  Dyad     public immutable dyad;
  Licenser public immutable vaultLicenser;

  KerosineManager public keroseneManager;//@note Kerosene Vault intended for locked deposit rewards. bounded cannot withdraw. unbounded free withdraw. bounded worth x2

  mapping (uint => EnumerableSet.AddressSet) internal vaults; 
  mapping (uint => EnumerableSet.AddressSet) internal vaultsKerosene; 

  mapping (uint => uint)                     public   idToBlockOfLastDeposit;

  modifier isDNftOwner(uint id) {
    if (dNft.ownerOf(id) != msg.sender)   revert NotOwner();    _;
  }
  modifier isValidDNft(uint id) {
    if (dNft.ownerOf(id) == address(0))   revert InvalidDNft(); _;
  }
  modifier isLicensed(address vault) {
    if (!vaultLicenser.isLicensed(vault)) revert NotLicensed(); _;
  }

  constructor(
    DNft          _dNft,
    Dyad          _dyad,
    Licenser      _licenser//@note licenser is new Licenser not reusing old vault liccenser
  ) {
    dNft          = _dNft;
    dyad          = _dyad;
    vaultLicenser = _licenser;
  }

  function setKeroseneManager(KerosineManager _keroseneManager) 
    external
      initializer 
    {
      keroseneManager = _keroseneManager;
  }

  /// @inheritdoc IVaultManager
  function add(//@note currently there is 3 vaultsV2, 1 not approved yet. UnboundedKerosineVault, VaultWstEth, new Vault WETH, BoundedKerosineVault is comment and not included into vault
      uint    id,
      address vault
  ) 
    external
      isDNftOwner(id)
  {
    if (vaults[id].length() >= MAX_VAULTS) revert TooManyVaults();
    if (!vaultLicenser.isLicensed(vault))  revert VaultNotLicensed();//@ no ex vault include or can be added
    if (!vaults[id].add(vault))            revert VaultAlreadyAdded();
    emit Added(id, vault);
  }

  function addKerosene(//@note Kerosene manager only have 2 vault, new ethVault WETH, and new WstETH vault same address as above.
      uint    id,
      address vault
  ) 
    external
      isDNftOwner(id)
  {
    if (vaultsKerosene[id].length() >= MAX_VAULTS_KEROSENE) revert TooManyVaults();//@audit-ok H4 H duplicate normal vault and kerosene vault. Both can be added to normalVault and kerosene Vault. This duplicate total value later.
    if (!keroseneManager.isLicensed(vault))                 revert VaultNotLicensed();//@audit-ok not possible with correct admin config.accept deprecated vault. old version vault through licenser
    if (!vaultsKerosene[id].add(vault))                     revert VaultAlreadyAdded();
    emit Added(id, vault);
  }

  /// @inheritdoc IVaultManager
  function remove(
      uint    id,
      address vault
  ) 
    external
      isDNftOwner(id)
  {
    if (Vault(vault).id2asset(id) > 0) revert VaultHasAssets();//@audit-ok lots of medium what happen when vault not licensed anymore?
    if (!vaults[id].remove(vault))     revert VaultNotAdded();
    emit Removed(id, vault);
  }

  function removeKerosene(
      uint    id,
      address vault
  ) 
    external
      isDNftOwner(id)
  {
    if (Vault(vault).id2asset(id) > 0)     revert VaultHasAssets();
    if (!vaultsKerosene[id].remove(vault)) revert VaultNotAdded();
    emit Removed(id, vault);
  }

  /// @inheritdoc IVaultManager
  function deposit(//@audit-ok 8992 wei gas. lowest is 3931 wei gas .can deposit someone else to prevent withdrawal
    uint    id,
    address vault,
    uint    amount
  ) 
    external 
      isValidDNft(id)//@audit-ok money still be transfered exploit price does nothing special.there is validNFT check only modifier. Anyone can call this as long as NFT is valid. include reentrancy.
  {//@audit-ok M can deposit into Vault not added to list
    idToBlockOfLastDeposit[id] = block.number;
    Vault _vault = Vault(vault);//@audit-ok deposit didnt validate vault is licensed or exist with id. What if user send money to deprecated vault. or NFT owner never add this vault. or NFT owner already remove this vault.
    _vault.asset().safeTransferFrom(msg.sender, address(vault), amount);
    _vault.deposit(id, amount);//@audit-ok anyone deposit allow dust token inside vault on L2. to prevent remove vault
  }

  /// @inheritdoc IVaultManager
  function withdraw(//@audit-ok people will just buy DYAD to withdraw their funds for cheap. R what happen DYAD depeg on uniswap. Lots of people get DYAD for free.
    uint    id,
    address vault,
    uint    amount,
    address to
  ) 
    public//@audit-ok only take from user.R is it possible for vault not have enough base asset after terrible loss. Does damage spread evenly between user like ERC4626
      isDNftOwner(id)
  {//@audit-ok M1 cannot withdraw deprecated vault. not exist in license list anymore. If collateral not enough
    if (idToBlockOfLastDeposit[id] == block.number) revert DepositedInSameBlock();//@audit-ok M3 flashloan protection allow other user to DOS withdraw.
    uint dyadMinted = dyad.mintedDyad(address(this), id);//@audit-ok L withdraw accept non licensed vault. It doesnt affect anything. as no external call outside vault itself.
    Vault _vault = Vault(vault);
    uint value = amount * _vault.assetPrice() //@oracle
                  * 1e18 //@audit-ok fixed 1e18 token decimal does not work.
                  / 10**_vault.oracle().decimals() //@cancel oracle
                  / 10**_vault.asset().decimals();//@cancel amount
    if (getNonKeroseneValue(id) - value < dyadMinted) revert NotEnoughExoCollat();
    _vault.withdraw(id, to, amount);//@audit-ok M3 H different vault allow
    if (collatRatio(id) < MIN_COLLATERIZATION_RATIO)  revert CrTooLow();//@audit-ok  known issue L this mainnet project allow oracle sandwich free swap.
  }//@note collatRatio include both normal and kerosene vault. Ignore nonlicensed Vault

  /// @inheritdoc IVaultManager
  function mintDyad(//@borrow
    uint    id,
    uint    amount,
    address to
  )
    external //@audit-ok L allow mint/borrow 0 zero token.
      isDNftOwner(id)
  {
    uint newDyadMinted = dyad.mintedDyad(address(this), id) + amount;//note user can mint 100% collateral as long as kerosine vault is included as collateral.
    if (getNonKeroseneValue(id) < newDyadMinted)     revert NotEnoughExoCollat();//@audit-ok nothing funny with vault so far L trust Vault to find correct oracle price. this is bad
    dyad.mint(id, to, amount);
    uint cr = collatRatio(id);
    console.log("cr after mint: %e", cr);
    if (cr < MIN_COLLATERIZATION_RATIO) revert CrTooLow(); 
    emit MintDyad(id, amount, to);
  }

  /// @inheritdoc IVaultManager
  function burnDyad(
    uint id,
    uint amount
  ) 
    external 
      isValidDNft(id)
  {
    dyad.burn(id, msg.sender, amount);//@audit-ok wrong assumption . R user can use DYAD stable token to reduce collateral value of other user. Normally this would be good. But this also prevent them from withdraw original token.
    emit BurnDyad(id, amount, msg.sender);
  }

  /// @inheritdoc IVaultManager
  function redeemDyad(//@audit-ok this burnDyad and call withdraw for user. 2 functions in one. @H redeem is not cross vault. This is exploitable.
    uint    id,
    address vault,
    uint    amount,//burn DYAD amount 1e18 decimal
    address to
  )
    external 
      isDNftOwner(id)
    returns (uint) { 
      dyad.burn(id, msg.sender, amount);//@audit-ok just try redeem again L revert on vault withdrawal. M burn token but vault does not exist. or deprecated
      Vault _vault = Vault(vault);
      uint asset = amount 
                    * (10**(_vault.oracle().decimals() + _vault.asset().decimals())) //8 + token decimal
                    / _vault.assetPrice() // cancel oracle 1e8
                    / 1e18;//@cancel DYAD amount  //@audit-ok converting DYAD 1e18 down M fixed 1e18 token here seem wrong than other place.
      withdraw(id, vault, asset, to);//@audit-ok This is internal call. msg.sender does not change. @M redeem does not work. withdraw here is external call. owner is this contract not msg.sender
      emit RedeemDyad(id, vault, amount, to);
      return asset;//@audit-ok cannot withdraw token more than original deposit for each NFT. M withdraw not possible from single vault might not enough token due to misbalance of asset between vault.
  }

  /// @inheritdoc IVaultManager
  function liquidate(//@audit H leverage x10 work here.
    uint id,
    uint to
  ) 
    external 
      isValidDNft(id)
      isValidDNft(to)
    {//@audit-ok have kerosene token deposit prevent liquidation when collateral collapse.This include kerosene token evaluation as well @H liquidation missing kerosene vault. evaluation also include kerosene. so liquidation have no incentive to liquidate this
      uint cr = collatRatio(id);//@ include both kerosene and non kerosene vault.
      if (cr >= MIN_COLLATERIZATION_RATIO) revert CrTooHigh();//@ok 
      dyad.burn(id, msg.sender, dyad.mintedDyad(address(this), id));//@audit-ok burn remove mintedDYAD from ID directly @H burn internal here should remove minted amount from borrower not liquidator.

      uint cappedCr               = cr < 1e18 ? 1e18 : cr;// cap = 1e18 -> 1.5e18
      uint liquidationEquityShare = (cappedCr - 1e18).mulWadDown(LIQUIDATION_REWARD);//y= x * 0.2e18 / 1e18 //@user only get 20% anything above 100% collateral value of repayment.
      uint liquidationAssetShare  = (liquidationEquityShare + 1e18).divWadDown(cappedCr);// (y+1e18 ) * 1e18/ cap
      //@audit-ok Liquidation receive 73% to 99% of original deposit .R liquidation got free share? liquidationAssetShare = 1e18->1.5e18  * 1e18 / cap
      uint numberOfVaults = vaults[id].length();//@liquidation take 20% value. but this might not be worth it if value drop lower < 100%
      for (uint i = 0; i < numberOfVaults; i++) {
          Vault vault      = Vault(vaults[id].at(i));//@audit-ok liquidation math working as intended.  H liquidation never work. collateral return more than vault worth? Not enough token to spread evenly.
          uint  collateral = vault.id2asset(id).mulWadUp(liquidationAssetShare);//@ asset *  liquidationAssetShare / 1e18
          vault.move(id, to, collateral);//@audit-ok math on desmos checkout M liquidation unfair due to vault token distribution and price not the same. totalUSD return to liquidator is not full.
      }//@audit-ok M6 there is no profit for liquidator when collaratio < 100%. collat include kerosene vault make sure of this
      emit Liquidate(id, msg.sender, to);
  }//@ T = x * 1.2 +y * 2.9
//@ 0.8*T = 0.8*1.2*x + 0.8*2.9*y = 0.96x + 2.32y
  function collatRatio(
    uint id
  )
    public 
    view
    returns (uint) {
      uint _dyad = dyad.mintedDyad(address(this), id);
      if (_dyad == 0) return type(uint).max;
      return getTotalUsdValue(id).divWadDown(_dyad);//ratio = total collateral value * 1e18 / total borrow DYAD
  }

  function getTotalUsdValue(
    uint id
  ) 
    public 
    view
    returns (uint) {//@audit-ok H4 for whatever dumb reason. Kerosene and nonKerosene Vault use same vault address. So single vault deposit count double
      return getNonKeroseneValue(id) + getKeroseneValue(id);
  }

  function getNonKeroseneValue(
    uint id
  ) 
    public 
    view
    returns (uint) {
      uint totalUsdValue;
      uint numberOfVaults = vaults[id].length(); 
      for (uint i = 0; i < numberOfVaults; i++) {
        Vault vault = Vault(vaults[id].at(i));//@audit-ok no reentrancy possible collatRatio and evaluation of total USD value depend on enum order. This can switched when vault removed. so any callback will cause significant harm.
        uint usdValue;
        if (vaultLicenser.isLicensed(address(vault))) {
          usdValue = vault.getUsdValue(id);   //@audit-ok vault is trusted .vault value depend on vault address to evaluate
        }
        totalUsdValue += usdValue;//@audit-ok M3 if admin remove vault license. It also allow liquidation of other vault as collateral suddenly drop
      }
      return totalUsdValue;
  }

  function getKeroseneValue(
    uint id
  ) 
    public 
    view
    returns (uint) {
      uint totalUsdValue;
      uint numberOfVaults = vaultsKerosene[id].length(); 
      for (uint i = 0; i < numberOfVaults; i++) {
        Vault vault = Vault(vaultsKerosene[id].at(i));
        uint usdValue;
        if (keroseneManager.isLicensed(address(vault))) {
          usdValue = vault.getUsdValue(id); //@audit-ok Reviewing vault value depend on evaluation of kerisineDEnominator which depend on balance of multisig. Donation attack available.       
        }
        totalUsdValue += usdValue;
      }
      return totalUsdValue;
  }

  // ----------------- MISC ----------------- //

  function getVaults(
    uint id
  ) 
    external 
    view 
    returns (address[] memory) {
      return vaults[id].values();
  }

  function hasVault(
    uint    id,
    address vault
  ) 
    external 
    view 
    returns (bool) {
      return vaults[id].contains(vault);
  }
}
