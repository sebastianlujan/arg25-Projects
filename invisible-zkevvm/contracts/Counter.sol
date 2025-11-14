// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {FHE, euint64, InEuint64} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title Counter with FHE
 * @dev A simple counter contract with encrypted values using Fhenix CoFHE
 * @dev Follows CoFHE best practices: encrypted constants, proper access control
 */
contract Counter {
    // Encrypted counter value
    euint64 private _encryptedNumber;

    // Encrypted constants for gas optimization (CoFHE best practice)
    euint64 private EUINT64_ZERO;
    euint64 private EUINT64_ONE;

    event NumberSet(address indexed setter);
    event NumberIncremented(address indexed caller);
    event NumberAdded(address indexed caller);
    event NumberMultiplied(address indexed caller);

    constructor() {
        // Initialize encrypted constants once in constructor to save gas
        EUINT64_ZERO = FHE.asEuint64(0);
        EUINT64_ONE = FHE.asEuint64(1);
        
        // Initialize counter to encrypted 0
        _encryptedNumber = EUINT64_ZERO;
    }

    /**
     * @dev Sets the encrypted number to a new encrypted value
     * @param newNumber The new encrypted value (InEuint64)
     * @dev The input must be encrypted using cofhejs before calling
     */
    function setNumber(InEuint64 memory newNumber) public {
        _encryptedNumber = FHE.asEuint64(newNumber);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(_encryptedNumber);
        FHE.allowSender(_encryptedNumber);
        
        emit NumberSet(msg.sender);
    }

    /**
     * @dev Increments the encrypted number by 1
     * @dev Uses pre-encrypted constant to save gas
     */
    function increment() public {
        _encryptedNumber = FHE.add(_encryptedNumber, EUINT64_ONE);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(_encryptedNumber);
        
        emit NumberIncremented(msg.sender);
    }

    /**
     * @dev Adds an encrypted value to the encrypted number
     * @param value The encrypted value to add (InEuint64)
     * @dev The input must be encrypted using cofhejs before calling
     */
    function addNumber(InEuint64 memory value) public {
        euint64 encryptedValue = FHE.asEuint64(value);
        _encryptedNumber = FHE.add(_encryptedNumber, encryptedValue);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(_encryptedNumber);
        
        emit NumberAdded(msg.sender);
    }

    /**
     * @dev Multiplies the encrypted number by an encrypted value
     * @param value The encrypted multiplier (InEuint64)
     * @dev The input must be encrypted using cofhejs before calling
     */
    function mulNumber(InEuint64 memory value) public {
        euint64 encryptedValue = FHE.asEuint64(value);
        _encryptedNumber = FHE.mul(_encryptedNumber, encryptedValue);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(_encryptedNumber);
        
        emit NumberMultiplied(msg.sender);
    }

    /**
     * @dev Gets the encrypted number
     * @return The encrypted number (euint64)
     * @dev To decrypt, use FHE.decrypt() and then FHE.getDecryptResultSafe()
     */
    function getEncryptedNumber() public view returns (euint64) {
        return _encryptedNumber;
    }

    /**
     * @dev Gets the decrypted number if available
     * @return result The decrypted number (0 if not yet decrypted)
     * @return decrypted Whether the number has been decrypted
     * @dev Use FHE.decrypt() first to request decryption
     */
    function getNumber() public view returns (uint64 result, bool decrypted) {
        (uint256 decryptedResult, bool isDecrypted) = FHE.getDecryptResultSafe(_encryptedNumber);
        result = isDecrypted ? uint64(decryptedResult) : 0;
        decrypted = isDecrypted;
    }

    /**
     * @dev Requests decryption of the encrypted number
     * @dev Only authorized parties can decrypt
     */
    function decryptNumber() public {
        FHE.decrypt(_encryptedNumber);
    }
}

