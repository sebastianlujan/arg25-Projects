//! Signature Recovery Library for EVVM
//!
//! Official EVVM library for verifying EIP-191 signatures in Stylus contracts.
//! Follows EVVM specification: "<evvmID>,<functionName>,<inputs>"
//!
//! # Example
//! ```ignore
//! use fhe_stylus::signature::SignatureRecover;
//!
//! let is_valid = SignatureRecover::signature_verification(
//!     &evvm_id_str,
//!     "orderCoffee",
//!     &inputs_str,
//!     &signature_bytes,
//!     client_address,
//! )?;
//!
//! if !is_valid {
//!     return Err(b"Invalid signature".to_vec());
//! }
//! ```

use stylus_sdk::alloy_primitives::{Address, keccak256, FixedBytes, B256};
use alloc::string::{String, ToString};
use alloc::vec::Vec;
use alloc::format;

/// Signature recovery utilities for EVVM
pub struct SignatureRecover;

/// Errors that can occur during signature verification
#[derive(Debug)]
pub enum SignatureError {
    /// Signature has invalid length (must be 65 bytes)
    InvalidLength,
    /// Signature v value is invalid (must be 27 or 28)
    InvalidV,
    /// Recovery failed
    RecoveryFailed,
}

impl SignatureRecover {
    /// Verifies a signature for EVVM function calls
    ///
    /// # Parameters
    /// * `evvm_id` - The EVVM ID string (e.g., "1234")
    /// * `function_name` - The name of the function being called (e.g., "orderCoffee")
    /// * `inputs` - The concatenated input parameters, comma-separated (e.g., "Espresso,2,100,42")
    /// * `signature` - The signature bytes (65 bytes: r=32, s=32, v=1)
    /// * `expected_signer` - The address that should have signed the message
    ///
    /// # Returns
    /// * `Result<bool, SignatureError>` - True if signature is valid and matches expected signer
    ///
    /// # Message Format
    /// The signed message follows EVVM specification:
    /// ```text
    /// "<evvmID>,<functionName>,<inputs>"
    /// ```
    ///
    /// For example:
    /// ```text
    /// "1234,orderCoffee,Espresso,2,100,42"
    /// ```
    ///
    /// # Example
    /// ```ignore
    /// let evvm_id = "1234";
    /// let function_name = "orderCoffee";
    /// let inputs = "Espresso,2,100,42";
    /// let signature = &signature_bytes;
    /// let client = Address::from([0x12; 20]);
    ///
    /// let is_valid = SignatureRecover::signature_verification(
    ///     evvm_id,
    ///     function_name,
    ///     inputs,
    ///     signature,
    ///     client,
    /// )?;
    /// ```
    pub fn signature_verification(
        evvm_id: &str,
        function_name: &str,
        inputs: &str,
        signature: &[u8],
        expected_signer: Address,
    ) -> Result<bool, SignatureError> {
        // Concatenate message components: "<evvmID>,<functionName>,<inputs>"
        let message = format!("{},{},{}", evvm_id, function_name, inputs);

        // Recover the signer from the signature
        let recovered_signer = Self::recover_signer(&message, signature)?;

        // Compare with expected signer
        Ok(recovered_signer == expected_signer)
    }

    /// Recovers the signer address from a message and signature
    ///
    /// # Parameters
    /// * `message` - The message that was signed (plain text)
    /// * `signature` - The signature bytes (65 bytes)
    ///
    /// # Returns
    /// * `Result<Address, SignatureError>` - The recovered signer address
    ///
    /// # EIP-191 Format
    /// The message is hashed using EIP-191 format:
    /// ```text
    /// keccak256("\x19Ethereum Signed Message:\n" + len(message) + message)
    /// ```
    pub fn recover_signer(
        message: &str,
        signature: &[u8],
    ) -> Result<Address, SignatureError> {
        // Create EIP-191 prefixed message hash
        let message_bytes = message.as_bytes();
        let message_len = message_bytes.len().to_string();

        // Build: "\x19Ethereum Signed Message:\n" + len + message
        let mut eth_message = Vec::new();
        eth_message.extend_from_slice(b"\x19Ethereum Signed Message:\n");
        eth_message.extend_from_slice(message_len.as_bytes());
        eth_message.extend_from_slice(message_bytes);

        // Hash the prefixed message
        let message_hash = keccak256(&eth_message);

        // Split signature into r, s, v components
        let (r, s, v) = Self::split_signature(signature)?;

        // Recover the address using ecrecover
        Self::ecrecover(&message_hash, v, &r, &s)
    }

