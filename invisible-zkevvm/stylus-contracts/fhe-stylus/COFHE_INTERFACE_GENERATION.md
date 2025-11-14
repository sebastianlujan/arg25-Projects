# CoFHE Interface Generation for Stylus

## 🎯 Objective

Create Rust/Stylus interfaces to interact with **Fhenix CoFHE** from Stylus contracts, replacing ZAMA FHEVM interfaces.

---

## 📋 Required Information

### ⚠️ IMPORTANT: FHE.sol is a Library, NOT a Contract

**Key discovery:** According to CoFHE documentation:

- `FHE.sol` is a **Solidity library** that is imported directly
- **It is NOT a deployed contract** with a fixed address
- FHE functions are called **directly**, not as external calls
- It is linked to the contract during compilation

**Implication for Stylus:**

- ❌ We cannot use `sol_interface!` to call FHE as an external contract
- ✅ We need to understand how the library works internally
- ✅ Possibly use mock contracts for testing
- ✅ Or create wrappers that replicate the functionality

### 1. CoFHE Mock Contracts

**Information found:**

- ✅ `cofhe-mock-contracts` - Mock contracts for testing
- ✅ Allow testing without real FHE operations
- ✅ Simulate FHE behavior
- ✅ Store plaintext values on-chain for testing

**Questions:**

- ❓ What are the addresses of the mock contracts?
- ❓ Can we use these mocks from Stylus?
- ❓ Do they have the same interfaces as the FHE library?

### 2. Internal Structure of FHE.sol

**We need to understand:**

- ✅ How the FHE library works internally
- ✅ Does it call external contracts or is it pure logic?
- ✅ Is there a coprocessor contract that is called?
- ✅ How are off-chain FHE operations handled?

**Sources to consult:**

- Source code of `@fhenixprotocol/cofhe-contracts`
- CoFHE technical documentation
- Repository: https://github.com/fhenixprotocol/cofhe-contracts

### 2. ABI of CoFHE FHE Contract

**We need:**

- ✅ Complete ABI of the `FHE` contract from `@fhenixprotocol/cofhe-contracts`
- ✅ Signatures of all public functions
- ✅ Parameter and return types

**Identified functions (from migrated contracts):**

```solidity
// Input conversion
FHE.asEuint8(InEuint8 memory) → euint8
FHE.asEuint32(uint32) → euint32
FHE.asEuint64(InEuint64 memory) → euint64
FHE.asEuint256(InEuint256 memory) → euint256
FHE.asEbool(bool) → ebool

// Arithmetic operations
FHE.add(euint64, euint64) → euint64
FHE.sub(euint64, euint64) → euint64
FHE.mul(euint64, euint64) → euint64
// FHE.div() - Not available for euint64

// Comparisons
FHE.eq(euint256, euint256) → ebool
FHE.and(ebool, ebool) → ebool
FHE.or(ebool, ebool) → ebool

// Conditional selection
FHE.select(ebool condition, euint32 ifTrue, euint32 ifFalse) → euint32

// Permissions
FHE.allowThis(euint64) → void
FHE.allowSender(euint64) → void
FHE.allow(euint64, address) → void

// Decryption
FHE.decrypt(euint64) → void
FHE.getDecryptResultSafe(euint64) → (uint256, bool)
```

### 3. Structure of `InEuint*` Types

**Question:** How is `InEuint64` structured in Solidity?

**From migrated contracts, we know:**

- `InEuint64` is a `struct` or `memory` type
- Includes ciphertext and proof internally
- Does not require separate `proof` parameter

**We need:**

- ✅ Exact definition of the `InEuint64` struct
- ✅ How it is serialized/deserialized for external calls
- ✅ Size in bytes

### 4. Stylus Compatibility

**Questions:**

- ❓ Does CoFHE work on Arbitrum Stylus?
- ❓ Are there specific limitations?
- ❓ Do external calls work the same as in Solidity?

