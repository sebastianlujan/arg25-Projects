# Stylus FHE Middleware: Practical Porting Guide

**Date:** 2025-11-11
**Project:** Invisible zkEVM - Stylus FHE Integration
**Version:** 1.0
**Approach:** Middleware pattern for existing FHEVM infrastructure

---

## Executive Summary

This document provides a **practical approach** to using FHE in Stylus contracts by creating a middleware layer that interacts with **existing deployed FHEVM infrastructure** on Arbitrum.

### The Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      User / DApp                             │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│               Stylus Smart Contract                          │
│  (Your business logic in Rust/WASM)                         │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Stylus FHE Middleware                           │
│  (Rust library wrapping FHEVM precompiles)                  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│       Deployed FHEVM Precompiles/Contracts                   │
│  (Already on Arbitrum/Sepolia - Solidity)                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Off-Chain Infrastructure                        │
│  • Coprocessor (FHE computation)                            │
│  • Gateway (Event monitoring)                               │
│  • KMS (Decryption)                                         │
│  [Already deployed and running]                             │
└─────────────────────────────────────────────────────────────┘
```

### Key Insight

**You don't need to rebuild FHEVM!** Just:
1. ✅ Create Stylus interfaces to existing FHEVM contracts
2. ✅ Port your contract logic to Rust
3. ✅ Use existing off-chain infrastructure

---

## Table of Contents

1. [FHEVM Contract Addresses](#fhevm-contract-addresses)
2. [Precompile Interface](#precompile-interface)
3. [Stylus Middleware Library](#stylus-middleware-library)
4. [Porting Contract Example](#porting-contract-example)
5. [Complete Implementation](#complete-implementation)
6. [Testing Strategy](#testing-strategy)
7. [Deployment Guide](#deployment-guide)

---

## FHEVM Contract Addresses

### Sepolia Testnet (Current Deployment)

```rust
// Known FHEVM contract addresses on Sepolia
pub const FHEVM_EXECUTOR: Address = address!("0x848B0066793BcC60346Da1F49049357399B8D595");
pub const ACL_CONTRACT: Address = address!("0x687820221192C5B662b25367F70076A37bc79b6c");
pub const KMS_VERIFIER: Address = address!("0x1364cBBf2cDF5032C47d8226a6f6FBD2AFCDacAC");
pub const INPUT_VERIFIER: Address = address!("0xbc91f3daD1A5F19F8390c400196e58073B6a0BC4");
pub const GATEWAY_CONTRACT: Address = address!("0xb6E160B1ff80D67Bfe90A85eE06Ce0A2613607D1");
```

**Note:** FHEVM is currently on Ethereum Sepolia testnet. For Arbitrum Sepolia/Arbitrum One deployment, check:
- [Zama Documentation](https://docs.zama.org/protocol)
- [Fhenix CoFHE on Arbitrum](https://www.fhenix.io/)

### Expected Arbitrum Deployment

Once FHEVM or Fhenix CoFHE is deployed on Arbitrum:

```rust
// To be updated with actual Arbitrum addresses
pub mod arbitrum_one {
    pub const FHEVM_EXECUTOR: Address = address!("0x...");  // TBD
    pub const ACL_CONTRACT: Address = address!("0x...");    // TBD
    // ... other contracts
}

pub mod arbitrum_sepolia {
    pub const FHEVM_EXECUTOR: Address = address!("0x...");  // TBD
    pub const ACL_CONTRACT: Address = address!("0x...");    // TBD
    // ... other contracts
}
```

---

## Precompile Interface

### FHEVM Precompile ABI

Based on fhEVM-go and Solidity library analysis, the precompile interface looks like:

```solidity
// Conceptual interface (actual implementation uses multiple precompiles)
interface IFHEVMPrecompile {
    // Arithmetic operations
    function fheAdd(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);
    function fheSub(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);
    function fheMul(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);
    function fheDiv(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);

    // Comparison operations
    function fheLt(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);
    function fheGt(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);
    function fheEq(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);

