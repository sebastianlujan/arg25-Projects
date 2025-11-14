//! # FHE-Stylus: FHEVM Middleware for Arbitrum Stylus
//!
//! This library provides a Rust interface to Zama's FHEVM (Fully Homomorphic Encryption
//! Virtual Machine) for use in Arbitrum Stylus smart contracts.
//!
//! ## Overview
//!
//! FHE-Stylus allows you to write confidential smart contracts in Rust that perform
//! computations on encrypted data. It works by calling existing FHEVM precompiles
//! deployed on Arbitrum, which handle the actual FHE operations off-chain.
//!
//! ## Architecture
//!
//! ```text
//! User → Stylus Contract → FHE Middleware → FHEVM Precompiles → Off-chain Coprocessor
//! ```
//!
//! ## Features
//!
//! - **Encrypted Types**: `Euint64`, `Euint256`, `Ebool` for confidential state
//! - **FHE Operations**: Arithmetic, comparison, and bitwise ops on encrypted data
//! - **Access Control**: Manage who can decrypt values with ACL
//! - **Input Verification**: Verify zero-knowledge proofs for user inputs
//! - **Network Support**: Sepolia testnet (Arbitrum mainnet coming soon)
//!
//! ## Quick Start
//!
//! ```ignore
//! use stylus_sdk::prelude::*;
//! use fhe_stylus::{FHE, Euint64, ExternalEuint64};
//!
//! #[storage]
//! #[entrypoint]
//! pub struct ConfidentialContract {
//!     balances: StorageMap<Address, Euint64>,
//! }
//!
//! #[public]
//! impl ConfidentialContract {
//!     pub fn transfer(
//!         &mut self,
//!         to: Address,
//!         amount: ExternalEuint64,
//!         proof: Vec<u8>
//!     ) -> Result<(), Vec<u8>> {
//!         // Verify encrypted input
//!         let verified_amount = FHE::from_external(amount, &proof)
//!             .map_err(|_| b"Invalid input".to_vec())?;
//!
//!         // Get encrypted balances
//!         let sender_balance = self.balances.get(msg::sender());
//!         let receiver_balance = self.balances.get(to);
//!
//!         // Perform encrypted arithmetic
//!         let new_sender = FHE::sub(sender_balance, verified_amount)
//!             .map_err(|_| b"Insufficient balance".to_vec())?;
//!         let new_receiver = FHE::add(receiver_balance, verified_amount)
//!             .map_err(|_| b"Overflow".to_vec())?;
//!
//!         // Update state
//!         self.balances.insert(msg::sender(), new_sender);
//!         self.balances.insert(to, new_receiver);
//!
//!         // Grant access for decryption
//!         FHE::allow(new_sender, msg::sender())
//!             .map_err(|_| b"Access control failed".to_vec())?;
//!         FHE::allow(new_receiver, to)
//!             .map_err(|_| b"Access control failed".to_vec())?;
//!
//!         Ok(())
//!     }
//! }
//! ```
//!
//! ## Network Configuration
//!
//! Use cargo features to select the target network:
//!
//! ```toml
//! [dependencies]
//! fhe-stylus = { path = "../fhe-stylus", features = ["sepolia"] }
//! ```
//!
//! Available features:
//! - `sepolia` - Ethereum Sepolia testnet (default)
//! - `arbitrum-mainnet` - Arbitrum mainnet (coming soon)
//! - `arbitrum-testnet` - Arbitrum testnet
//!
//! ## Security Considerations
//!
//! 1. **Always verify external inputs** with `FHE::from_external()` and proofs
//! 2. **Grant access carefully** - only allow decryption to authorized addresses
//! 3. **Handle errors** - FHE operations can fail, always use proper error handling
//! 4. **Gas costs** - FHE operations are more expensive than plaintext operations
//!
//! ## Limitations
//!
//! - Encrypted values cannot be used in control flow (if/else/loops)
//! - Division by encrypted values requires special handling
//! - Decryption is asynchronous and happens off-chain
//! - Contract size must stay under 24KB (Stylus limit)

#![no_std]
extern crate alloc;

// Re-export alloy_sol_types so the sol! macro can find it
pub extern crate stylus_sdk;

// Module declarations
pub mod config;
pub mod fhe;
pub mod interfaces;
pub mod signature;
pub mod types;

// CoFHE modules (new)
pub mod cofhe;
pub mod cofhe_config;
pub mod cofhe_interfaces;

// Re-export main types and functions for convenience
pub use config::{get_config, FHEVMConfig};
pub use fhe::{FHEError, FHE};
pub use signature::{SignatureError, SignatureRecover};
pub use types::{Ebool, Euint256, Euint64, ExternalEuint256, ExternalEuint64};

// CoFHE re-exports
pub use cofhe::{CoFHE, CoFHEError};
pub use cofhe_config::{get_cofhe_config, CoFHEConfig};
pub use cofhe_interfaces::{ITaskManager, InEuint64, InEuint8, InEuint32, InEuint256, InEbool, FunctionId, Utils};

// Re-export commonly used Stylus types
pub use stylus_sdk::prelude::*;

/// Library version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Prelude module for convenient imports
///
/// Import everything you need with:
/// ```ignore
/// use fhe_stylus::prelude::*;
/// ```
pub mod prelude {
    // ZAMA FHEVM (legacy)
    pub use crate::fhe::{FHEError, FHE};
    pub use crate::types::{Ebool, Euint256, Euint64, ExternalEuint256, ExternalEuint64};
    pub use crate::signature::{SignatureError, SignatureRecover};
    pub use crate::config::get_config;
    
    // CoFHE (new)
    pub use crate::cofhe::{CoFHE, CoFHEError};
    pub use crate::cofhe_config::{get_cofhe_config, CoFHEConfig};
    pub use crate::cofhe_interfaces::{ITaskManager, InEuint64, InEuint8, InEuint32, InEuint256, InEbool, FunctionId, Utils};
    
    pub use stylus_sdk::prelude::*;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert!(!VERSION.is_empty());
    }

    #[test]
    fn test_config_exists() {
        let config = get_config();
        // Config should be valid
        let _ = config.precompile_address();
    }
}
