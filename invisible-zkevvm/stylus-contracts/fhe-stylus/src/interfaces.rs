//! FHEVM Precompile Interfaces
//!
//! This module defines Solidity interfaces for FHEVM precompiles deployed on
//! Arbitrum. These interfaces allow Stylus contracts to interact with the
//! existing FHEVM infrastructure.
//!
//! The precompiles handle:
//! - Input verification and proof validation
//! - FHE arithmetic operations (add, sub, mul, div)
//! - FHE comparison operations (eq, ne, lt, gt, le, ge)
//! - FHE bitwise operations (and, or, xor, not, shl, shr)
//! - Access control for encrypted values

use stylus_sdk::prelude::*;
use stylus_sdk::alloy_sol_types;

// Define the Solidity interface for FHEVM Input Verifier
sol_interface! {
    /// Input Verifier Precompile
    ///
    /// Verifies encrypted inputs from users along with their zero-knowledge proofs.
    /// This is the entry point for bringing external encrypted values into the FHE system.
    interface IInputVerifier {
        /// Verifies an encrypted input with its proof and returns a handle
        ///
        /// # Parameters
        /// * `inputHandle` - The encrypted input from the user (32 bytes)
        /// * `inputProof` - Zero-knowledge proof of correct encryption
        /// * `inputType` - Type of the encrypted value (8, 16, 32, 64, 128, 256 bits)
        ///
        /// # Returns
        /// * `bytes32` - Verified handle that can be used in FHE operations
        function verifyInput(
            bytes32 inputHandle,
            bytes calldata inputProof,
            uint8 inputType
        ) external returns (bytes32);

        /// Verifies an encrypted input with user signature
        function verifyInputWithSignature(
            bytes32 inputHandle,
            bytes calldata inputProof,
            uint8 inputType,
            address userAddress
        ) external returns (bytes32);
    }
}