    // Bitwise operations
    function fheAnd(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);
    function fheOr(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);
    function fheXor(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);

    // Special operations
    function fheMin(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);
    function fheMax(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
        external pure returns (bytes32);
    function fheNeg(bytes32 ct)
        external pure returns (bytes32);
    function fheNot(bytes32 ct)
        external pure returns (bytes32);

    // Conditional selection
    function fheSelect(bytes32 control, bytes32 ifTrue, bytes32 ifFalse)
        external pure returns (bytes32);

    // Random generation
    function fheRand(bytes1 randType)
        external returns (bytes32);
    function fheRandBounded(uint256 upperBound, bytes1 randType)
        external returns (bytes32);
}

// ACL (Access Control List) interface
interface IFHEVMACLmiddleware {
    function allow(bytes32 handle, address account) external;
    function allowTransient(bytes32 handle, address account) external;
    function isAllowed(bytes32 handle, address account)
        external view returns (bool);
}

// Input verification interface
interface IFHEVMInputVerifier {
    function verifyCiphertext(
        bytes32 inputHandle,
        bytes calldata inputProof,
        uint8 toType
    ) external returns (bytes32);
}
```

**Key Parameters:**
- `bytes32 lhs/rhs`: Left/right operand handles
- `bytes1 scalarByte`: Type information (0x00 = encrypted, 0x01 = plaintext scalar)
- `bytes32 handle`: Encrypted value handle (pointer to ciphertext)
- `uint8 toType`: Target encrypted type (0 = ebool, 1 = euint8, 2 = euint16, etc.)

---

## Stylus Middleware Library

### Step 1: Create Stylus Interfaces

```rust
// fhe_middleware/src/interfaces.rs

#![no_std]
extern crate alloc;

use stylus_sdk::{
    prelude::*,
    call::Call,
    alloy_primitives::{Address, U256, FixedBytes},
};
use alloy_sol_types::sol;

// Define Solidity interface for FHEVM precompiles
sol_interface! {
    interface IFHEVMPrecompile {
        function fheAdd(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);

        function fheSub(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);

        function fheMul(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);

        function fheDiv(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);

        function fheLt(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);

        function fheGt(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);

        function fheEq(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);

        function fheMin(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);

        function fheMax(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);

        function fheNeg(bytes32 ct)
            external pure returns (bytes32);

        function fheNot(bytes32 ct)
            external pure returns (bytes32);

        function fheSelect(bytes32 control, bytes32 ifTrue, bytes32 ifFalse)
            external pure returns (bytes32);

        function fheRand(bytes1 randType)
            external returns (bytes32);
    }
}

sol_interface! {
    interface IFHEVMACL {
        function allow(bytes32 handle, address account) external;
        function allowTransient(bytes32 handle, address account) external;
        function isAllowed(bytes32 handle, address account)
            external view returns (bool);
    }
}

sol_interface! {
    interface IFHEVMInputVerifier {
        function verifyCiphertext(
            bytes32 inputHandle,
            bytes calldata inputProof,
            uint8 toType
        ) external returns (bytes32);
    }
}
```

### Step 2: Create Type Wrappers

```rust
// fhe_middleware/src/types.rs

use alloy_primitives::FixedBytes;

/// Type alias for encrypted value handles
pub type EHandle = FixedBytes<32>;

/// Encrypted unsigned integer types
#[repr(transparent)]
#[derive(Clone, Copy, Debug)]
pub struct Euint8(pub EHandle);

#[repr(transparent)]
#[derive(Clone, Copy, Debug)]
pub struct Euint16(pub EHandle);

#[repr(transparent)]
#[derive(Clone, Copy, Debug)]
pub struct Euint32(pub EHandle);

#[repr(transparent)]
#[derive(Clone, Copy, Debug)]
pub struct Euint64(pub EHandle);

#[repr(transparent)]
#[derive(Clone, Copy, Debug)]
pub struct Euint128(pub EHandle);

#[repr(transparent)]
#[derive(Clone, Copy, Debug)]
pub struct Euint256(pub EHandle);

/// Encrypted boolean
#[repr(transparent)]
#[derive(Clone, Copy, Debug)]
pub struct Ebool(pub EHandle);

/// Encrypted address
#[repr(transparent)]
#[derive(Clone, Copy, Debug)]
pub struct Eaddress(pub EHandle);

/// External input types (for function parameters with proofs)
#[derive(Clone, Copy, Debug)]
pub struct ExternalEuint64 {
    pub input_handle: FixedBytes<32>,
    pub input_proof: &'static [u8],
}

// Similar for all external types

/// Scalar byte for operation type
pub const SCALAR_ENCRYPTED: u8 = 0x00;
pub const SCALAR_PLAINTEXT: u8 = 0x01;

/// Encrypted type identifiers
pub const TYPE_EBOOL: u8 = 0;
pub const TYPE_EUINT8: u8 = 1;
pub const TYPE_EUINT16: u8 = 2;
pub const TYPE_EUINT32: u8 = 3;
pub const TYPE_EUINT64: u8 = 4;
pub const TYPE_EUINT128: u8 = 5;
pub const TYPE_EUINT256: u8 = 6;
pub const TYPE_EADDRESS: u8 = 7;
```

### Step 3: Implement FHE Operations

```rust
// fhe_middleware/src/fhe.rs

use crate::{
    interfaces::*,
    types::*,
};
use stylus_sdk::{
    call::Call,
    alloy_primitives::Address,
    evm,
};
use alloc::vec::Vec;

/// Configuration for FHEVM contracts
pub struct FHEConfig {
    pub precompile_address: Address,
    pub acl_address: Address,
    pub input_verifier_address: Address,
}

/// Main FHE operations struct
pub struct FHE;

impl FHE {
    /// Get FHE configuration (network-specific)
    pub fn config() -> FHEConfig {
        // TODO: Make this configurable per network
        FHEConfig {
            precompile_address: address!("0x848B0066793BcC60346Da1F49049357399B8D595"),
            acl_address: address!("0x687820221192C5B662b25367F70076A37bc79b6c"),
            input_verifier_address: address!("0xbc91f3daD1A5F19F8390c400196e58073B6a0BC4"),
        }
    }

