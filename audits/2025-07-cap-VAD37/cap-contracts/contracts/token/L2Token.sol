// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { OFTPermit } from "./OFTPermit.sol";

/// @title L2 Token
/// @author kexley, Cap Labs, LayerZero Labs
/// @notice L2 Token with permit functions
contract L2Token is OFTPermit {
    /// @dev Initialize the L2 token
    /// @param _name Name of the token
    /// @param _symbol Symbol of the token
    /// @param _lzEndpoint Layerzero endpoint
    /// @param _delegate Delegate capable of making OApp changes
    constructor(string memory _name, string memory _symbol, address _lzEndpoint, address _delegate)//move cToken to L2Token on another network. unclear why moving it away. Something to do with campaigns on multiple network. L2 cheaper for staking and deposit maybe.
        OFTPermit(_name, _symbol, _lzEndpoint, _delegate)//@delegate is vault admin. L1 token is cToken must deposit raw token. and then it is moved to L2 for other purposes.
    { }
}
