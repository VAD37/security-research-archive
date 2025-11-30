// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { LibDiamond } from "../Libraries/LibDiamond.sol";
import { LibAccess } from "../Libraries/LibAccess.sol";
import { LibAllowList } from "../Libraries/LibAllowList.sol";
import { CannotAuthoriseSelf } from "../Errors/GenericErrors.sol";

/// @title Dex Manager Facet
/// @author LI.FI (https://li.fi)
/// @notice Facet contract for managing approved DEXs to be used in swaps.
/// @custom:version 1.0.0
contract DexManagerFacet {
    /// Events ///

    event DexAdded(address indexed dexAddress);
    event DexRemoved(address indexed dexAddress);
    event FunctionSignatureApprovalChanged(
        bytes4 indexed functionSignature,
        bool indexed approved
    );

    /// External Methods ///

    /// @notice Register the address of a DEX contract to be approved for swapping.
    /// @param _dex The address of the DEX contract to be approved.
    function addDex(address _dex) external {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }

        if (_dex == address(this)) {
            revert CannotAuthoriseSelf();
        }

        LibAllowList.addAllowedContract(_dex);

        emit DexAdded(_dex);
    }

    /// @notice Batch register the address of DEX contracts to be approved for swapping.
    /// @param _dexs The addresses of the DEX contracts to be approved.
    function batchAddDex(address[] calldata _dexs) external {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }
        uint256 length = _dexs.length;

        for (uint256 i = 0; i < length; ) {
            address dex = _dexs[i];
            if (dex == address(this)) {
                revert CannotAuthoriseSelf();
            }
            if (LibAllowList.contractIsAllowed(dex)) continue;
            LibAllowList.addAllowedContract(dex);
            emit DexAdded(dex);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Unregister the address of a DEX contract approved for swapping.
    /// @param _dex The address of the DEX contract to be unregistered.
    function removeDex(address _dex) external {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }
        LibAllowList.removeAllowedContract(_dex);
        emit DexRemoved(_dex);
    }

    /// @notice Batch unregister the addresses of DEX contracts approved for swapping.
    /// @param _dexs The addresses of the DEX contracts to be unregistered.
    function batchRemoveDex(address[] calldata _dexs) external {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }
        uint256 length = _dexs.length;
        for (uint256 i = 0; i < length; ) {
            LibAllowList.removeAllowedContract(_dexs[i]);
            emit DexRemoved(_dexs[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Adds/removes a specific function signature to/from the allowlist
    /// @param _signature the function signature to allow/disallow
    /// @param _approval whether the function signature should be allowed
    function setFunctionApprovalBySignature(
        bytes4 _signature,
        bool _approval
    ) external {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }

        if (_approval) {
            LibAllowList.addAllowedSelector(_signature);
        } else {
            LibAllowList.removeAllowedSelector(_signature);
        }

        emit FunctionSignatureApprovalChanged(_signature, _approval);
    }

    /// @notice Batch Adds/removes a specific function signature to/from the allowlist
    /// @param _signatures the function signatures to allow/disallow
    /// @param _approval whether the function signatures should be allowed
    function batchSetFunctionApprovalBySignature(
        bytes4[] calldata _signatures,
        bool _approval
    ) external {
        if (msg.sender != LibDiamond.contractOwner()) {
            LibAccess.enforceAccessControl();
        }
        uint256 length = _signatures.length;
        for (uint256 i = 0; i < length; ) {
            bytes4 _signature = _signatures[i];
            if (_approval) {
                LibAllowList.addAllowedSelector(_signature);
            } else {
                LibAllowList.removeAllowedSelector(_signature);
            }
            emit FunctionSignatureApprovalChanged(_signature, _approval);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns whether a function signature is approved
    /// @param _signature the function signature to query
    /// @return approved Approved or not
    function isFunctionApproved(
        bytes4 _signature
    ) public view returns (bool approved) {
        return LibAllowList.selectorIsAllowed(_signature);
    }

    /// @notice Returns a list of all approved DEX addresses.
    /// @return addresses List of approved DEX addresses
    function approvedDexs()
        external
        view
        returns (address[] memory addresses)
    {
        return LibAllowList.getAllowedContracts();
    }
}
// approved dex
//   0xCB859eA579b28e02B87A1FDE08d087ab9dbE5149 // DODOApprove ?
//   0xa356867fDCEa8e71AEaF87805808803806231FdC // DODOV2Proxy02
//   0xa2398842F37465f89540430bDC00219fA9E4D28a // DODORouteProxy
//   0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57 //AugustusSwapper PARASWAP
//   0x216B4B4Ba9F3e719726886d34a177484278Bfcae //TokenTransferProxy by paraswap
//   0x6352a56caadC4F1E25CD6c75970Fa768A3304e64 // OpenOceanExchangeProxy swap,uniswapV3Swap, calltouniswap 0x90411a32 swap
//   0x1111111254fb6c44bAC0beD2854e76F90643097d // 1inch AggregationRouterV4  allow permit?
//   0xDef1C0ded9bec7F1a1670819833240f027b25EfF //ZeroEx 0x  transform ERC20 0x415565b0
//   0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D // UniswapV2Router02 
//   0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F // SushiswapRouter 
//   0xbD6C7B0d2f68c2b7805d88388319cfB6EcB50eA9 //FeeCollector by LIFI diamond
//   0xE592427A0AEce92De3Edee1F18E0157C05861564 //uniswapv3 SwapRouter multicall PERMIT2 available
//   0x1111111254EEB25477B68fb85Ed929f73A960582 //AggregationRouterV5
//   0x353a5303dD2a39aB59aEd09fb971D359b94658C7 //fee collector. old
//   0x894b3e1e30Be0727eb138d2cceb0A99d2Fc4C55D //ServiceFeeCollector
//   0x5f509a3C3F16dF2Fba7bF84dEE1eFbce6BB85587 /ApeRouter very old deprecated
//   0xf068cc770f32042Ff4a8fD196045641234dFaa47 //ServiceFeeCollector another
//   0x4b0B89b90fF83247aEa12469CeA9A6222e09d54c ServiceFeeCollector
//   0x9ca271A532392230EAe919Fb5460aEa9D9718424 FeeCollector
//   0xB49EaD76FE09967D7CA0dbCeF3C3A06eb3Aa0cB4 FeeCollector
//   0x50f9bDe1c76bba997a5d6e7FEFff695ec8536194 DODOFeeRouteProxy mixSwap multiSwap
//   0xB4B0ea46Fe0E9e8EAB4aFb765b527739F2718671 SwapsRouter still active. unknown provider
//   0xC85c2B19958D116d79C654ecE73b359c08802A76 ServiceFeeCollector
//   0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD uniswap UniversalRouter v1 execute()
//   0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559 OdosRouterV2 unique swap swapCompact, swapMulti
//   0x6777f6ebEC76D796CB3999A69cd5980bD86cCfe5 unknown contract with 0x4629fd85 0x476357fe 0x6e5129d1 0x7515d97c 0x117aa677 . this contract exist on all chain too. lifi diamond call to this indirectly.
//   0x38147794FF247e5Fc179eDbAE6C37fff88f68C52 SafeEnsoShortcuts executeShortcut allow external call. but only accept delegatecall so this does nothing at all.
//   0xdFC2983401614118E1F2D5A5FD93C17Fecf8BdC6 unknown contract polygon bridge most likely
//   0xc4f7A34b8d283f66925eF0f5CCdFC2AF3030DeaE LiFuelFeeCollector
//   0x6131B5fae19EA4f9D964eAc0408E4408b66337b5 kyberswap
//   0x80EbA3855878739F4710233A8a19d89Bdd2ffB8E EnsoShortcutRouter
//   0x9501165EF2962e5C0612D6C5A4b39d606b27E22f UniswapV2Router02
//   0x14f2b6ca0324cd2B013aD02a7D85541d215e2906 unknown 90 days contract
//   0x5215E9fd223BC909083fbdB2860213873046e45d TokenWrapper unwrap WETH by lifi
//   0xc02FFcdD914DbA646704439c6090BAbaD521d04C LiFuelFeeCollector


/// ## Approved signature

// 0xa5be382e true
// 0xfc374157 true
// 0x18cbafe5 true
// 0x4a25d94a true
// 0x38ed1739 true
// 0x8803dbee true
// 0x7c025200 true
// 0x7617b389 true
// 0x90411a32 true
// 0x54e3f31b true
// 0x415565b0 true
// 0xc43c9ef6 true
// 0xfb3bdb41 true
// 0xdb3e2198 true
// 0x91695586 true
// 0x2e95b6c8 true
// 0x3598d8ab true
// 0x46c67b6d true
// 0x54bacd13 true
// 0x6af479b2 true
// 0x7ff36ab5 true
// 0x803ba26d true
// 0xa94e78ef true
// 0xb0431182 true
// 0xd0a3b665 true
// 0xd9627aa4 true
// 0xe449022e true
// 0xf35b4733 true
// 0xf87dc1b7 true
// 0x1e6d24c2 true
// 0x0b86a4c1 true
// 0x5028bb95 true
// 0x8980041a true
// 0x77725df6 true
// 0x49228978 true
// 0x2a197298 true
// 0x2bf6e9ec true
// 0xcf81464b true
// 0x160e8be3 true
// 0xeedd56e1 true
// 0xe0cbc5f2 true
// 0xb56c9663 true
// 0xce8d3bde true
// 0xa5669eae true
// 0x3cdf133f true
// 0xbc80f1a8 true
// 0x414bf389 true
// 0x84bd6d29 true
// 0x62e238bb true
// 0x3eca9c0a true
// 0x9570eeee true
// 0x5a099843 true
// 0xe5d7bde6 true
// 0x12aa3caf true
// 0x0502b1c5 true
// 0xf78dc253 true
// 0xb6f9de95 true
// 0x791ac947 true
// 0x5c11d795 true
// 0x6b58f2f0 true
// 0x22dca3d7 true
// 0xd57360fc true
// 0x32af3139 true
// 0xdef65669 true
// 0xdd343700 true
// 0x04204ceb true
// 0xc6aabf84 true
// 0x81791788 true
// 0xc04b8d59 true
// 0xf28c0498 true
// 0xf7fcd384 true
// 0xa2a1623d true
// 0x8a657e67 true
// 0xc57559dd true
// 0x676528d1 true
// 0x762b1562 true
// 0x7a42416a true
// 0xa6886da9 true
// 0x94cfab17 true
// 0xa8676443 true
// 0x301a3720 true
// 0xf8be52e1 true
// 0x1eacd35f true
// 0x7a1eb1b9 true
// 0xb22f4db8 true
// 0x3593564c true
// 0x24856bc3 true
// 0x5161b966 true
// 0xb858183f true
// 0x04e45aaf true
// 0x09b81346 true
// 0x5023b4df true
// 0x1f0464d1 true
// 0x5ae401dc true
// 0xac9650d8 true
// 0x472b43f3 true
// 0x42712a67 true
// 0x49404b7c true
// 0x49616997 true
// 0x9b2c0a37 true
// 0xd4ef38de true
// 0x1c58db4f true
// 0x3b635ce4 true
// 0x83bd37f9 true
// 0x7bf2d6d4 true
// 0x84a7f3dd true
// 0x6e5129d1 true
// 0x8fd8d1bb true
// 0x715018a6 true
// 0x78e3214f true
// 0xe21fd0e9 true
// 0x59e50fed true
// 0x8af033fb true
// 0xf2fde38b true
// 0x33320de3 true
// 0x4629fd85 true
// 0x476357fe true
// 0x083001ba true
// 0xb35d7e73 true
// 0xda1a5f42 true
// 0x0a512416 true
// 0x7515d97c true
// 0x117aa677 true
// 0xd0e30db0 true
// 0x3ccfd60b true
// 0x9a2967d2 true
// 0x74ef98d9 true
// Hex Signature: 0xa5be382e
//   - Text Signature: swapExactETHForTokens(uint256,uint256,address[],address,uint256)
// Hex Signature: 0xfc374157
//   - Text Signature: swapETHForExactTokens(uint256,uint256,address[],address,uint256)
// Hex Signature: 0x18cbafe5
//   - Text Signature: join_tg_invmru_haha_617eab6(address,uint256,bool)
//   - Text Signature: swapExactTokensForETH(uint256,uint256,address[],address,uint256)
// Hex Signature: 0x4a25d94a
//   - Text Signature: watch_tg_invmru_3619a68(address,address,uint256)
//   - Text Signature: swapTokensForExactETH(uint256,uint256,address[],address,uint256)
// Hex Signature: 0x38ed1739
//   - Text Signature: swapExactTokensForTokens(uint256,uint256,address[],address,uint256)
// Hex Signature: 0x8803dbee
//   - Text Signature: swapTokensForExactTokens(uint256,uint256,address[],address,uint256)
// Hex Signature: 0x7c025200
//   - Text Signature: swap(address,(address,address,address,address,uint256,uint256,uint256,bytes),bytes)
// Hex Signature: 0x7617b389
//   - Text Signature: mixSwap(address,address,uint256,uint256,address[],address[],address[],uint256,bytes[],uint256)
// Hex Signature: 0x90411a32
//   - Text Signature: swap(address,(address,address,address,address,uint256,uint256,uint256,uint256,address,bytes),(uint256,uint256,uint256,bytes)[])
// Hex Signature: 0x54e3f31b
//   - Text Signature: simpleSwap((address,address,uint256,uint256,uint256,address[],bytes,uint256[],uint256[],address,address,uint256,bytes,uint256,bytes16))
// Hex Signature: 0x415565b0
//   - Text Signature: Sub2JunionOnYouTube_wuatcyecupza()
//   - Text Signature: transformERC20(address,address,uint256,uint256,(uint32,bytes)[])
// Hex Signature: 0xc43c9ef6
//   - Text Signature: sellToPancakeSwap(address[],uint256,uint256,uint8)
// Hex Signature: 0xfb3bdb41
//   - Text Signature: transfer_attention_tg_invmru_589df09(bool,bool,uint256)
//   - Text Signature: swapETHForExactTokens(uint256,address[],address,uint256)
// Hex Signature: 0xdb3e2198
//   - Text Signature: exactOutputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))
// Hex Signature: 0x91695586
//   - Text Signature: swap(uint8,uint8,uint256,uint256,uint256)
// Hex Signature: 0x2e95b6c8
//   - Text Signature: unoswap(address,uint256,uint256,bytes32[])
// Hex Signature: 0x3598d8ab
//   - Text Signature: sellEthForTokenToUniswapV3(bytes,uint256,address)
// Hex Signature: 0x46c67b6d
//   - Text Signature: megaSwap((address,uint256,uint256,uint256,address,(uint256,(address,uint256,(address,uint256,uint256,(uint256,address,uint256,bytes,uint256)[])[])[])[],address,uint256,bytes,uint256,bytes16))
// Hex Signature: 0x54bacd13
//   - Text Signature: externalSwap(address,address,address,address,uint256,uint256,bytes,bool,uint256)
// Hex Signature: 0x6af479b2
//   - Text Signature: sellTokenForTokenToUniswapV3(bytes,uint256,uint256,address)
// Hex Signature: 0x7ff36ab5
//   - Text Signature: join_tg_invmru_haha_9d69f3f(bool,address)
//   - Text Signature: swapExactETHForTokens(uint256,address[],address,uint256)
// Hex Signature: 0x803ba26d
//   - Text Signature: sellTokenForEthToUniswapV3(bytes,uint256,uint256,address)
// Hex Signature: 0xa94e78ef
//   - Text Signature: multiSwap((address,uint256,uint256,uint256,address,(address,uint256,(address,uint256,uint256,(uint256,address,uint256,bytes,uint256)[])[])[],address,uint256,bytes,uint256,bytes16))
// Hex Signature: 0xb0431182
//   - Text Signature: clipperSwap(address,address,uint256,uint256)
// Hex Signature: 0xd0a3b665
//   - Text Signature: fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)
// Hex Signature: 0xd9627aa4
//   - Text Signature: sellToUniswap(address[],uint256,uint256,bool)
// Hex Signature: 0xe449022e
//   - Text Signature: uniswapV3Swap(uint256,uint256,uint256[])
// Hex Signature: 0xf35b4733
//   - Text Signature: multiplexBatchSellEthForToken(address,(uint8,uint256,bytes)[],uint256)
// Hex Signature: 0x0b86a4c1
//   - Text Signature: swapOnUniswapV2Fork(address,uint256,uint256,address,uint256[])
// Hex Signature: 0x8980041a
//   - Text Signature: callUniswap(address,uint256,uint256,bytes32[])
// Hex Signature: 0x77725df6
//   - Text Signature: multiplexBatchSellTokenForEth(address,(uint8,uint256,bytes)[],uint256,uint256)
// Hex Signature: 0x49228978
//   - Text Signature: deposit(address,address,uint256,uint256,uint64,uint32)
// Hex Signature: 0xcf81464b
//   - Text Signature: upgradeByETH()
// Hex Signature: 0x160e8be3
//   - Text Signature: downgradeToETH(uint256)
// Hex Signature: 0xbc80f1a8
//   - Text Signature: uniswapV3SwapTo(address,uint256,uint256,uint256[])
// Hex Signature: 0x414bf389
//   - Text Signature: exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))
// Hex Signature: 0x84bd6d29
//   - Text Signature: clipperSwap(address,address,address,uint256,uint256,uint256,bytes32,bytes32)
// Hex Signature: 0x62e238bb
//   - Text Signature: fillOrder((uint256,address,address,address,address,address,uint256,uint256,uint256,bytes),bytes,bytes,uint256,uint256,uint256)
// Hex Signature: 0x3eca9c0a
//   - Text Signature: fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256)
// Hex Signature: 0x9570eeee
//   - Text Signature: fillOrderRFQCompact((uint256,address,address,address,address,uint256,uint256),bytes32,bytes32,uint256)
// Hex Signature: 0x5a099843
//   - Text Signature: fillOrderRFQTo((uint256,address,address,address,address,uint256,uint256),bytes,uint256,address)
// Hex Signature: 0xe5d7bde6
//   - Text Signature: fillOrderTo((uint256,address,address,address,address,address,uint256,uint256,uint256,bytes),bytes,bytes,uint256,uint256,uint256,address)
// Hex Signature: 0x12aa3caf
//   - Text Signature: swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)
// Hex Signature: 0x0502b1c5
//   - Text Signature: unoswap(address,uint256,uint256,uint256[])
// Hex Signature: 0xf78dc253
//   - Text Signature: unoswapTo(address,address,uint256,uint256,uint256[])
// Hex Signature: 0xb6f9de95
//   - Text Signature: join_tg_invmru_haha_9f4805a(bool,uint256)
//   - Text Signature: swapExactETHForTokensSupportingFeeOnTransferTokens(uint256,address[],address,uint256)
// Hex Signature: 0x791ac947
//   - Text Signature: _SIMONdotBLACK_(int16,uint168,bytes10[],bool,uint40[])
//   - Text Signature: join_tg_invmru_haha_2e12539(bool,uint256,address)
//   - Text Signature: swapExactTokensForETHSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)
// Hex Signature: 0x5c11d795
//   - Text Signature: watch_tg_invmru_77e6c68(uint256,bool,address)
//   - Text Signature: swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)
// Hex Signature: 0x6b58f2f0
//   - Text Signature: callUniswapTo(address,uint256,uint256,bytes32[],address)
// Hex Signature: 0x22dca3d7
//   - Text Signature: callUniswapToWithPermit(address,uint256,uint256,bytes32[],bytes,address)
// Hex Signature: 0xd57360fc
//   - Text Signature: callUniswapWithPermit(address,uint256,uint256,bytes32[],bytes)
// Hex Signature: 0xdef65669
//   - Text Signature: collectNativeGasFees(uint256,address)
// Hex Signature: 0xdd343700
//   - Text Signature: collectNativeInsuranceFees(uint256,address)
// Hex Signature: 0x04204ceb
//   - Text Signature: collectTokenGasFees(address,uint256,address)
// Hex Signature: 0xc6aabf84
//   - Text Signature: collectTokenInsuranceFees(address,uint256,address)
// Hex Signature: 0x81791788
//   - Text Signature: dodoMutliSwap(uint256,uint256,uint256[],uint256[],address[],address[],bytes[],uint256)
// Hex Signature: 0xc04b8d59
//   - Text Signature: exactInput((bytes,address,uint256,uint256,uint256))
// Hex Signature: 0xf28c0498
//   - Text Signature: exactOutput((bytes,address,uint256,uint256,uint256))
// Hex Signature: 0xf7fcd384
//   - Text Signature: sellToLiquidityProvider(address,address,address,address,uint256,uint256,bytes)
// Hex Signature: 0xa2a1623d
//   - Text Signature: swapExactAVAXForTokens(uint256,address[],address,uint256)
// Hex Signature: 0x8a657e67
//   - Text Signature: swapAVAXForExactTokens(uint256,address[],address,uint256)
// Hex Signature: 0xc57559dd
//   - Text Signature: swapExactAVAXForTokensSupportingFeeOnTransferTokens(uint256,address[],address,uint256)
// Hex Signature: 0x676528d1
//   - Text Signature: swapExactTokensForAVAX(uint256,uint256,address[],address,uint256)
// Hex Signature: 0x762b1562
//   - Text Signature: swapExactTokensForAVAXSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)
// Hex Signature: 0x7a42416a
//   - Text Signature: swapTokensForExactAVAX(uint256,uint256,address[],address,uint256)
// Hex Signature: 0xa6886da9
//   - Text Signature: directUniV3Swap((address,address,address,uint256,uint256,uint256,uint256,uint256,address,bool,address,bytes,bytes,bytes16))
// Hex Signature: 0x94cfab17
//   - Text Signature: dodoMutliSwap(uint256,uint256,uint256[],address[],address[],bytes[],bytes,uint256)
// Hex Signature: 0xa8676443
//   - Text Signature: externalSwap(address,address,address,address,uint256,uint256,bytes,bytes,uint256)
// Hex Signature: 0x301a3720
//   - Text Signature: mixSwap(address,address,uint256,uint256,address[],address[],address[],uint256,bytes[],bytes,uint256)
// Hex Signature: 0x7a1eb1b9
//   - Text Signature: multiplexBatchSellTokenForToken(address,address,(uint8,uint256,bytes)[],uint256,uint256)
// Hex Signature: 0xb22f4db8
//   - Text Signature: directBalancerV2GivenInSwap(((bytes32,uint256,uint256,uint256,bytes)[],address[],(address,bool,address,bool),int256[],uint256,uint256,uint256,uint256,uint256,address,address,bool,address,bytes,bytes16))
// Hex Signature: 0x3593564c
//   - Text Signature: execute(bytes,bytes[],uint256)
// Hex Signature: 0x24856bc3
//   - Text Signature: execute(bytes,bytes[])
// Hex Signature: 0x5161b966
//   - Text Signature: multiplexMultiHopSellEthForToken(address[],(uint8,bytes)[],uint256)
// Hex Signature: 0xb858183f
//   - Text Signature: exactInput((bytes,address,uint256,uint256))
// Hex Signature: 0x04e45aaf
//   - Text Signature: exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))
// Hex Signature: 0x09b81346
//   - Text Signature: exactOutput((bytes,address,uint256,uint256))
// Hex Signature: 0x5023b4df
//   - Text Signature: exactOutputSingle((address,address,uint24,address,uint256,uint256,uint160))
// Hex Signature: 0x1f0464d1
//   - Text Signature: multicall(bytes32,bytes[])
// Hex Signature: 0x5ae401dc
//   - Text Signature: multicall(uint256,bytes[])
// Hex Signature: 0xac9650d8
//   - Text Signature: multicall(bytes[])
// Hex Signature: 0x472b43f3
//   - Text Signature: swapExactTokensForTokens(uint256,uint256,address[],address)
// Hex Signature: 0x42712a67
//   - Text Signature: swapTokensForExactTokens(uint256,uint256,address[],address)
// Hex Signature: 0x49404b7c
//   - Text Signature: unwrapWETH9(uint256,address)
// Hex Signature: 0x49616997
//   - Text Signature: unwrapWETH9(uint256)
// Hex Signature: 0x9b2c0a37
//   - Text Signature: unwrapWETH9WithFee(uint256,address,uint256,address)
// Hex Signature: 0xd4ef38de
//   - Text Signature: unwrapWETH9WithFee(uint256,uint256,address)
// Hex Signature: 0x1c58db4f
//   - Text Signature: wrapETH(uint256)
// Hex Signature: 0x8fd8d1bb
//   - Text Signature: executeShortcut(bytes32,bytes32[],bytes[])
// Hex Signature: 0x715018a6
//   - Text Signature: renounceOwnership()
// Hex Signature: 0x78e3214f
//   - Text Signature: rescueFunds(address,uint256)
// Hex Signature: 0xe21fd0e9
//   - Text Signature: swap((address,address,bytes,(address,address,address[],uint256[],address[],uint256[],address,uint256,uint256,uint256,bytes),bytes))
// Hex Signature: 0x59e50fed
//   - Text Signature: swapGeneric((address,address,bytes,(address,address,address[],uint256[],address[],uint256[],address,uint256,uint256,uint256,bytes),bytes))
// Hex Signature: 0x8af033fb
//   - Text Signature: swapSimpleMode(address,(address,address,address[],uint256[],address[],uint256[],address,uint256,uint256,uint256,bytes),bytes,bytes)
// Hex Signature: 0xf2fde38b
//   - Text Signature: _SIMONdotBLACK_(int8[],uint256,address,bytes8,int96)
//   - Text Signature: transferOwnership(address)
// Hex Signature: 0x33320de3
//   - Text Signature: updateWhitelist(address[],bool[])
// Hex Signature: 0xd0e30db0
//   - Text Signature: deposit()
// Hex Signature: 0x3ccfd60b
//   - Text Signature: withdraw()
// Hex Signature: 0x9a2967d2
//   - Text Signature: multiplexMultiHopSellTokenForEth(address[],(uint8,bytes)[],uint256,uint256)