    // ============ Arithmetic Operations ============

    pub fn add_euint64(lhs: Euint64, rhs: Euint64) -> Euint64 {
        let config = Self::config();
        let precompile = IFHEVMPrecompile::new(config.precompile_address);

        let result = precompile
            .fhe_add(
                Call::new(),
                lhs.0,
                rhs.0,
                FixedBytes::from([SCALAR_ENCRYPTED])
            )
            .expect("FHE add failed");

        Euint64(result._0)
    }

    pub fn sub_euint64(lhs: Euint64, rhs: Euint64) -> Euint64 {
        let config = Self::config();
        let precompile = IFHEVMPrecompile::new(config.precompile_address);

        let result = precompile
            .fhe_sub(
                Call::new(),
                lhs.0,
                rhs.0,
                FixedBytes::from([SCALAR_ENCRYPTED])
            )
            .expect("FHE sub failed");

        Euint64(result._0)
    }

    pub fn mul_euint64(lhs: Euint64, rhs: Euint64) -> Euint64 {
        let config = Self::config();
        let precompile = IFHEVMPrecompile::new(config.precompile_address);

        let result = precompile
            .fhe_mul(
                Call::new(),
                lhs.0,
                rhs.0,
                FixedBytes::from([SCALAR_ENCRYPTED])
            )
            .expect("FHE mul failed");

        Euint64(result._0)
    }

    // ============ Comparison Operations ============

