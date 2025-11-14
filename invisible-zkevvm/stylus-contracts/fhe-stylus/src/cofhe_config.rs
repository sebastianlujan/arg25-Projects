//! Network Configuration for CoFHE TaskManager
//!
//! This module provides network-specific addresses for the CoFHE TaskManager contract.
//! The TaskManager is the contract that FHE.sol library calls internally.

use stylus_sdk::alloy_primitives::Address;

/// Configuration for CoFHE TaskManager addresses on a specific network
#[derive(Debug, Clone, Copy)]
pub struct CoFHEConfig {
    /// Address of the TaskManager contract
    /// This is the contract that FHE.sol library calls internally
    pub task_manager: Address,
}

impl CoFHEConfig {
    /// Get the configuration for the current network based on cargo features
    pub const fn current() -> Self {
        #[cfg(feature = "arb-sepolia")]
        {
            Self::arbitrum_sepolia()
        }

        #[cfg(feature = "eth-sepolia")]
        {
            Self::ethereum_sepolia()
        }

        #[cfg(feature = "localcofhe")]
        {
            Self::local_cofhe()
        }

        // Default to Arbitrum Sepolia if no feature is set
        #[cfg(not(any(feature = "arb-sepolia", feature = "eth-sepolia", feature = "localcofhe")))]
        {
            Self::arbitrum_sepolia()
        }
    }

    /// Arbitrum Sepolia testnet configuration
    ///
    /// ⚠️ NOTE: The address in FHE.sol has a TODO comment saying "CHANGE ME AFTER DEPLOYING"
    /// This address may need to be updated based on actual deployment.
    /// Current address from FHE.sol: 0xeA30c4B8b44078Bbf8a6ef5b9f1eC1626C7848D9
    pub const fn arbitrum_sepolia() -> Self {
        Self {
            // TODO: Verify this is the correct address for Arbitrum Sepolia
            // Source: FHE.sol constant TASK_MANAGER_ADDRESS
            task_manager: Address::new([
                0xea, 0x30, 0xc4, 0xB8, 0xb4, 0x40, 0x78, 0xBb,
                0xf8, 0xa6, 0xef, 0x5b, 0x9f, 0x1e, 0xC1, 0x62,
                0x6C, 0x78, 0x48, 0xD9
            ]), // 0xeA30c4B8b44078Bbf8a6ef5b9f1eC1626C7848D9
        }
    }

    /// Ethereum Sepolia testnet configuration
    ///
    /// ⚠️ NOTE: Verify the actual address for Ethereum Sepolia
    pub const fn ethereum_sepolia() -> Self {
        Self {
            // TODO: Get actual address for Ethereum Sepolia
            // May be the same as Arbitrum Sepolia or different
            task_manager: Address::new([
                0xea, 0x30, 0xc4, 0xB8, 0xb4, 0x40, 0x78, 0xBb,
                0xf8, 0xa6, 0xef, 0x5b, 0x9f, 0x1e, 0xC1, 0x62,
                0x6C, 0x78, 0x48, 0xD9
            ]), // Placeholder - verify actual address
        }
    }

    /// Local CoFHE network configuration
    ///
    /// For local development with mock contracts
    pub const fn local_cofhe() -> Self {
        Self {
            // TODO: Get address for local mock TaskManager
            // This should be the address of cofhe-mock-contracts TaskManager
            task_manager: Address::ZERO, // Placeholder
        }
    }
}

/// Get the current network's CoFHE configuration
///
/// This is a convenience function that returns the configuration
/// based on the cargo feature flags set at compile time.
///
/// # Example
/// ```ignore
/// use fhe_stylus::cofhe_config::get_cofhe_config;
///
/// let config = get_cofhe_config();
/// let task_manager = ITaskManager::new(config.task_manager);
/// ```
pub const fn get_cofhe_config() -> CoFHEConfig {
    CoFHEConfig::current()
}

/// TaskManager address getter for convenience
impl CoFHEConfig {
    /// Get the TaskManager contract address
    pub const fn task_manager_address(&self) -> Address {
        self.task_manager
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_arbitrum_sepolia_config() {
        let config = CoFHEConfig::arbitrum_sepolia();
        assert_ne!(config.task_manager, Address::ZERO);
    }

    #[test]
    fn test_current_config() {
        let config = CoFHEConfig::current();
        // Should not panic and return valid config
        let _ = config.task_manager_address();
    }
}

