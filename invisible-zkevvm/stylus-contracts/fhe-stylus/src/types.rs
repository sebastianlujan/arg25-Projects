//! Encrypted type system for FHE operations
//!
//! This module provides Rust equivalents for Zama FHEVM encrypted types.
//! All types are simply aliases for `FixedBytes<32>` (bytes32 in Solidity),
//! which already implements all necessary ABI traits for use in Stylus contracts.

use stylus_sdk::alloy_primitives::FixedBytes;

/// Encrypted 64-bit unsigned integer (internal representation)
///
/// Wraps a 32-byte handle that references an encrypted value in the FHEVM system.
/// This is the equivalent of Solidity's `euint64` type.
pub type Euint64 = FixedBytes<32>;

/// External encrypted 64-bit unsigned integer (user input)
///
/// This type represents encrypted values that come from external sources.
/// It's equivalent to Solidity's `externalEuint64`.
pub type ExternalEuint64 = FixedBytes<32>;

/// Encrypted boolean value
///
/// Equivalent to Solidity's `ebool` type.
pub type Ebool = FixedBytes<32>;

/// Encrypted 256-bit unsigned integer
///
/// Equivalent to Solidity's `euint256` type.
pub type Euint256 = FixedBytes<32>;

/// External encrypted 256-bit unsigned integer
pub type ExternalEuint256 = FixedBytes<32>;

// Since these are just type aliases for FixedBytes<32>, they automatically
// inherit all the necessary implementations including:
// - AbiType, AbiEncode, AbiDecode (for contract ABI)
// - Debug, Clone, Copy, PartialEq, Eq, and other common traits
// - Conversion to/from bytes

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_euint64_creation() {
        let bytes = FixedBytes([1u8; 32]);
        let val: Euint64 = bytes;
        assert_eq!(val, bytes);
    }

    #[test]
    fn test_conversions() {
        let bytes = FixedBytes([42u8; 32]);
        let euint: Euint64 = bytes;
        let external: ExternalEuint64 = bytes;

        // Both should be equal since they're the same underlying type
        assert_eq!(euint.as_slice(), external.as_slice());
    }
}