    /// Splits a signature into its r, s, and v components
    ///
    /// # Parameters
    /// * `signature` - The signature bytes (must be exactly 65 bytes)
    ///
    /// # Returns
    /// * `Result<(B256, B256, u8), SignatureError>` - The (r, s, v) components
    ///
    /// # Signature Layout
    /// ```text
    /// [  r: 32 bytes  ][  s: 32 bytes  ][ v: 1 byte ]
    /// ```
    pub fn split_signature(signature: &[u8]) -> Result<(B256, B256, u8), SignatureError> {
        if signature.len() != 65 {
            return Err(SignatureError::InvalidLength);
        }

        // Extract r (first 32 bytes)
        let mut r_bytes = [0u8; 32];
        r_bytes.copy_from_slice(&signature[0..32]);
        let r = B256::from(r_bytes);

        // Extract s (next 32 bytes)
        let mut s_bytes = [0u8; 32];
        s_bytes.copy_from_slice(&signature[32..64]);
        let s = B256::from(s_bytes);

        // Extract v (last byte)
        let mut v = signature[64];

        // Normalize v to 27 or 28
        if v < 27 {
            v += 27;
        }

        // Validate v
        if v != 27 && v != 28 {
            return Err(SignatureError::InvalidV);
        }

        Ok((r, s, v))
    }

    /// Performs ecrecover to get the signer address
    ///
    /// # Parameters
    /// * `message_hash` - The keccak256 hash of the message
    /// * `v` - Recovery ID (27 or 28)
    /// * `r` - First 32 bytes of signature
    /// * `s` - Last 32 bytes of signature
    ///
    /// # Returns
    /// * `Result<Address, SignatureError>` - The recovered address
    ///
    /// # Note
    /// This uses the EVM's ecrecover precompile (address 0x01)
    fn ecrecover(
        message_hash: &B256,
        v: u8,
        r: &B256,
        s: &B256,
    ) -> Result<Address, SignatureError> {
        // Build the input for ecrecover precompile:
        // [hash: 32 bytes][v: 32 bytes][r: 32 bytes][s: 32 bytes]
        let mut input = [0u8; 128];

        // Copy message hash
        input[0..32].copy_from_slice(message_hash.as_slice());

        // Copy v (as 32 bytes, right-aligned)
        input[63] = v;

        // Copy r
        input[64..96].copy_from_slice(r.as_slice());

        // Copy s
        input[96..128].copy_from_slice(s.as_slice());

        // Call ecrecover precompile at address 0x01
        use stylus_sdk::call::RawCall;

        let ecrecover_address = Address::from([
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
        ]);

        // Call ecrecover precompile using raw_static_call
        let result = unsafe { RawCall::new_static().call(ecrecover_address, &input) };

        match result {
            Ok(output) => {
                if output.len() >= 32 {
                    // ecrecover returns 32 bytes, with address in last 20 bytes
                    let mut addr_bytes = [0u8; 20];
                    addr_bytes.copy_from_slice(&output[12..32]);
                    Ok(Address::from(addr_bytes))
                } else {
                    Err(SignatureError::RecoveryFailed)
                }
            }
            Err(_) => Err(SignatureError::RecoveryFailed),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_split_signature_valid() {
        // Create a dummy 65-byte signature
        let mut sig = [0u8; 65];
        sig[64] = 27; // v = 27

        let result = SignatureRecover::split_signature(&sig);
        assert!(result.is_ok());

        let (r, s, v) = result.unwrap();
        assert_eq!(v, 27);
    }

    #[test]
    fn test_split_signature_invalid_length() {
        let sig = [0u8; 64]; // Wrong length
        let result = SignatureRecover::split_signature(&sig);
        assert!(matches!(result, Err(SignatureError::InvalidLength)));
    }

    #[test]
    fn test_split_signature_normalize_v() {
        let mut sig = [0u8; 65];
        sig[64] = 0; // v = 0, should be normalized to 27

        let result = SignatureRecover::split_signature(&sig);
        assert!(result.is_ok());

        let (_, _, v) = result.unwrap();
        assert_eq!(v, 27);
    }

    #[test]
    fn test_split_signature_invalid_v() {
        let mut sig = [0u8; 65];
        sig[64] = 30; // Invalid v value

        let result = SignatureRecover::split_signature(&sig);
        assert!(matches!(result, Err(SignatureError::InvalidV)));
    }
}
