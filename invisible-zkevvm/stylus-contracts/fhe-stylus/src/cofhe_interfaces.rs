//! CoFHE Contract Interfaces
//!
//! This module defines Solidity interfaces for Fhenix CoFHE.
//! FHE.sol is a library that calls ITaskManager contract internally.
//! We can call ITaskManager directly from Stylus contracts.

// Allow non-snake-case names to match Solidity interface conventions
#![allow(non_snake_case)]

use stylus_sdk::prelude::*;
use stylus_sdk::alloy_sol_types;
use stylus_sdk::alloy_primitives::U256;
use alloc::vec::Vec;

// ============ Structs ============

/// Encrypted input structure (matches Solidity EncryptedInput)
#[derive(Debug, Clone)]
pub struct EncryptedInput {
    pub ct_hash: U256,
    pub security_zone: u8,
    pub utype: u8,
    pub signature: Vec<u8>,
}

/// Input encrypted uint64 (matches Solidity InEuint64)
#[derive(Debug, Clone)]
pub struct InEuint64 {
    pub ct_hash: U256,
    pub security_zone: u8,
    pub utype: u8,
    pub signature: Vec<u8>,
}

/// Input encrypted uint8 (matches Solidity InEuint8)
#[derive(Debug, Clone)]
pub struct InEuint8 {
    pub ct_hash: U256,
    pub security_zone: u8,
    pub utype: u8,
    pub signature: Vec<u8>,
}

/// Input encrypted uint32 (matches Solidity InEuint32)
#[derive(Debug, Clone)]
pub struct InEuint32 {
    pub ct_hash: U256,
    pub security_zone: u8,
    pub utype: u8,
    pub signature: Vec<u8>,
}

/// Input encrypted uint256 (matches Solidity InEuint256)
#[derive(Debug, Clone)]
pub struct InEuint256 {
    pub ct_hash: U256,
    pub security_zone: u8,
    pub utype: u8,
    pub signature: Vec<u8>,
}

/// Input encrypted bool (matches Solidity InEbool)
#[derive(Debug, Clone)]
pub struct InEbool {
    pub ct_hash: U256,
    pub security_zone: u8,
    pub utype: u8,
    pub signature: Vec<u8>,
}

// ============ Enums ============

/// Function ID enum (matches Solidity FunctionId)
/// Order matches fheos/precompiles/types/types.go
#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FunctionId {
    _0 = 0,             // GetNetworkKey
    _1 = 1,             // Verify
    Cast = 2,
    SealOutput = 3,
    Select = 4,
    _5 = 5,             // req
    Decrypt = 6,
    Sub = 7,
    Add = 8,
    Xor = 9,
    And = 10,
    Or = 11,
    Not = 12,
    Div = 13,
    Rem = 14,
    Mul = 15,
    Shl = 16,
    Shr = 17,
    Gte = 18,
    Lte = 19,
    Lt = 20,
    Gt = 21,
    Min = 22,
    Max = 23,
    Eq = 24,
    Ne = 25,
    TrivialEncrypt = 26,
    Random = 27,
    Rol = 28,
    Ror = 29,
    Square = 30,
    _31 = 31,
}

// ============ Constants ============

/// Type constants for TFHE (matches Utils library)
pub mod Utils {
    pub const EUINT8_TFHE: u8 = 2;
    pub const EUINT16_TFHE: u8 = 3;
    pub const EUINT32_TFHE: u8 = 4;
    pub const EUINT64_TFHE: u8 = 5;
    pub const EUINT128_TFHE: u8 = 6;
    pub const EUINT256_TFHE: u8 = 8;
    pub const EADDRESS_TFHE: u8 = 7;
    pub const EBOOL_TFHE: u8 = 0;
}

// ============ Interface ============

/// Task Manager Interface (matches Solidity ITaskManager)
///
/// This is the main contract that FHE.sol library calls internally.
/// We can call it directly from Stylus contracts.
sol_interface! {
    interface ITaskManager {
        /// Create a task for FHE operation
        ///
        /// # Parameters
        /// * `returnType` - Type of the return value (EUINT64_TFHE, etc.)
        /// * `funcId` - Function ID (Add, Sub, Mul, etc.)
        /// * `encryptedInputs` - Array of encrypted input hashes
        /// * `extraInputs` - Array of extra inputs (for operations like cast)
        ///
        /// # Returns
        /// * `uint256` - Hash of the encrypted result
        function createTask(
            uint8 returnType,
            uint8 funcId,  // FunctionId enum as uint8
            uint256[] memory encryptedInputs,
            uint256[] memory extraInputs
        ) external returns (uint256);

        /// Create a random task
        function createRandomTask(
            uint8 returnType,
            uint256 seed,
            int32 securityZone
        ) external returns (uint256);

        /// Create a decryption task
        function createDecryptTask(
            uint256 ctHash,
            address requestor
        ) external;

        /// Verify an encrypted input
        /// 
        /// ⚠️ NOTE: In Solidity, this takes EncryptedInput struct.
        /// sol_interface! cannot handle structs directly, so we need to use
        /// a workaround or call it differently.
        /// 
        /// For now, we'll define it with flattened parameters.
        /// The actual Solidity signature is:
        /// function verifyInput(EncryptedInput memory input, address sender) external returns (uint256);
        function verifyInput(
            uint256 ctHash,
            uint8 securityZone,
            uint8 utype,
            bytes calldata signature,
            address sender
        ) external returns (uint256);

        /// Allow an address to access an encrypted value
        function allow(
            uint256 ctHash,
            address account
        ) external;

        /// Check if an address is allowed to access an encrypted value
        function isAllowed(
            uint256 ctHash,
            address account
        ) external view returns (bool);

        /// Allow global access to an encrypted value
        function allowGlobal(uint256 ctHash) external;

        /// Allow transient access (for current transaction only)
        function allowTransient(
            uint256 ctHash,
            address account
        ) external;

        /// Get decryption result safely
        function getDecryptResultSafe(
            uint256 ctHash
        ) external view returns (uint256 result, bool decrypted);

        /// Get decryption result (reverts if not decrypted)
        function getDecryptResult(
            uint256 ctHash
        ) external view returns (uint256);
    }
}