    pub fn eq_euint64(lhs: Euint64, rhs: Euint64) -> Ebool {
        let config = Self::config();
        let precompile = IFHEVMPrecompile::new(config.precompile_address);

        let result = precompile
            .fhe_eq(
                Call::new(),
                lhs.0,
                rhs.0,
                FixedBytes::from([SCALAR_ENCRYPTED])
            )
            .expect("FHE eq failed");

        Ebool(result._0)
    }

    pub fn lt_euint64(lhs: Euint64, rhs: Euint64) -> Ebool {
        let config = Self::config();
        let precompile = IFHEVMPrecompile::new(config.precompile_address);

        let result = precompile
            .fhe_lt(
                Call::new(),
                lhs.0,
                rhs.0,
                FixedBytes::from([SCALAR_ENCRYPTED])
            )
            .expect("FHE lt failed");

        Ebool(result._0)
    }

    pub fn gt_euint64(lhs: Euint64, rhs: Euint64) -> Ebool {
        let config = Self::config();
        let precompile = IFHEVMPrecompile::new(config.precompile_address);

        let result = precompile
            .fhe_gt(
                Call::new(),
                lhs.0,
                rhs.0,
                FixedBytes::from([SCALAR_ENCRYPTED])
            )
            .expect("FHE gt failed");

        Ebool(result._0)
    }

    // ============ Conditional Selection ============

    pub fn select_euint64(
        condition: Ebool,
        if_true: Euint64,
        if_false: Euint64
    ) -> Euint64 {
        let config = Self::config();
        let precompile = IFHEVMPrecompile::new(config.precompile_address);

        let result = precompile
            .fhe_select(
                Call::new(),
                condition.0,
                if_true.0,
                if_false.0
            )
            .expect("FHE select failed");

        Euint64(result._0)
    }

    // ============ Type Conversions ============

    pub fn as_euint64(value: u64) -> Euint64 {
        // Create trivial encrypted value from plaintext
        // This would normally call a precompile, but simplified here
        let mut handle = FixedBytes::<32>::default();
        handle.0[0] = TYPE_EUINT64;
        handle.0[1..9].copy_from_slice(&value.to_le_bytes());

        Euint64(handle)
    }

    pub fn as_ebool(value: bool) -> Ebool {
        let mut handle = FixedBytes::<32>::default();
        handle.0[0] = TYPE_EBOOL;
        handle.0[1] = if value { 1 } else { 0 };

        Ebool(handle)
    }

    pub fn from_external_euint64(
        input_handle: FixedBytes<32>,
        input_proof: &[u8]
    ) -> Result<Euint64, &'static str> {
        let config = Self::config();
        let verifier = IFHEVMInputVerifier::new(config.input_verifier_address);

        let result = verifier
            .verify_ciphertext(
                Call::new(),
                input_handle,
                input_proof,
                TYPE_EUINT64
            )
            .map_err(|_| "Input verification failed")?;

        Ok(Euint64(result._0))
    }

    // ============ Access Control ============

    pub fn allow(handle: Euint64, account: Address) {
        let config = Self::config();
        let acl = IFHEVMACL::new(config.acl_address);

        acl.allow(Call::new(), handle.0, account)
            .expect("ACL allow failed");
    }

    pub fn allow_this(handle: Euint64) {
        let contract_address = evm::contract_address();
        Self::allow(handle, contract_address);
    }

    pub fn is_allowed(handle: Euint64, account: Address) -> bool {
        let config = Self::config();
        let acl = IFHEVMACL::new(config.acl_address);

        acl.is_allowed(Call::new(), handle.0, account)
            .unwrap_or(false)
            ._0
    }

    // ============ Random Generation ============

    pub fn rand_euint64() -> Euint64 {
        let config = Self::config();
        let precompile = IFHEVMPrecompile::new(config.precompile_address);

        let result = precompile
            .fhe_rand(
                Call::new(),
                FixedBytes::from([TYPE_EUINT64])
            )
            .expect("FHE rand failed");

        Euint64(result._0)
    }
}

// ============ Operator Overloading ============

use core::ops::{Add, Sub, Mul};

