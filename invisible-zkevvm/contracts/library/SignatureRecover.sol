// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0
// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense
// Based on official EVVM library: https://github.com/EVVM-org/EVVM-viem-signature-library

pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title Signature Recovery Library
/// @notice Official EVVM library for verifying EIP-191 signatures
/// @dev Follows EVVM specification: "<evvmID>,<functionName>,<inputs>"
library SignatureRecover {
    /// @notice Verifies a signature for EVVM function calls
    /// @param evvmID The EVVM ID string
    /// @param functionName The name of the function being called
    /// @param inputs The concatenated input parameters (comma-separated)
    /// @param signature The signature to verify
    /// @param expectedSigner The address that should have signed the message
    /// @return True if the signature is valid and matches the expected signer
    /// @dev Message format: "<evvmID>,<functionName>,<inputs>"
    function signatureVerification(
        string memory evvmID,
        string memory functionName,
        string memory inputs,
        bytes memory signature,
        address expectedSigner
    ) internal pure returns (bool) {
        return
            recoverSigner(
                string.concat(evvmID, ",", functionName, ",", inputs),
                signature
            ) == expectedSigner;
    }

    /// @notice Recovers the signer address from a message and signature
    /// @param message The message that was signed (EIP-191 format)
    /// @param signature The signature to recover from
    /// @return The address of the signer
    function recoverSigner(
        string memory message,
        bytes memory signature
    ) internal pure returns (address) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n",
                Strings.toString(bytes(message).length),
                message
            )
        );
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        return ecrecover(messageHash, v, r, s);
    }

    /// @notice Splits a signature into its r, s, and v components
    /// @param signature The signature to split (65 bytes)
    /// @return r The r component of the signature
    /// @return s The s component of the signature
    /// @return v The v component of the signature
    function splitSignature(
        bytes memory signature
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(signature.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        // Ensure signature is valid
        if (v < 27) {
            v += 27;
        }
        require(v == 27 || v == 28, "Invalid signature value");
    }
}
