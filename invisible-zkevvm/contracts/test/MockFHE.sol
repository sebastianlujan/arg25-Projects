// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MockKMSVerifier
 * @notice Mock contract for FHE input verification in tests
 * @dev This mock accepts all inputs as valid for testing purposes
 */
contract MockKMSVerifier {
    /**
     * @notice Mock verifyInput - always returns true
     * @dev In production, this would verify zero-knowledge proofs
     */
    function verifyInput(
        bytes32 /* inputHandle */,
        address /* userAddress */,
        bytes memory /* inputProof */,
        uint8 /* inputType */
    ) external pure returns (bool) {
        return true;
    }
}

/**
 * @title MockACL
 * @notice Mock Access Control List for FHE operations in tests
 * @dev This mock allows all operations for testing purposes
 */
contract MockACL {
    /**
     * @notice Mock allow - does nothing in tests
     * @dev In production, this would grant decryption permissions
     */
    function allow(
        bytes32 /* ciphertext */,
        address /* account */
    ) external pure {
        // No-op for testing
    }

    /**
     * @notice Mock allowTransient - does nothing in tests
     * @dev In production, this would grant temporary decryption permissions
     */
    function allowTransient(
        bytes32 /* ciphertext */,
        address /* account */
    ) external pure {
        // No-op for testing
    }

    /**
     * @notice Mock allowForDecryption - does nothing in tests
     * @dev In production, this would grant decryption permissions to addresses
     */
    function allowForDecryption(
        bytes32[] memory /* ciphertexts */
    ) external pure {
        // No-op for testing
    }

    /**
     * @notice Mock isAllowed - always returns true
     * @dev In production, this would check if an address can decrypt a ciphertext
     */
    function isAllowed(
        bytes32 /* ciphertext */,
        address /* account */
    ) external pure returns (bool) {
        return true;
    }
}

/**
 * @title MockCoprocessor
 * @notice Mock FHE Coprocessor for tests
 * @dev This mock simulates FHE operations without actual encryption
 */
contract MockCoprocessor {
    /**
     * @notice Mock verifyInput - returns the input as output for testing
     * @dev In production, this would verify the input proof and return a handle
     */
    function verifyInput(
        bytes32 inputHandle,
        address /* callerAddress */,
        bytes memory /* inputProof */,
        uint8 /* inputType */
    ) external pure returns (bytes32) {
        // In tests, just return the input handle as if it was verified
        return inputHandle;
    }

    /**
     * @notice Mock trivialEncrypt - returns encrypted representation of plaintext value
     * @dev In tests, we just wrap the value in a bytes32
     */
    function trivialEncrypt(
        uint256 value,
        uint8 /* toType */
    ) external pure returns (bytes32) {
        // In tests, just return the value as bytes32
        return bytes32(value);
    }

    /**
     * @notice Mock FHE Add operation - returns lhs for simplicity
     * @dev In production, this would perform actual FHE addition
     */
    function fheAdd(
        bytes32 lhs,
        bytes32 /* rhs */,
        bytes1 /* scalarByte */
    ) external pure returns (bytes32) {
        return lhs;
    }

    /**
     * @notice Mock FHE Sub operation - returns lhs for simplicity
     * @dev In production, this would perform actual FHE subtraction
     */
    function fheSub(
        bytes32 lhs,
        bytes32 /* rhs */,
        bytes1 /* scalarByte */
    ) external pure returns (bytes32) {
        return lhs;
    }

    /**
     * @notice Fallback to handle any other FHE operations
     * @dev Returns a mock value for any unimplemented FHE function
     */
    fallback(bytes calldata) external returns (bytes memory) {
        // Return a default mock result (bytes32) for any FHE operation
        return abi.encode(bytes32(uint256(1)));
    }
}
