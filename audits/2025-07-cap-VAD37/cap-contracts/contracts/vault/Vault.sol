// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Access } from "../access/Access.sol";

import { IVault } from "../interfaces/IVault.sol";
import { VaultStorageUtils } from "../storage/VaultStorageUtils.sol";
import { FractionalReserve } from "./FractionalReserve.sol";
import { Minter } from "./Minter.sol";
import { VaultLogic } from "./libraries/VaultLogic.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { console } from "forge-std/console.sol";
/// @title Vault for storing the backing for cTokens
/// @author kexley, Cap Labs
/// @notice Tokens are supplied by cToken minters and borrowed by covered agents
/// @dev Supplies, borrows and utilization rates are tracked. Interest rates should be computed and
/// charged on the external contracts, only the principle amount is counted on this contract.
abstract contract Vault is //@note all capToken are vault token 18 decimals. but accept 6 decimals USDC, 18 decimals ETH, 6 decimals USDT, 18 decimals WETH
    IVault,
    ERC20PermitUpgradeable,
    PausableUpgradeable,
    Access,
    Minter,
    FractionalReserve,
    VaultStorageUtils
{//@live code is older version 0x77d2d43e76e50ac3c43dd54533cd303e69cb0307 impl 0xdd649adab2e67cadc2ec29d75abe73f3df08065c
    using EnumerableSet for EnumerableSet.AddressSet;//@idk why deployer use older version

    /// @inheritdoc IVault
    function mint(address _asset, uint256 _amountIn, uint256 _minAmountOut, address _receiver, uint256 _deadline)
        external
        whenNotPaused
        returns (uint256 amountOut)
    {//@do accept cUSD as collateral. but VaultLogic ignore this with its whitelist check
        console.log("start minting cToken for asset: %s", _asset);
        uint256 fee;//@audit M mint with price before fee. so after fee. price of cUSD suddenly drop, due to price fixed to value in oracle USD
        (amountOut, fee) = getMintAmount(_asset, _amountIn);//out = amountIn_USD * 1e18/ (totalUSD_e8 * e18 /totalCapSupply_e18) = out_e18
        VaultLogic.mint(//@trigger updateIndex(), reset utilizationIndex for asset, reset lastUpdate
            getVaultStorage(),//@also check if asset exist in vault. only now not before
            MintBurnParams({
                asset: _asset, //transfer USDC by amountIn from user to this
                amountIn: _amountIn,// increase totalSupply for this asset. aka deposit USDC
                amountOut: amountOut,// mint cUSD > 0
                minAmountOut: _minAmountOut,// slippage prevention for cETH if price fluctuate too much
                receiver: _receiver,//just for event
                deadline: _deadline,
                fee: fee
            })
        );
        _mint(_receiver, amountOut);
        if (fee > 0) _mint(getVaultStorage().insuranceFund, fee);//@audit R. price cUSD never drop after fee. due to fee is taken in the form of output token.
    }

    /// @inheritdoc IVault
    function burn(address _asset, uint256 _amountIn, uint256 _minAmountOut, address _receiver, uint256 _deadline)
        external
        whenNotPaused
        returns (uint256 amountOut)
    {
        uint256 fee;
        (amountOut, fee) = getBurnAmount(_asset, _amountIn);
        divest(_asset, amountOut + fee);
        VaultLogic.burn(
            getVaultStorage(),
            MintBurnParams({
                asset: _asset,
                amountIn: _amountIn,
                amountOut: amountOut,
                minAmountOut: _minAmountOut,
                receiver: _receiver,
                deadline: _deadline,
                fee: fee
            })
        );
        _burn(msg.sender, _amountIn);
    }

    /// @inheritdoc IVault
    function redeem(uint256 _amountIn, uint256[] calldata _minAmountsOut, address _receiver, uint256 _deadline)
        external
        whenNotPaused
        returns (uint256[] memory amountsOut)
    {
        uint256[] memory fees;
        (amountsOut, fees) = getRedeemAmount(_amountIn);
        uint256[] memory totalDivestAmounts = new uint256[](amountsOut.length);
        for (uint256 i; i < amountsOut.length; i++) {
            totalDivestAmounts[i] = amountsOut[i] + fees[i];
        }

        divestMany(assets(), totalDivestAmounts);
        VaultLogic.redeem(
            getVaultStorage(),
            RedeemParams({
                amountIn: _amountIn,
                amountsOut: amountsOut,
                minAmountsOut: _minAmountsOut,
                receiver: _receiver,
                deadline: _deadline,
                fees: fees
            })
        );
        _burn(msg.sender, _amountIn);
    }

    /// @inheritdoc IVault
    function borrow(address _asset, uint256 _amount, address _receiver)
        external
        whenNotPaused
        checkAccess(this.borrow.selector)
    {
        divest(_asset, _amount);
        VaultLogic.borrow(getVaultStorage(), BorrowParams({ asset: _asset, amount: _amount, receiver: _receiver }));
    }

    /// @inheritdoc IVault
    function repay(address _asset, uint256 _amount) external whenNotPaused checkAccess(this.repay.selector) {
        VaultLogic.repay(getVaultStorage(), RepayParams({ asset: _asset, amount: _amount }));
    }

    /// @inheritdoc IVault
    function addAsset(address _asset) external checkAccess(this.addAsset.selector) {
        VaultLogic.addAsset(getVaultStorage(), _asset);
    }

    /// @inheritdoc IVault
    function removeAsset(address _asset) external checkAccess(this.removeAsset.selector) {
        VaultLogic.removeAsset(getVaultStorage(), _asset);
    }

    /// @inheritdoc IVault
    function pauseAsset(address _asset) external checkAccess(this.pauseAsset.selector) {
        VaultLogic.pause(getVaultStorage(), _asset);
    }

    /// @inheritdoc IVault
    function unpauseAsset(address _asset) external checkAccess(this.unpauseAsset.selector) {
        VaultLogic.unpause(getVaultStorage(), _asset);
    }

    /// @inheritdoc IVault
    function pauseProtocol() external checkAccess(this.pauseProtocol.selector) {
        _pause();
    }

    /// @inheritdoc IVault
    function unpauseProtocol() external checkAccess(this.unpauseProtocol.selector) {
        _unpause();
    }

    /// @inheritdoc IVault
    function setInsuranceFund(address _insuranceFund) external checkAccess(this.setInsuranceFund.selector) {
        VaultLogic.setInsuranceFund(getVaultStorage(), _insuranceFund);
    }

    /// @inheritdoc IVault
    function rescueERC20(address _asset, address _receiver) external checkAccess(this.rescueERC20.selector) {
        VaultLogic.rescueERC20(getVaultStorage(), getFractionalReserveStorage(), _asset, _receiver);
    }

    /// @inheritdoc IVault
    function assets() public view returns (address[] memory assetList) {
        assetList = getVaultStorage().assets.values();
    }

    /// @inheritdoc IVault
    function totalSupplies(address _asset) external view returns (uint256 _totalSupply) {
        _totalSupply = getVaultStorage().totalSupplies[_asset];
    }//@also read by MinterLogic

    /// @inheritdoc IVault
    function totalBorrows(address _asset) external view returns (uint256 totalBorrow) {
        totalBorrow = getVaultStorage().totalBorrows[_asset];
    }

    /// @inheritdoc IVault
    function paused(address _asset) external view returns (bool isPaused) {
        isPaused = getVaultStorage().paused[_asset];
    }

    /// @inheritdoc IVault
    function availableBalance(address _asset) external view returns (uint256 amount) {
        amount = VaultLogic.availableBalance(getVaultStorage(), _asset);
    }

    /// @inheritdoc IVault
    function utilization(address _asset) external view returns (uint256 ratio) {
        ratio = VaultLogic.utilization(getVaultStorage(), _asset);
    }

    /// @inheritdoc IVault
    function currentUtilizationIndex(address _asset) external view returns (uint256 index) {
        index = VaultLogic.currentUtilizationIndex(getVaultStorage(), _asset);
    }

    /// @inheritdoc IVault
    function insuranceFund() external view returns (address) {
        return getVaultStorage().insuranceFund;
    }

    /// @dev Initialize the assets
    /// @param _name Name of the cap token
    /// @param _symbol Symbol of the cap token
    /// @param _accessControl Access control address
    /// @param _feeAuction Fee auction address
    /// @param _oracle Oracle address
    /// @param _assets Asset addresses
    /// @param _insuranceFund Insurance fund
    function __Vault_init(
        string memory _name,
        string memory _symbol,
        address _accessControl,
        address _feeAuction,
        address _oracle,
        address[] calldata _assets,
        address _insuranceFund
    ) internal onlyInitializing {
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __Access_init(_accessControl);
        __FractionalReserve_init(_feeAuction);
        __Minter_init(_oracle);
        __Vault_init_unchained(_assets, _insuranceFund);
    }

    /// @dev Initialize unchained
    /// @param _assets Asset addresses
    /// @param _insuranceFund Insurance fund
    function __Vault_init_unchained(address[] calldata _assets, address _insuranceFund) internal onlyInitializing {
        VaultStorage storage $ = getVaultStorage();
        uint256 length = _assets.length;
        for (uint256 i; i < length; ++i) {
            $.assets.add(_assets[i]);
        }
        $.insuranceFund = _insuranceFund;
    }
}
