# Stylus FHE Middleware: Ultra-Detailed Implementation Plan

**Date:** 2025-11-11
**Project:** Invisible zkEVM - Stylus FHE Integration
**Status:** Ready for Implementation
**Estimated Timeline:** 4-6 weeks
**Complexity:** Medium-High

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture Deep Dive](#architecture-deep-dive)
3. [Phase-by-Phase Implementation](#phase-by-phase-implementation)
4. [Technical Specifications](#technical-specifications)
5. [Code Structure](#code-structure)
6. [Testing Strategy](#testing-strategy)
7. [Deployment Plan](#deployment-plan)
8. [Risk Mitigation](#risk-mitigation)
9. [Success Metrics](#success-metrics)

---

## Project Overview

### Goal
Create a production-ready Stylus middleware library that allows Rust smart contracts to use FHE operations by calling existing FHEVM precompiles on Arbitrum.

### Non-Goals
- ❌ Reimplementing FHE cryptography
- ❌ Building coprocessor infrastructure
- ❌ Modifying Stylus VM
- ❌ Creating new KMS

### Deliverables

1. **fhe-stylus** - Reusable middleware library crate
2. **confidential-erc20** - Example implementation
3. **evvm-core-stylus** - Ported EVVMCore contract
4. **Test suite** - Unit, integration, and E2E tests
5. **Documentation** - API docs, guides, examples
6. **Deployment scripts** - Automated deployment

---

## Architecture Deep Dive

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Layer 1: User/DApp                        │
│  • Web frontend with fhevmjs                                │
│  • Encrypts data client-side                                │
│  • Signs transactions                                       │
└─────────────────────────────────────────────────────────────┘
                           │ Encrypted input + proof
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Layer 2: Stylus Smart Contract                  │
│  • Business logic in Rust                                   │
│  • State management                                         │
│  • Access control                                           │
│  • Event emission                                           │
└─────────────────────────────────────────────────────────────┘
                           │ FHE operation calls
                           ▼
┌─────────────────────────────────────────────────────────────┐
│            Layer 3: FHE Middleware Library                   │
│  • Type abstractions (Euint64, Ebool)                       │
│  • sol_interface! definitions                               │
│  • Operator overloading                                     │
│  • Configuration management                                 │
└─────────────────────────────────────────────────────────────┘
                           │ External contract calls
                           ▼
┌─────────────────────────────────────────────────────────────┐
│          Layer 4: FHEVM Precompiles (Solidity)              │
│  • Already deployed on Arbitrum                             │
│  • Arithmetic operations                                    │
│  • Comparison operations                                    │
│  • ACL management                                           │
└─────────────────────────────────────────────────────────────┘
                           │ Events + symbolic execution
                           ▼
┌─────────────────────────────────────────────────────────────┐
│         Layer 5: Off-Chain Infrastructure                    │
│  • Coprocessor (FHE computation)                            │
│  • Gateway (event monitoring)                               │
│  • KMS (threshold decryption)                               │
│  [Already operational]                                      │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

#### 1. Encrypted Input Flow
```
Client (fhevmjs)
  └─> Encrypt(value, publicKey) → ciphertext
      └─> Generate ZK proof
          └─> Send (ciphertext, proof) to contract
              └─> Stylus contract
                  └─> FHE::from_external(ciphertext, proof)
                      └─> Call InputVerifier precompile
                          └─> Verify proof ✓
                              └─> Return handle (bytes32)
```

#### 2. FHE Operation Flow
```
Stylus Contract: balance1 - amount
  └─> FHE::sub_euint64(balance1, amount)
      └─> IFHEVMPrecompile.fheSub(handle1, handle2, 0x00)
          └─> Precompile: emit FHEOperation event
              └─> Gateway: detect event
                  └─> Coprocessor: FHE.sub(ct1, ct2)
                      └─> Store result ciphertext
                          └─> Return result handle
```

#### 3. Decryption Flow
```
Contract: FHE::allow_for_decryption(balance)
  └─> Gateway: detect decryption request
      └─> KMS: threshold decryption
          └─> Gateway: callback with plaintext
              └─> Contract: fulfill_decryption(requestId, plaintext)
```

### Key Design Decisions

#### Decision 1: Handle-Based Types
**Rationale:** Encrypted values are never stored in contracts, only 32-byte handles (pointers to off-chain ciphertexts).

```rust
// Handle representation
pub struct Euint64(FixedBytes<32>);  // Just a pointer, not the ciphertext

// Storage efficiency
#[storage]
pub struct Contract {
    balance: Euint64,  // Only 32 bytes in storage
}
```

#### Decision 2: External Precompile Calls
**Rationale:** Don't modify Stylus VM, use existing `sol_interface!` mechanism.

```rust
sol_interface! {
    interface IFHEVMPrecompile {
        function fheAdd(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);
    }
}

// Usage
let precompile = IFHEVMPrecompile::new(PRECOMPILE_ADDR);
let result = precompile.fhe_add(Call::new(), lhs, rhs, scalar)?;
```

#### Decision 3: Operator Overloading
**Rationale:** Ergonomic Rust API matching Solidity patterns.

```rust
// Natural syntax
let new_balance = balance - amount;  // Calls FHE::sub internally

// Instead of verbose
let new_balance = FHE::sub_euint64(balance, amount);
```

#### Decision 4: Network Configuration
**Rationale:** Support multiple networks without code changes.

```rust
// Compile-time network selection
#[cfg(feature = "sepolia")]
const CONFIG: FHEConfig = FHEConfig::sepolia();

#[cfg(feature = "arbitrum-one")]
const CONFIG: FHEConfig = FHEConfig::arbitrum_one();
```

---

## Phase-by-Phase Implementation

### Phase 1: Foundation (Week 1)

**Goal:** Set up project structure, dependencies, basic types

#### Day 1: Project Setup
- [ ] Create workspace with 3 crates:
  - `fhe-stylus` (middleware library)
  - `examples/confidential-erc20` (example contract)
  - `examples/evvm-core` (EVVMCore port)
- [ ] Configure Cargo.toml with dependencies
- [ ] Set up build scripts for WASM target
- [ ] Create documentation structure

**Deliverables:**
```
invisible-zkevvm/
├── stylus-contracts/
│   ├── Cargo.toml (workspace)
│   ├── fhe-stylus/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       └── lib.rs
│   └── examples/
│       ├── confidential-erc20/
│       └── evvm-core/
```

#### Day 2-3: Type System
- [ ] Define encrypted type wrappers
  - `Euint8`, `Euint16`, `Euint32`, `Euint64`, `Euint128`, `Euint256`
  - `Ebool`, `Eaddress`
  - `ExternalEuint*` types
- [ ] Implement `StorageType` trait for each type
- [ ] Add type conversion utilities
- [ ] Write unit tests for type system

**Code Structure:**
```rust
// fhe-stylus/src/types.rs
pub type EHandle = FixedBytes<32>;

#[repr(transparent)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Euint64(pub(crate) EHandle);

impl Euint64 {
    pub const fn new(handle: EHandle) -> Self {
        Self(handle)
    }

    pub const fn handle(&self) -> EHandle {
        self.0
    }

    pub const fn zero() -> Self {
        Self(FixedBytes::ZERO)
    }
}

unsafe impl StorageType for Euint64 {
    type Wraps<'a> = Euint64;
    const SLOT_BYTES: usize = 32;

    fn load(slot: U256) -> Self {
        let handle = storage::load_bytes32(slot);
        Euint64(handle)
    }

    fn store(&self, slot: U256) {
        storage::store_bytes32(slot, &self.0);
    }
}
```

#### Day 4-5: Precompile Interfaces
- [ ] Define `sol_interface!` for all FHEVM precompiles
  - Arithmetic operations (15 functions)
  - Comparison operations (6 functions)
  - Bitwise operations (8 functions)
  - Special operations (5 functions)
- [ ] Define ACL interface
- [ ] Define InputVerifier interface
- [ ] Add comprehensive inline documentation

**Code Structure:**
```rust
// fhe-stylus/src/interfaces.rs
use alloy_sol_types::sol;

sol_interface! {
    /// FHEVM precompile for encrypted operations
    /// Deployed at: 0x848B0066793BcC60346Da1F49049357399B8D595 (Sepolia)
    interface IFHEVMPrecompile {
        /// Add two encrypted integers
        /// @param lhs Left operand handle
        /// @param rhs Right operand handle
        /// @param scalarByte 0x00=both encrypted, 0x01=rhs is scalar
        /// @return Result handle
        function fheAdd(bytes32 lhs, bytes32 rhs, bytes1 scalarByte)
            external pure returns (bytes32);

        // ... all other operations
    }
}

sol_interface! {
    /// Access Control List for FHE handles
    interface IFHEVMACL {
        /// Grant permanent access to handle
        function allow(bytes32 handle, address account) external;

        /// Grant transient access (cleared after transaction)
        function allowTransient(bytes32 handle, address account) external;

        /// Check if account can access handle
        function isAllowed(bytes32 handle, address account)
            external view returns (bool);
    }
}
```

### Phase 2: Core Operations (Week 2)

**Goal:** Implement FHE operations, operator overloading

#### Day 6-7: Arithmetic Operations
- [ ] Implement add, sub, mul, div, rem, neg
- [ ] Support both encrypted-encrypted and encrypted-scalar
- [ ] Handle errors gracefully
- [ ] Add gas estimation helpers
- [ ] Write unit tests (mocked precompiles)

**Implementation Pattern:**
```rust
// fhe-stylus/src/operations/arithmetic.rs
impl FHE {
    /// Add two encrypted uint64 values
    pub fn add_euint64(lhs: Euint64, rhs: Euint64) -> Result<Euint64, FHEError> {
        let config = CONFIG.get();
        let precompile = IFHEVMPrecompile::new(config.precompile_address);

        let result = precompile
            .fhe_add(
                Call::new(),
                lhs.handle(),
                rhs.handle(),
                FixedBytes::from([SCALAR_ENCRYPTED])
            )
            .map_err(|_| FHEError::PrecompileCallFailed)?;

        Ok(Euint64::new(result._0))
    }

    /// Add encrypted uint64 and plaintext scalar
    pub fn add_euint64_scalar(lhs: Euint64, rhs: u64) -> Result<Euint64, FHEError> {
        let scalar_handle = Self::scalar_to_handle(rhs, TYPE_EUINT64);
        let config = CONFIG.get();
        let precompile = IFHEVMPrecompile::new(config.precompile_address);

        let result = precompile
            .fhe_add(
                Call::new(),
                lhs.handle(),
                scalar_handle,
                FixedBytes::from([SCALAR_PLAINTEXT])
            )
            .map_err(|_| FHEError::PrecompileCallFailed)?;

        Ok(Euint64::new(result._0))
    }
}
```

#### Day 8-9: Comparison & Logic
- [ ] Implement eq, ne, lt, le, gt, ge
- [ ] Implement and, or, xor, not
- [ ] Implement select (ternary operator)
- [ ] Implement min, max
- [ ] Write unit tests

#### Day 10: Operator Overloading
- [ ] Implement `Add`, `Sub`, `Mul` traits
- [ ] Implement `BitAnd`, `BitOr`, `BitXor`, `Not` traits
- [ ] Implement `Neg` trait
- [ ] Implement `Shl`, `Shr` traits
- [ ] Test operator syntax

**Implementation:**
```rust
// fhe-stylus/src/operators.rs
use core::ops::*;

impl Add<Euint64> for Euint64 {
    type Output = Result<Euint64, FHEError>;

    fn add(self, rhs: Euint64) -> Self::Output {
        FHE::add_euint64(self, rhs)
    }
}

impl Add<u64> for Euint64 {
    type Output = Result<Euint64, FHEError>;

    fn add(self, rhs: u64) -> Self::Output {
        FHE::add_euint64_scalar(self, rhs)
    }
}

// Macro to reduce boilerplate
macro_rules! impl_arithmetic_ops {
    ($type:ty, $bit_width:expr) => {
        impl Add for $type { /* ... */ }
        impl Sub for $type { /* ... */ }
        impl Mul for $type { /* ... */ }
        impl Neg for $type { /* ... */ }
    };
}

impl_arithmetic_ops!(Euint8, 8);
impl_arithmetic_ops!(Euint16, 16);
impl_arithmetic_ops!(Euint32, 32);
impl_arithmetic_ops!(Euint64, 64);
```

### Phase 3: Advanced Features (Week 3)

**Goal:** Access control, input verification, configuration

#### Day 11-12: Access Control
- [ ] Implement `allow`, `allowTransient`, `allowThis`
- [ ] Implement `isAllowed`, `isSenderAllowed`
- [ ] Add batch permission granting
- [ ] Test ACL integration

```rust
// fhe-stylus/src/acl.rs
impl FHE {
    /// Grant permanent access to encrypted handle
    pub fn allow<T: EncryptedType>(handle: T, account: Address) -> Result<(), FHEError> {
        let config = CONFIG.get();
        let acl = IFHEVMACL::new(config.acl_address);

        acl.allow(Call::new(), handle.handle(), account)
            .map_err(|_| FHEError::ACLFailed)?;

        Ok(())
    }

    /// Grant access to contract itself
    pub fn allow_this<T: EncryptedType>(handle: T) -> Result<(), FHEError> {
        let contract_addr = evm::contract_address();
        Self::allow(handle, contract_addr)
    }

    /// Grant access to multiple addresses at once
    pub fn allow_batch<T: EncryptedType>(
        handle: T,
        accounts: &[Address]
    ) -> Result<(), FHEError> {
        for &account in accounts {
            Self::allow(handle, account)?;
        }
        Ok(())
    }
}
```

#### Day 13-14: Input Verification
- [ ] Implement `fromExternal` for all types
- [ ] Add proof verification
- [ ] Handle verification failures
- [ ] Test with real proofs

```rust
// fhe-stylus/src/input.rs
impl FHE {
    /// Convert external input to internal encrypted type
    pub fn from_external_euint64(
        input_handle: FixedBytes<32>,
        input_proof: &[u8]
    ) -> Result<Euint64, FHEError> {
        let config = CONFIG.get();
        let verifier = IFHEVMInputVerifier::new(config.input_verifier_address);

        let result = verifier
            .verify_ciphertext(
                Call::new(),
                input_handle,
                input_proof,
                TYPE_EUINT64
            )
            .map_err(|_| FHEError::VerificationFailed)?;

        Ok(Euint64::new(result._0))
    }
}
```

#### Day 15: Configuration System
- [ ] Create network configurations
- [ ] Add feature flags for networks
- [ ] Implement runtime configuration
- [ ] Add address validation

```rust
// fhe-stylus/src/config.rs
use once_cell::race::OnceBox;

static CONFIG: OnceBox<FHEConfig> = OnceBox::new();

#[derive(Clone, Copy, Debug)]
pub struct FHEConfig {
    pub precompile_address: Address,
    pub acl_address: Address,
    pub input_verifier_address: Address,
    pub kms_verifier_address: Address,
    pub gateway_address: Address,
}

impl FHEConfig {
    /// Initialize configuration (call once at contract deployment)
    pub fn init(config: FHEConfig) {
        CONFIG.set(Box::new(config)).ok();
    }

    /// Get current configuration
    pub fn get() -> &'static FHEConfig {
        CONFIG.get().expect("FHE config not initialized")
    }

    // Network presets
    pub const fn sepolia() -> Self { /* ... */ }
    pub const fn arbitrum_one() -> Self { /* ... */ }
    pub const fn arbitrum_sepolia() -> Self { /* ... */ }
}
```

### Phase 4: Example Contracts (Week 4)

**Goal:** Implement working examples, prove the pattern

#### Day 16-18: Confidential ERC20
- [ ] Port complete ERC20 interface
- [ ] Implement transfer, transferFrom, approve
- [ ] Add mint, burn (owner functions)
- [ ] Implement balance queries
- [ ] Add event emissions
- [ ] Write comprehensive tests

**Full Implementation:**
```rust
// examples/confidential-erc20/src/lib.rs
#![cfg_attr(not(feature = "export-abi"), no_main)]
extern crate alloc;

use stylus_sdk::{
    prelude::*,
    storage::{StorageMap, StorageString, StorageU256},
    alloy_primitives::{Address, U256},
    msg, block, evm,
};
use fhe_stylus::{FHE, Euint64, FHEError};
use alloc::vec::Vec;

sol! {
    event Transfer(address indexed from, address indexed to, bytes32 value);
    event Approval(address indexed owner, address indexed spender, bytes32 value);
    event Mint(address indexed to, bytes32 amount);
    event Burn(address indexed from, bytes32 amount);
}

#[storage]
pub struct ConfidentialERC20 {
    // Encrypted balances
    balances: StorageMap<Address, Euint64>,
    // Encrypted allowances
    allowances: StorageMap<(Address, Address), Euint64>,
    // Total supply (encrypted)
    total_supply: Euint64,
    // Token metadata (public)
    name: StorageString,
    symbol: StorageString,
    decimals: StorageU256,
    // Owner
    owner: Address,
}

#[entrypoint]
impl ConfidentialERC20 {
    /// Initialize the token
    pub fn init(
        &mut self,
        name: String,
        symbol: String,
        decimals: u8
    ) -> Result<(), Vec<u8>> {
        require(self.owner == Address::ZERO, "Already initialized");

        self.name.set_str(&name);
        self.symbol.set_str(&symbol);
        self.decimals.set(U256::from(decimals));
        self.owner = msg::sender();
        self.total_supply = Euint64::zero();

        Ok(())
    }

    /// Transfer encrypted amount
    pub fn transfer(
        &mut self,
        to: Address,
        amount: Euint64
    ) -> Result<bool, Vec<u8>> {
        require(to != Address::ZERO, "Transfer to zero address");

        let sender = msg::sender();

        let sender_balance = self.balances.get(sender);
        let receiver_balance = self.balances.get(to);

        // Encrypted arithmetic via precompiles
        let new_sender_balance = FHE::sub_euint64(sender_balance, amount)
            .map_err(|_| b"FHE operation failed")?;
        let new_receiver_balance = FHE::add_euint64(receiver_balance, amount)
            .map_err(|_| b"FHE operation failed")?;

        // Update balances
        self.balances.insert(sender, new_sender_balance);
        self.balances.insert(to, new_receiver_balance);

        // Set access control
        FHE::allow(new_sender_balance, sender)?;
        FHE::allow(new_receiver_balance, to)?;

        // Emit event
        evm::log(Transfer {
            from: sender,
            to,
            value: amount.handle(),
        });

        Ok(true)
    }

    /// Approve spender
    pub fn approve(
        &mut self,
        spender: Address,
        amount: Euint64
    ) -> Result<bool, Vec<u8>> {
        require(spender != Address::ZERO, "Approve to zero address");

        let owner = msg::sender();
        self.allowances.insert((owner, spender), amount);

        FHE::allow(amount, spender)?;

        evm::log(Approval {
            owner,
            spender,
            value: amount.handle(),
        });

        Ok(true)
    }

    /// Transfer from
    pub fn transfer_from(
        &mut self,
        from: Address,
        to: Address,
        amount: Euint64
    ) -> Result<bool, Vec<u8>> {
        require(from != Address::ZERO, "Transfer from zero");
        require(to != Address::ZERO, "Transfer to zero");

        let spender = msg::sender();

        // Check and update allowance
        let current_allowance = self.allowances.get((from, spender));
        let new_allowance = FHE::sub_euint64(current_allowance, amount)?;
        self.allowances.insert((from, spender), new_allowance);

        // Update balances
        let from_balance = self.balances.get(from);
        let to_balance = self.balances.get(to);

        let new_from_balance = FHE::sub_euint64(from_balance, amount)?;
        let new_to_balance = FHE::add_euint64(to_balance, amount)?;

        self.balances.insert(from, new_from_balance);
        self.balances.insert(to, new_to_balance);

        // Access control
        FHE::allow(new_from_balance, from)?;
        FHE::allow(new_to_balance, to)?;
        FHE::allow(new_allowance, spender)?;

        evm::log(Transfer { from, to, value: amount.handle() });

        Ok(true)
    }

    /// Mint (owner only)
    pub fn mint(
        &mut self,
        to: Address,
        amount: Euint64
    ) -> Result<(), Vec<u8>> {
        require(msg::sender() == self.owner, "Not owner");
        require(to != Address::ZERO, "Mint to zero address");

        let balance = self.balances.get(to);
        let new_balance = FHE::add_euint64(balance, amount)?;
        self.balances.insert(to, new_balance);

        let new_supply = FHE::add_euint64(self.total_supply, amount)?;
        self.total_supply = new_supply;

        FHE::allow(new_balance, to)?;
        FHE::allow_this(new_supply)?;

        evm::log(Mint { to, amount: amount.handle() });

        Ok(())
    }

    // View functions
    pub fn balance_of(&self, account: Address) -> Euint64 {
        self.balances.get(account)
    }

    pub fn allowance(&self, owner: Address, spender: Address) -> Euint64 {
        self.allowances.get((owner, spender))
    }

    pub fn total_supply(&self) -> Euint64 {
        self.total_supply
    }

    pub fn name(&self) -> String {
        self.name.get_string()
    }

    pub fn symbol(&self) -> String {
        self.symbol.get_string()
    }

    pub fn decimals(&self) -> u8 {
        self.decimals.get().as_limbs()[0] as u8
    }
}

// Helper macro
macro_rules! require {
    ($cond:expr, $msg:expr) => {
        if !$cond {
            return Err($msg.as_bytes().to_vec());
        }
    };
}
```

#### Day 19-21: EVVMCore Minimal Port
- [ ] Port payment function
- [ ] Port balance management
- [ ] Port access control (validators)
- [ ] Add basic block structure
- [ ] Test integration

**Minimal EVVMCore:**
```rust
// examples/evvm-core/src/lib.rs
#![cfg_attr(not(feature = "export-abi"), no_main)]
extern crate alloc;

use stylus_sdk::{prelude::*, storage::{StorageMap, StorageBool}, msg};
use fhe_stylus::{FHE, Euint64};

#[storage]
pub struct EVVMCoreMinimal {
    // Encrypted balances: user -> token -> encrypted amount
    balances: StorageMap<(Address, Address), Euint64>,
    // Validators
    validators: StorageMap<Address, StorageBool>,
    // Initialized flag
    initialized: StorageBool,
}

#[entrypoint]
impl EVVMCoreMinimal {
    /// Initialize
    pub fn initialize(&mut self) -> Result<(), Vec<u8>> {
        require(!self.initialized.get(), "Already initialized");

        self.initialized.set(true);
        self.validators.insert(msg::sender(), StorageBool::new(true));

        Ok(())
    }

    /// Process payment
    pub fn pay(
        &mut self,
        from: Address,
        to: Address,
        token: Address,
        amount: Euint64
    ) -> Result<(), Vec<u8>> {
        require(self.initialized.get(), "Not initialized");

        // Get balances
        let from_balance = self.balances.get((from, token));
        let to_balance = self.balances.get((to, token));

        // Update via FHE operations
        let new_from_balance = FHE::sub_euint64(from_balance, amount)?;
        let new_to_balance = FHE::add_euint64(to_balance, amount)?;

        // Store
        self.balances.insert((from, token), new_from_balance);
        self.balances.insert((to, token), new_to_balance);

        // Access control
        FHE::allow(new_from_balance, from)?;
        FHE::allow(new_to_balance, to)?;

        evm::log(PaymentProcessed { from, to, token });

        Ok(())
    }

    /// Add tokens to user (treasury function)
    pub fn add_amount_to_user(
        &mut self,
        user: Address,
        token: Address,
        amount: Euint64
    ) -> Result<(), Vec<u8>> {
        require(self.is_validator(msg::sender()), "Not validator");

        let balance = self.balances.get((user, token));
        let new_balance = FHE::add_euint64(balance, amount)?;

        self.balances.insert((user, token), new_balance);
        FHE::allow(new_balance, user)?;

        Ok(())
    }

    /// Get balance
    pub fn get_balance(&self, user: Address, token: Address) -> Euint64 {
        self.balances.get((user, token))
    }

    /// Check if validator
    pub fn is_validator(&self, addr: Address) -> bool {
        self.validators.get(addr).get()
    }
}

sol! {
    event PaymentProcessed(address indexed from, address indexed to, address indexed token);
}
```

### Phase 5: Testing & Documentation (Week 5)

**Goal:** Comprehensive testing, documentation, examples

#### Day 22-24: Testing
- [ ] Unit tests for all operations
- [ ] Integration tests with mock precompiles
- [ ] E2E tests on testnet
- [ ] Gas benchmarking
- [ ] Security review

**Test Structure:**
```rust
// fhe-stylus/tests/unit_tests.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_euint64_addition() {
        let a = Euint64::from_plaintext(100);
        let b = Euint64::from_plaintext(50);

        // In unit tests, use mock precompile
        let result = FHE::add_euint64(a, b).unwrap();

        assert!(result.handle() != FixedBytes::ZERO);
    }

    #[test]
    fn test_operator_overloading() {
        let a = Euint64::from_plaintext(100);
        let b = Euint64::from_plaintext(50);

        let result = (a + b).unwrap();
        let result2 = (a - b).unwrap();

        assert!(result.handle() != result2.handle());
    }
}

// examples/confidential-erc20/tests/integration.rs
#[cfg(test)]
mod integration {
    #[tokio::test]
    #[ignore] // Run only with --ignored on testnet
    async fn test_transfer_on_testnet() {
        // Connect to Sepolia
        let provider = Provider::new(/* ... */);
        let contract = ConfidentialERC20::new(address, provider);

        // Create encrypted input
        let fhevm = create_fhevm_instance().await;
        let amount = fhevm.encrypt_uint64(100).await;

        // Execute transfer
        let tx = contract.transfer(bob_address, amount).await?;
        let receipt = tx.await?;

        assert!(receipt.status == 1);
    }
}
```

#### Day 25-26: Documentation
- [ ] API documentation (rustdoc)
- [ ] Usage guide
- [ ] Architecture document
- [ ] Example gallery
- [ ] Troubleshooting guide

#### Day 27-28: Final Polish
- [ ] Code review
- [ ] Performance optimization
- [ ] Size optimization (< 24KB)
- [ ] Security audit checklist
- [ ] Deployment scripts

### Phase 6: Deployment (Week 6)

**Goal:** Deploy to testnet, verify, document

#### Day 29-30: Testnet Deployment
- [ ] Deploy middleware library
- [ ] Deploy example contracts
- [ ] Verify on Arbiscan
- [ ] Test all functions
- [ ] Document deployed addresses

**Deployment Script:**
```bash
#!/bin/bash
# deploy.sh

set -e

echo "Building contracts..."
cargo build --release --target wasm32-unknown-unknown

echo "Optimizing WASM..."
wasm-opt -Oz -o optimized.wasm target/wasm32-unknown-unknown/release/*.wasm

echo "Checking size..."
SIZE=$(stat -f%z optimized.wasm)
if [ $SIZE -gt 24576 ]; then
    echo "ERROR: Contract too large ($SIZE bytes > 24KB)"
    exit 1
fi

echo "Deploying to Arbitrum Sepolia..."
cargo stylus deploy \
    --private-key=$PRIVATE_KEY \
    --endpoint=https://sepolia-rollup.arbitrum.io/rpc \
    --wasm-file=optimized.wasm

echo "Deployment complete!"
```

---

## Technical Specifications

### Size Budget

```
Component                    | Size (KB) | Percentage
-----------------------------|-----------|------------
Type definitions             | 1.2       | 5%
Interface definitions        | 2.5       | 10%
FHE operations              | 8.0       | 33%
Operator overloading        | 3.0       | 13%
Storage implementations     | 1.5       | 6%
Configuration & utilities   | 2.0       | 8%
Error handling              | 1.0       | 4%
Documentation/metadata      | 0.8       | 3%
-----------------------------|-----------|------------
Total (compressed)          | 20.0      | 83%
Reserve                     | 4.0       | 17%
-----------------------------|-----------|------------
Limit                       | 24.0      | 100%
```

### Gas Cost Analysis

#### Baseline Costs (Solidity)
```
Operation          | Solidity Gas | Notes
-------------------|--------------|------------------
euint64 ADD        | 94,000       | Via precompile
euint64 SUB        | 94,000       | Via precompile
euint64 MUL        | 150,000      | Via precompile
euint64 LT         | 85,000       | Via precompile
Storage (SSTORE)   | 20,000       | Standard
```

#### Expected Stylus Costs
```
Operation          | Stylus Gas   | Notes
-------------------|--------------|------------------
euint64 ADD        | 94,000       | Same precompile
  + External call  | +2,100       | Cross-contract call
  = Total          | 96,100       | +2.2% overhead
-------------------|--------------|------------------
euint64 SUB        | 94,000       |
  + External call  | +2,100       |
  = Total          | 96,100       | +2.2% overhead
-------------------|--------------|------------------
Storage (SSTORE)   | 20,000       | Same as Solidity
Non-FHE logic      | -50%         | Stylus advantage
```

**Conclusion:** ~2% gas overhead for FHE operations, ~50% savings on non-FHE logic.

### Dependencies

```toml
[dependencies]
# Core Stylus SDK
stylus-sdk = "0.6.0"

# Alloy primitives
alloy-primitives = "0.8.0"
alloy-sol-types = "0.8.0"

# Utilities
once_cell = { version = "1.19", default-features = false }

[dev-dependencies]
# Testing
tokio = { version = "1.35", features = ["full"] }
hex = "0.4"

[features]
default = []
export-abi = ["stylus-sdk/export-abi"]

# Network features
sepolia = []
arbitrum-one = []
arbitrum-sepolia = []
```

---

## Testing Strategy

### 1. Unit Tests (Rust)
```rust
// Test individual operations in isolation
// Use mocked precompile responses
// Fast, run on every commit

cargo test --lib
```

### 2. Integration Tests (Rust + Mock Network)
```rust
// Test contract interactions
// Mock Stylus environment
// Medium speed, run before PR merge

cargo test --test '*'
```

### 3. Testnet E2E Tests (TypeScript)
```typescript
// Test on actual Sepolia testnet
// Real FHEVM precompiles
// Slow, run before release

npm test
```

### 4. Gas Benchmarks
```rust
// Measure gas consumption
// Compare Solidity vs Stylus
// Run weekly

cargo bench
```

---

## Risk Mitigation

### Risk 1: FHEVM Not on Arbitrum Yet
**Probability:** Medium
**Impact:** High
**Mitigation:**
- Use Sepolia for development
- Work with Fhenix (CoFHE on Arbitrum)
- Prepare for future FHEVM deployment

### Risk 2: Precompile Interface Changes
**Probability:** Low
**Impact:** Medium
**Mitigation:**
- Version lock dependencies
- Monitor FHEVM releases
- Maintain compatibility layer

### Risk 3: Size Limit Exceeded
**Probability:** Low
**Impact:** High
**Mitigation:**
- Continuous size monitoring
- Aggressive optimization
- Modular architecture (split if needed)

### Risk 4: Gas Costs Too High
**Probability:** Low
**Impact:** Medium
**Mitigation:**
- Early gas benchmarking
- Optimize hot paths
- Consider hybrid approach if needed

---

## Success Metrics

### Technical Metrics
- ✅ Contract size < 24KB compressed
- ✅ All FHE operations functional
- ✅ Gas overhead < 5% vs Solidity
- ✅ 100% test coverage
- ✅ Zero security vulnerabilities

### Development Metrics
- ✅ Complete in 6 weeks
- ✅ 3+ example contracts
- ✅ Full API documentation
- ✅ Deployment on testnet

### Adoption Metrics
- 🎯 EVVMCore successfully ported
- 🎯 2+ external projects using library
- 🎯 Community contributions
- 🎯 Production deployment

---

## Next Steps

1. **Immediate (Today)**
   - Set up repository structure
   - Initialize Cargo workspace
   - Create basic type definitions

2. **This Week**
   - Implement Phase 1 completely
   - Start Phase 2 (operations)
   - Set up CI/CD

3. **This Month**
   - Complete Phases 1-4
   - Deploy to testnet
   - Write documentation

4. **Next Month**
   - Production deployment
   - Community outreach
   - Support adopters

---

## Appendix: Command Reference

### Development
```bash
# Build library
cargo build --release --target wasm32-unknown-unknown -p fhe-stylus

# Build example
cargo build --release --target wasm32-unknown-unknown -p confidential-erc20

# Run tests
cargo test -p fhe-stylus
cargo test -p confidential-erc20 --features export-abi

# Generate docs
cargo doc --no-deps --open -p fhe-stylus

# Check size
cargo stylus check -p confidential-erc20

# Export ABI
cargo stylus export-abi -p confidential-erc20
```

### Deployment
```bash
# Deploy to Sepolia
cargo stylus deploy \
    --private-key=$PRIVATE_KEY \
    --endpoint=https://sepolia-rollup.arbitrum.io/rpc \
    -p confidential-erc20

# Verify on Arbiscan
cargo stylus verify \
    --contract-address=$ADDRESS \
    --endpoint=https://sepolia-rollup.arbitrum.io/rpc \
    -p confidential-erc20
```

---

**Document Status:** ✅ Ready for Implementation
**Approval:** Pending
**Start Date:** TBD
**Team Size:** 1-2 developers
**Budget:** Development time only (no infrastructure costs)

Let's build this! 🚀