---

## 🔧 Implementation Plan

### Phase 1: Research (1-2 days)

1. **Get contract addresses:**

   ```bash
   # Consult Fhenix documentation
   # Verify contracts deployed on Arbitrum Sepolia
   # Get official addresses
   ```

2. **Get FHE contract ABI:**

   ```bash
   # Option 1: From npm package
   npm install @fhenixprotocol/cofhe-contracts
   # Extract FHE contract ABI
   
   # Option 2: From repository
   git clone https://github.com/fhenixprotocol/cofhe-contracts
   # Compile and extract ABI
   ```

3. **Verify type structure:**

   ```solidity
   // Review InEuint64 definition in the contract
   struct InEuint64 {
       bytes ciphertext;
       bytes proof;  // Or is it structured differently?
   }
   ```

### Phase 2: Create Interfaces (2-3 days)

#### 2.1 New File: `cofhe_interfaces.rs`

**⚠️ IMPORTANT:** We first need to understand if:

1. FHE.sol calls external contracts (coprocessor)
2. Or if it is pure logic that is linked

**Option A: If FHE.sol calls external contracts**

```rust
//! CoFHE Contract Interfaces
//!
//! This module defines Solidity interfaces for Fhenix CoFHE.
//! FHE.sol is a library, but it may call external contracts (coprocessor).

use stylus_sdk::prelude::*;
use stylus_sdk::alloy_sol_types;

// Interface for CoFHE coprocessor contract (if it exists)
sol_interface! {
    /// CoFHE Coprocessor Interface
    ///
    /// External contract that handles FHE operations.
    /// Called internally by FHE.sol library.
    interface ICoFHECoprocessor {
        // ============ Input Conversion ============
        
        /// Convert encrypted input to euint8
        function asEuint8(InEuint8 memory input) 
            external returns (euint8);
        
        /// Convert encrypted input to euint32
        function asEuint32(uint32 value) 
            external returns (euint32);
        
        /// Convert encrypted input to euint64
        function asEuint64(InEuint64 memory input) 
            external returns (euint64);
        
        /// Convert encrypted input to euint256
        function asEuint256(InEuint256 memory input) 
            external returns (euint256);
        
        /// Convert boolean to ebool
        function asEbool(bool value) 
            external returns (ebool);
        
        // ============ Arithmetic Operations ============
        
        /// Add two encrypted integers
        function add(euint64 lhs, euint64 rhs) 
            external returns (euint64);
        
        /// Subtract two encrypted integers (lhs - rhs)
        function sub(euint64 lhs, euint64 rhs) 
            external returns (euint64);
        
        /// Multiply two encrypted integers
        function mul(euint64 lhs, euint64 rhs) 
            external returns (euint64);
        
        // ============ Comparison Operations ============
        
        /// Encrypted equality comparison
        function eq(euint256 lhs, euint256 rhs) 
            external returns (ebool);
        
        /// Encrypted AND operation
        function and(ebool lhs, ebool rhs) 
            external returns (ebool);
        
        /// Encrypted OR operation
        function or(ebool lhs, ebool rhs) 
            external returns (ebool);
        
        // ============ Conditional Selection ============
        
        /// Conditional selection: if condition then ifTrue else ifFalse
        function select(ebool condition, euint32 ifTrue, euint32 ifFalse) 
            external returns (euint32);
        
        // ============ Access Control ============
        
        /// Allow contract to access encrypted value
        function allowThis(euint64 ct) external;
        
        /// Allow sender to access encrypted value
        function allowSender(euint64 ct) external;
        
        /// Allow specific address to access encrypted value
        function allow(euint64 ct, address account) external;
        
        // ============ Decryption ============
        
        /// Request decryption of encrypted value
        function decrypt(euint64 ct) external;
        
        /// Get decryption result safely
        function getDecryptResultSafe(euint64 ct) 
            external view returns (uint256 result, bool decrypted);
    }
}
```

