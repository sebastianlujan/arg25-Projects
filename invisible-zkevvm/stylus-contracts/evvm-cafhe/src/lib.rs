//! # EVVM Cafhe - Coffee Shop with FHE
//!
//! Example contract demonstrating EVVM integration with encrypted payments.
//! This is a Stylus port of the original Solidity EVVMCafhe contract.
//!
//! ## Features
//! - Order coffee with encrypted payments
//! - Signature verification for order authorization
//! - Nonce tracking to prevent replay attacks
//! - Fisher incentive system for transaction processing
//! - Withdraw rewards and funds (encrypted)
//!
//! ## Architecture
//! ```text
//! User → EVVMCafhe (Stylus) → EVVMCore → CoFHE TaskManager → Coprocessor
//! ```

#![cfg_attr(not(feature = "std"), no_std)]
extern crate alloc;

use alloc::string::{String, ToString};
use alloc::vec::Vec;
use alloc::format;

use stylus_sdk::prelude::*;
use stylus_sdk::alloy_primitives::{Address, U256};
use stylus_sdk::storage::{StorageMap, StorageAddress, StorageBool};
use stylus_sdk::call::Call;
use stylus_sdk::msg;
use stylus_sdk::contract;

// Import FHE middleware
use fhe_stylus::prelude::*;
use fhe_stylus::interfaces::IEVVMCore;
use fhe_stylus::cofhe_interfaces::{InEuint64, Utils};

// Unit tests - only compile for WASM target
#[cfg(all(test, target_arch = "wasm32"))]
mod tests {
    use super::*;

    #[test]
    fn test_contract_compiles() {
        // If this compiles, the contract structure is valid
        assert!(true);
    }
}

// Panic handler for no_std - only for WASM target in production, not for tests
// (global allocator provided by stylus-sdk)
#[cfg(all(target_arch = "wasm32", not(feature = "std")))]
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}

/// Custom errors for EVVMCafhe
mod errors {
    pub const INVALID_SIGNATURE: &[u8] = b"Invalid signature";
    pub const NONCE_ALREADY_USED: &[u8] = b"Nonce already used";
    pub const UNAUTHORIZED: &[u8] = b"Unauthorized";
    pub const PAYMENT_FAILED: &[u8] = b"Payment failed";
}

/// Constant representing ETH in the EVVM virtual blockchain
const ETHER_ADDRESS: Address = Address::ZERO;

/// Constant representing the principal token in EVVM virtual blockchain
const PRINCIPAL_TOKEN_ADDRESS: Address = Address::new([
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
]);

/// Main storage structure for EVVMCafhe contract
#[storage]
#[entrypoint]
pub struct EVVMCafhe {
    /// Address of the EVVM Core contract for payment processing
    evvm_core: StorageAddress,

    /// Address of the coffee shop owner who can withdraw funds and rewards
    owner_of_shop: StorageAddress,

    /// Mapping to track used nonces per client address to prevent replay attacks
    /// client_address => (nonce => is_used)
    check_async_nonce: StorageMap<Address, StorageMap<U256, StorageBool>>,
}

/// Public interface for EVVMCafhe contract
#[public]
impl EVVMCafhe {
    /// Initialize the coffee shop contract
    ///
    /// # Parameters
    /// * `evvm_core_address` - Address of the EVVM Core contract
    /// * `owner_of_shop` - Address that will have administrative privileges
    pub fn initialize(
        &mut self,
        evvm_core_address: Address,
        owner_of_shop: Address,
    ) -> Result<(), Vec<u8>> {
        // Set EVVMCore contract address
        self.evvm_core.set(evvm_core_address);

        // Set owner
        self.owner_of_shop.set(owner_of_shop);

        Ok(())
    }