impl Add for Euint64 {
    type Output = Euint64;

    fn add(self, rhs: Euint64) -> Euint64 {
        FHE::add_euint64(self, rhs)
    }
}

impl Sub for Euint64 {
    type Output = Euint64;

    fn sub(self, rhs: Euint64) -> Euint64 {
        FHE::sub_euint64(self, rhs)
    }
}

impl Mul for Euint64 {
    type Output = Euint64;

    fn mul(self, rhs: Euint64) -> Euint64 {
        FHE::mul_euint64(self, rhs)
    }
}
```

---

## Porting Contract Example

### Original Solidity: ConfidentialERC20

```solidity
// Original Solidity contract
pragma solidity ^0.8.24;

import {FHE, euint64} from "@fhevm/solidity/lib/FHE.sol";

contract ConfidentialERC20 {
    mapping(address => euint64) internal balances;
    mapping(address => mapping(address => euint64)) internal allowances;

    function transfer(address to, euint64 amount) public returns (bool) {
        euint64 senderBalance = balances[msg.sender];
        euint64 newSenderBalance = FHE.sub(senderBalance, amount);
        balances[msg.sender] = newSenderBalance;

        euint64 receiverBalance = balances[to];
        euint64 newReceiverBalance = FHE.add(receiverBalance, amount);
        balances[to] = newReceiverBalance;

        FHE.allow(newSenderBalance, msg.sender);
        FHE.allow(newReceiverBalance, to);

        return true;
    }

    function balanceOf(address account) public view returns (euint64) {
        return balances[account];
    }
}
```

### Ported to Stylus

```rust
// Ported Stylus contract
#![cfg_attr(not(feature = "export-abi"), no_main)]
extern crate alloc;

use stylus_sdk::{
    prelude::*,
    storage::{StorageMap, StorageAddress},
    alloy_primitives::{Address, U256},
    msg,
};
use fhe_middleware::{FHE, Euint64};

#[storage]
pub struct ConfidentialERC20 {
    balances: StorageMap<Address, Euint64>,
    allowances: StorageMap<(Address, Address), Euint64>,
    total_supply: Euint64,
}

#[entrypoint]
impl ConfidentialERC20 {
    /// Transfer encrypted amount to recipient
    pub fn transfer(
        &mut self,
        to: Address,
        amount: Euint64
    ) -> Result<bool, Vec<u8>> {
        let sender = msg::sender();

        // Get current balances
        let sender_balance = self.balances.get(sender);
        let receiver_balance = self.balances.get(to);

        // Perform encrypted arithmetic via FHE precompiles
        let new_sender_balance = FHE::sub_euint64(sender_balance, amount);
        let new_receiver_balance = FHE::add_euint64(receiver_balance, amount);

        // Update storage
        self.balances.insert(sender, new_sender_balance);
        self.balances.insert(to, new_receiver_balance);

        // Set access control
        FHE::allow(new_sender_balance, sender);
        FHE::allow(new_receiver_balance, to);

        // Emit event (optional)
        evm::log(Transfer {
            from: sender,
            to,
            value: amount.0,  // Handle, not plaintext
        });

        Ok(true)
    }

    /// Get encrypted balance
    pub fn balance_of(&self, account: Address) -> Euint64 {
        self.balances.get(account)
    }

    /// Get allowance
    pub fn allowance(&self, owner: Address, spender: Address) -> Euint64 {
        self.allowances.get((owner, spender))
    }

    /// Approve spender
    pub fn approve(
        &mut self,
        spender: Address,
        amount: Euint64
    ) -> Result<bool, Vec<u8>> {
        let owner = msg::sender();

        self.allowances.insert((owner, spender), amount);

        FHE::allow(amount, spender);

        Ok(true)
    }

