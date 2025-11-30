// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./external/council/CoreVoting.sol";

/**
 * @title ArcadeGSCCoreVoting
 * @author Non-Fungible Technologies, Inc.
 *
 * The Arcade GSC Core Voting contract allows members of the GSC vault to vote on and execute proposals
 * in an instance of governance separate from general governance votes.
 */
contract ArcadeGSCCoreVoting is CoreVoting {
    // ==================================== CONSTRUCTOR ================================================

    /**
     * @notice Constructs the contract by setting deployment variables.
     *
     * @param timelock                  The timelock contract.
     * @param baseQuorum                The default quorum for all functions with no set quorum.
     * @param minProposalPower          The minimum voting power needed to submit a proposal.
     * @param gsc                       The governance steering committee contract.
     * @param votingVaults              The initial approved voting vaults.
     */
    constructor(
        address timelock,//signer 0
        uint256 baseQuorum,//3
        uint256 minProposalPower,//1
        address gsc,// zero
        address[] memory votingVaults// [arcadeGSCVault]
    ) CoreVoting(timelock, baseQuorum, minProposalPower, gsc, votingVaults) {}
}