**⚠️ Note:** We need to verify:
- If `InEuint64` can be passed directly or needs serialization
- If functions are `pure`, `view`, or `external`
- Exact return types

#### 2.2 Update Types: `types.rs`

```rust
//! Encrypted type system for CoFHE operations

use stylus_sdk::alloy_primitives::FixedBytes;

// Internal types (same as before)
pub type Euint64 = FixedBytes<32>;
pub type Euint256 = FixedBytes<32>;
pub type Ebool = FixedBytes<32>;
pub type Euint8 = FixedBytes<32>;
pub type Euint32 = FixedBytes<32>;

// ❌ REMOVE: ExternalEuint64 (ZAMA specific)

// ✅ ADD: CoFHE input types
/// CoFHE encrypted input (InEuint64)
///
/// Structure that includes ciphertext and proof.
/// We need to verify the exact structure from the Solidity contract.
#[derive(Debug, Clone)]
pub struct InEuint64 {
    // TODO: Verify exact structure
    // Probably:
    pub ciphertext: Vec<u8>,  // Encrypted ciphertext
    pub proof: Vec<u8>,       // Encryption proof
}

// Similar for other types
pub struct InEuint8 { /* ... */ }
pub struct InEuint256 { /* ... */ }
```

#### 2.3 New Configuration: `cofhe_config.rs`

```rust
//! Network Configuration for CoFHE Contracts

use stylus_sdk::alloy_primitives::Address;

/// Configuration for CoFHE contract addresses on a specific network
#[derive(Debug, Clone, Copy)]
pub struct CoFHEConfig {
    /// Address of the main FHE contract
    pub fhe_contract: Address,
    
    /// Address of the decryption contract (if separate)
    pub decrypt_contract: Address,
}

impl CoFHEConfig {
    /// Arbitrum Sepolia testnet configuration
    ///
    /// TODO: Get real CoFHE addresses on Arbitrum Sepolia
    pub const fn arbitrum_sepolia() -> Self {
        Self {
            // ⚠️ UPDATE: Get real address
            fhe_contract: Address::ZERO,  // Placeholder
            decrypt_contract: Address::ZERO,
        }
    }
    
    /// Ethereum Sepolia testnet configuration
    pub const fn ethereum_sepolia() -> Self {
        Self {
            // ⚠️ UPDATE: Get real address
            fhe_contract: Address::ZERO,
            decrypt_contract: Address::ZERO,
        }
    }
}

/// Get the current network's CoFHE configuration
pub const fn get_cofhe_config() -> CoFHEConfig {
    // For now, use Arbitrum Sepolia
    CoFHEConfig::arbitrum_sepolia()
}
```

#### 2.4 Update API: `cofhe.rs`

```rust
//! CoFHE Operations API
//!
//! High-level API for CoFHE operations, similar to fhe.rs but for CoFHE.

use crate::cofhe_interfaces::IFHEContract;
use crate::cofhe_config::get_cofhe_config;
use crate::types::*;
use stylus_sdk::call::Call;

pub struct CoFHE;

impl CoFHE {
    /// Convert encrypted input to euint64
    pub fn as_euint64(
        input: InEuint64,
        fhe_contract: Address
    ) -> Result<Euint64, CoFHEError> {
        let fhe = IFHEContract::new(fhe_contract);
        // TODO: Verify how to pass InEuint64
        // May require special serialization
        let result = fhe.asEuint64(
            Call::new(),
            input  // How to serialize?
        )?;
        Ok(result)
    }
    
    /// Add two encrypted integers
    pub fn add(
        lhs: Euint64,
        rhs: Euint64,
        fhe_contract: Address
    ) -> Result<Euint64, CoFHEError> {
        let fhe = IFHEContract::new(fhe_contract);
        let result = fhe.add(
            Call::new(),
            lhs.into(),
            rhs.into()
        )?;
        Ok(result)
    }
    
    // Similar for other operations...
}
```