sol_interface! {
    /// FHEVM Operations Precompile
    ///
    /// Core precompile for all FHE arithmetic, comparison, and bitwise operations.
    /// Operations are performed symbolically; actual computation happens off-chain.
    interface IFHEVMPrecompile {
        // ============ Arithmetic Operations ============

        /// Add two encrypted integers
        ///
        /// # Parameters
        /// * `lhs` - Left operand handle
        /// * `rhs` - Right operand handle
        /// * `scalarByte` - 0x00 for encrypted-encrypted, 0x01 for encrypted-scalar
        ///
        /// # Returns
        /// * `bytes32` - Handle to the encrypted result (lhs + rhs)
        function fheAdd(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Subtract two encrypted integers (lhs - rhs)
        function fheSub(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Multiply two encrypted integers
        function fheMul(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Divide two encrypted integers
        function fheDiv(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Compute modulo of two encrypted integers
        function fheRem(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        // ============ Bitwise Operations ============

        /// Bitwise AND of two encrypted integers
        function fheBitAnd(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Bitwise OR of two encrypted integers
        function fheBitOr(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Bitwise XOR of two encrypted integers
        function fheBitXor(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Shift left
        function fheShl(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Shift right
        function fheShr(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Rotate left
        function fheRotl(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Rotate right
        function fheRotr(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        // ============ Comparison Operations ============

        /// Encrypted equality comparison (returns encrypted boolean)
        function fheEq(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Encrypted not-equal comparison
        function fheNe(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Encrypted greater-or-equal comparison
        function fheGe(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Encrypted greater-than comparison
        function fheGt(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Encrypted less-or-equal comparison
        function fheLe(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Encrypted less-than comparison
        function fheLt(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        // ============ Special Operations ============

        /// Minimum of two encrypted integers
        function fheMin(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Maximum of two encrypted integers
        function fheMax(
            bytes32 lhs,
            bytes32 rhs,
            bytes1 scalarByte
        ) external pure returns (bytes32);

        /// Negate an encrypted integer
        function fheNeg(bytes32 ct) external pure returns (bytes32);

        /// Bitwise NOT of an encrypted integer
        function fheNot(bytes32 ct) external pure returns (bytes32);

        /// Conditional selection: if condition then ifTrue else ifFalse
        /// All operands are encrypted
        function fheIfThenElse(
            bytes32 condition,
            bytes32 ifTrue,
            bytes32 ifFalse
        ) external pure returns (bytes32);

        // ============ Random Number Generation ============

        /// Generate a random encrypted integer
        /// Returns a handle to an encrypted random value
        function fheRand(uint8 randType) external returns (bytes32);

        /// Generate a bounded random encrypted integer
        function fheRandBounded(uint256 upperBound, uint8 randType) external returns (bytes32);
    }
}

sol_interface! {
    /// Access Control List (ACL) Precompile
    ///
    /// Manages permissions for who can decrypt and access encrypted values.
    /// Essential for maintaining confidentiality in the FHE system.
    interface IACL {
        /// Allow an address to access an encrypted value
        ///
        /// # Parameters
        /// * `handle` - Handle to the encrypted value
        /// * `account` - Address to grant access to
        ///
        /// # Security
        /// Only the owner of an encrypted value (usually the contract that created it)
        /// can grant access to others.
        function allow(bytes32 handle, address account) external;

        /// Check if an address has permission to access an encrypted value
        ///
        /// # Returns
        /// * `bool` - True if the account has access, false otherwise
        function isAllowed(bytes32 handle, address account) external view returns (bool);

        /// Revoke access to an encrypted value
        function revoke(bytes32 handle, address account) external;

        /// Transfer ownership of an encrypted value to another address
        function transferOwnership(bytes32 handle, address newOwner) external;

        /// Get the owner of an encrypted value
        function getOwner(bytes32 handle) external view returns (address);
    }
}

sol_interface! {
    /// Gateway Contract Interface
    ///
    /// The Gateway handles off-chain decryption requests through the KMS
    /// (Key Management Service). When you need to decrypt a value, you
    /// request it through the Gateway, and it coordinates with the
    /// threshold decryption network.
    interface IGateway {
        /// Request decryption of an encrypted value
        ///
        /// # Parameters
        /// * `ciphertextHandle` - Handle to the encrypted value to decrypt
        /// * `userAddress` - Address requesting the decryption
        ///
        /// # Returns
        /// * `uint256` - Request ID for tracking the decryption
        ///
        /// # Note
        /// The actual decrypted value is returned asynchronously via callback
        function requestDecryption(
            bytes32 ciphertextHandle,
            address userAddress
        ) external returns (uint256);

        /// Check if a decryption request is ready
        function isDecryptionReady(uint256 requestId) external view returns (bool);

        /// Get the decrypted result (only after decryption is complete)
        function getDecryptedValue(uint256 requestId) external view returns (uint256);
    }
}

sol_interface! {
    /// FHE Payment Gateway
    ///
    /// Specialized interface for handling encrypted payment operations.
    /// This is used by contracts like EVVMCore for confidential transactions.
    interface IFHEPayment {
        /// Transfer encrypted amount from one address to another
        ///
        /// # Parameters
        /// * `from` - Source address
        /// * `to` - Destination address
        /// * `encryptedAmount` - Handle to encrypted transfer amount
        ///
        /// # Returns
        /// * `bool` - Success status
        function transferEncrypted(
            address from,
            address to,
            bytes32 encryptedAmount
        ) external returns (bool);
    }
}

sol_interface! {
    /// EVVM Core Contract Interface
    ///
    /// Interface for interacting with the EVVMCore contract which handles
    /// encrypted balance management and payments in the EVVM virtual blockchain.
    interface IEVVMCore {
        /// Process an encrypted payment
        ///
        /// # Parameters
        /// * `from` - Source address
        /// * `to` - Destination address
        /// * `toIdentity` - Destination identity string (can be empty)
        /// * `token` - Token address
        /// * `amountPlaintext` - Amount in plaintext (for signature)
        /// * `inputEncryptedAmount` - Encrypted amount
        /// * `inputAmountProof` - Proof for amount
        /// * `priorityFeePlaintext` - Priority fee in plaintext
        /// * `inputEncryptedPriorityFee` - Encrypted priority fee
        /// * `inputFeeProof` - Proof for fee
        /// * `nonce` - Transaction nonce
        /// * `priorityFlag` - Priority flag
        /// * `executor` - Executor address
        /// * `signature` - Signature bytes
        function pay(
            address from,
            address to,
            string toIdentity,
            address token,
            uint256 amountPlaintext,
            bytes32 inputEncryptedAmount,
            bytes inputAmountProof,
            uint256 priorityFeePlaintext,
            bytes32 inputEncryptedPriorityFee,
            bytes inputFeeProof,
            uint256 nonce,
            bool priorityFlag,
            address executor,
            bytes signature
        ) external;

        /// Get the encrypted balance of a user for a specific token
        function getBalance(address user, address token) external view returns (bytes32);

        /// Check if an address is registered as a staker
        function isAddressStaker(address user) external view returns (bool);

        /// Get the EVVM ID
        function evvmID() external view returns (uint256);
    }
}

// Type constants for input verification
pub const EUINT8_TYPE: u8 = 0;
pub const EUINT16_TYPE: u8 = 1;
pub const EUINT32_TYPE: u8 = 2;
pub const EUINT64_TYPE: u8 = 3;
pub const EUINT128_TYPE: u8 = 4;
pub const EUINT256_TYPE: u8 = 5;
pub const EBOOL_TYPE: u8 = 6;
pub const EADDRESS_TYPE: u8 = 7;

// Scalar byte constants
/// Indicates both operands are encrypted
pub const SCALAR_ENCRYPTED: u8 = 0x00;
/// Indicates the right operand is a plaintext scalar
pub const SCALAR_PLAIN: u8 = 0x01;