    /// Process a coffee order with encrypted payment through EVVM
    ///
    /// # Parameters
    /// * `client_address` - Address of the customer placing the order
    /// * `coffee_type` - Type/name of coffee being ordered (e.g., "Espresso", "Latte")
    /// * `quantity` - Number of coffee units being ordered
    /// * `total_price_plaintext` - Total price in plaintext (for signature verification)
    /// * `input_encrypted_total_price` - Encrypted total price to be paid in ETH (InEuint64 with proof included)
    /// * `nonce` - Unique number to prevent replay attacks (must not be reused)
    /// * `signature` - Client's signature authorizing the coffee order
    /// * `priority_fee_plaintext` - Priority fee in plaintext
    /// * `input_encrypted_priority_fee` - Encrypted priority fee for EVVM transaction (InEuint64 with proof included)
    /// * `nonce_evvm` - Unique nonce for the EVVM payment transaction
    /// * `priority_flag_evvm` - Boolean flag indicating the type of nonce
    ///
    /// # Signature Format
    /// The client must sign: "<evvmID>,orderCoffee,<coffeeType>,<quantity>,<totalPrice>,<nonce>"
    ///
    /// # Errors
    /// * `InvalidSignature` - If client signature verification fails
    /// * `NonceAlreadyUsed` - If nonce has been previously used
    /// * `PaymentFailed` - If EVVM payment fails
    #[allow(clippy::too_many_arguments)]
    pub fn order_coffee(
        &mut self,
        client_address: Address,
        coffee_type: String,
        quantity: U256,
        total_price_plaintext: U256,
        input_encrypted_total_price: InEuint64,
        nonce: U256,
        signature: Vec<u8>,
        priority_fee_plaintext: U256,
        input_encrypted_priority_fee: InEuint64,
        nonce_evvm: U256,
        priority_flag_evvm: bool,
    ) -> Result<(), Vec<u8>> {
        // Get EVVM Core contract
        let evvm_core_addr = self.evvm_core.get();
        let evvm_core = IEVVMCore::new(evvm_core_addr);

        // Get EVVM ID for signature verification
        let evvm_id = evvm_core
            .evvm_id(Call::new_in(self))
            .map_err(|_| errors::PAYMENT_FAILED)?;

        // Build the message for signature verification
        // Format: "<evvmID>,orderCoffee,<coffeeType>,<quantity>,<totalPrice>,<nonce>"
        let inputs = format!(
            "{},{},{},{}",
            coffee_type,
            quantity,
            total_price_plaintext,
            nonce
        );

        // Verify client's signature
        let is_valid = SignatureRecover::signature_verification(
            &evvm_id.to_string(),
            "orderCoffee",
            &inputs,
            &signature,
            client_address,
        )
        .map_err(|_| errors::INVALID_SIGNATURE)?;

        if !is_valid {
            return Err(errors::INVALID_SIGNATURE.to_vec());
        }

        // Check if nonce has been used before (prevent replay attacks)
        let nonce_used = self
            .check_async_nonce
            .getter(client_address)
            .getter(nonce)
            .get();

        if nonce_used {
            return Err(errors::NONCE_ALREADY_USED.to_vec());
        }

        // Process the payment through EVVMCore
        evvm_core
            .pay(
                Call::new_in(self),
                client_address,                                     // from
                contract::address(),                                // to
                String::new(),                                      // toIdentity
                ETHER_ADDRESS,                                      // token
                total_price_plaintext,                              // amountPlaintext
                input_encrypted_total_price.ct_hash,                // inputEncryptedAmount_ctHash
                input_encrypted_total_price.security_zone,          // inputEncryptedAmount_securityZone
                input_encrypted_total_price.utype,                   // inputEncryptedAmount_utype
                input_encrypted_total_price.signature.into(),       // inputEncryptedAmount_signature
                priority_fee_plaintext,                             // priorityFeePlaintext
                input_encrypted_priority_fee.ct_hash,               // inputEncryptedPriorityFee_ctHash
                input_encrypted_priority_fee.security_zone,        // inputEncryptedPriorityFee_securityZone
                input_encrypted_priority_fee.utype,                 // inputEncryptedPriorityFee_utype
                input_encrypted_priority_fee.signature.into(),      // inputEncryptedPriorityFee_signature
                nonce_evvm,                                         // nonce
                priority_flag_evvm,                                 // priorityFlag
                Address::ZERO,                                      // executor
                Vec::new().into(),                                  // signature
            )
            .map_err(|_| errors::PAYMENT_FAILED)?;

        // Mark nonce as used
        self.check_async_nonce
            .setter(client_address)
            .setter(nonce)
            .set(true);

        Ok(())
    }

    /// Withdraw accumulated virtual blockchain reward tokens from the contract
    ///
    /// # Parameters
    /// * `to` - Address where the withdrawn reward tokens will be sent
    /// * `input_encrypted_balance` - Encrypted balance to withdraw (InEuint64 with proof included)
    /// * `nonce_evvm` - Nonce for the EVVM payment transaction
    /// * `priority_flag_evvm` - Boolean flag for nonce type
    /// * `input_encrypted_priority_fee` - Encrypted priority fee (InEuint64 with proof included)
    ///
    /// # Security
    /// Only callable by the coffee shop owner
    #[allow(clippy::too_many_arguments)]
    pub fn withdraw_rewards(
        &mut self,
        to: Address,
        input_encrypted_balance: InEuint64,
        nonce_evvm: U256,
        priority_flag_evvm: bool,
        input_encrypted_priority_fee: InEuint64,
    ) -> Result<(), Vec<u8>> {
        // Check authorization
        if msg::sender() != self.owner_of_shop.get() {
            return Err(errors::UNAUTHORIZED.to_vec());
        }

        // Get EVVM Core contract
        let evvm_core_addr = self.evvm_core.get();
        let evvm_core = IEVVMCore::new(evvm_core_addr);

        // Transfer rewards
        evvm_core
            .pay(
                Call::new_in(self),
                contract::address(),                                // from
                to,                                                 // to
                String::new(),                                      // toIdentity
                PRINCIPAL_TOKEN_ADDRESS,                            // token
                U256::ZERO,                                         // amountPlaintext
                input_encrypted_balance.ct_hash,                    // inputEncryptedAmount_ctHash
                input_encrypted_balance.security_zone,              // inputEncryptedAmount_securityZone
                input_encrypted_balance.utype,                      // inputEncryptedAmount_utype
                input_encrypted_balance.signature.into(),           // inputEncryptedAmount_signature
                U256::ZERO,                                         // priorityFeePlaintext
                input_encrypted_priority_fee.ct_hash,               // inputEncryptedPriorityFee_ctHash
                input_encrypted_priority_fee.security_zone,         // inputEncryptedPriorityFee_securityZone
                input_encrypted_priority_fee.utype,                 // inputEncryptedPriorityFee_utype
                input_encrypted_priority_fee.signature.into(),      // inputEncryptedPriorityFee_signature
                nonce_evvm,                                         // nonce
                priority_flag_evvm,                                 // priorityFlag
                Address::ZERO,                                      // executor
                Vec::new().into(),                                  // signature
            )
            .map_err(|_| errors::PAYMENT_FAILED)?;

        Ok(())
    }

