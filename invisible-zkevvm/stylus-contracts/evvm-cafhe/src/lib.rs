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
//! User → EVVMCafhe (Stylus) → EVVMCore → FHEVM Precompiles → Coprocessor
//! ```

#![no_std]
extern crate alloc;

use alloc::string::{String, ToString};
use alloc::vec::Vec;
use alloc::format;

use stylus_sdk::prelude::*;
use stylus_sdk::alloy_primitives::{Address, U256, FixedBytes};
use stylus_sdk::storage::{StorageMap, StorageAddress, StorageBool, StorageU256};
use stylus_sdk::call::Call;
use stylus_sdk::msg;
use stylus_sdk::contract;

// Import FHE middleware
use fhe_stylus::prelude::*;
use fhe_stylus::interfaces::IEVVMCore;

// Use wee_alloc as global allocator
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

// Panic handler for no_std
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
    /// * `input_encrypted_total_price` - Encrypted total price to be paid in ETH
    /// * `input_price_proof` - Proof for encrypted total price
    /// * `nonce` - Unique number to prevent replay attacks (must not be reused)
    /// * `signature` - Client's signature authorizing the coffee order
    /// * `priority_fee_plaintext` - Priority fee in plaintext
    /// * `input_encrypted_priority_fee` - Encrypted priority fee for EVVM transaction
    /// * `input_fee_proof` - Proof for encrypted priority fee
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
        input_encrypted_total_price: ExternalEuint64,
        input_price_proof: Vec<u8>,
        nonce: U256,
        signature: Vec<u8>,
        priority_fee_plaintext: U256,
        input_encrypted_priority_fee: ExternalEuint64,
        input_fee_proof: Vec<u8>,
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
                input_encrypted_total_price,                        // inputEncryptedAmount
                input_price_proof.into(),                           // inputAmountProof
                priority_fee_plaintext,                             // priorityFeePlaintext
                input_encrypted_priority_fee,                       // inputEncryptedPriorityFee
                input_fee_proof.into(),                             // inputFeeProof
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
    /// * `input_encrypted_balance` - Encrypted balance to withdraw
    /// * `input_balance_proof` - Proof for encrypted balance
    /// * `nonce_evvm` - Nonce for the EVVM payment transaction
    /// * `priority_flag_evvm` - Boolean flag for nonce type
    /// * `input_encrypted_priority_fee` - Encrypted priority fee
    /// * `input_fee_proof` - Proof for encrypted priority fee
    ///
    /// # Security
    /// Only callable by the coffee shop owner
    #[allow(clippy::too_many_arguments)]
    pub fn withdraw_rewards(
        &mut self,
        to: Address,
        input_encrypted_balance: ExternalEuint64,
        input_balance_proof: Vec<u8>,
        nonce_evvm: U256,
        priority_flag_evvm: bool,
        input_encrypted_priority_fee: ExternalEuint64,
        input_fee_proof: Vec<u8>,
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
                input_encrypted_balance,                            // inputEncryptedAmount
                input_balance_proof.into(),                         // inputAmountProof
                U256::ZERO,                                         // priorityFeePlaintext
                input_encrypted_priority_fee,                       // inputEncryptedPriorityFee
                input_fee_proof.into(),                             // inputFeeProof
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
    /// * `input_encrypted_balance` - Encrypted balance to withdraw
    /// * `input_balance_proof` - Proof for encrypted balance
    /// * `nonce_evvm` - Nonce for the EVVM payment transaction
    /// * `priority_flag_evvm` - Boolean flag for nonce type
    /// * `input_encrypted_priority_fee` - Encrypted priority fee
    /// * `input_fee_proof` - Proof for encrypted priority fee
    ///
    /// # Security
    /// Only callable by the coffee shop owner
    #[allow(clippy::too_many_arguments)]
    pub fn withdraw_funds(
        &mut self,
        to: Address,
        input_encrypted_balance: ExternalEuint64,
        input_balance_proof: Vec<u8>,
        nonce_evvm: U256,
        priority_flag_evvm: bool,
        input_encrypted_priority_fee: ExternalEuint64,
        input_fee_proof: Vec<u8>,
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
                input_encrypted_balance,                            // inputEncryptedAmount
                input_balance_proof.into(),                         // inputAmountProof
                U256::ZERO,                                         // priorityFeePlaintext
                input_encrypted_priority_fee,                       // inputEncryptedPriorityFee
                input_fee_proof.into(),                             // inputFeeProof
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

    /// Get encrypted balance of principal tokens in the shop
    ///
    /// # Returns
    /// Encrypted balance (euint64) - decrypt with SDK off-chain
    pub fn get_amount_of_principal_token_in_shop(&self) -> Euint64 {
        let evvm_core_addr = self.evvm_core.get();
        let evvm_core = IEVVMCore::new(evvm_core_addr);

        // For view functions, we need to use a different approach
        // Since we can't get mutable reference, return zero or handle differently
        // In practice, this would use static_call
        FixedBytes::ZERO
    }

    /// Get encrypted balance of ETH in the shop
    ///
    /// # Returns
    /// Encrypted balance (euint64) - decrypt with SDK off-chain
    pub fn get_amount_of_ether_in_shop(&self) -> Euint64 {
        let evvm_core_addr = self.evvm_core.get();
        let evvm_core = IEVVMCore::new(evvm_core_addr);

        // For view functions, we need to use a different approach
        // Since we can't get mutable reference, return zero or handle differently
        // In practice, this would use static_call
        FixedBytes::ZERO
    }

    /// Get the EVVM Core contract address
    pub fn get_evvm_address(&self) -> Address {
        self.evvm_core.get()
    }

    /// Get the owner address
    pub fn get_owner(&self) -> Address {
        self.owner_of_shop.get()
    }
}
