//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../core/BaseGuard.sol";

/**
 * @title SafeGuard
 * @author Amir M. Shirif
 * @notice A Telcoin Laboratories Contract
 * @notice Designed to protect against non-compliant votes
 */
contract SafeGuard is BaseGuard, Ownable {
    error PreviouslyVetoed(bytes32 hash);

    // Mapping of transaction hash to its veto status
    mapping(bytes32 => bool) public transactionHashes;
    uint256[] public nonces;

    constructor() Ownable(_msgSender()) {}

    /**
     * @notice Allows the contract owner to veto a transaction by its hash
     * @dev restricted to onlyOwner
     * @param transactionHash Hash of the transaction to be vetoed
     * @param nonce Nonce of the transaction
     */
    function vetoTransaction(
        bytes32 transactionHash,
        uint256 nonce
    ) public onlyOwner {
        // Revert if the transaction has already been vetoed
        if (transactionHashes[transactionHash])
            revert PreviouslyVetoed(transactionHash);
        // Mark the transaction as vetoed
        transactionHashes[transactionHash] = true;
        // Add the nonce of the transaction to the nonces array
        nonces.push(nonce);
    }

    /**
     * @dev Checks if a transaction has been vetoed by its hash
     * @param to Address of the recipient of the transaction
     * @param value Value of the transaction
     * @param data Data of the transaction
     * @param operation Operation of the transaction
     */
    function checkTransaction(//@note safeGuard is gnosis transaction guard
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256,//safeTxGas
        uint256,//basegas
        uint256,//gasprice
        address,//gastoken
        address payable,//refundreceiver
        bytes memory,//signatures
        address//msgsender //@audit where msg.sender come from? Why relied on Reality contract?
    ) external view override {//@ maybe this is msg.sender https://github.com/gnosisguild/zodiac/blob/master/contracts/core/Module.sol
        // cycles through possible transactions //@ RealityModule inherit from Module or https://github.com/gnosisguild/zodiac-module-reality/blob/main/contracts/RealityModule.sol
        for (uint256 i = 0; i < nonces.length; i++) {//@audit how many nonces length before it crash?
            bytes32 transactionHash = IReality(_msgSender()).getTransactionHash(//@ keccak256( generateTransactionHashData(to, value, data, operation, nonce)
                to,//@audit all module is proxy when created
                value,//@note module call exec()
                data,
                operation,
                nonces[i]//@audit who is msg.sender? It is realityModule is correct. But why not other module? What happen with duplicate getTransactionHash?
            );
            require(
                !transactionHashes[transactionHash],
                "SafeGuard: transaction has been vetoed"
            );
        }
    }
//@note realitymodule call into ExecuteProposalWithIndex https://github.com/gnosisguild/zodiac-module-reality/blob/a02e707b61156d3a2f0b2c5a9b6fccd4adddaba7/contracts/RealityModule.sol#L416
//@ which go into original module https://github.com/gnosisguild/zodiac/blob/2656dc04077bdae88c0a60b1d06b941fc0ce0d75/contracts/core/Module.sol#L43-L50C23
//@ it call Avatar to exec. So avatar is possible msg.sender?
//@only GuardableModifier have checkTransaction() call //https://github.com/gnosisguild/zodiac/blob/2656dc04077bdae88c0a60b1d06b941fc0ce0d75/contracts/core/GuardableModifier.sol
//@ module exec call is delegate call. So it is avatar contract delegate to module and exec somethings.
//@ so avatar delegate call executeProposalWithIndex() into RealityModule contract.
//@ RealityModule while being delegate call into safeguard asking who is msg.sender. It is avatar contract.
//@ audit H msg.sender is not module but avatar/gnosis safe contract
//@ avatar Mech is not gnosis safe. https://github.com/gnosisguild/mech/blob/391ca033ea7550d60ba79d722f5ccdd6855e7906/contracts/ZodiacMech.sol
    // not used
    function checkAfterExecution(bytes32, bool) external view override {}
}
