//! Network Configuration for FHEVM Precompiles
//!
//! This module provides network-specific addresses for FHEVM precompiles.
//! Use cargo features to select the target network:
//!
//! ```toml
//! [features]
//! default = ["sepolia"]
//! sepolia = []
//! arbitrum-mainnet = []
//! ```

use stylus_sdk::alloy_primitives::Address;

/// Configuration for FHEVM precompile addresses on a specific network
#[derive(Debug, Clone, Copy)]
pub struct FHEVMConfig {
    /// Address of the FHEVM operations precompile (add, sub, mul, etc.)
    pub fhevm_precompile: Address,

    /// Address of the Input Verifier precompile
    pub input_verifier: Address,

    /// Address of the Access Control List (ACL) precompile
    pub acl: Address,

    /// Address of the Gateway for decryption requests
    pub gateway: Address,

    /// Address of the KMS (Key Management Service) verifier
    pub kms_verifier: Address,
}

impl FHEVMConfig {
    /// Get the configuration for the current network based on cargo features
    pub const fn current() -> Self {
        #[cfg(feature = "sepolia")]
        {
            Self::sepolia()
        }

        #[cfg(all(feature = "arbitrum-mainnet", not(feature = "sepolia")))]
        {
            Self::arbitrum_mainnet()
        }

        #[cfg(all(feature = "arbitrum-testnet", not(feature = "sepolia"), not(feature = "arbitrum-mainnet")))]
        {
            Self::arbitrum_testnet()
        }

        // Default to Sepolia if no feature is set
        #[cfg(not(any(feature = "sepolia", feature = "arbitrum-mainnet", feature = "arbitrum-testnet")))]
        {
            Self::sepolia()
        }
    }

    /// Sepolia testnet configuration (Ethereum L1 testnet with FHEVM)
    ///
    /// These are the known FHEVM contract addresses on Sepolia.
    /// Source: Zama FHEVM documentation
    pub const fn sepolia() -> Self {
        Self {
            // Main FHEVM operations precompile
            // Handles all FHE arithmetic, comparison, and bitwise operations
            fhevm_precompile: Address::new([
                0x84, 0x8B, 0x00, 0x66, 0x79, 0x3B, 0xCC, 0x60,
                0x34, 0x6D, 0xa1, 0xF4, 0x90, 0x49, 0x35, 0x73,
                0x99, 0xB8, 0xD5, 0x95
            ]), // 0x848B0066793BcC60346Da1F49049357399B8D595

            // Input Verifier precompile
            // Verifies zero-knowledge proofs for encrypted inputs
            input_verifier: Address::new([
                0xbc, 0x91, 0xf3, 0xda, 0xD1, 0xA5, 0xF1, 0x9F,
                0x83, 0x90, 0xc4, 0x00, 0x19, 0x6e, 0x58, 0x07,
                0x3B, 0x6a, 0x0B, 0xC4
            ]), // 0xbc91f3daD1A5F19F8390c400196e58073B6a0BC4

            // Access Control List precompile
            // Manages permissions for encrypted value access
            acl: Address::new([
                0x68, 0x78, 0x20, 0x22, 0x11, 0x92, 0xC5, 0xB6,
                0x62, 0xb2, 0x53, 0x67, 0xF7, 0x00, 0x76, 0xA3,
                0x7b, 0xc7, 0x9b, 0x6c
            ]), // 0x687820221192C5B662b25367F70076A37bc79b6c

            // Gateway for decryption requests
            // Coordinates with KMS for threshold decryption
            gateway: Address::new([
                0x33, 0x47, 0x25, 0x22, 0xf9, 0x9C, 0x5e, 0x58,
                0xA5, 0x8D, 0x0d, 0x69, 0x6D, 0x48, 0x30, 0x95,
                0x45, 0xD7, 0x0a, 0x3C
            ]), // 0x33472522f99C5e58A58D0d696D48309545D70a3C (example)

            // KMS Verifier
            kms_verifier: Address::new([
                0x05, 0xfD, 0x2B, 0x95, 0x65, 0x40, 0x57, 0xC6,
                0xBA, 0x8c, 0x8C, 0x42, 0xFC, 0x0B, 0x3F, 0x54,
                0x28, 0x64, 0x31, 0xE5
            ]), // 0x05fD2B9565405 7C6BA8c8C42FC0B3F542864 31E5 (example)
        }
    }

    /// Arbitrum Mainnet configuration (Production)
    ///
    /// NOTE: FHEVM is not yet deployed on Arbitrum Mainnet.
    /// These are placeholder addresses and will be updated once
    /// Zama deploys FHEVM to Arbitrum Mainnet.
    pub const fn arbitrum_mainnet() -> Self {
        Self {
            // TODO: Update with actual addresses once deployed
            fhevm_precompile: Address::ZERO,
            input_verifier: Address::ZERO,
            acl: Address::ZERO,
            gateway: Address::ZERO,
            kms_verifier: Address::ZERO,
        }
    }

    /// Arbitrum Testnet (Sepolia) configuration
    ///
    /// This is for when FHEVM is deployed specifically on Arbitrum's testnet.
    pub const fn arbitrum_testnet() -> Self {
        Self {
            // TODO: Update with actual addresses once deployed
            fhevm_precompile: Address::ZERO,
            input_verifier: Address::ZERO,
            acl: Address::ZERO,
            gateway: Address::ZERO,
            kms_verifier: Address::ZERO,
        }
    }
}

/// Get the current network's FHEVM configuration
///
/// This is a convenience function that returns the configuration
/// based on the cargo feature flags set at compile time.
///
/// # Example
/// ```ignore
/// use fhe_stylus::config::get_config;
///
/// let config = get_config();
/// let precompile = IFHEVMPrecompile::new(config.fhevm_precompile);
/// ```
pub const fn get_config() -> FHEVMConfig {
    FHEVMConfig::current()
}

/// Precompile address getters for convenience
impl FHEVMConfig {
    /// Get the FHEVM operations precompile address
    pub const fn precompile_address(&self) -> Address {
        self.fhevm_precompile
    }

    /// Get the Input Verifier address
    pub const fn input_verifier_address(&self) -> Address {
        self.input_verifier
    }

    /// Get the ACL address
    pub const fn acl_address(&self) -> Address {
        self.acl
    }

    /// Get the Gateway address
    pub const fn gateway_address(&self) -> Address {
        self.gateway
    }

    /// Get the KMS Verifier address
    pub const fn kms_verifier_address(&self) -> Address {
        self.kms_verifier
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sepolia_config() {
        let config = FHEVMConfig::sepolia();
        assert_ne!(config.fhevm_precompile, Address::ZERO);
        assert_ne!(config.input_verifier, Address::ZERO);
        assert_ne!(config.acl, Address::ZERO);
    }

    #[test]
    fn test_current_config() {
        let config = FHEVMConfig::current();
        // Should not panic and return valid config
        let _ = config.precompile_address();
    }
}
