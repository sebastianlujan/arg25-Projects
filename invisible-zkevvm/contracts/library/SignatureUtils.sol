// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SignatureRecover} from "./SignatureRecover.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title Signature Utils Library
/// @notice Utility library for verifying EVVM payment signatures
/// @dev Follows EVVM specification for message signing
library SignatureUtils {
    /**
     * @notice Converts an address to a lowercase hex string
     * @param addr Address to convert
     * @return String representation of the address in lowercase
     */
    function addressToString(address addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    /**
     * @notice Verifies the message signed for a payment transaction
     * @param evvmID EVVM chain ID
     * @param signer Address of the user who signed the message
     * @param receiverAddress Address of the receiver (or address(0) if using identity)
     * @param receiverIdentity Identity of the receiver (empty string if using address)
     * @param token Address of the token to send
     * @param amount Amount to send (plaintext for signature verification)
     * @param priorityFee Priority fee to send to the staker
     * @param nonce Nonce of the transaction
     * @param priorityFlag If the transaction is priority or not
     * @param executor The executor of the transaction
     * @param signature Signature of the user who wants to send the payment
     * @return True if the signature is valid
     * @dev Message format: "<evvmID>,pay,<to>,<token>,<amount>,<priorityFee>,<nonce>,<priorityFlag>,<executor>"
     */
    function verifyMessageSignedForPay(
        uint256 evvmID,
        address signer,
        address receiverAddress,
        string memory receiverIdentity,
        address token,
        uint256 amount,
        uint256 priorityFee,
        uint256 nonce,
        bool priorityFlag,
        address executor,
        bytes memory signature
    ) internal pure returns (bool) {
        // Build the receiver string (use identity if address is zero, otherwise use address)
        string memory receiver = receiverAddress == address(0)
            ? receiverIdentity
            : addressToString(receiverAddress);

        // Build the inputs string according to EVVM specification
        string memory inputs = string.concat(
            receiver,
            ",",
            addressToString(token),
            ",",
            Strings.toString(amount),
            ",",
            Strings.toString(priorityFee),
            ",",
            Strings.toString(nonce),
            ",",
            priorityFlag ? "true" : "false",
            ",",
            addressToString(executor)
        );

        // Verify signature using SignatureRecover
        return SignatureRecover.signatureVerification(
            Strings.toString(evvmID),
            "pay",
            inputs,
            signature,
            signer
        );
    }
}

