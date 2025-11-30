// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

contract echidna_test_solo {
    mapping(uint64 => uint256) internal s_executionStates;
    enum MessageExecutionState {
        UNTOUCHED,
        IN_PROGRESS,
        SUCCESS,
        FAILURE
    }
    // The size of the execution state in bits
    uint256 private constant MESSAGE_EXECUTION_STATE_BIT_WIDTH = 2;
    // The mask for the execution state bits
    uint256 private constant MESSAGE_EXECUTION_STATE_MASK =
        (1 << MESSAGE_EXECUTION_STATE_BIT_WIDTH) - 1;

    MessageExecutionState _stateOne;
    MessageExecutionState _stateTwo;

    constructor() {
        // _stateOne = MessageExecutionState.IN_PROGRESS;
        // _stateTwo = MessageExecutionState.SUCCESS;
        // _setExecutionState(2, _stateOne);
        // _setExecutionState(3, _stateTwo);
    }

    function setStateOne(MessageExecutionState newState) public {
        _stateOne = newState;
        _setExecutionState(2, newState);
    }

    function setStateTwo(MessageExecutionState newState) public {
        _stateTwo = newState;
        _setExecutionState(3, newState);
    }

    function getExecutionState(
        uint64 sequenceNumber
    ) internal view returns (MessageExecutionState) {
        return
            MessageExecutionState(
                (s_executionStates[sequenceNumber / 128] >>
                    ((sequenceNumber % 128) *
                        MESSAGE_EXECUTION_STATE_BIT_WIDTH)) &
                    MESSAGE_EXECUTION_STATE_MASK
            );
    }

    /// @notice Sets a new execution state for a given sequence number. It will overwrite any existing state.
    /// @param sequenceNumber The sequence number for which the state will be saved.
    /// @param newState The new value the state will be in after this function is called.
    /// @dev we use the literal number 128 because using a constant increased gas usage.
    function _setExecutionState(
        uint64 sequenceNumber,
        MessageExecutionState newState
    ) internal {
        uint256 offset = (sequenceNumber % 128) *
            MESSAGE_EXECUTION_STATE_BIT_WIDTH; // * 2
        uint256 bitmap = s_executionStates[sequenceNumber / 128];

        // to unset any potential existing state we zero the bits of the section the state occupies,
        // then we do an AND operation to blank out any existing state for the section.
        bitmap &= ~(MESSAGE_EXECUTION_STATE_MASK << offset);

        // Set the new state
        bitmap |= uint256(newState) << offset;

        s_executionStates[sequenceNumber / 128] = bitmap;
    }

    function echidna_test_both() public returns (bool) {
        if (getExecutionState(2) != _stateOne) return false;
        if (getExecutionState(3) != _stateTwo) return false;
        return true;
    }
    function echidna_test_one() public returns (bool) {
        if (getExecutionState(2) != _stateOne) return false;
        return true;
    }
    function echidna_test_two() public returns (bool) {
        if (getExecutionState(3) != _stateTwo) return false;
        return true;
    }
}
