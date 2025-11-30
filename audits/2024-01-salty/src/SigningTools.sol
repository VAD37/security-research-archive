pragma solidity =0.8.22;


library SigningTools
	{
	// The public address of the signer for verfication of BootstrapBallot voting and default AccessManager
	address constant public EXPECTED_SIGNER = 0x1234519DCA2ef23207E1CA7fd70b96f281893bAa;


	// Verify that the messageHash was signed by the authoratative signer.
    function _verifySignature(bytes32 messageHash, bytes memory signature ) internal pure returns (bool)
    	{
    	require( signature.length == 65, "Invalid signature length" );

		bytes32 r;
		bytes32 s;
		uint8 v;

		assembly
			{
			r := mload (add (signature, 0x20))
			s := mload (add (signature, 0x40))
			v := mload (add (signature, 0x41))//@audit L signature this is different from ECDSA from openzeppelin. This does not work with mask? Still allow v <64 and s upper limit
			}//@ everyone else us and(mload(add(_signature, 0x41)), 0xff) to get v. Then check for v ==27 || v == 28

		address recoveredAddress = ecrecover(messageHash, v, r, s);

        return (recoveredAddress == EXPECTED_SIGNER);
    	}
	}
