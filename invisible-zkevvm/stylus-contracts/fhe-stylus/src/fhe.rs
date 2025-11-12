//! FHE Operations API
//!
//! This module provides type definitions and documentation for FHE operations.
//! In practice, you should use the FHEVM precompile interfaces directly from
//! your contract code (see `fhe_stylus::interfaces`).
//!
//! # Example Usage in Contracts
//! ```ignore
//! use fhe_stylus::prelude::*;
//! use fhe_stylus::interfaces::{IInputVerifier, IFHEVMPrecompile, IACL};
//! use fhe_stylus::config::get_config;
//! use stylus_sdk::call::Call;
//!
//! #[storage]
//! #[entrypoint]
//! pub struct MyContract {
//!     balances: StorageMap<Address, Euint64>,
//! }
//!
//! #[public]
//! impl MyContract {
//!     pub fn transfer(&mut self, to: Address, amount: ExternalEuint64, proof: Vec<u8>) -> Result<(), Vec<u8>> {
//!         // Verify encrypted input
//!         let config = get_config();
//!         let verifier = IInputVerifier::new(config.input_verifier_address());
//!         let verified_amount = verifier.verify_input(
//!             Call::new_in(self),
//!             amount.into_inner(),
//!             proof.into(),
//!             EUINT64_TYPE
//!         ).map_err(|_| b"Invalid input".to_vec())?;
//!
//!         // Perform FHE operations
//!         let precompile = IFHEVMPrecompile::new(config.precompile_address());
//!         let sender_balance = self.balances.get(msg::sender()).into_inner();
//!         let new_balance = precompile.fhe_sub(
//!             Call::new_in(self),
//!             sender_balance,
//!             verified_amount._0,
//!             FixedBytes([0x00])
//!         ).map_err(|_| b"Operation failed".to_vec())?;
//!
//!         self.balances.insert(msg::sender(), Euint64::from(new_balance._0));
//!         Ok(())
//!     }
//! }
//! ```

use crate::types::*;

/// Main FHE operations struct
///
/// This provides documentation for FHE operations. For actual implementation,
/// use the precompile interfaces directly (see module documentation).
pub struct FHE;

/// Errors that can occur during FHE operations
#[derive(Debug)]
pub enum FHEError {
    /// Precompile call failed
    PrecompileCallFailed,
    /// Input verification failed
    InvalidInput,
    /// Access control check failed
    AccessDenied,
    /// Invalid proof provided
    InvalidProof,
    /// Generic operation error
    OperationFailed,
}

impl FHE {
    /// Verify and convert an external encrypted value (stub)
    ///
    /// **Use `IInputVerifier::verify_input()` directly in your contract instead.**
    pub fn from_external(_input: ExternalEuint64, _proof: &[u8]) -> Result<Euint64, FHEError> {
        Err(FHEError::OperationFailed)
    }

    /// Add two encrypted integers (stub)
    ///
    /// **Use `IFHEVMPrecompile::fhe_add()` directly in your contract instead.**
    pub fn add(_lhs: Euint64, _rhs: Euint64) -> Result<Euint64, FHEError> {
        Err(FHEError::OperationFailed)
    }

    /// Subtract two encrypted integers (stub)
    ///
    /// **Use `IFHEVMPrecompile::fhe_sub()` directly in your contract instead.**
    pub fn sub(_lhs: Euint64, _rhs: Euint64) -> Result<Euint64, FHEError> {
        Err(FHEError::OperationFailed)
    }

    /// Multiply two encrypted integers (stub)
    ///
    /// **Use `IFHEVMPrecompile::fhe_mul()` directly in your contract instead.**
    pub fn mul(_lhs: Euint64, _rhs: Euint64) -> Result<Euint64, FHEError> {
        Err(FHEError::OperationFailed)
    }

    /// Grant access to an encrypted value (stub)
    ///
    /// **Use `IACL::allow()` directly in your contract instead.**
    pub fn allow(_handle: Euint64, _account: stylus_sdk::alloy_primitives::Address) -> Result<(), FHEError> {
        Err(FHEError::OperationFailed)
    }
}

// Re-export for convenience
pub use FHEError as Error;
