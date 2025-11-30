// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { IBalancerVault, IERC20 } from "../external/interfaces/Balancer/IBalancerVault.sol";
import { IFlashLoanRecipient } from "../external/interfaces/Balancer/IFlashLoanRecipient.sol";
import { PositionRegistry, PositionBP } from "../accountingManager/Registry.sol";
import { BaseConnector } from "../helpers/BaseConnector.sol";
import "@openzeppelin/contracts-5.0/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts-5.0/token/ERC20/utils/SafeERC20.sol";

contract BalancerFlashLoan is IFlashLoanRecipient, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IBalancerVault internal vault;
    PositionRegistry public registry;
    address caller;

    error Unauthorized(address sender);

    event MakeFlashLoan(IERC20[] tokens, uint256[] amounts);
    event ReceiveFlashLoan(IERC20[] tokens, uint256[] amounts, uint256[] feeAmounts, bytes userData);

    constructor(address _balancerVault, PositionRegistry _registry) {
        require(_balancerVault != address(0));
        require(address(_registry) != address(0));
        vault = IBalancerVault(_balancerVault);//@0xBA12222222228d8Ba445958a75a0704d566BF2C8
        registry = _registry;
    }

    /**
     * @notice Make a flash loan
     * @param tokens - tokens to flash loan
     * @param amounts - amounts to flash loan
     * @param userData - user data for the flash loan (will be decoded after the flash loan is received)
     */
    function makeFlashLoan(IERC20[] memory tokens, uint256[] memory amounts, bytes memory userData)
        external//@note only Keepers can call flashloan Balancer. This was checked inside callback
        nonReentrant//@audit-ok non-Reentrancy check prevent reset caller to zero value.
    {//@tokens,amounts same length check //@note balancer Vault Flashloan have reentrancy guard.
        caller = msg.sender;//@tokens must be sorted in ascending order, non zero address
        emit MakeFlashLoan(tokens, amounts);//@ all token transfered first to this address. before going to next token. All tokens,address accepted, this mean callback can happen in between execution of tokens.
        vault.flashLoan(this, tokens, amounts, userData);//@ call receiveFlashLoan with fee lists and borrow amount
        caller = address(0);//@post condition checking enough is repayed.
    }

    /**
     * @notice Receive the flash loan
     * @param tokens - tokens to flash loan
     * @param amounts - amounts to flash loan
     * @param feeAmounts - fee amounts to flash loan
     * @param userData - user data for the flash loan (used to execute transactions with the flash loaned tokens)
     */
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData//@same as user input above.
    ) external override {
        emit ReceiveFlashLoan(tokens, amounts, feeAmounts, userData);
        require(msg.sender == address(vault));
        (
            uint256 vaultId,
            address receiver,
            address[] memory destinationConnector,
            bytes[] memory callingData,
            uint256[] memory gas
        ) = abi.decode(userData, (uint256, address, address[], bytes[], uint256[]));
        (,,, address keeperContract,, address emergencyManager) = registry.getGovernanceAddresses(vaultId);//@audit-ok keeper only
        if (!(caller == keeperContract)) {//@audit-ok L failed to check emergency manager in flashloan callback.
            revert Unauthorized(caller);
        }//@audit-ok M7 Keepers from different vault can use each other funds. thanks to cross vault permission 
        if (registry.isAnActiveConnector(vaultId, receiver)) {
            for (uint256 i = 0; i < tokens.length; i++) {//@transfer flashloan token to single BaseConnector
                // send the tokens to the receiver
                tokens[i].safeTransfer(receiver, amounts[i]);
                amounts[i] = amounts[i] + feeAmounts[i];//@audit-ok L This happen with fee not increase into amount array.flashloan will fail if activeConnector is disable by vaulter.
            }
            for (uint256 i = 0; i < destinationConnector.length; i++) {//@ make call to a list of address with data and gas
                // execute the transactions
                (bool success,) = destinationConnector[i].call{ value: 0, gas: gas[i] }(callingData[i]);//@audit-ok M7 L how do keepers cleanup stuck token and approval ?
                require(success, "BalancerFlashLoan: Flash loan failed");
            }
            for (uint256 i = 0; i < tokens.length; i++) {//@ take token back from Connector + fee.
                // send the tokens back to this contract
                BaseConnector(receiver).sendTokensToTrustedAddress(address(tokens[i]), amounts[i], address(this), "");
            }//@audit-ok postcheck safe. R sendTokensToTrustedAddress return 0 if failed to transfer due to permission cehck.
        }
        for (uint256 i = 0; i < tokens.length; i++) {//@refund balancer vault with fee
            // send the tokens back to the vault
            tokens[i].safeTransfer(msg.sender, amounts[i]);//@audit-ok M6 DOS flashloan by keepers if someone send some tokens to this contract to exploit null balance check.
            require(tokens[i].balanceOf(address(this)) == 0, "BalancerFlashLoan: Flash loan extra tokens");
        }
    }
}//@note balance flashloan have funny assemblycode queryBatchSwap is non-view function that does not revert if internal call  have return data different from expected result
// balancer Vault.Flashloan() 0xBA12222222228d8Ba445958a75a0704d566BF2C8
// function flashLoan(
//         IFlashLoanRecipient recipient,
//         IERC20[] memory tokens,
//         uint256[] memory amounts,
//         bytes memory userData
//     ) external override nonReentrant whenNotPaused {
//         InputHelpers.ensureInputLengthMatch(tokens.length, amounts.length);

//         uint256[] memory feeAmounts = new uint256[](tokens.length);
//         uint256[] memory preLoanBalances = new uint256[](tokens.length);

//         // Used to ensure `tokens` is sorted in ascending order, which ensures token uniqueness.
//         IERC20 previousToken = IERC20(0);

//         for (uint256 i = 0; i < tokens.length; ++i) {
//             IERC20 token = tokens[i];
//             uint256 amount = amounts[i];

//             _require(token > previousToken, token == IERC20(0) ? Errors.ZERO_TOKEN : Errors.UNSORTED_TOKENS);
//             previousToken = token;

//             preLoanBalances[i] = token.balanceOf(address(this));
//             feeAmounts[i] = _calculateFlashLoanFeeAmount(amount);

//             _require(preLoanBalances[i] >= amount, Errors.INSUFFICIENT_FLASH_LOAN_BALANCE);
//             token.safeTransfer(address(recipient), amount);
//         }

//         recipient.receiveFlashLoan(tokens, amounts, feeAmounts, userData);

//         for (uint256 i = 0; i < tokens.length; ++i) {
//             IERC20 token = tokens[i];
//             uint256 preLoanBalance = preLoanBalances[i];

//             // Checking for loan repayment first (without accounting for fees) makes for simpler debugging, and results
//             // in more accurate revert reasons if the flash loan protocol fee percentage is zero.
//             uint256 postLoanBalance = token.balanceOf(address(this));
//             _require(postLoanBalance >= preLoanBalance, Errors.INVALID_POST_LOAN_BALANCE);

//             // No need for checked arithmetic since we know the loan was fully repaid.
//             uint256 receivedFeeAmount = postLoanBalance - preLoanBalance;
//             _require(receivedFeeAmount >= feeAmounts[i], Errors.INSUFFICIENT_FLASH_LOAN_FEE_AMOUNT);

//             _payFeeAmount(token, receivedFeeAmount);
//             emit FlashLoan(recipient, token, amounts[i], receivedFeeAmount);
//         }
//     }