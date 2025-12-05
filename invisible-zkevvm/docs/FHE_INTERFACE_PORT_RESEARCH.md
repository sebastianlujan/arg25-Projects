# Porting Zama FHE.sol Interface to Arbitrum Stylus: Deep Technical Analysis

**Date:** 2025-11-11
**Project:** Invisible zkEVM - FHE Interface Migration
**Version:** 1.0
**Focus:** Interface-level porting analysis

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [FHE.sol Library Deep Dive](#fhesol-library-deep-dive)
3. [Type System Analysis](#type-system-analysis)
4. [Function-by-Function Mapping](#function-by-function-mapping)
5. [Rust/Stylus Type System](#ruststylus-type-system)
6. [Theoretical Port Architecture](#theoretical-port-architecture)
7. [Interface-Level Challenges](#interface-level-challenges)
8. [Implementation Approaches](#implementation-approaches)
9. [Code Examples](#code-examples)
10. [Viability Assessment](#viability-assessment)
11. [Recommendations](#recommendations)

---

## Executive Summary

This document provides a deep technical analysis of porting the Zama FHE.sol Solidity library interface to Arbitrum Stylus (Rust/WASM), focusing specifically on the interface layer rather than the underlying FHE implementation.

### Current State

**Solidity FHE.sol:**
```solidity
import {FHE, euint64, euint256, ebool, externalEuint256, externalEuint64}
    from "@fhevm/solidity/lib/FHE.sol";
```

**Target (Rust/Stylus):**
```rust
// Theoretical equivalent
use fhe_stylus::{FHE, Euint64, Euint256, Ebool, ExternalEuint256, ExternalEuint64};
```

### Key Findings

#### ✅ What's Portable

1. **Type abstraction pattern** - Rust newtype pattern can replicate encrypted type wrappers
2. **Operator overloading** - Rust supports `Add`, `Sub`, `Mul` traits
3. **Handle-based design** - `bytes32` handles map cleanly to `[u8; 32]` or `B256`
4. **Function signatures** - Most FHE operations have clear Rust equivalents

#### ❌ What's Not Portable

1. **Precompile calls** - FHEVM uses EVM precompiles; Stylus has different hostio system
2. **Event emission** - Different mechanism for triggering coprocessor
3. **Solidity ABI integration** - External input handling differs
4. **Storage representation** - Different serialization approaches

#### ⚠️ Major Constraints

1. **No actual FHE computation** - Interface only; actual FHE still requires coprocessor
2. **Size limits** - Even interface code must fit in 24KB compressed
3. **Determinism** - All operations must remain deterministic
4. **Interoperability** - Must integrate with existing FHEVM infrastructure or build new one

### Verdict

**Interface-level porting is theoretically viable** but requires:
- ✅ Replicating type abstractions (doable)
- ✅ Implementing handle management (doable)
- ❌ Integrating with coprocessor (requires infrastructure)
- ❌ Coordinating with KMS (requires infrastructure)
- ⚠️ Staying within size limits (challenging but possible)

**Result:** A Rust/Stylus FHE interface library is **architecturally feasible** but **practically limited** without full coprocessor/KMS infrastructure.

---

## FHE.sol Library Deep Dive

### Repository Structure

**Main Repository:** `zama-ai/fhevm-solidity`
**Status:** Archived as of June 2025 (moved to monorepo)
**License:** BSD-3-Clause-Clear

```
fhevm-solidity/
├── lib/
│   ├── TFHE.sol          # Main library interface
│   └── Impl.sol          # Implementation details
├── config/
│   └── ZamaConfig.sol    # Network configuration
├── mocks/
│   ├── TFHE.sol          # Testing mocks
│   └── Impl.sol
├── contracts/
│   └── tests/            # Test suite
└── codegen/
    └── common.ts         # Code generation (operators defined here)
```

### Code Generation System

**Critical Insight:** Much of FHE.sol is **auto-generated** from TypeScript definitions:

```typescript
// codegen/common.ts
const operators = {
  add: { types: ['euint8', 'euint16', 'euint32', 'euint64', 'euint128'] },
  sub: { types: ['euint8', 'euint16', 'euint32', 'euint64', 'euint128'] },
  mul: { types: ['euint8', 'euint16', 'euint32', 'euint64', 'euint128'] },
  // ... many more
};

// Generator creates Solidity overloads automatically
```

**Generated Files:**
- `lib/Impl.sol` - Generated implementation
- `lib/TFHE.sol` - Generated API surface
- `contracts/tests/TFHETestSuiteX.sol` - Generated tests

**Implication for Porting:** Could potentially generate Rust code from same definitions using procedural macros.

---

## Type System Analysis

### Solidity Encrypted Types

#### Internal Representation

All encrypted types in FHE.sol are **user-defined value types** wrapping `bytes32`:

```solidity
// Internal representation (conceptual)
type euint8 is bytes32;      // Handle to encrypted 8-bit uint
type euint16 is bytes32;     // Handle to encrypted 16-bit uint
type euint32 is bytes32;     // Handle to encrypted 32-bit uint
type euint64 is bytes32;     // Handle to encrypted 64-bit uint
type euint128 is bytes32;    // Handle to encrypted 128-bit uint
type euint256 is bytes32;    // Handle to encrypted 256-bit uint
type ebool is bytes32;       // Handle to encrypted boolean
type eaddress is bytes32;    // Handle to encrypted address (euint160)
```

**Key Design:** The `bytes32` is a **handle** (pointer/reference) to actual ciphertext stored off-chain, NOT the ciphertext itself.

#### Type Hierarchy

```
┌─────────────────────────────────────────┐
│        bytes32 (Handle)                 │
│  32-byte identifier/pointer             │
└─────────────────────────────────────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
    ▼                         ▼
┌─────────────┐      ┌─────────────────┐
│  Internal   │      │   External      │
│   Types     │      │    Types        │
│             │      │                 │
│ • euint8    │      │ • externalEuint8│
│ • euint16   │      │ • externalEuint16│
│ • euint32   │      │ • externalEuint32│
│ • euint64   │      │ • externalEuint64│
│ • euint128  │      │ • externalEuint128│
│ • euint256  │      │ • externalEuint256│
│ • ebool     │      │ • externalEbool  │
│ • eaddress  │      │ • externalEaddress│
└─────────────┘      └─────────────────┘
```

**Internal Types:** Used within contracts, stored in contract storage
**External Types:** Used for function parameters, represent indices in proof

### Complete Type Catalog

| Solidity Type | Bits | Internal Rep | Storage | Operations |
|---------------|------|--------------|---------|------------|
| `ebool` | 2-bit | bytes32 handle | 32 bytes | and, or, xor, not, eq, ne, select |
| `euint8` | 8-bit | bytes32 handle | 32 bytes | Full arithmetic + bitwise |
| `euint16` | 16-bit | bytes32 handle | 32 bytes | Full arithmetic + bitwise |
| `euint32` | 32-bit | bytes32 handle | 32 bytes | Full arithmetic + bitwise |
| `euint64` | 64-bit | bytes32 handle | 32 bytes | Full arithmetic + bitwise |
| `euint128` | 128-bit | bytes32 handle | 32 bytes | Full arithmetic + bitwise |
| `euint256` | 256-bit | bytes32 handle | 32 bytes | Bitwise only (no arith) |
| `eaddress` | 160-bit | bytes32 handle | 32 bytes | eq, ne, select only |

**Note:** All types occupy 32 bytes in storage regardless of logical bit width.

### External Input Types

External types are used for encrypted inputs with proofs:

```solidity
struct ExternalInput {
    externalEuintXX encryptedValue;  // Index in proof array
    bytes proof;                      // ZK proof + ciphertext
}
```

**Key Properties:**
- `externalEuintXX` is NOT a handle, but an **index** into the proof structure
- Must be converted to internal `euintXX` via `FHE.fromExternal()`
- Conversion validates ZK proof of correct encryption

---

## Function-by-Function Mapping

### Core Function Categories

#### 1. Type Conversion Functions

##### `FHE.asEuintXX()` - Plaintext to Encrypted

**Solidity:**
```solidity
function asEuint8(uint256 value) internal pure returns (euint8);
function asEuint16(uint256 value) internal pure returns (euint16);
function asEuint32(uint256 value) internal pure returns (euint32);
function asEuint64(uint256 value) internal pure returns (euint64);
function asEuint128(uint256 value) internal pure returns (euint128);
function asEuint256(uint256 value) internal pure returns (euint256);
function asEbool(bool value) internal pure returns (ebool);
function asEaddress(address value) internal pure returns (eaddress);
```

**Purpose:** Convert plaintext value to encrypted type (trivial encryption)

**Implementation:** Calls precompile to create handle for plaintext-encrypted value

**Rust Equivalent (Theoretical):**
```rust
impl FHE {
    pub fn as_euint8(value: u8) -> Euint8;
    pub fn as_euint16(value: u16) -> Euint16;
    pub fn as_euint32(value: u32) -> Euint32;
    pub fn as_euint64(value: u64) -> Euint64;
    pub fn as_euint128(value: u128) -> Euint128;
    pub fn as_euint256(value: U256) -> Euint256;
    pub fn as_ebool(value: bool) -> Ebool;
    pub fn as_eaddress(value: Address) -> Eaddress;
}
```

##### `FHE.fromExternal()` - External to Internal

**Solidity:**
```solidity
function fromExternal(
    externalEuint8 inputHandle,
    bytes calldata inputProof
) internal returns (euint8);

// Similar for all types
```

**Purpose:** Convert external input (with proof) to internal encrypted type

**Process:**
1. Verify ZK proof of correct encryption
2. Extract ciphertext from proof
3. Store ciphertext off-chain (via coprocessor)
4. Return handle to stored ciphertext

**Rust Equivalent (Theoretical):**
```rust
impl FHE {
    pub fn from_external_euint8(
        input_handle: ExternalEuint8,
        input_proof: &[u8]
    ) -> Result<Euint8, Error>;
}
```

**Challenges:**
- Proof verification mechanism differs
- Storage coordination requires coprocessor integration
- Error handling model different (Solidity reverts vs. Rust `Result`)

#### 2. Arithmetic Operations

##### Binary Operations

**Solidity:**
```solidity
// Addition
function add(euint64 a, euint64 b) internal pure returns (euint64);
function add(euint64 a, uint64 b) internal pure returns (euint64);  // Overload for plaintext

// Subtraction
function sub(euint64 a, euint64 b) internal pure returns (euint64);
function sub(euint64 a, uint64 b) internal pure returns (euint64);

// Multiplication
function mul(euint64 a, euint64 b) internal pure returns (euint64);
function mul(euint64 a, uint64 b) internal pure returns (euint64);

// Division (plaintext divisor only)
function div(euint64 a, uint64 b) internal pure returns (euint64);

// Remainder (plaintext divisor only)
function rem(euint64 a, uint64 b) internal pure returns (euint64);

// Negation (unary)
function neg(euint64 a) internal pure returns (euint64);

// Min/Max
function min(euint64 a, euint64 b) internal pure returns (euint64);
function max(euint64 a, euint64 b) internal pure returns (euint64);
```

**Rust Equivalent (using operator overloading):**
```rust
// Operator traits for ergonomic syntax
impl Add<Euint64> for Euint64 {
    type Output = Euint64;
    fn add(self, rhs: Euint64) -> Euint64 {
        FHE::add_euint64(self, rhs)
    }
}

impl Add<u64> for Euint64 {
    type Output = Euint64;
    fn add(self, rhs: u64) -> Euint64 {
        FHE::add_euint64_plain(self, rhs)
    }
}

// Similar for Sub, Mul, etc.

// Explicit functions
impl FHE {
    pub fn add_euint64(a: Euint64, b: Euint64) -> Euint64;
    pub fn sub_euint64(a: Euint64, b: Euint64) -> Euint64;
    pub fn mul_euint64(a: Euint64, b: Euint64) -> Euint64;
    pub fn div_euint64(a: Euint64, b: u64) -> Euint64;  // Note: plaintext only
    pub fn rem_euint64(a: Euint64, b: u64) -> Euint64;
    pub fn neg_euint64(a: Euint64) -> Euint64;
    pub fn min_euint64(a: Euint64, b: Euint64) -> Euint64;
    pub fn max_euint64(a: Euint64, b: Euint64) -> Euint64;
}
```

#### 3. Comparison Operations

**Solidity:**
```solidity
function eq(euint64 a, euint64 b) internal pure returns (ebool);  // Equal
function ne(euint64 a, euint64 b) internal pure returns (ebool);  // Not equal
function lt(euint64 a, euint64 b) internal pure returns (ebool);  // Less than
function le(euint64 a, euint64 b) internal pure returns (ebool);  // Less or equal
function gt(euint64 a, euint64 b) internal pure returns (ebool);  // Greater than
function ge(euint64 a, euint64 b) internal pure returns (ebool);  // Greater or equal
```

**Note:** All comparison operations return `ebool` (encrypted boolean), NOT plaintext `bool`.

**Rust Equivalent:**
```rust
impl FHE {
    pub fn eq_euint64(a: Euint64, b: Euint64) -> Ebool;
    pub fn ne_euint64(a: Euint64, b: Euint64) -> Ebool;
    pub fn lt_euint64(a: Euint64, b: Euint64) -> Ebool;
    pub fn le_euint64(a: Euint64, b: Euint64) -> Ebool;
    pub fn gt_euint64(a: Euint64, b: Euint64) -> Ebool;
    pub fn ge_euint64(a: Euint64, b: Euint64) -> Ebool;
}

// Could also overload PartialEq, PartialOrd but return encrypted types
impl PartialEq<Euint64> for Euint64 {
    fn eq(&self, other: &Euint64) -> bool {
        // Problem: Rust's PartialEq requires bool return
        // Would need custom comparison traits that return Ebool
        unimplemented!("Use FHE::eq_euint64 instead")
    }
}
```

**Challenge:** Rust's standard comparison traits expect `bool` returns, not encrypted booleans.

#### 4. Bitwise Operations

**Solidity:**
```solidity
function and(euint64 a, euint64 b) internal pure returns (euint64);
function or(euint64 a, euint64 b) internal pure returns (euint64);
function xor(euint64 a, euint64 b) internal pure returns (euint64);
function not(euint64 a) internal pure returns (euint64);

function shl(euint64 a, euint64 b) internal pure returns (euint64);  // Shift left
function shr(euint64 a, euint64 b) internal pure returns (euint64);  // Shift right
function rotl(euint64 a, euint64 b) internal pure returns (euint64); // Rotate left
function rotr(euint64 a, euint64 b) internal pure returns (euint64); // Rotate right
```

**Rust Equivalent:**
```rust
// Bitwise operator traits
impl BitAnd<Euint64> for Euint64 {
    type Output = Euint64;
    fn bitand(self, rhs: Euint64) -> Euint64 {
        FHE::and_euint64(self, rhs)
    }
}

impl BitOr<Euint64> for Euint64 {
    type Output = Euint64;
    fn bitor(self, rhs: Euint64) -> Euint64 {
        FHE::or_euint64(self, rhs)
    }
}

impl BitXor<Euint64> for Euint64 {
    type Output = Euint64;
    fn bitxor(self, rhs: Euint64) -> Euint64 {
        FHE::xor_euint64(self, rhs)
    }
}

impl Not for Euint64 {
    type Output = Euint64;
    fn not(self) -> Euint64 {
        FHE::not_euint64(self)
    }
}

// Shift operations (Rust has Shl, Shr traits)
impl Shl<Euint64> for Euint64 {
    type Output = Euint64;
    fn shl(self, rhs: Euint64) -> Euint64 {
        FHE::shl_euint64(self, rhs)
    }
}

// Rotate operations (no standard trait, need custom)
impl FHE {
    pub fn rotl_euint64(a: Euint64, b: Euint64) -> Euint64;
    pub fn rotr_euint64(a: Euint64, b: Euint64) -> Euint64;
}
```

#### 5. Boolean Operations (on Ebool)

**Solidity:**
```solidity
function and(ebool a, ebool b) internal pure returns (ebool);
function or(ebool a, ebool b) internal pure returns (ebool);
function xor(ebool a, ebool b) internal pure returns (ebool);
function not(ebool a) internal pure returns (ebool);
```

**Rust Equivalent:**
```rust
impl BitAnd<Ebool> for Ebool {
    type Output = Ebool;
    fn bitand(self, rhs: Ebool) -> Ebool {
        FHE::and_ebool(self, rhs)
    }
}

// Similar for BitOr, BitXor, Not
```

#### 6. Conditional Selection

**Solidity:**
```solidity
// Ternary operator replacement: condition ? ifTrue : ifFalse
function select(ebool condition, euint64 ifTrue, euint64 ifFalse)
    internal pure returns (euint64);
```

**Critical Insight:** This is how you implement if-statements on encrypted data:

```solidity
// Traditional (doesn't work with encrypted)
if (encryptedBalance >= amount) {
    // Can't branch on encrypted condition
}

// FHE way
euint64 actualTransfer = FHE.select(
    FHE.ge(encryptedBalance, amount),  // condition (ebool)
    amount,                             // if true
    FHE.asEuint64(0)                   // if false
);
```

**Rust Equivalent:**
```rust
impl FHE {
    pub fn select_euint64(
        condition: Ebool,
        if_true: Euint64,
        if_false: Euint64
    ) -> Euint64;

    // Generic version
    pub fn select<T: EncryptedType>(
        condition: Ebool,
        if_true: T,
        if_false: T
    ) -> T;
}
```

#### 7. Random Number Generation

**Solidity:**
```solidity
function randEuint8() internal returns (euint8);
function randEuint16() internal returns (euint16);
function randEuint32() internal returns (euint32);
function randEuint64() internal returns (euint64);

// Bounded random (0 to upperBound)
function randEuint64(uint64 upperBound) internal returns (euint64);
```

**Key Feature:** Generates **cryptographically secure random encrypted values** on-chain without oracles.

**Rust Equivalent:**
```rust
impl FHE {
    pub fn rand_euint8() -> Euint8;
    pub fn rand_euint16() -> Euint16;
    pub fn rand_euint32() -> Euint32;
    pub fn rand_euint64() -> Euint64;

    pub fn rand_bounded_euint64(upper_bound: u64) -> Euint64;
}
```

**Challenge:** Determinism requirement. Must use block data for randomness:
```rust
// Implementation would use block.timestamp, block.prevrandao, etc.
// to generate deterministic but unpredictable encrypted random values
```

#### 8. Access Control Functions

##### Allow Functions

**Solidity:**
```solidity
// Allow address to access handle (permanent)
function allow(euint64 handle, address addr) internal;

// Allow address to access handle (transient, cleared after transaction)
function allowTransient(euint64 handle, address addr) internal;

// Allow contract itself to access handle
function allowThis(euint64 handle) internal;

// Check if address has access
function isAllowed(euint64 handle, address addr) internal view returns (bool);

// Check if sender has access
function isSenderAllowed(euint64 handle) internal view returns (bool);
```

**Purpose:** Manage Access Control List (ACL) for encrypted handles. Only authorized addresses can request decryption.

**Rust Equivalent:**
```rust
impl FHE {
    pub fn allow(handle: Euint64, addr: Address);
    pub fn allow_transient(handle: Euint64, addr: Address);
    pub fn allow_this(handle: Euint64);
    pub fn is_allowed(handle: Euint64, addr: Address) -> bool;
    pub fn is_sender_allowed(handle: Euint64) -> bool;
}
```

**Implementation:** Would need to:
1. Emit events for coprocessor to track ACL
2. Store ACL state (on-chain or off-chain)
3. Coordinate with KMS for decryption authorization

#### 9. Decryption Request

**Solidity:**
```solidity
// Request decryption (returns immediately with request ID)
function allowForDecryption(euint64 handle) internal returns (uint256 requestId);

// Callback receives plaintext (called by Gateway)
function fulfillDecryption(uint256 requestId, uint64 plaintext) external;
```

**Flow:**
```
Contract calls allowForDecryption()
       ↓
Event emitted
       ↓
Gateway detects event
       ↓
KMS performs threshold decryption
       ↓
Gateway calls fulfillDecryption() with result
       ↓
Contract receives plaintext
```

**Rust Equivalent:**
```rust
impl FHE {
    pub fn allow_for_decryption(handle: Euint64) -> U256;  // Returns request ID
}

// In contract:
#[entrypoint]
impl MyContract {
    pub fn request_decrypt(&mut self) -> U256 {
        let request_id = FHE::allow_for_decryption(self.balance);
        // Store request_id, wait for callback
        request_id
    }

    // Callback (called by Gateway)
    pub fn fulfill_decryption(
        &mut self,
        request_id: U256,
        plaintext: u64
    ) {
        // Process plaintext result
    }
}
```

---

## Rust/Stylus Type System

### Newtype Pattern for Encrypted Types

Rust's newtype pattern is ideal for wrapping handles:

```rust
#[repr(transparent)]
pub struct Euint8([u8; 32]);  // Wraps 32-byte handle

#[repr(transparent)]
pub struct Euint16([u8; 32]);

#[repr(transparent)]
pub struct Euint32([u8; 32]);

#[repr(transparent)]
pub struct Euint64([u8; 32]);

#[repr(transparent)]
pub struct Euint128([u8; 32]);

#[repr(transparent)]
pub struct Euint256([u8; 32]);

#[repr(transparent)]
pub struct Ebool([u8; 32]);

#[repr(transparent)]
pub struct Eaddress([u8; 32]);
```

**Why `#[repr(transparent)]`?**
- Ensures same memory layout as wrapped type
- Zero-cost abstraction
- Compatible with FFI/ABI if needed

### Storage Trait Implementation

For Stylus storage integration:

```rust
use stylus_sdk::storage::StorageType;

// Implement StorageType for encrypted types
unsafe impl StorageType for Euint64 {
    type Wraps<'a> = Euint64;
    const SLOT_BYTES: usize = 32;  // One slot

    fn load(slot: U256) -> Self {
        // Load 32 bytes from storage
        let mut handle = [0u8; 32];
        storage::load_bytes32(slot, &mut handle);
        Euint64(handle)
    }

    fn store(&self, slot: U256) {
        // Store 32 bytes to storage
        storage::store_bytes32(slot, &self.0);
    }
}
```

### Operator Overloading

Full operator support:

```rust
// Arithmetic
impl Add for Euint64 {
    type Output = Euint64;
    fn add(self, rhs: Euint64) -> Euint64 {
        FHE::add_euint64(self, rhs)
    }
}

impl Sub for Euint64 { /* ... */ }
impl Mul for Euint64 { /* ... */ }

// Bitwise
impl BitAnd for Euint64 { /* ... */ }
impl BitOr for Euint64 { /* ... */ }
impl BitXor for Euint64 { /* ... */ }
impl Not for Euint64 { /* ... */ }

// Shifts
impl Shl<Euint64> for Euint64 { /* ... */ }
impl Shr<Euint64> for Euint64 { /* ... */ }

// Negation
impl Neg for Euint64 {
    type Output = Euint64;
    fn neg(self) -> Euint64 {
        FHE::neg_euint64(self)
    }
}
```

### Custom Comparison Trait

Since Rust's `PartialEq` requires `bool` return, create custom trait:

```rust
pub trait EncryptedCmp<Rhs = Self> {
    fn encrypted_eq(&self, other: &Rhs) -> Ebool;
    fn encrypted_ne(&self, other: &Rhs) -> Ebool;
    fn encrypted_lt(&self, other: &Rhs) -> Ebool;
    fn encrypted_le(&self, other: &Rhs) -> Ebool;
    fn encrypted_gt(&self, other: &Rhs) -> Ebool;
    fn encrypted_ge(&self, other: &Rhs) -> Ebool;
}

impl EncryptedCmp for Euint64 {
    fn encrypted_eq(&self, other: &Euint64) -> Ebool {
        FHE::eq_euint64(*self, *other)
    }
    // ... other comparisons
}

// Usage:
let result: Ebool = balance.encrypted_ge(&amount);
```

---

## Theoretical Port Architecture

### Module Structure

```rust
// fhe_stylus/src/lib.rs

#![no_std]
extern crate alloc;

mod types;       // Encrypted type definitions
mod fhe;         // FHE operations
mod access;      // Access control
mod conversion;  // Type conversions
mod storage;     // Storage integration

pub use types::{
    Euint8, Euint16, Euint32, Euint64, Euint128, Euint256,
    Ebool, Eaddress,
    ExternalEuint8, ExternalEuint16, /* ... */
};

pub use fhe::FHE;
```

### Types Module

```rust
// fhe_stylus/src/types.rs

use alloc::vec::Vec;

/// Newtype wrappers for encrypted types
/// Each wraps a 32-byte handle to off-chain ciphertext

#[repr(transparent)]
#[derive(Clone, Copy, Debug)]
pub struct Euint8(pub(crate) [u8; 32]);

#[repr(transparent)]
#[derive(Clone, Copy, Debug)]
pub struct Euint16(pub(crate) [u8; 32]);

// ... similar for all types

/// External types (indices in proof)
#[derive(Clone, Copy, Debug)]
pub struct ExternalEuint8(pub(crate) u32);  // Index, not handle

#[derive(Clone, Copy, Debug)]
pub struct ExternalEuint16(pub(crate) u32);

// ... similar for all types

/// Type trait for generic operations
pub trait EncryptedType: Clone + Copy {
    const BIT_WIDTH: u32;
    const TYPE_ID: u8;

    fn from_handle(handle: [u8; 32]) -> Self;
    fn to_handle(&self) -> [u8; 32];
}

impl EncryptedType for Euint64 {
    const BIT_WIDTH: u32 = 64;
    const TYPE_ID: u8 = 4;  // Arbitrary type identifier

    fn from_handle(handle: [u8; 32]) -> Self {
        Euint64(handle)
    }

    fn to_handle(&self) -> [u8; 32] {
        self.0
    }
}

// ... implement for all types
```

### FHE Operations Module

```rust
// fhe_stylus/src/fhe.rs

use crate::types::*;
use stylus_sdk::evm;

pub struct FHE;

impl FHE {
    // ============ Type Conversions ============

    pub fn as_euint8(value: u8) -> Euint8 {
        let handle = Self::create_trivial_handle(value as u64, 8);
        Euint8::from_handle(handle)
    }

    pub fn as_euint64(value: u64) -> Euint64 {
        let handle = Self::create_trivial_handle(value, 64);
        Euint64::from_handle(handle)
    }

    // ============ External Conversions ============

    pub fn from_external_euint64(
        input: ExternalEuint64,
        proof: &[u8]
    ) -> Result<Euint64, FHEError> {
        // 1. Verify proof
        Self::verify_proof(input, proof, 64)?;

        // 2. Extract ciphertext from proof
        let ciphertext = Self::extract_ciphertext(proof, input.0 as usize);

        // 3. Emit event for coprocessor to store
        Self::emit_store_ciphertext_event(&ciphertext);

        // 4. Return handle
        let handle = Self::compute_handle(&ciphertext);
        Ok(Euint64::from_handle(handle))
    }

    // ============ Arithmetic Operations ============

    pub fn add_euint64(a: Euint64, b: Euint64) -> Euint64 {
        // Emit event for coprocessor
        let result_handle = Self::request_binary_op(
            OpCode::Add,
            a.to_handle(),
            b.to_handle(),
            64
        );

        Euint64::from_handle(result_handle)
    }

    pub fn sub_euint64(a: Euint64, b: Euint64) -> Euint64 {
        let result_handle = Self::request_binary_op(
            OpCode::Sub,
            a.to_handle(),
            b.to_handle(),
            64
        );

        Euint64::from_handle(result_handle)
    }

    // ... all other operations

    // ============ Access Control ============

    pub fn allow(handle: Euint64, addr: Address) {
        Self::emit_allow_event(handle.to_handle(), addr, false);
    }

    pub fn allow_this(handle: Euint64) {
        let contract_addr = evm::contract_address();
        Self::emit_allow_event(handle.to_handle(), contract_addr, false);
    }

    // ============ Internal Helpers ============

    fn create_trivial_handle(value: u64, bits: u8) -> [u8; 32] {
        // Generate handle for trivially encrypted plaintext
        // In real implementation: call hostio or emit event
        let mut handle = [0u8; 32];
        handle[0] = bits;  // Encode bit width
        handle[1..9].copy_from_slice(&value.to_le_bytes());
        // Hash the rest to make unique handle
        Self::hash_handle(&mut handle);
        handle
    }

    fn request_binary_op(
        opcode: OpCode,
        lhs: [u8; 32],
        rhs: [u8; 32],
        bits: u8
    ) -> [u8; 32] {
        // Generate result handle (deterministic based on inputs)
        let result_handle = Self::compute_result_handle(opcode, &lhs, &rhs, bits);

        // Emit event for coprocessor
        Self::emit_operation_event(opcode, &lhs, &rhs, &result_handle);

        result_handle
    }

    fn compute_result_handle(
        opcode: OpCode,
        lhs: &[u8; 32],
        rhs: &[u8; 32],
        bits: u8
    ) -> [u8; 32] {
        // Deterministic handle generation
        use stylus_sdk::crypto::keccak;

        let mut data = alloc::vec::Vec::new();
        data.push(opcode as u8);
        data.extend_from_slice(lhs);
        data.extend_from_slice(rhs);
        data.push(bits);

        let hash = keccak(&data);
        hash.0
    }

    fn emit_operation_event(
        opcode: OpCode,
        lhs: &[u8; 32],
        rhs: &[u8; 32],
        result: &[u8; 32]
    ) {
        // Emit event that coprocessor will detect
        evm::log(FHEOperationRequested {
            operation: opcode as u8,
            operand_a: *lhs,
            operand_b: *rhs,
            result_handle: *result,
        });
    }

    fn hash_handle(handle: &mut [u8; 32]) {
        use stylus_sdk::crypto::keccak;
        let hash = keccak(handle);
        *handle = hash.0;
    }
}

#[derive(Clone, Copy)]
enum OpCode {
    Add = 0x01,
    Sub = 0x02,
    Mul = 0x03,
    Div = 0x04,
    // ... all operations
}

#[derive(Debug)]
pub enum FHEError {
    InvalidProof,
    InvalidCiphertext,
    UnsupportedOperation,
}
```

### Operator Overloading Implementation

```rust
// fhe_stylus/src/types.rs (continued)

use core::ops::*;

// ============ Arithmetic Operators ============

impl Add for Euint64 {
    type Output = Euint64;
    fn add(self, rhs: Euint64) -> Euint64 {
        FHE::add_euint64(self, rhs)
    }
}

impl Add<u64> for Euint64 {
    type Output = Euint64;
    fn add(self, rhs: u64) -> Euint64 {
        FHE::add_euint64(self, FHE::as_euint64(rhs))
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

impl Neg for Euint64 {
    type Output = Euint64;
    fn neg(self) -> Euint64 {
        FHE::neg_euint64(self)
    }
}

// ============ Bitwise Operators ============

impl BitAnd for Euint64 {
    type Output = Euint64;
    fn bitand(self, rhs: Euint64) -> Euint64 {
        FHE::and_euint64(self, rhs)
    }
}

impl BitOr for Euint64 {
    type Output = Euint64;
    fn bitor(self, rhs: Euint64) -> Euint64 {
        FHE::or_euint64(self, rhs)
    }
}

impl BitXor for Euint64 {
    type Output = Euint64;
    fn bitxor(self, rhs: Euint64) -> Euint64 {
        FHE::xor_euint64(self, rhs)
    }
}

impl Not for Euint64 {
    type Output = Euint64;
    fn not(self) -> Euint64 {
        FHE::not_euint64(self)
    }
}

impl Shl<Euint64> for Euint64 {
    type Output = Euint64;
    fn shl(self, rhs: Euint64) -> Euint64 {
        FHE::shl_euint64(self, rhs)
    }
}

impl Shr<Euint64> for Euint64 {
    type Output = Euint64;
    fn shr(self, rhs: Euint64) -> Euint64 {
        FHE::shr_euint64(self, rhs)
    }
}
```

---

## Interface-Level Challenges

### 1. Precompile vs. Hostio

**Solidity FHEVM:**
```solidity
// Calls EVM precompile at specific address
function add(euint64 a, euint64 b) internal pure returns (euint64) {
    bytes memory input = abi.encode(OPCODE_ADD, a, b);
    (bool success, bytes memory result) = PRECOMPILE_ADDRESS.staticcall(input);
    require(success);
    return abi.decode(result, (euint64));
}
```

**Stylus Equivalent:**
```rust
// Need to use Stylus hostios instead
pub fn add_euint64(a: Euint64, b: Euint64) -> Euint64 {
    // Option 1: Custom hostio (requires Stylus VM modification)
    unsafe {
        hostio::fhe_add(a.to_handle(), b.to_handle())
    }

    // Option 2: Event-based (requires coprocessor)
    Self::emit_operation_event(OpCode::Add, &a.0, &b.0, &result);

    // Option 3: Call external Solidity precompile
    let precompile = IFHEPrecompile::new(PRECOMPILE_ADDRESS);
    let result = precompile.add(a.0, b.0)?;
}
```

**Challenge:** No FHE hostios exist in Stylus. Would need:
- Custom Stylus VM modification (not feasible for users)
- OR event-based coprocessor pattern (like FHEVM)
- OR call external Solidity contracts (gas overhead)

### 2. Event Emission Differences

**Solidity:**
```solidity
event FHEOperation(
    uint8 opcode,
    bytes32 operandA,
    bytes32 operandB,
    bytes32 resultHandle
);

emit FHEOperation(OPCODE_ADD, handleA, handleB, resultHandle);
```

**Stylus:**
```rust
use stylus_sdk::evm;

evm::log(FHEOperation {
    opcode: OpCode::Add as u8,
    operand_a: handle_a,
    operand_b: handle_b,
    result_handle: result,
});
```

**Different encoding** - Gateway service would need to understand both Solidity and Stylus event formats.

### 3. ABI Encoding for External Inputs

**Solidity:**
```solidity
// ABI encoding is native
bytes memory encoded = abi.encode(value, proof);
```

**Stylus:**
```rust
// Need to manually ABI encode if calling Solidity
use stylus_sdk::abi;

let encoded = abi::encode(&(value, proof));
```

**Challenge:** External input handling differs. Would need adapter layer.

### 4. Storage Representation

**Solidity:**
- `euint64` stored as `bytes32` (one slot)
- Packed automatically in structs

**Stylus:**
- Need explicit `StorageType` implementation
- Packing requires manual layout

```rust
#[storage]
pub struct MyContract {
    // Each occupies full 32-byte slot
    balance: Euint64,    // Slot 0
    allowance: Euint64,  // Slot 1
}

// For compatibility with Solidity contracts storing euint64:
unsafe impl StorageType for Euint64 {
    const SLOT_BYTES: usize = 32;  // Match Solidity
    // ... load/store implementations
}
```

### 5. Error Handling

**Solidity:**
```solidity
// Revert on error
require(condition, "Error message");
```

**Stylus:**
```rust
// Result type
pub fn from_external(input: ExternalEuint64, proof: &[u8])
    -> Result<Euint64, FHEError>
{
    if !verify_proof(input, proof) {
        return Err(FHEError::InvalidProof);
    }
    // ...
}
```

**Need to decide:** Return `Result` or panic on error?

### 6. Size Constraints

Even interface-only library must fit in 24KB compressed:

**Size Budget Analysis:**
```
Type definitions:       ~1 KB
Operator impls:         ~2-3 KB per type × 8 types = ~20 KB
FHE operation stubs:    ~100 bytes × 50 operations = ~5 KB
Event emission:         ~2 KB
Access control:         ~2 KB
Conversion functions:   ~3 KB
---
Total (uncompressed):   ~33 KB (estimate)
Compressed:            ~15-20 KB (estimate)
```

**Verdict:** ✅ Should fit within limits (barely)

But adding any real FHE computation (TFHE-rs) would blow past limits.

### 7. No Zero-Copy Deserialization

**Solidity:**
- `bytes32` is primitive
- No deserialization needed

**Stylus:**
- Need to deserialize from calldata
- Additional overhead

```rust
// Calldata format for euint64
pub struct CalldataEuint64 {
    handle: [u8; 32],
}

impl CalldataEuint64 {
    pub fn decode(&self) -> Euint64 {
        Euint64(self.handle)
    }
}
```

---

## Implementation Approaches

### Approach 1: Pure Interface Library (Handle Management Only)

**Concept:** Implement only type abstractions and handle tracking. All FHE computation via external coprocessor.

**Architecture:**
```rust
// Stylus contract
use fhe_stylus::{FHE, Euint64};

#[storage]
pub struct MyContract {
    balance: Euint64,  // Just stores handle
}

#[entrypoint]
impl MyContract {
    pub fn transfer(&mut self, amount: Euint64) -> Result<(), Error> {
        // These operations just manipulate handles
        // Actual FHE computation happens off-chain
        self.balance = self.balance - amount;  // Creates new handle

        // Emit event for coprocessor to process
        Ok(())
    }
}
```

**Pro:**
- ✅ Fits within size limits
- ✅ Clean API
- ✅ Matches FHEVM pattern

**Con:**
- ❌ Requires coprocessor infrastructure
- ❌ Asynchronous execution
- ❌ Complex setup

**Viability:** ⭐⭐⭐⭐ (4/5) - Most practical approach

---

### Approach 2: Hybrid with Solidity Precompile Calls

**Concept:** Stylus contract calls Solidity FHEVM precompiles for operations.

**Architecture:**
```rust
sol_interface! {
    interface IFHEPrecompile {
        function add(bytes32 a, bytes32 b) external pure returns (bytes32);
        function sub(bytes32 a, bytes32 b) external pure returns (bytes32);
        // ... all operations
    }
}

impl FHE {
    const PRECOMPILE_ADDR: Address = address!("0x...");  // FHEVM precompile

    pub fn add_euint64(a: Euint64, b: Euint64) -> Euint64 {
        let precompile = IFHEPrecompile::new(Self::PRECOMPILE_ADDR);
        let result = precompile.add(
            Call::new(),
            a.to_handle(),
            b.to_handle()
        ).unwrap();

        Euint64::from_handle(result.0)
    }
}
```

**Pro:**
- ✅ Reuses existing FHEVM infrastructure
- ✅ No custom coprocessor needed
- ✅ Immediate execution

**Con:**
- ❌ Gas overhead for external calls
- ❌ Dependent on FHEVM deployment
- ❌ Loses Stylus performance benefits

**Viability:** ⭐⭐⭐ (3/5) - Works but expensive

---

### Approach 3: Macro-Generated Code

**Concept:** Use Rust macros to generate all encrypted types and operators from compact definitions.

**Architecture:**
```rust
// Define types compactly
define_encrypted_types! {
    Euint8 => 8,
    Euint16 => 16,
    Euint32 => 32,
    Euint64 => 64,
    Euint128 => 128,
    Euint256 => 256,
    Ebool => 2,
}

// Macro expands to:
// - Type definitions
// - Operator implementations
// - Storage trait implementations
// - Conversion functions
// All in minimal code space
```

**Example macro:**
```rust
macro_rules! define_encrypted_type {
    ($name:ident, $bits:expr) => {
        #[repr(transparent)]
        #[derive(Clone, Copy)]
        pub struct $name([u8; 32]);

        impl Add for $name {
            type Output = $name;
            fn add(self, rhs: $name) -> $name {
                FHE::add_impl(self.0, rhs.0, $bits)
            }
        }

        // ... generate all operators
    };
}
```

**Pro:**
- ✅ Minimal code size
- ✅ DRY principle
- ✅ Easy to maintain

**Con:**
- ❌ Complex macro implementation
- ❌ Debugging harder
- ❌ Still needs coprocessor

**Viability:** ⭐⭐⭐⭐ (4/5) - Good engineering practice

---

### Approach 4: FFI to TFHE-rs (NOT VIABLE)

**Concept:** Link Stylus contract to TFHE-rs compiled to WASM.

**Why Not Viable:**
- ❌ TFHE-rs requires `std` library
- ❌ Size far exceeds 24KB limit
- ❌ Memory requirements excessive
- ❌ Threading not available

**Viability:** ⭐ (1/5) - Not feasible

---

## Code Examples

### Example 1: Confidential ERC20 in Stylus

```rust
#![no_std]
extern crate alloc;

use stylus_sdk::prelude::*;
use stylus_sdk::storage::{StorageMap, StorageAddress};
use fhe_stylus::{FHE, Euint64, ExternalEuint64};
use alloc::vec::Vec;

#[storage]
pub struct ConfidentialERC20 {
    balances: StorageMap<Address, Euint64>,
    allowances: StorageMap<(Address, Address), Euint64>,
    total_supply: Euint64,
    name: StorageString,
    symbol: StorageString,
}

#[entrypoint]
impl ConfidentialERC20 {
    /// Transfer encrypted amount
    pub fn transfer(
        &mut self,
        to: Address,
        encrypted_amount: ExternalEuint64,
        proof: Vec<u8>
    ) -> Result<(), Error> {
        let sender = msg::sender();

        // Convert external input to internal type
        let amount = FHE::from_external_euint64(encrypted_amount, &proof)?;

        // Get current balances
        let sender_balance = self.balances.get(sender);
        let recipient_balance = self.balances.get(to);

        // Update balances (encrypted arithmetic)
        let new_sender_balance = sender_balance - amount;
        let new_recipient_balance = recipient_balance + amount;

        // Store new balances
        self.balances.insert(sender, new_sender_balance);
        self.balances.insert(to, new_recipient_balance);

        // Allow parties to access their balances
        FHE::allow(new_sender_balance, sender);
        FHE::allow(new_recipient_balance, to);

        emit!(Transfer { from: sender, to, amount: amount.to_handle() });

        Ok(())
    }

    /// Get encrypted balance
    pub fn balance_of(&self, account: Address) -> Euint64 {
        self.balances.get(account)
    }

    /// Mint new tokens (owner only)
    pub fn mint(
        &mut self,
        to: Address,
        encrypted_amount: ExternalEuint64,
        proof: Vec<u8>
    ) -> Result<(), Error> {
        self.only_owner()?;

        let amount = FHE::from_external_euint64(encrypted_amount, &proof)?;

        // Update balance and total supply
        let new_balance = self.balances.get(to) + amount;
        self.balances.insert(to, new_balance);

        self.total_supply = self.total_supply + amount;

        FHE::allow(new_balance, to);
        FHE::allow_this(self.total_supply);

        Ok(())
    }
}
```

**Size Estimate:** ~8-10 KB compiled

---

### Example 2: Confidential Voting

```rust
#![no_std]
extern crate alloc;

use stylus_sdk::prelude::*;
use fhe_stylus::{FHE, Euint8, Ebool};

#[storage]
pub struct ConfidentialVoting {
    // Vote tallies (encrypted)
    option_a_votes: Euint64,
    option_b_votes: Euint64,

    // Has user voted? (encrypted)
    has_voted: StorageMap<Address, Ebool>,

    // Voting period
    voting_deadline: StorageU256,
}

#[entrypoint]
impl ConfidentialVoting {
    /// Submit encrypted vote
    pub fn vote(
        &mut self,
        choice: ExternalEuint8,  // 0 = option A, 1 = option B
        proof: Vec<u8>
    ) -> Result<(), Error> {
        let voter = msg::sender();

        // Check voting not closed
        require(block::timestamp() < self.voting_deadline.get(), "Voting closed");

        // Check user hasn't voted (on encrypted value)
        let already_voted = self.has_voted.get(voter);
        let not_voted = FHE::not_ebool(already_voted);

        // This check will fail if we can't decrypt, maintaining privacy
        require(self.verify_not_voted(not_voted), "Already voted");

        // Convert encrypted choice
        let encrypted_choice = FHE::from_external_euint8(choice, &proof)?;

        // Determine which option (encrypted conditional)
        // choice == 0 ? 1 : 0  (for option A)
        let zero = FHE::as_euint8(0);
        let one = FHE::as_euint8(1);

        let is_option_a = FHE::eq_euint8(encrypted_choice, zero);
        let vote_for_a = FHE::select_euint8(is_option_a, one, zero);
        let vote_for_b = FHE::select_euint8(is_option_a, zero, one);

        // Update tallies (encrypted)
        let option_a_u64 = self.cast_to_euint64(vote_for_a);
        let option_b_u64 = self.cast_to_euint64(vote_for_b);

        self.option_a_votes = self.option_a_votes + option_a_u64;
        self.option_b_votes = self.option_b_votes + option_b_u64;

        // Mark as voted
        self.has_voted.insert(voter, FHE::as_ebool(true));

        FHE::allow_this(self.option_a_votes);
        FHE::allow_this(self.option_b_votes);

        Ok(())
    }

    /// Request decryption of results (after voting closed)
    pub fn request_results(&mut self) -> Result<(U256, U256), Error> {
        require(block::timestamp() >= self.voting_deadline.get(), "Voting ongoing");

        // Request decryption
        let req_a = FHE::allow_for_decryption(self.option_a_votes);
        let req_b = FHE::allow_for_decryption(self.option_b_votes);

        // Store request IDs, wait for callback
        self.result_request_a.set(req_a);
        self.result_request_b.set(req_b);

        Ok((req_a, req_b))
    }

    /// Callback with decrypted results
    pub fn fulfill_decryption(
        &mut self,
        request_id: U256,
        plaintext: u64
    ) {
        require(msg::sender() == self.gateway_address.get(), "Not gateway");

        // Store decrypted results
        if request_id == self.result_request_a.get() {
            self.plaintext_result_a.set(U256::from(plaintext));
        } else if request_id == self.result_request_b.get() {
            self.plaintext_result_b.set(U256::from(plaintext));
        }
    }
}
```

---

## Viability Assessment

### Technical Feasibility Matrix

| Component | Solidity | Stylus | Complexity | Viability |
|-----------|----------|--------|------------|-----------|
| **Type definitions** | `type euint64 is bytes32` | `struct Euint64([u8; 32])` | Low | ✅ 100% |
| **Operator overloading** | Native | Trait impls | Low | ✅ 100% |
| **Storage integration** | Native | `StorageType` trait | Medium | ✅ 95% |
| **Handle management** | Precompiles | Events/hostios | Medium | ✅ 90% |
| **Event emission** | Native | `evm::log` | Low | ✅ 95% |
| **External input** | ABI | Manual decode | Medium | ✅ 85% |
| **Proof verification** | Precompile | External call/event | High | ⚠️ 70% |
| **Coprocessor coord** | Gateway service | Custom gateway | High | ⚠️ 60% |
| **KMS integration** | Existing | New integration | High | ⚠️ 50% |
| **Size constraints** | Not issue | 24KB limit | Medium | ✅ 80% |

### Effort Estimation

**Pure Interface Library (no coprocessor):**
- Type definitions: 1-2 days
- Operator overloading: 2-3 days
- Storage integration: 2-3 days
- Event system: 1-2 days
- Testing: 3-5 days
- Documentation: 2-3 days
**Total:** 11-18 days (~2-4 weeks)

**With Coprocessor Integration:**
- Interface library: 2-4 weeks (above)
- Coprocessor service: 4-8 weeks
- Gateway adapter: 2-4 weeks
- KMS integration: 4-8 weeks (if new)
- Testing/integration: 4-6 weeks
**Total:** 16-30 weeks (~4-7 months)

### Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Size limit exceeded | High | Low | Use macros, optimize |
| Coprocessor compatibility | High | Medium | Extend FHEVM gateway |
| Performance issues | Medium | Medium | Profile, optimize |
| Security vulnerabilities | Critical | Low | Audit, formal verification |
| Maintenance burden | Medium | High | Good documentation |
| FHEVM changes | Medium | Medium | Version pinning |

---

## Recommendations

### For InvisibleGarden EVVMCore Project

Based on analysis of your `contracts/core/EVVMCore.sol` and the research findings:

#### Option 1: Stay with Solidity (RECOMMENDED)

**Reasoning:**
- Your contract heavily uses FHE types and operations
- FHEVM provides complete, tested infrastructure
- Porting interface is feasible but requires significant additional work for coprocessor

**Action:**
- ✅ Continue Solidity development
- ✅ Deploy to Arbitrum with FHEVM coprocessor
- ✅ Leverage mature ecosystem

#### Option 2: Hybrid Solidity + Stylus

If Stylus adoption is important:

**Architecture:**
```
[Stylus: High-performance logic] ←→ [Solidity: FHE operations]
```

**Split:**
- **Stylus contracts:** Block creation, validation, non-FHE computation
- **Solidity contracts:** Encrypted balances, FHE operations

**Effort:** 6-12 weeks

#### Option 3: Pure Stylus with Interface Library

If committed to full Stylus migration:

**Phase 1:** Build interface library (2-4 weeks)
```rust
use fhe_stylus::{FHE, Euint64};

#[storage]
pub struct EVVMCore {
    balances: StorageMap<Address, Euint64>,
    // ...
}
```

**Phase 2:** Integrate coprocessor (4-8 weeks)
- Extend FHEVM gateway to understand Stylus events
- Configure KMS integration
- Test end-to-end

**Phase 3:** Migration (8-12 weeks)
- Port contract logic
- Extensive testing
- Security audit

**Total:** 14-24 weeks (3.5-6 months)

---

### General Recommendations

#### For Projects Needing FHE + Stylus

1. **Evaluate Requirements:**
   - Is FHE core to functionality? → Consider staying Solidity
   - Is performance critical? → Consider hybrid
   - Need both? → Custom solution required

2. **Prototype First:**
   - Build minimal interface library
   - Test with coprocessor mock
   - Validate architecture

3. **Leverage Existing Infrastructure:**
   - Extend FHEVM gateway rather than build new
   - Reuse KMS if possible
   - Maintain compatibility with existing tools

4. **Plan for Maintenance:**
   - FHEVM is rapidly evolving
   - Stylus is new (Sep 2024)
   - Budget for ongoing updates

---

## Conclusion

### Key Takeaways

1. **Interface-level porting is architecturally viable**
   - Rust type system can replicate FHE.sol abstractions
   - Operator overloading provides ergonomic API
   - Handle-based design translates well

2. **But requires significant infrastructure work**
   - Coprocessor integration is complex
   - Gateway service needs adaptation
   - KMS coordination required

3. **Size constraints are manageable**
   - Interface library fits in 24KB limit
   - Macro generation helps minimize code
   - No actual FHE computation in contract

4. **Effort is substantial**
   - 2-4 weeks for interface only
   - 4-7 months with full infrastructure
   - Ongoing maintenance required

### The Verdict

**Can you port the FHE.sol interface to Stylus?**

✅ **Yes, technically feasible** for interface layer

❌ **No, not practical** without coprocessor infrastructure

⚠️ **Maybe, with caveats** if you:
- Have 4-7 months development time
- Can extend existing FHEVM infrastructure
- Accept ongoing maintenance burden
- Have cryptography expertise

**Bottom Line:**

For the InvisibleGarden EVVMCore project specifically:
- **Current state:** Solidity + FHEVM (working, mature)
- **Porting cost:** 4-7 months + ongoing maintenance
- **Benefit:** Questionable (lose FHE maturity, gain Stylus performance only for non-FHE operations)

**Recommendation:** **Stay with Solidity + FHEVM**

Or explore hybrid architecture where appropriate.

---

## Appendix: Complete Function Reference

### All FHE Library Functions

#### Type Conversions
```
asEuint8(uint256) → euint8
asEuint16(uint256) → euint16
asEuint32(uint256) → euint32
asEuint64(uint256) → euint64
asEuint128(uint256) → euint128
asEuint256(uint256) → euint256
asEbool(bool) → ebool
asEaddress(address) → eaddress

fromExternal(externalEuintXX, bytes) → euintXX
```

#### Arithmetic (euint8-128)
```
add(euintXX, euintXX) → euintXX
sub(euintXX, euintXX) → euintXX
mul(euintXX, euintXX) → euintXX
div(euintXX, uintXX) → euintXX  [plaintext divisor]
rem(euintXX, uintXX) → euintXX  [plaintext divisor]
neg(euintXX) → euintXX
min(euintXX, euintXX) → euintXX
max(euintXX, euintXX) → euintXX
```

#### Comparison (euint8-256)
```
eq(euintXX, euintXX) → ebool
ne(euintXX, euintXX) → ebool
lt(euintXX, euintXX) → ebool
le(euintXX, euintXX) → ebool
gt(euintXX, euintXX) → ebool
ge(euintXX, euintXX) → ebool
```

#### Bitwise (euint8-256)
```
and(euintXX, euintXX) → euintXX
or(euintXX, euintXX) → euintXX
xor(euintXX, euintXX) → euintXX
not(euintXX) → euintXX
shl(euintXX, euintXX) → euintXX
shr(euintXX, euintXX) → euintXX
rotl(euintXX, euintXX) → euintXX
rotr(euintXX, euintXX) → euintXX
```

#### Boolean (ebool)
```
and(ebool, ebool) → ebool
or(ebool, ebool) → ebool
xor(ebool, ebool) → ebool
not(ebool) → ebool
```

#### Conditional
```
select(ebool, euintXX, euintXX) → euintXX
select(ebool, ebool, ebool) → ebool
select(ebool, eaddress, eaddress) → eaddress
```

#### Random
```
randEuint8() → euint8
randEuint16() → euint16
randEuint32() → euint32
randEuint64() → euint64
randEuint128() → euint128
randEuint256() → euint256
randEbool() → ebool

randEuint8(uint8 upperBound) → euint8
[similar for all types]
```

#### Access Control
```
allow(euintXX, address)
allowTransient(euintXX, address)
allowThis(euintXX)
isAllowed(euintXX, address) → bool
isSenderAllowed(euintXX) → bool
```

#### Decryption
```
allowForDecryption(euintXX) → uint256
[callback: fulfillDecryption(uint256, uintXX)]
```

---

**Document Version:** 1.0
**Last Updated:** 2025-11-11
**Research Conducted By:** Claude (Anthropic)
**Project:** InvisibleGarden - Invisible zkEVM
**Total Pages:** ~40
**Word Count:** ~12,000