### Phase 3: Testing (1-2 days)

1. **Compilation test:**

   ```bash
   cargo check -p fhe-stylus
   ```

2. **Interface tests:**
   - Verify that `sol_interface!` compiles correctly
   - Verify parameter types

3. **Integration test (when we have addresses):**
   - Call real CoFHE contracts
   - Verify responses

---

## 📝 Required Information Checklist

### Critical Information (Blocking)

- [ ] **CoFHE contract addresses on Arbitrum Sepolia**
  - [ ] Main FHE contract address
  - [ ] Decryption contract address (if exists)
  - [ ] Other required addresses

- [ ] **Complete FHE contract ABI**
  - [ ] All public functions
  - [ ] Exact parameter types
  - [ ] Exact return types
  - [ ] Modifiers (pure, view, external)

- [ ] **`InEuint64` structure**
  - [ ] Struct definition in Solidity
  - [ ] How it is serialized for external calls
  - [ ] Size in bytes

### Important Information (Non-blocking)

- [ ] **Stylus compatibility**
  - [ ] Does CoFHE work on Stylus?
  - [ ] Are there limitations?
  - [ ] Usage examples on Stylus?

- [ ] **Official documentation**
  - [ ] Stylus integration guide
  - [ ] Code examples
  - [ ] Best practices

---

## 🔍 Information Sources

### 1. Official Repository

```
https://github.com/fhenixprotocol/cofhe-contracts
```

**What to look for:**

- `FHE.sol` contract
- `InEuint64` definition
- Generated ABI

### 2. Documentation

```
https://cofhe-docs.fhenix.zone/
```

**What to look for:**

- Integration guide
- API reference
- Usage examples

### 3. Deployed Contracts

- Arbitrum Sepolia Explorer
- Verify official addresses

### 4. NPM Package

```bash
npm install @fhenixprotocol/cofhe-contracts
```

**What to extract:**

- FHE contract ABI
- TypeScript types (if they exist)

---

## 🚀 Immediate Next Steps

1. **Research addresses:**

   ```bash
   # Consult Fhenix documentation
   # Search in cofhe-contracts repository
   # Verify on blockchain explorers
   ```

2. **Get ABI:**

   ```bash
   # Clone repository
   git clone https://github.com/fhenixprotocol/cofhe-contracts
   cd cofhe-contracts
   
   # Compile contracts
   npm install
   npm run compile
   
   # Extract ABI
   # Look in artifacts/ or build/
   ```

3. **Analyze type structure:**

   ```solidity
   // Search in source code:
   // - InEuint64 definition
   // - How it's used in functions
   // - Serialization/deserialization
   ```

---

## ⚠️ Important Considerations

### 1. Architectural Difference

**ZAMA FHEVM:**

- Precompiles with fixed addresses
- `pure` functions (do not modify state)
- Handles (bytes32) as identifiers

**Fhenix CoFHE:**

- Deployed contracts (variable addresses)
- Can have state
- Direct encrypted types (euint64, etc.)

### 2. Type Serialization

**Potential problem:**

- `InEuint64` is a struct in Solidity
- Stylus needs to serialize it for external calls
- May require special encoding

**Solution:**

- Verify how `sol_interface!` handles structs
- Possibly need manual encoding

### 3. Compatibility

**Verify:**

- Is CoFHE available on Arbitrum?
- Does it work with Stylus?
- Are there existing examples?

---

## 📚 References

- **CoFHE Docs:** https://cofhe-docs.fhenix.zone/
- **CoFHE Contracts:** https://github.com/fhenixprotocol/cofhe-contracts
- **CoFHE Hardhat Starter:** https://github.com/fhenixprotocol/cofhe-hardhat-starter
- **Stylus SDK:** https://docs.rs/stylus-sdk/

---

**Status:** ⏳ Waiting for information on addresses and ABI

**Last updated:** $(date)
