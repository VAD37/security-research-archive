// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISignatureTransfer} from "permit2/interfaces/ISignatureTransfer.sol";

enum ApprovalType {
    STANDARD,
    PERMIT,
    PERMIT2
}

struct PermitParams {
    ApprovalType approvalType;
    uint256 approvalAmount;
    uint256 nonce;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

abstract contract TransferAction {
    /*//////////////////////////////////////////////////////////////
                               LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Permit;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Permit2
    address public constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;//uniswap permit2 on all chains

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Perform a permit2, a ERC20 permit transferFrom, or a standard transferFrom
    function _transferFrom(//@from SwapAction.sol //@msg.sender for hash is PrbProxy.sol
        address token,//swapParams.assetIn
        address from,//from != address(this) 
        address to,//address(this)
        uint256 amount,//exactAmountIn or swapLimit
        PermitParams memory params//user input PermitParams //@ signature hash  is from PRBproxy contract
    ) internal {
        if (params.approvalType == ApprovalType.PERMIT2) {//@note permit2 transferAction also accept permit from owner with IERC1271.isValidSignature.
            // Consume a permit2 message and transfer tokens. //@nonce is unique so permit hash also unique. signature also unique for each chain.
            ISignatureTransfer(permit2).permitTransferFrom(
                ISignatureTransfer.PermitTransferFrom({
                    permitted: ISignatureTransfer.TokenPermissions({token: token, amount: params.approvalAmount}),
                    nonce: params.nonce,//@nonce is unordered nonce and flipbit. this mean user can send multiple nonce at the same times. 
                    deadline: params.deadline
                }),//@signature sign can approve any amount. but only transfer some of its.
                ISignatureTransfer.SignatureTransferDetails({to: to, requestedAmount: amount}),//@to:address(this),  ,iv: amount <= approvalAmount
                from,//@user input, uniswap check this owner signature nonce
                bytes.concat(params.r, params.s, bytes1(params.v)) // Construct signature //@signature check hash from: domain,(toAddress,amount) ,owner
            );//@audit L TransferAction not support signature lenght 64 bytes. It use 65 bytes version with v ==28. but this is user input. so it can be any value.
            //@permit have internal transfer directly with requestedAmount: amount
        } else if (params.approvalType == ApprovalType.PERMIT) {
            // Consume a standard ERC20 permit message
            IERC20Permit(token).safePermit(//@audit L safePermit from OZ require token also have nonces too. Or derived from OZ ERC20 Permit. Does swell and other staking ETH token support this?
                from,
                to,
                params.approvalAmount,
                params.deadline,
                params.v,
                params.r,
                params.s
            );
            IERC20(token).safeTransferFrom(from, to, amount);//@audit-ok R what happen with leftover allowance?
        } else {//@standard
            // No signature provided, just transfer tokens.
            IERC20(token).safeTransferFrom(from, to, amount);//@audit-ok this is all delegateCall. RH is it possible to craft @from address to be anything
        }//@audit-ok already ignore transfer 0 amount M some token with balancer revert when transferFrom 0 amount token PoolAction.TransferAndJoin with balancer depend on transfer empty 0 token.
    }//@gas issue fix
}