    /// Transfer from (with allowance)
    pub fn transfer_from(
        &mut self,
        from: Address,
        to: Address,
        amount: Euint64
    ) -> Result<bool, Vec<u8>> {
        let spender = msg::sender();

        // Check allowance
        let current_allowance = self.allowances.get((from, spender));
        let new_allowance = FHE::sub_euint64(current_allowance, amount);
        self.allowances.insert((from, spender), new_allowance);

        // Perform transfer
        let from_balance = self.balances.get(from);
        let to_balance = self.balances.get(to);

        let new_from_balance = FHE::sub_euint64(from_balance, amount);
        let new_to_balance = FHE::add_euint64(to_balance, amount);

        self.balances.insert(from, new_from_balance);
        self.balances.insert(to, new_to_balance);

        // Access control
        FHE::allow(new_from_balance, from);
        FHE::allow(new_to_balance, to);
        FHE::allow(new_allowance, spender);

        Ok(true)
    }
}

// Event definitions
sol! {
    event Transfer(address indexed from, address indexed to, bytes32 value);
    event Approval(address indexed owner, address indexed spender, bytes32 value);
}
```

---

## Complete Implementation

### Project Structure

```
fhe-stylus-middleware/
├── Cargo.toml
├── src/
│   ├── lib.rs          # Library entry point
│   ├── interfaces.rs   # sol_interface! definitions
│   ├── types.rs        # Encrypted type wrappers
│   ├── fhe.rs          # FHE operations implementation
│   └── config.rs       # Network configuration
└── examples/
    ├── confidential_erc20.rs
    ├── confidential_voting.rs
    └── evvm_core.rs    # Your EVVMCore port
```

### Cargo.toml

```toml
[package]
name = "fhe-stylus-middleware"
version = "0.1.0"
edition = "2021"

[dependencies]
stylus-sdk = "0.6"
alloy-primitives = "0.8"
alloy-sol-types = "0.8"

[features]
export-abi = ["stylus-sdk/export-abi"]

[profile.release]
opt-level = "z"
lto = true
codegen-units = 1
strip = true
```

### lib.rs

```rust
#![cfg_attr(not(feature = "export-abi"), no_std)]
extern crate alloc;

pub mod interfaces;
pub mod types;
pub mod fhe;
pub mod config;

// Re-exports
pub use fhe::FHE;
pub use types::{
    Euint8, Euint16, Euint32, Euint64, Euint128, Euint256,
    Ebool, Eaddress,
    ExternalEuint64,
};
pub use config::FHEConfig;
```

### config.rs

```rust
use stylus_sdk::alloy_primitives::Address;

#[derive(Clone, Copy)]
pub struct FHEConfig {
    pub precompile_address: Address,
    pub acl_address: Address,
    pub input_verifier_address: Address,
    pub kms_verifier_address: Address,
    pub gateway_address: Address,
}

impl FHEConfig {
    /// Sepolia testnet configuration
    pub const fn sepolia() -> Self {
        Self {
            precompile_address: address!("0x848B0066793BcC60346Da1F49049357399B8D595"),
            acl_address: address!("0x687820221192C5B662b25367F70076A37bc79b6c"),
            input_verifier_address: address!("0xbc91f3daD1A5F19F8390c400196e58073B6a0BC4"),
            kms_verifier_address: address!("0x1364cBBf2cDF5032C47d8226a6f6FBD2AFCDacAC"),
            gateway_address: address!("0xb6E160B1ff80D67Bfe90A85eE06Ce0A2613607D1"),
        }
    }

    /// Arbitrum One configuration (TBD - update when deployed)
    pub const fn arbitrum_one() -> Self {
        Self {
            precompile_address: address!("0x0000000000000000000000000000000000000000"),  // TBD
            acl_address: address!("0x0000000000000000000000000000000000000000"),          // TBD
            input_verifier_address: address!("0x0000000000000000000000000000000000000000"), // TBD
            kms_verifier_address: address!("0x0000000000000000000000000000000000000000"),   // TBD
            gateway_address: address!("0x0000000000000000000000000000000000000000"),        // TBD
        }
    }