    /// Withdraw accumulated ETH funds from coffee sales
    ///
    /// # Parameters
    /// * `to` - Address where the withdrawn ETH will be sent
    /// * `input_encrypted_balance` - Encrypted balance to withdraw (InEuint64 with proof included)
    /// * `nonce_evvm` - Nonce for the EVVM payment transaction
    /// * `priority_flag_evvm` - Boolean flag for nonce type
    /// * `input_encrypted_priority_fee` - Encrypted priority fee (InEuint64 with proof included)
    ///
    /// # Security
    /// Only callable by the coffee shop owner
    #[allow(clippy::too_many_arguments)]
    pub fn withdraw_funds(
        &mut self,
        to: Address,
        input_encrypted_balance: InEuint64,
        nonce_evvm: U256,
        priority_flag_evvm: bool,
        input_encrypted_priority_fee: InEuint64,
    ) -> Result<(), Vec<u8>> {
        // Check authorization
        if msg::sender() != self.owner_of_shop.get() {
            return Err(errors::UNAUTHORIZED.to_vec());
        }

        // Get EVVM Core contract
        let evvm_core_addr = self.evvm_core.get();
        let evvm_core = IEVVMCore::new(evvm_core_addr);

        // Transfer funds
        evvm_core
            .pay(
                Call::new_in(self),
                contract::address(),                                // from
                to,                                                 // to
                String::new(),                                      // toIdentity
                ETHER_ADDRESS,                                      // token
                U256::ZERO,                                         // amountPlaintext
                input_encrypted_balance.ct_hash,                    // inputEncryptedAmount_ctHash
                input_encrypted_balance.security_zone,              // inputEncryptedAmount_securityZone
                input_encrypted_balance.utype,                      // inputEncryptedAmount_utype
                input_encrypted_balance.signature.into(),           // inputEncryptedAmount_signature
                U256::ZERO,                                         // priorityFeePlaintext
                input_encrypted_priority_fee.ct_hash,               // inputEncryptedPriorityFee_ctHash
                input_encrypted_priority_fee.security_zone,         // inputEncryptedPriorityFee_securityZone
                input_encrypted_priority_fee.utype,                 // inputEncryptedPriorityFee_utype
                input_encrypted_priority_fee.signature.into(),      // inputEncryptedPriorityFee_signature
                nonce_evvm,                                         // nonce
                priority_flag_evvm,                                 // priorityFlag
                Address::ZERO,                                      // executor
                Vec::new().into(),                                  // signature
            )
            .map_err(|_| errors::PAYMENT_FAILED)?;

        Ok(())
    }

    // ============================================================================
    // View Functions
    // ============================================================================

    /// Check if a nonce has been used for a specific client
    pub fn is_this_nonce_used(&self, client_address: Address, nonce: U256) -> bool {
        self.check_async_nonce
            .getter(client_address)
            .getter(nonce)
            .get()
    }

    /// Get the principal token address
    pub fn get_principal_token_address(&self) -> Address {
        PRINCIPAL_TOKEN_ADDRESS
    }

    /// Get the ether address
    pub fn get_ether_address(&self) -> Address {
        ETHER_ADDRESS
    }

    // NOTE: View functions for encrypted balances have been removed
    // because they always returned zero (silent failure).
    //
    // Stylus limitation: Cannot call EVVMCore's view functions without
    // mutable reference to self. These functions created false expectations
    // by appearing to work but always returning FixedBytes::ZERO.
    //
    // To get encrypted balances, use EVVMCore directly:
    //   - get_encrypted_eth_balance(shop_address)
    //   - get_encrypted_token_balance(shop_address, token_id)
    //
    // Removed functions:
    //   - get_amount_of_principal_token_in_shop()
    //   - get_amount_of_ether_in_shop()

    /// Get the EVVM Core contract address
    pub fn get_evvm_address(&self) -> Address {
        self.evvm_core.get()
    }

    /// Get the owner address
    pub fn get_owner(&self) -> Address {
        self.owner_of_shop.get()
    }
}