    /// Arbitrum Sepolia configuration (TBD)
    pub const fn arbitrum_sepolia() -> Self {
        Self {
            precompile_address: address!("0x0000000000000000000000000000000000000000"),  // TBD
            acl_address: address!("0x0000000000000000000000000000000000000000"),          // TBD
            input_verifier_address: address!("0x0000000000000000000000000000000000000000"), // TBD
            kms_verifier_address: address!("0x0000000000000000000000000000000000000000"),   // TBD
            gateway_address: address!("0x0000000000000000000000000000000000000000"),        // TBD
        }
    }
}
```

---

## Testing Strategy

### 1. Unit Tests (Mock Precompiles)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_euint64_addition() {
        // Mock implementation for testing
        let a = Euint64::from_plaintext(100);
        let b = Euint64::from_plaintext(50);

        let result = FHE::add_euint64(a, b);

        // In real tests, you'd verify the handle was created correctly
        assert!(result.0 != FixedBytes::default());
    }
}
```

### 2. Integration Tests (With TestnetPrecompiles)

```rust
// tests/integration_test.rs

use fhe_stylus_middleware::{FHE, Euint64, FHEConfig};

#[test]
#[ignore] // Only run when connected to testnet
fn test_real_precompile() {
    // Set up connection to Sepolia testnet
    let config = FHEConfig::sepolia();

    // Test actual precompile call
    let a = FHE::as_euint64(100);
    let b = FHE::as_euint64(50);

    let result = FHE::add_euint64(a, b);

    // Verify result handle is valid
    assert!(result.0 != FixedBytes::default());
}
```

### 3. E2E Tests (Full Stack)

```typescript
// test/confidential_erc20.test.ts

import { ethers } from "hardhat";
import { createInstance } from "fhevmjs";

describe("Stylus Confidential ERC20", () => {
  it("should transfer encrypted amounts", async () => {
    const [alice, bob] = await ethers.getSigners();

    // Deploy Stylus contract
    const ConfidentialERC20 = await ethers.getContractFactory("ConfidentialERC20");
    const token = await ConfidentialERC20.deploy();

    // Create FHE instance
    const fhevm = await createInstance({ chainId: 421614 }); // Arbitrum Sepolia

    // Encrypt amount
    const amount = await fhevm.encrypt64(100);

    // Transfer
    await token.connect(alice).transfer(bob.address, amount);

    // Verify (need to decrypt to check)
    // ... decryption flow
  });
});
```

---

## Deployment Guide

### 1. Deploy Middleware Library

```bash
# Build the library
cd fhe-stylus-middleware
cargo build --release --target wasm32-unknown-unknown

# Optimize WASM
wasm-opt -Oz -o optimized.wasm target/wasm32-unknown-unknown/release/fhe_stylus_middleware.wasm

# Check size
ls -lh optimized.wasm  # Should be < 24KB

# Deploy to Arbitrum Sepolia
cargo stylus deploy \
  --private-key=$PRIVATE_KEY \
  --endpoint=https://sepolia-rollup.arbitrum.io/rpc
```

### 2. Deploy Your Contract

```bash
# Build contract using the middleware
cd my-contract
cargo build --release --target wasm32-unknown-unknown

# Deploy
cargo stylus deploy \
  --private-key=$PRIVATE_KEY \
  --endpoint=https://sepolia-rollup.arbitrum.io/rpc
```

### 3. Verify on Arbiscan

```bash
cargo stylus verify \
  --contract-address=$CONTRACT_ADDRESS \
  --endpoint=https://sepolia-rollup.arbitrum.io/rpc
```

---

## Porting Your EVVMCore Contract

### Strategy

Your EVVMCore.sol has these main components:
1. **Encrypted state** (balances, metadata)
2. **FHE operations** (add, sub, mul for payments)
3. **Virtual blockchain logic** (blocks, transactions)
4. **Access control** (validators, staking)

### Port Plan

```
Phase 1: Middleware Setup (Week 1)
├── Create sol_interface! for FHEVM precompiles
├── Implement type wrappers (Euint64, Ebool, etc.)
├── Implement FHE operations (add, sub, mul, etc.)
└── Test with mock precompiles

Phase 2: Core Logic Port (Week 2-3)
├── Port encrypted balance management
├── Port FHE payment logic
├── Port access control (non-FHE parts)
└── Port event emissions

Phase 3: Virtual Blockchain (Week 4)
├── Port block creation logic
├── Port transaction management
├── Port validator logic
└── Integration testing

Phase 4: Testing & Deployment (Week 5)
├── Unit tests
├── Integration tests with testnet
├── Gas optimization
└── Mainnet deployment
```

### Example: Porting Payment Function

**Original Solidity:**
```solidity
function pay(PaymentParams memory params) external onlyInitialized {
    euint64 encryptedAmount = FHE.fromExternal(
        params.inputEncryptedAmount,
        params.inputAmountProof
    );

    balances[params.from][params.token] = FHE.sub(
        balances[params.from][params.token],
        encryptedAmount
    );

    balances[params.to][params.token] = FHE.add(
        balances[params.to][params.token],
        encryptedAmount
    );

    FHE.allow(balances[params.from][params.token], params.from);
    FHE.allow(balances[params.to][params.token], params.to);
}
```

**Ported Stylus:**
```rust
pub fn pay(
    &mut self,
    from: Address,
    to: Address,
    token: Address,
    input_encrypted_amount: FixedBytes<32>,
    input_amount_proof: Vec<u8>
) -> Result<(), Vec<u8>> {
    self.only_initialized()?;

    // Convert external input
    let encrypted_amount = FHE::from_external_euint64(
        input_encrypted_amount,
        &input_amount_proof
    )?;

    // Get current balances
    let from_balance = self.balances.get((from, token));
    let to_balance = self.balances.get((to, token));

    // Update balances (calls FHEVM precompiles)
    let new_from_balance = FHE::sub_euint64(from_balance, encrypted_amount);
    let new_to_balance = FHE::add_euint64(to_balance, encrypted_amount);

    // Store updated balances
    self.balances.insert((from, token), new_from_balance);
    self.balances.insert((to, token), new_to_balance);

    // Set access control
    FHE::allow(new_from_balance, from);
    FHE::allow(new_to_balance, to);

    Ok(())
}
```

---

## Next Steps

1. **Find or Deploy FHEVM on Arbitrum**
   - Check if Fhenix CoFHE is already on Arbitrum
   - Or work with Zama to deploy FHEVM to Arbitrum
   - Get actual contract addresses

2. **Build Middleware Library**
   - Implement sol_interface! for all precompiles
   - Create type wrappers
   - Implement FHE operations
   - Test locally

3. **Port ConfidentialERC20 First**
   - Use as proof-of-concept
   - Test on testnet
   - Verify gas costs
   - Ensure compatibility

4. **Port EVVMCore**
   - Follow phased approach
   - Extensive testing
   - Security audit
   - Production deployment

---

## Conclusion

This middleware approach is **practical and achievable** because:

✅ You don't need to rebuild FHE infrastructure
✅ You can call existing precompiles via `sol_interface!`
✅ Off-chain infrastructure (coprocessor, KMS) already works
✅ Only port on-chain contract logic
✅ Leverage Stylus performance for non-FHE operations

**Estimated Effort:** 4-6 weeks for full EVVMCore port

**Key Success Factors:**
1. Get accurate FHEVM contract addresses on Arbitrum
2. Test middleware library thoroughly
3. Start with simpler contracts (ERC20) before complex ones
4. Monitor gas costs compared to Solidity
5. Plan for ongoing maintenance as FHEVM evolves

**This is the RIGHT approach** for practical FHE + Stylus integration!

---

**Document Version:** 1.0
**Last Updated:** 2025-11-11
**Author:** Claude (Anthropic)
**Project:** InvisibleGarden - Invisible zkEVM
