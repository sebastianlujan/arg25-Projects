# Porting Solidity + Zama FHE to Arbitrum Stylus: Comprehensive Research Report

**Date:** 2025-11-11
**Project:** Invisible zkEVM - EVVMCore Migration
**Version:** 1.0

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Technology Overview](#technology-overview)
   - [Zama FHEVM & TFHE-rs](#zama-fhevm--tfhe-rs)
   - [Arbitrum Stylus](#arbitrum-stylus)
3. [Technical Deep Dive](#technical-deep-dive)
4. [Integration Analysis](#integration-analysis)
5. [Challenges and Limitations](#challenges-and-limitations)
6. [Potential Approaches](#potential-approaches)
7. [Alternative Solutions](#alternative-solutions)
8. [Recommendations](#recommendations)
9. [References](#references)

---

## Executive Summary

This research investigates the feasibility of porting Solidity smart contracts using Zama's Fully Homomorphic Encryption (FHE) library to Arbitrum Stylus (Rust/WASM). The analysis covers three core technologies:

1. **Zama FHEVM** - A framework for confidential smart contracts using FHE
2. **TFHE-rs** - Zama's pure Rust FHE implementation
3. **Arbitrum Stylus** - A WASM-based smart contract platform supporting Rust/C/C++

### Key Findings

✅ **Rust FHE Library Exists**: TFHE-rs provides native Rust FHE capabilities
✅ **Stylus Supports Rust**: Full Rust SDK with storage compatibility
⚠️ **Critical Incompatibilities**: Several fundamental architectural conflicts
❌ **Direct Port Not Viable**: Significant technical barriers prevent straightforward migration
✅ **Alternative Approaches**: Coprocessor architecture shows promise

### Critical Incompatibilities

1. **TFHE-rs requires `std` library** - Stylus requires `#[no_std]` for size constraints
2. **WASM memory limits** - 2GB browser limit vs. FHE's intensive memory needs
3. **No threading in WASM** - FHE operations benefit heavily from parallelization
4. **Deterministic execution requirement** - FHE randomness/entropy conflicts with blockchain determinism
5. **Contract size limits** - 24KB compressed / 128KB uncompressed WASM vs. large FHE binaries
6. **Coprocessor dependency** - FHEVM architecture requires off-chain computation layer

---

## Technology Overview

### Zama FHEVM & TFHE-rs

#### What is FHEVM?

**FHEVM (Fully Homomorphic Encryption Virtual Machine)** is Zama's framework for building confidential smart contracts that can compute on encrypted data without decryption.

**Key Characteristics:**
- **Release Timeline**: Initial version (2-3 TPS) → Coprocessor v0.7 (May 2025, 20 TPS)
- **Target**: 100-1000+ TPS in future releases
- **Funding**: $130M+ raised, $1B+ valuation (unicorn status)
- **Architecture**: Symbolic execution on-chain + off-chain coprocessor model

#### FHEVM Architecture Components

```
┌─────────────────────────────────────────────────────────────┐
│                      Blockchain Layer                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │    Smart Contract (Solidity)                         │   │
│  │    - Uses FHE.sol library                            │   │
│  │    - Symbolic execution (lightweight handles)        │   │
│  │    - Emits events for FHE operations                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     Gateway Service                          │
│  - Bridges blockchain and off-chain systems                  │
│  - Forwards requests/results                                 │
└─────────────────────────────────────────────────────────────┘
                           │
                ┌──────────┴──────────┐
                │                     │
                ▼                     ▼
┌───────────────────────┐   ┌─────────────────────────┐
│  FHE Coprocessor      │   │    KMS (Key Mgmt)       │
│  - Rust-based         │   │    - MPC-based          │
│  - Heavy computation  │   │    - 13 nodes           │
│  - 20+ TPS            │   │    - 2/3 majority       │
│  - Asynchronous       │   │    - Threshold decrypt  │
└───────────────────────┘   └─────────────────────────┘
```

#### Solidity Integration

**Developer Experience:**
```solidity
import {FHE, euint64, euint256, ebool} from "@fhevm/solidity/lib/FHE.sol";

contract ConfidentialContract {
    // Encrypted state variables
    euint64 private encryptedBalance;

    function transfer(externalEuint64 inputAmount, bytes calldata proof) external {
        // Convert external input to internal encrypted type
        euint64 amount = FHE.fromExternal(inputAmount, proof);

        // Perform encrypted arithmetic
        encryptedBalance = FHE.sub(encryptedBalance, amount);

        // Set access control
        FHE.allow(encryptedBalance, msg.sender);
    }
}
```

**Key Features:**
- Standard Solidity syntax with encrypted types (`euint8` to `euint256`, `ebool`)
- Full arithmetic operators: `+`, `-`, `*`, `/`, `<`, `>`, `==`, ternary operations
- Boolean logic on encrypted data
- Access control via `FHE.allow()` and `FHE.allowThis()`
- Compatible with existing toolchains (Hardhat, Foundry)

#### TFHE-rs: Rust Implementation

**Overview:**
- **Pure Rust implementation** of TFHE (Torus FHE)
- **License**: BSD-3-Clause-Clear (commercial license required for production)
- **Rust Version Required**: ≥ 1.84
- **Multi-API Support**: Rust API, C FFI, WASM/JavaScript client API

**API Layers:**
```
┌──────────────────────────────────────────────┐
│  High-Level API (Application Layer)          │
│  - Boolean, Shortint, Integer operations     │
│  - Easy-to-use abstractions                  │
└──────────────────────────────────────────────┘
                     │
┌──────────────────────────────────────────────┐
│  Fine-Grained APIs (Circuit Evaluation)      │
│  - Boolean circuit evaluation                │
│  - Short integer circuits                    │
│  - Integer arithmetic circuits               │
└──────────────────────────────────────────────┘
                     │
┌──────────────────────────────────────────────┐
│  Core Crypto API (Primitives)                │
│  - TFHE scheme primitives                    │
│  - Programmable bootstrapping                │
│  - Low-level cryptographic operations        │
└──────────────────────────────────────────────┘
```

**TFHE-rs Features:**

| Feature | Support | Notes |
|---------|---------|-------|
| Encrypted integers | ✅ | Up to 256 bits |
| Encrypted booleans | ✅ | Full boolean circuits |
| Arithmetic operations | ✅ | Add, sub, mul, div |
| Comparisons | ✅ | lt, gt, eq, min, max |
| Bitwise operations | ✅ | AND, OR, XOR, NOT |
| GPU acceleration | ✅ | Nvidia GPUs supported |
| HPU acceleration | ✅ | Specialized hardware |
| WASM client API | ✅ | Browser/Node.js |
| **WASM FHE compute** | ❌ | **Only client-side encryption/decryption** |
| `no_std` support | ❌ | **Requires Rust standard library** |
| Threading | ✅ | **Rayon-based parallelization** |
| Quantum resistance | ✅ | Based on lattice cryptography |

**Critical Technical Requirements:**
1. **Standard Library Dependency**: Requires full `std` library
2. **CSPRNG (Crypto-Secure RNG)**: Platform-specific entropy sources needed
3. **Threading/Rayon**: Heavy use of parallel computation
4. **Memory**: Large key sizes (can exceed 2GB for certain parameter sets)
5. **File I/O**: Serialization support for keys/ciphertexts
6. **Platform Constraints**: No Windows ARM64 (AArch64) due to entropy issues

#### WASM Support in TFHE-rs

**What's Supported:**
```javascript
// Client-side operations (Browser/Node.js)
import { tfhe } from 'tfhe';

// ✅ Key generation (slow, limited parameter sets)
const keys = await tfhe.generateKeys();

// ✅ Encryption
const ciphertext = await tfhe.encrypt(plaintext, keys.publicKey);

// ✅ Decryption
const plaintext = await tfhe.decrypt(ciphertext, keys.privateKey);

// ❌ FHE Operations (add, multiply, etc.) - NOT SUPPORTED IN WASM
```

**Major WASM Limitations:**
1. **No FHE Computation**: Only encryption/decryption/key generation
2. **Memory Limit**: Browser 2GB limit prevents large parameter sets
3. **Threading**: No thread support → very slow key generation
4. **Key Size**: Large keys (>2GB for some params) unusable in browser
5. **Performance**: Intended for "browser creates keys, server computes" pattern

---

### Arbitrum Stylus

#### What is Stylus?

**Arbitrum Stylus** extends Arbitrum chains to support smart contracts written in Rust, C, and C++ that compile to WebAssembly (WASM), running alongside traditional Solidity/EVM contracts with full interoperability.

**Key Launch Info:**
- **Public Launch**: September 2024
- **Developer**: Offchain Labs (Arbitrum team)
- **WASM Runtime**: Wasmer (modified fork)
- **Audit**: OpenZeppelin (August 2024)
- **Status**: Production-ready on Arbitrum One and Nova

#### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Arbitrum Execution Layer                  │
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │  EVM Contracts   │ ◄─────► │  Stylus Contracts│         │
│  │  (Solidity)      │         │  (Rust/C/C++)    │         │
│  │                  │         │                  │         │
│  │  Traditional     │         │  WASM execution  │         │
│  │  bytecode        │         │  via Wasmer      │         │
│  └──────────────────┘         └──────────────────┘         │
│           │                            │                    │
│           └────────────┬───────────────┘                    │
│                        ▼                                    │
│              ┌────────────────────┐                         │
│              │   Unified Storage   │                        │
│              │   (Same Trie)       │                        │
│              └────────────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

**Interoperability:**
- Solidity contracts can call Rust contracts
- Rust contracts can call Solidity contracts
- Shared storage trie (identical layout to Solidity)
- ABI compatibility (standard Ethereum ABI)
- Both VMs define the state transition function together

#### Stylus Performance Advantages

**Computation & Memory:**

| Metric | Solidity/EVM | Stylus/WASM | Improvement |
|--------|--------------|-------------|-------------|
| Compute operations | Baseline | 10-100x faster | **10-100x** |
| Memory operations | Baseline | 100-500x cheaper | **100-500x** |
| Cryptographic operations | Baseline | 18x faster | **18x** (Poseidon) |
| Oracle workloads | Baseline | 26-50% cheaper | **~35%** average |

**Real-World Examples:**
- **Poseidon hash**: 18x gas reduction vs. Solidity
- **Keccak operations**: 86.6% gas reduction
- **RedStone Oracle**: 30%+ gas savings vs. optimized EVM

**Why Faster?**
1. WASM bytecode more efficient than EVM opcodes
2. Native Rust/C/C++ compiler optimizations (LLVM)
3. Superior memory model with exponential pricing
4. Direct execution vs. interpretation

#### Gas Model: "Ink"

**What is Ink?**
Stylus introduces a new gas unit called **ink** because WASM is so much faster:

```
Traditional: 1 EVM opcode ≈ 1 gas unit
Stylus:     1000s of WASM opcodes ≈ 1 gas unit

Default Ratio: 1 gas = 10,000 ink
```

**Why Different?**
- Executing thousands of WASM opcodes takes the same time as one EVM opcode
- Ink provides granular metering for fast WASM execution
- Configurable by chain owner (can adjust as VMs improve)

**Cost Implications:**
- ✅ Heavy computation: Major gas savings
- ✅ Memory-intensive: Exponential pricing drastically cheaper
- ❌ Simple contracts: 128-2048 gas overhead to call Stylus
- ⚖️ Breakeven: ~5-10 operations before Stylus becomes cheaper

#### Rust SDK Overview

**Storage System:**
```rust
use stylus_sdk::prelude::*;

// Option 1: Rust native storage
#[storage]
pub struct MyContract {
    owner: StorageAddress,
    balance: StorageU256,
    users: StorageMap<Address, StorageU256>,
}

// Option 2: Solidity-compatible storage layout
sol_storage! {
    pub struct MyContract {
        address owner;
        uint256 balance;
        mapping(address => uint256) users;
    }
}
```

**Storage Features:**
- **Optimal Caching**: SDK caches storage to minimize `SLOAD`/`SSTORE`
- **Lazy Loading**: Only loads storage slots when accessed
- **Write Batching**: Batches writes for efficiency
- **Solidity Compatibility**: `sol_storage!` guarantees identical layout
- **Migration Support**: Existing Solidity contracts can upgrade to Rust

**Function Definition:**
```rust
#[entrypoint]
impl MyContract {
    // View function (read-only)
    pub fn get_balance(&self) -> U256 {
        self.balance.get()
    }

    // Write function (state mutation)
    pub fn transfer(&mut self, to: Address, amount: U256) -> Result<(), Vec<u8>> {
        // Business logic
        self.balance.set(new_balance);
        Ok(())
    }

    // Pure function (no state access)
    pub fn compute(x: U256, y: U256) -> U256 {
        x + y
    }
}
```

**External Calls:**
```rust
sol_interface! {
    interface IERC20 {
        function balanceOf(address) external view returns (uint256);
        function transfer(address, uint256) external returns (bool);
    }
}

// Call external Solidity contract
let erc20 = IERC20::new(token_address);
let balance = erc20.balance_of(Call::new(), user_address)?;
let success = erc20.transfer(
    Call::new().gas(100_000).value(U256::ZERO),
    recipient,
    amount
)?;
```

#### WASM Constraints & Validation

**Contract Size Limits:**
```
Compressed WASM:   ≤ 24 KB
Uncompressed WASM: ≤ 128 KB
```

**Why These Limits?**
- Match EVM contract size limit (24KB)
- Maintain full interoperability
- Ensure reasonable deployment costs
- Prevent state bloat

**Optimization Strategies:**
```bash
# Enable optimization
cargo build --release

# Strip debug symbols
cargo strip

# Use wasm-opt
wasm-opt --strip-debug --optimize-level=3

# Minimize dependencies
[profile.release]
opt-level = "z"  # Optimize for size
lto = true       # Link-time optimization
codegen-units = 1
strip = true
```

**Validation Checks During Activation:**
1. **Size Verification**: Enforce 24KB/128KB limits
2. **Stack Depth Analysis**: Ensure deterministic behavior across compilers
3. **Memory Bounds**: Enforce maximum allocation limits
4. **Export/Import Limits**: Prevent excessive complexity
5. **Opcode Restrictions**: Block unsupported WASM features (e.g., SIMD)
6. **Reserved Symbols**: Detect naming conflicts
7. **Gas Metering Instrumentation**: Inject ink counting

**Prohibited Features:**
- ❌ SIMD instructions (not deterministic across all processors)
- ❌ Floating point (non-determinism, limited support)
- ❌ Host imports (except approved hostios)
- ❌ Memory growth beyond limits
- ❌ Non-deterministic operations

**Determinism Requirements:**

Stylus contracts **must be deterministic** - same input always produces same output:

```
✅ Allowed:
- Arithmetic operations
- Cryptographic functions (deterministic)
- Storage reads/writes
- Block data (block.number, block.timestamp)
- Approved hostios

❌ Prohibited:
- System time (WASI time APIs)
- Random number generation (must use block data)
- File system access
- Network operations
- Non-deterministic floating point
```

**Available Hostios:**

Stylus contracts interact with the blockchain through hostios defined in `hostio.h`:

```c
// Context queries
void msg_sender(uint8_t *sender);
void msg_value(uint8_t *value);
uint64_t block_number();
uint64_t block_timestamp();

// Storage operations
void storage_store_bytes32(const uint8_t *key, const uint8_t *value);
void storage_load_bytes32(const uint8_t *key, uint8_t *value);

// Contract calls
uint8_t call_contract(
    const uint8_t *contract,
    const uint8_t *input,
    size_t input_len,
    uint8_t *output,
    size_t output_len,
    uint64_t *gas
);

// Memory operations
uint32_t memory_grow(uint32_t pages);

// Cryptographic functions
void native_keccak256(const uint8_t *bytes, size_t len, uint8_t *output);

// ... many more in hostio.h
```

**Cryptographic Support:**
- ✅ Keccak256 (native hostio)
- ✅ SHA256 (can implement or use crates)
- ✅ ECDSA signature verification (via precompiles)
- ✅ Standard Rust crypto crates (with `no_std`)
- ❌ Heavy FHE operations (size/memory constraints)

#### Stylus Best Practices

**Memory Management:**
```rust
#![no_std]  // Required for size constraints
extern crate alloc;

use alloc::vec::Vec;
use alloc::string::String;

// Use custom allocator for efficiency
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;
```

**Dependency Selection:**
```toml
[dependencies]
stylus-sdk = "0.9"

# Choose no_std compatible crates
serde = { version = "1.0", default-features = false }
tiny-keccak = { version = "2.0", features = ["keccak"] }

# Avoid heavy dependencies that bloat WASM
# ❌ tokio (async runtime, std only)
# ❌ std filesystem
# ❌ heavy crypto crates
```

**Reactivation Requirement:**
- Contracts must be **reactivated every 365 days**
- Or when Stylus upgrades occur
- Non-reactivated contracts become non-callable
- Reactivation updates gas metering/instrumentation

---

## Technical Deep Dive

### FHEVM Coprocessor Model

The coprocessor architecture is critical to understanding why direct porting is challenging.

#### Symbolic Execution Flow

```
Step 1: Smart Contract Execution (On-Chain)
┌────────────────────────────────────────┐
│ function transfer(                      │
│   externalEuint64 amount,              │
│   bytes proof                          │
│ ) {                                    │
│   euint64 amt = FHE.fromExternal(...); │ ─┐
│   balance = FHE.sub(balance, amt);     │  │ Symbolic execution
│   // Emits event with handle           │  │ (lightweight)
│ }                                      │  │
└────────────────────────────────────────┘ ─┘
           │
           │ Event: "FHE operation requested"
           │ Data: Operation type, handles, params
           ▼
Step 2: Gateway Detects Event
┌────────────────────────────────────────┐
│ Gateway Service monitors blockchain    │
│ - Detects FHE operation events         │
│ - Extracts operation metadata          │
│ - Forwards to coprocessor              │
└────────────────────────────────────────┘
           │
           ▼
Step 3: Coprocessor Executes FHE (Off-Chain)
┌────────────────────────────────────────┐
│ Coprocessor (Rust + TFHE-rs)          │
│ - Performs actual FHE computation      │
│ - Heavy lifting (add, multiply, etc.)  │
│ - GPU-accelerated if available         │
│ - Produces encrypted result            │
└────────────────────────────────────────┘
           │
           ▼
Step 4: Result Posted Back On-Chain
┌────────────────────────────────────────┐
│ Gateway posts result to blockchain     │
│ - Transaction with result ciphertext   │
│ - Handle stored in contract storage    │
│ - Contract continues execution         │
└────────────────────────────────────────┘
```

**Why This Architecture?**

1. **Performance**: FHE is 1000-10000x slower than plaintext operations
2. **Cost**: Running FHE on-chain would make gas costs astronomical
3. **Scalability**: Coprocessor can be parallelized/distributed
4. **Flexibility**: Coprocessor can use GPU acceleration, specialized hardware

**Throughput Evolution:**
- **FHEVM v1** (on-chain): ~2-3 TPS
- **FHEVM Coprocessor v0.7** (May 2025): ~20 TPS
- **Target** (future): 100-1000+ TPS

#### Key Management System (KMS)

**Architecture:**
```
┌──────────────────────────────────────────────────────────┐
│              Decryption Request                          │
│  (User or contract requests to decrypt handle)           │
└──────────────────────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│                   KMS Network                            │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐        │
│  │Node 1  │  │Node 2  │  │Node 3  │  │  ...   │        │
│  │        │  │        │  │        │  │        │        │
│  │ Share  │  │ Share  │  │ Share  │  │ Share  │        │
│  │  1/13  │  │  2/13  │  │  3/13  │  │ 13/13  │        │
│  └────────┘  └────────┘  └────────┘  └────────┘        │
│                                                          │
│  MPC Protocol: 13 nodes, 2/3 majority (9 of 13)         │
│  - Threshold decryption                                  │
│  - No single node has full key                           │
│  - Malicious minority tolerated                          │
│  - All nodes in AWS Nitro Enclaves                       │
└──────────────────────────────────────────────────────────┘
                        │
                        ▼
              ┌─────────────────────┐
              │ Decrypted Plaintext │
              │ (only if authorized)│
              └─────────────────────┘
```

**Security Properties:**
- Private key never exists in full anywhere
- Requires 9 of 13 nodes to cooperate for decryption
- Maliciously secure MPC protocol
- Hardware-level security (AWS Nitro Enclaves)
- Quantum-resistant (based on TFHE lattice crypto)

**Access Control:**
```solidity
// In smart contract
euint64 secretValue = FHE.asEuint64(42);

// Allow contract itself to use the value
FHE.allowThis(secretValue);

// Allow specific user to decrypt
FHE.allow(secretValue, msg.sender);

// Allow another contract
FHE.allow(secretValue, address(otherContract));
```

Only addresses with `FHE.allow()` permission can request KMS decryption.

---

## Integration Analysis

### Direct Port Feasibility

**Scenario**: Compile TFHE-rs directly into Stylus WASM contract

```rust
// Hypothetical (DOES NOT WORK)
#![no_std]  // Required by Stylus
extern crate alloc;

use stylus_sdk::prelude::*;
use tfhe::*;  // ❌ Problem: requires std

#[storage]
pub struct FHEContract {
    encrypted_balance: StorageBytes,  // Store ciphertext
}

#[entrypoint]
impl FHEContract {
    pub fn add_balance(&mut self, amount: Vec<u8>) -> Result<(), Vec<u8>> {
        // ❌ Problem: tfhe requires std library
        let server_key = ServerKey::new(...);

        // ❌ Problem: This operation is HUGE (many MB of WASM)
        let result = server_key.add(&ciphertext1, &ciphertext2);

        // ❌ Problem: Even if it compiled, contract >> 24KB limit
        Ok(())
    }
}
```

#### Incompatibility Matrix

| Requirement | Stylus | TFHE-rs | Compatible? |
|-------------|--------|---------|-------------|
| **Standard Library** | ❌ Requires `#[no_std]` | ✅ Requires `std` | ❌ **INCOMPATIBLE** |
| **Contract Size** | ≤ 24KB compressed | FHE operations = MB | ❌ **INCOMPATIBLE** |
| **Memory** | Limited, exponential pricing | Large keys (>2GB possible) | ❌ **INCOMPATIBLE** |
| **Threading** | ❌ No threads | ✅ Rayon parallelization | ❌ **INCOMPATIBLE** |
| **Entropy/RNG** | Block-based only | OS entropy sources | ⚠️ **PROBLEMATIC** |
| **Determinism** | ✅ Strictly enforced | FHE uses randomness | ⚠️ **PROBLEMATIC** |
| **Floating Point** | ⚠️ Limited support | Some FHE params use floats | ⚠️ **PROBLEMATIC** |
| **File I/O** | ❌ Not available | Key serialization uses I/O | ❌ **INCOMPATIBLE** |
| **External Calls** | ✅ Via hostios | Not applicable | ➖ N/A |

**Verdict**: ❌ **Direct compilation of TFHE-rs into Stylus contracts is not viable.**

---

## Challenges and Limitations

### 1. Standard Library Dependency

**TFHE-rs Requirements:**
```rust
// TFHE-rs heavily uses std
use std::error::Error;
use std::fs::File;
use std::io::{Read, Write};
use rayon::prelude::*;  // Requires std::thread

// Example from TFHE-rs
pub fn generate_keys() -> Result<ClientKey, Box<dyn Error>> {
    // Uses std::error::Error
    // Uses std::thread (via rayon)
    // Uses std::sync (for parallelization)
    // ...
}
```

**Stylus Requirements:**
```rust
// Stylus contracts must use no_std
#![no_std]
extern crate alloc;  // Only heap allocation, no threading

use alloc::vec::Vec;
use alloc::string::String;

// NO access to:
// - std::thread
// - std::fs
// - std::io (except via hostios)
// - std::sync (no threads to sync)
```

**Why This Matters:**
- TFHE-rs is **fundamentally designed** around `std` features
- Rayon (parallel computation) requires `std::thread`
- CSPRNG requires OS-level entropy sources
- No `no_std` mode exists or is planned

**Potential Workarounds:**
- ❌ Port TFHE-rs to `no_std`: Massive engineering effort (months/years)
- ❌ Fork and modify: Ongoing maintenance burden
- ✅ **Keep FHE off-chain**: Use coprocessor architecture

### 2. Contract Size Limits

**Size Comparison:**

```
Stylus Limits:
├─ Compressed WASM:   24 KB
└─ Uncompressed WASM: 128 KB

Typical Rust Contract:
├─ Simple ERC-20:     ~15 KB compressed ✅
├─ Complex DeFi:      ~22 KB compressed ✅
└─ With TFHE-rs:      ??? MB compressed ❌

TFHE-rs Binary Size:
├─ Core library:      ~50-100 MB
├─ With dependencies: ~100-200 MB
└─ WASM compiled:     ~10-50 MB (estimated)
```

**Why So Large?**
1. **Bootstrapping tables**: FHE bootstrapping requires large lookup tables
2. **Polynomial operations**: NTT/FFT implementations are code-heavy
3. **Multiple parameter sets**: Different security levels = more code
4. **Crypto primitives**: Lattice-based crypto is complex

**Optimization Attempts:**
```bash
# Even with aggressive optimization
cargo build --release
wasm-opt -Oz --strip-debug output.wasm

# Result: Still orders of magnitude over 24KB limit
```

**Reality Check:**
- Even if we **only** included FHE addition, it would exceed limits
- Bootstrapping alone is massive
- No feasible way to fit FHE operations in 24KB

### 3. Memory Constraints

**FHE Memory Requirements:**

| Operation | Memory Usage |
|-----------|--------------|
| Key generation | 100 MB - 2 GB |
| Single ciphertext | 1-10 KB |
| Bootstrapping | 100 MB - 1 GB |
| Homomorphic ops | 10-100 MB |

**Stylus Memory:**
- Uses WASM linear memory model
- Exponential pricing for memory growth
- Practical limit: ~10-50 MB before gas costs become prohibitive
- 2GB absolute limit (WASM spec)

**Memory Growth Costs:**

```
Pages 0-128:   Cheap (first 8MB)
Pages 128-256: More expensive
Pages 256+:    Exponentially expensive
```

**Problem:**
- FHE key material alone can exceed practical limits
- Bootstrapping operations require huge working memory
- Stylus gas costs would make operations uneconomical

### 4. Threading and Parallelization

**TFHE-rs Design:**
```rust
// TFHE-rs uses Rayon for parallelization
use rayon::prelude::*;

impl ServerKey {
    pub fn add_parallelized(&self, ct1: &Ciphertext, ct2: &Ciphertext) -> Ciphertext {
        // Parallel polynomial operations
        let results: Vec<_> = polynomials
            .par_iter()  // ← Uses threads
            .map(|poly| poly.evaluate())
            .collect();
        // ...
    }
}
```

**WASM Reality:**
- ❌ No thread support in WASM (by spec)
- ❌ No `std::thread` in `no_std`
- ⚠️ WASM threads proposal exists but:
  - Not widely supported
  - Not deterministic
  - Not suitable for blockchain

**Performance Impact:**
- FHE is **already slow** (1000-10000x plaintext)
- Without parallelization: **Even slower**
- Single-threaded FHE: Potentially 10-100x slower than parallel
- Result: Completely impractical for on-chain execution

### 5. Determinism vs. Randomness

**Blockchain Requirement:**
```
Same input → Same execution → Same output
(Every validator must reach identical state)
```

**FHE Operations:**
```rust
// Encryption uses randomness
let ciphertext = encrypt(plaintext, public_key, &mut rng);
// ↑ Different random values each time

// Problem: Two validators encrypting same value → different ciphertexts
// → Different state → Consensus failure
```

**Solutions:**
1. **Pre-encrypted inputs**: Encrypt off-chain, submit ciphertext
   - ✅ Used by FHEVM
   - Requires proof of correct encryption

2. **Deterministic RNG**: Seed from block data
   - ⚠️ Potential security issues (predictable randomness)
   - Not standard in TFHE-rs

3. **Off-chain execution**: Don't do FHE on-chain
   - ✅ Coprocessor model
   - Requires additional infrastructure

**FHEVM Solution:**
```solidity
// User provides encrypted input + proof (generated off-chain)
function transfer(
    externalEuint64 inputAmount,    // Encrypted by user
    bytes calldata inputProof       // Proof it's valid
) external {
    // Verify and convert to internal type
    euint64 amount = FHE.fromExternal(inputAmount, inputProof);

    // All operations are deterministic
    // (no new encryption, only homomorphic ops on existing ciphertexts)
}
```

### 6. Entropy Sources

**TFHE-rs Needs:**
- Cryptographically secure random number generator (CSPRNG)
- Requires OS-level entropy (e.g., `/dev/urandom`, RDRAND)
- Platform-specific implementation

**Stylus Provides:**
- ❌ No WASI random APIs (non-deterministic)
- ✅ Block data (deterministic):
  - `block.timestamp`
  - `block.prevrandao`
  - `block.number`

**Problem:**
- TFHE-rs CSPRNG requires OS entropy
- Stylus cannot provide this (breaks determinism)
- Block data is predictable (not suitable for crypto key generation)

### 7. Coprocessor Dependency

**FHEVM Architecture Requirement:**
```
Smart Contract (Symbolic) ←→ Coprocessor (Actual FHE) ←→ KMS (Decryption)
```

This is **not optional** - it's fundamental to the design:

1. **Contract emits events** for FHE operations
2. **Gateway service** monitors events
3. **Coprocessor executes** FHE off-chain
4. **Results posted** back to contract

**Stylus Doesn't Have:**
- ❌ Event monitoring infrastructure
- ❌ Coprocessor coordination
- ❌ Gateway service integration
- ❌ KMS integration

**To Replicate:**
- Would need to build entire infrastructure
- Gateway service (off-chain)
- Coprocessor network
- KMS with MPC
- = Months/years of development

---

## Potential Approaches

### Approach 1: Hybrid Coprocessor Model (RECOMMENDED)

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                   Arbitrum Stylus Chain                      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Stylus Contract (Rust/WASM)                         │  │
│  │  - Stores encrypted data (ciphertexts)               │  │
│  │  - Emits events for FHE operations                   │  │
│  │  - Manages access control                            │  │
│  │  - Handles non-FHE logic                             │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                        │
                        │ Events
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                  Gateway Service (Off-Chain)                 │
│  - Monitors Stylus contract events                          │
│  - Forwards FHE operation requests                          │
│  - Returns results to contract                              │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              FHE Coprocessor (TFHE-rs + Rust)               │
│  - Runs full TFHE-rs with std library                       │
│  - GPU acceleration available                               │
│  - Parallel computation (Rayon)                             │
│  - Executes actual FHE operations                           │
└─────────────────────────────────────────────────────────────┘
```

**Implementation Steps:**

1. **Stylus Contract** (On-Chain):
```rust
#![no_std]
extern crate alloc;
use stylus_sdk::prelude::*;
use alloc::vec::Vec;

#[storage]
pub struct FHEContract {
    // Store ciphertext bytes
    balances: StorageMap<Address, StorageBytes>,
    // Track pending FHE operations
    pending_ops: StorageMap<U256, StorageBytes>,
}

#[entrypoint]
impl FHEContract {
    // Submit encrypted value (encrypted off-chain by user)
    pub fn submit_encrypted_balance(
        &mut self,
        ciphertext: Vec<u8>,
        proof: Vec<u8>
    ) -> Result<(), Vec<u8>> {
        // Verify proof (using hostio crypto functions)
        self.verify_encryption_proof(&ciphertext, &proof)?;

        // Store ciphertext
        self.balances.setter(msg::sender()).set_bytes(&ciphertext);

        Ok(())
    }

    // Request FHE operation (emits event)
    pub fn request_add(
        &mut self,
        user_a: Address,
        user_b: Address
    ) -> Result<U256, Vec<u8>> {
        let op_id = self.generate_op_id();

        // Emit event for coprocessor
        evm::log(FHEOperationRequested {
            op_id,
            operation: Operation::Add,
            operand_a: user_a,
            operand_b: user_b,
        });

        Ok(op_id)
    }

    // Callback for coprocessor to submit result
    pub fn submit_result(
        &mut self,
        op_id: U256,
        result: Vec<u8>,
        proof: Vec<u8>
    ) -> Result<(), Vec<u8>> {
        // Verify caller is authorized coprocessor
        require(self.is_authorized_coprocessor(msg::sender()));

        // Verify proof of correct execution
        self.verify_execution_proof(op_id, &result, &proof)?;

        // Store result
        self.pending_ops.setter(op_id).set_bytes(&result);

        Ok(())
    }
}
```

2. **Gateway Service** (Off-Chain Rust):
```rust
// Full std library available
use tokio;
use ethers::prelude::*;

#[tokio::main]
async fn main() {
    let provider = Provider::<Ws>::connect("wss://arb1.arbitrum.io/rpc").await?;

    // Monitor contract events
    let filter = Filter::new()
        .address(contract_address)
        .event("FHEOperationRequested(uint256,uint8,address,address)");

    let mut stream = provider.subscribe_logs(&filter).await?;

    while let Some(log) = stream.next().await {
        let event = parse_fhe_operation_requested(log)?;

        // Forward to coprocessor
        let result = coprocessor_client
            .execute_operation(event)
            .await?;

        // Submit result back to contract
        contract
            .submit_result(event.op_id, result.ciphertext, result.proof)
            .send()
            .await?;
    }
}
```

3. **Coprocessor** (Off-Chain Rust + TFHE-rs):
```rust
// Full TFHE-rs with std, threading, GPU
use tfhe::prelude::*;
use rayon::prelude::*;

pub struct FHECoprocessor {
    server_key: ServerKey,
}

impl FHECoprocessor {
    pub fn execute_operation(&self, op: FHEOperation) -> Result<FHEResult> {
        match op.operation {
            Operation::Add => {
                let ct_a = Ciphertext::deserialize(&op.operand_a)?;
                let ct_b = Ciphertext::deserialize(&op.operand_b)?;

                // Actual FHE computation (can use GPU, threads, etc.)
                let result = self.server_key.add(&ct_a, &ct_b);

                // Generate proof of correct execution
                let proof = self.generate_proof(&op, &result)?;

                Ok(FHEResult {
                    ciphertext: result.serialize(),
                    proof,
                })
            }
            // ... other operations
        }
    }
}
```

**Advantages:**
- ✅ Stylus contract stays within size/memory limits
- ✅ FHE operations can use full TFHE-rs capabilities
- ✅ GPU acceleration, threading available off-chain
- ✅ Leverages Stylus performance for non-FHE logic
- ✅ Similar architecture to proven FHEVM design

**Disadvantages:**
- ❌ Requires off-chain infrastructure
- ❌ Additional complexity
- ❌ Centralization risk (need decentralized coprocessor network)
- ❌ Latency (async execution)

**Best For:**
- Production systems requiring confidential computation
- Applications with FHE-heavy workloads
- Projects willing to operate infrastructure

---

### Approach 2: Use Fhenix CoFHE on Arbitrum

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│               Your Stylus Contract (Arbitrum)                │
│  - Standard Rust/WASM logic                                  │
│  - No FHE operations                                         │
└─────────────────────────────────────────────────────────────┘
                        │
                        │ External calls
                        ▼
┌─────────────────────────────────────────────────────────────┐
│          Fhenix CoFHE Integration Contract (Solidity)        │
│  - Interface to CoFHE coprocessor                           │
│  - Already deployed on Arbitrum                             │
│  - Single-line FHE operations                               │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Fhenix CoFHE (Off-Chain Coprocessor)           │
│  - Secured by EigenLayer                                    │
│  - 50x faster decryption                                    │
│  - Low on-chain gas costs                                   │
└─────────────────────────────────────────────────────────────┘
```

**Implementation:**
```rust
// Your Stylus contract
#![no_std]
extern crate alloc;
use stylus_sdk::prelude::*;

sol_interface! {
    interface IFhenixCoFHE {
        function add(bytes calldata ct1, bytes calldata ct2)
            external returns (bytes memory result);
        function multiply(bytes calldata ct1, bytes calldata ct2)
            external returns (bytes memory result);
    }
}

#[storage]
pub struct MyContract {
    cofhe_address: StorageAddress,
    encrypted_balances: StorageMap<Address, StorageBytes>,
}

#[entrypoint]
impl MyContract {
    pub fn transfer_confidential(
        &mut self,
        to: Address,
        amount_ciphertext: Vec<u8>
    ) -> Result<(), Vec<u8>> {
        // Get sender's encrypted balance
        let sender_balance = self.encrypted_balances
            .getter(msg::sender())
            .get_bytes();

        // Call Fhenix CoFHE for FHE subtraction
        let cofhe = IFhenixCoFHE::new(self.cofhe_address.get());
        let new_sender_balance = cofhe.sub(
            Call::new(),
            sender_balance.clone(),
            amount_ciphertext.clone()
        )?;

        // Get recipient's encrypted balance
        let recipient_balance = self.encrypted_balances
            .getter(to)
            .get_bytes();

        // Call Fhenix CoFHE for FHE addition
        let new_recipient_balance = cofhe.add(
            Call::new(),
            recipient_balance,
            amount_ciphertext
        )?;

        // Store updated encrypted balances
        self.encrypted_balances
            .setter(msg::sender())
            .set_bytes(&new_sender_balance);
        self.encrypted_balances
            .setter(to)
            .set_bytes(&new_recipient_balance);

        Ok(())
    }
}
```

**Advantages:**
- ✅ **Already deployed**: Fhenix CoFHE live on Arbitrum
- ✅ **No infrastructure needed**: Managed by Fhenix
- ✅ **EigenLayer security**: Decentralized verification
- ✅ **Fast**: 50x decryption performance
- ✅ **Simple integration**: Just external calls

**Disadvantages:**
- ❌ **External dependency**: Rely on Fhenix service
- ❌ **Trust assumptions**: Different from self-hosted
- ❌ **Costs**: Fhenix may charge for operations
- ❌ **Less control**: Can't customize FHE parameters

**Best For:**
- Quick prototyping
- Projects wanting to avoid infrastructure
- Applications prioritizing speed-to-market
- Teams comfortable with external dependencies

---

### Approach 3: Client-Side FHE with Stylus Verification

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                    Client Application                        │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  TFHE-rs WASM Client                                   │ │
│  │  - Generate keys (browser)                             │ │
│  │  - Encrypt data                                        │ │
│  │  - Decrypt results                                     │ │
│  │  - Sign proofs                                         │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                        │
                        │ Submit encrypted data + proofs
                        ▼
┌─────────────────────────────────────────────────────────────┐
│             Stylus Contract (Arbitrum Chain)                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  - Store encrypted data (ciphertexts as bytes)        │ │
│  │  - Verify encryption proofs                           │ │
│  │  - Verify zero-knowledge proofs of operations         │ │
│  │  - No FHE computation on-chain                        │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Implementation:**

1. **Client-Side** (JavaScript/WASM):
```javascript
import init, { TfheClientKey, TfhePublicKey } from 'tfhe';

await init(); // Initialize TFHE WASM

// Generate keys (slow, one-time)
const clientKey = TfheClientKey.generate();
const publicKey = clientKey.public_key();

// Encrypt balance
const balance = 1000;
const encryptedBalance = publicKey.encrypt_u64(balance);

// Generate proof that ciphertext is valid
const proof = clientKey.generate_proof(encryptedBalance);

// Submit to blockchain
await stylusContract.submit_encrypted_data(
    encryptedBalance.serialize(),
    proof.serialize()
);
```

2. **Stylus Contract**:
```rust
#![no_std]
extern crate alloc;
use stylus_sdk::prelude::*;
use stylus_sdk::crypto;

#[storage]
pub struct VerifiedFHEContract {
    // Store ciphertexts
    encrypted_data: StorageMap<Address, StorageBytes>,
    // Store public keys
    public_keys: StorageMap<Address, StorageBytes>,
}

#[entrypoint]
impl VerifiedFHEContract {
    // Verify and store encrypted data
    pub fn submit_encrypted_data(
        &mut self,
        ciphertext: Vec<u8>,
        proof: Vec<u8>
    ) -> Result<(), Vec<u8>> {
        // Get user's public key
        let public_key = self.public_keys
            .getter(msg::sender())
            .get_bytes();

        // Verify proof that ciphertext is valid
        // (Uses ZK-SNARKs or similar - proof that user knows plaintext
        //  and ciphertext is correctly formed)
        require(self.verify_encryption_proof(
            &ciphertext,
            &public_key,
            &proof
        )?);

        // Store verified ciphertext
        self.encrypted_data
            .setter(msg::sender())
            .set_bytes(&ciphertext);

        Ok(())
    }

    // Verify proof of FHE operation correctness
    pub fn verify_operation_proof(
        &self,
        input_a: Vec<u8>,
        input_b: Vec<u8>,
        result: Vec<u8>,
        proof: Vec<u8>
    ) -> Result<bool, Vec<u8>> {
        // Verify ZK proof that:
        // result = operation(input_a, input_b)
        // without decrypting anything

        // Use Stylus crypto hostios for verification
        let verification = crypto::verify_snark(
            &proof,
            &self.build_verification_inputs(input_a, input_b, result)
        );

        Ok(verification)
    }
}
```

**Advantages:**
- ✅ No off-chain infrastructure needed
- ✅ Users control their own keys
- ✅ Maximum privacy (keys never leave client)
- ✅ Stylus contract stays small (no FHE code)

**Disadvantages:**
- ❌ **Heavy client-side computation**: Encryption slow in browser
- ❌ **Complex proof generation**: ZK-SNARKs for FHE operations difficult
- ❌ **Limited FHE operations**: Can't do contract-initiated FHE
- ❌ **User experience**: Slow, requires powerful client device

**Best For:**
- Privacy-first applications
- Applications where users encrypt their own data
- Use cases without contract-initiated FHE operations
- Projects with sophisticated cryptography team

---

### Approach 4: Minimal FHE Operations Only

**Concept**: Implement only the *absolutely minimal* FHE operations in Stylus, accepting major limitations.

**What Might Fit:**

1. **Lightweight additively homomorphic encryption** (not full FHE):
   - Paillier cryptosystem (~10-20KB implementation)
   - Only supports addition
   - Much simpler than TFHE

2. **Limited parameter sets**:
   - Only smallest security levels
   - Binary operations only (no integers)
   - Single operation type

**Example** (Paillier-like):
```rust
#![no_std]
extern crate alloc;
use stylus_sdk::prelude::*;

// Implement minimal additively homomorphic encryption
// (This is NOT full FHE, only addition)
pub struct PaillierLite {
    // Minimal state
}

impl PaillierLite {
    // Only homomorphic addition (ciphertext + ciphertext)
    pub fn add(ct1: &[u8], ct2: &[u8]) -> Vec<u8> {
        // Simple modular arithmetic
        // Much smaller than TFHE
    }
}

#[storage]
pub struct MinimalFHE {
    encrypted_values: StorageMap<Address, StorageBytes>,
}

#[entrypoint]
impl MinimalFHE {
    // Only support addition
    pub fn add_encrypted(
        &mut self,
        user_a: Address,
        user_b: Address
    ) -> Result<Vec<u8>, Vec<u8>> {
        let ct_a = self.encrypted_values.getter(user_a).get_bytes();
        let ct_b = self.encrypted_values.getter(user_b).get_bytes();

        // Perform homomorphic addition (lightweight)
        let result = PaillierLite::add(&ct_a, &ct_b);

        Ok(result)
    }
}
```

**Advantages:**
- ✅ Might fit in Stylus size limits
- ✅ No off-chain infrastructure
- ✅ Simple to implement

**Disadvantages:**
- ❌ **Not full FHE**: Very limited operations
- ❌ **Weaker security**: Simpler schemes = easier to break
- ❌ **Limited use cases**: Addition only or very restricted
- ❌ **Still challenging**: Even Paillier implementation non-trivial

**Best For:**
- Proof-of-concept
- Specific use cases needing only addition
- Research projects
- Temporary solution

---

## Alternative Solutions

### 1. Stay with Solidity + Zama FHEVM

**Recommendation**: If FHE is a core requirement, staying with the proven FHEVM stack may be optimal.

**Why Consider This:**
```
✅ Proven: FHEVM is production-ready
✅ Supported: Active development, $130M funding
✅ Integrated: Full stack (contracts, coprocessor, KMS) works together
✅ Documented: Comprehensive docs and examples
✅ Audited: Security audited by professionals
```

**Deploy Options:**
- **Ethereum mainnet**: FHEVM coprocessor already live
- **Arbitrum**: Deploy FHEVM-compatible contracts
- **Dedicated chain**: Run your own fhEVM-native chain

**Migration Consideration:**
Your existing `EVVMCore.sol` is already written for FHEVM. Porting to Stylus would:
- Lose FHEVM integration
- Require rebuilding infrastructure
- Take months of development
- Introduce new security risks

**Verdict**: If FHE is essential, **stay with Solidity + FHEVM**.

---

### 2. Hybrid: Stylus for Computation, FHEVM for Privacy

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                     Arbitrum Chain                           │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Stylus Contracts (Rust/WASM)                        │  │
│  │  - High-performance business logic                   │  │
│  │  - Non-confidential operations                       │  │
│  │  - Gas-optimized computation                         │  │
│  └──────────────────────────────────────────────────────┘  │
│                        │                                    │
│                        │ Interop                            │
│                        ▼                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  FHEVM Contracts (Solidity)                          │  │
│  │  - Confidential state (encrypted)                    │  │
│  │  - FHE operations                                    │  │
│  │  - Privacy-critical logic                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                        │
                        ▼
                  FHEVM Coprocessor
```

**Example Use Case: Confidential DEX**

```rust
// Stylus: High-performance AMM logic
#[storage]
pub struct AMMContract {
    fhe_balances: StorageAddress,  // Address of FHEVM contract
}

#[entrypoint]
impl AMMContract {
    pub fn swap(
        &mut self,
        token_in: Address,
        token_out: Address,
        encrypted_amount: Vec<u8>
    ) -> Result<(), Vec<u8>> {
        // 1. Heavy computation in Stylus (cheap gas)
        let price = self.calculate_price(token_in, token_out)?;
        let fee = self.calculate_fees()?;

        // 2. Confidential balance updates via FHEVM
        let fhe_contract = IFHEVMBalances::new(self.fhe_balances.get());
        fhe_contract.transfer_encrypted(
            msg::sender(),
            self.pool_address(),
            encrypted_amount
        )?;

        Ok(())
    }
}
```

```solidity
// Solidity: FHEVM for confidential balances
import {FHE, euint64} from "@fhevm/solidity/lib/FHE.sol";

contract FHEVMBalances {
    mapping(address => euint64) private encryptedBalances;

    function transferEncrypted(
        address from,
        address to,
        externalEuint64 inputAmount,
        bytes calldata proof
    ) external {
        // Only callable by approved Stylus contracts
        require(isApprovedContract(msg.sender));

        euint64 amount = FHE.fromExternal(inputAmount, proof);
        encryptedBalances[from] = FHE.sub(encryptedBalances[from], amount);
        encryptedBalances[to] = FHE.add(encryptedBalances[to], amount);

        FHE.allow(encryptedBalances[from], from);
        FHE.allow(encryptedBalances[to], to);
    }
}
```

**Advantages:**
- ✅ Best of both worlds: Stylus performance + FHEVM privacy
- ✅ Leverage each platform's strengths
- ✅ Incremental migration possible
- ✅ Full interoperability

**Disadvantages:**
- ❌ Complexity: Two contract types to maintain
- ❌ Gas overhead: Cross-contract calls
- ❌ Deployment: Need both Stylus and FHEVM infrastructure

---

### 3. Use Stylus with FHE-Friendly Alternatives

**Options:**

#### A. **Zero-Knowledge Proofs (ZK-SNARKs)**
Instead of FHE, use ZK for privacy:

```rust
// Stylus contract verifies ZK proofs
pub fn verify_balance_proof(
    &self,
    commitment: [u8; 32],
    proof: Vec<u8>
) -> Result<bool, Vec<u8>> {
    // Verify proof that user has sufficient balance
    // without revealing actual balance
    crypto::verify_groth16(proof, commitment)
}
```

**Pros**: ZK verification is lightweight, fits in Stylus
**Cons**: Different privacy model, can't do computation on encrypted data

#### B. **Trusted Execution Environments (TEE)**
Use hardware enclaves (SGX, Nitro, etc.):

```
Stylus Contract → Attestation Verification → TEE Coprocessor
```

**Pros**: Fast execution, existing hardware
**Cons**: Hardware trust assumptions, limited availability

#### C. **MPC (Multi-Party Computation)**
Distribute computation across multiple parties:

```
Stylus Contract → MPC Protocol → Distributed Computation
```

**Pros**: No single point of trust
**Cons**: Slower than FHE, complex coordination

---

## Recommendations

### For the InvisibleGarden EVVMCore Project

Based on the research, here are prioritized recommendations:

#### **Priority 1: Stay with Solidity + FHEVM (RECOMMENDED)**

**Reasoning:**
1. Your `EVVMCore.sol` is already FHE-native
2. FHEVM is production-ready and well-supported
3. Porting to Stylus would lose FHE capabilities
4. FHE appears core to your design

**Action Items:**
- ✅ Continue development with FHEVM
- ✅ Deploy to Ethereum mainnet or Arbitrum
- ✅ Leverage FHEVM coprocessor (20+ TPS)
- ✅ Plan for future FHEVM scaling (100-1000 TPS)

---

#### **Priority 2: Hybrid Approach (If Stylus is Critical)**

If Stylus adoption is a hard requirement:

**Phase 1** - Core FHE in Solidity:
```solidity
// FHEVM contract for confidential state
contract InvisibleCore {
    mapping(address => euint64) encryptedBalances;
    // ... FHE operations
}
```

**Phase 2** - Performance Optimization in Stylus:
```rust
// Stylus contract for heavy computation
pub struct InvisibleEngine {
    // Non-confidential, gas-intensive operations
    // Calls into InvisibleCore for FHE operations
}
```

**Action Items:**
- Identify which operations need FHE (keep in Solidity)
- Identify which operations are compute-heavy (move to Stylus)
- Design interop layer between contracts

---

#### **Priority 3: Future Migration Path**

If you want to prepare for eventual Stylus migration:

**Now:**
- Continue with FHEVM
- Monitor TFHE-rs development for `no_std` support
- Track Stylus contract size limit increases

**6-12 Months:**
- Evaluate FHE coprocessor solutions (Fhenix CoFHE on Arbitrum)
- Prototype hybrid architecture

**12-24 Months:**
- If TFHE-rs adds `no_std` support: revisit direct integration
- If Stylus increases size limits: reassess feasibility
- Consider building custom FHE coprocessor for Stylus

---

### General Guidance by Use Case

#### **Use Case: Confidential DeFi (Trading, Lending)**
→ **FHEVM (Solidity)**
- FHE essential for balance privacy
- Proven architecture
- 20 TPS sufficient for current needs

#### **Use Case: High-Performance Blockchain (Gaming, Social)**
→ **Stylus** + **Alternative Privacy** (ZK, TEE)
- Stylus performance critical
- FHE not mandatory
- Use ZK for selective privacy

#### **Use Case: Hybrid (Some Confidential, Some Public)**
→ **FHEVM** + **Stylus Hybrid**
- FHE for confidential operations
- Stylus for public, compute-heavy operations
- Leverage interoperability

#### **Use Case: Research / Prototype**
→ **Experiment with Client-Side FHE**
- TFHE WASM for client-side encryption
- Stylus for proof verification
- Learn and iterate quickly

---

## Conclusion

**The Reality:**

Directly porting Solidity + Zama FHE to Arbitrum Stylus is **not currently viable** due to fundamental incompatibilities:

1. ❌ TFHE-rs requires `std` library (Stylus requires `no_std`)
2. ❌ FHE operations far exceed 24KB WASM size limit
3. ❌ Memory requirements exceed practical Stylus limits
4. ❌ Threading/parallelization unavailable in WASM
5. ❌ Determinism conflicts with FHE randomness

**The Path Forward:**

✅ **Best Option**: Continue with **Solidity + FHEVM**
- Production-ready, proven, actively developed
- Your `EVVMCore.sol` already works with it
- Coprocessor architecture solves performance issues

⚠️ **Alternative**: **Hybrid FHEVM + Stylus**
- Use Stylus for non-confidential, compute-heavy operations
- Use FHEVM for confidential state and FHE operations
- Leverage both platforms' strengths

🔬 **Future**: **Monitor Technology Evolution**
- TFHE-rs may add `no_std` support (but not soon)
- Stylus size limits may increase
- FHE coprocessor solutions (Fhenix CoFHE) maturing

**Final Verdict:**

For the **InvisibleGarden EVVMCore project**, the recommendation is clear:

**Continue development with Solidity + Zama FHEVM. Do not port to Stylus at this time.**

The FHEVM stack is purpose-built for confidential smart contracts and your codebase is already optimized for it. Porting to Stylus would require:
- Rebuilding FHE infrastructure from scratch
- Months/years of development
- Significant security risks
- Loss of proven, audited framework

Instead, leverage FHEVM's strengths and monitor the ecosystem for future opportunities to integrate Stylus where appropriate (e.g., hybrid architecture for non-FHE operations).

---

## References

### Official Documentation

**Zama:**
- FHEVM: https://github.com/zama-ai/fhevm
- TFHE-rs: https://github.com/zama-ai/tfhe-rs
- Documentation: https://docs.zama.org/fhevm
- TFHE-rs Docs: https://docs.zama.org/tfhe-rs

**Arbitrum Stylus:**
- Documentation: https://docs.arbitrum.io/stylus/
- Quickstart: https://docs.arbitrum.io/stylus/quickstart
- Rust SDK: https://github.com/OffchainLabs/stylus-sdk-rs
- SDK Reference: https://docs.rs/stylus-sdk/

**Fhenix:**
- Website: https://www.fhenix.io/
- CoFHE Docs: https://cofhe-docs.fhenix.zone/
- GitHub: https://github.com/fhenixprotocol

### Key Articles & Blog Posts

1. "Introducing the fhEVM Coprocessor" - Zama (May 2025)
   https://www.zama.ai/post/fhevm-coprocessor

2. "Fhenix: Bringing Private Computation to Web3 with Arbitrum" - Arbitrum Blog
   https://blog.arbitrum.io/fhenix-private-computation/

3. "Stylus Now Live — One Chain, Many Languages" - Offchain Labs
   https://medium.com/offchainlabs/stylus-now-live-one-chain-many-languages-eee56ad7266d

4. "Poseidon go brr with Stylus" - OpenZeppelin (18x gas savings)
   https://blog.openzeppelin.com/poseidon-go-brr-with-stylus

5. "Arbitrum Stylus & WASM: Superior Performance" - RedStone
   https://blog.redstone.finance/2025/11/04/arbitrum-stylus-wasm-superior-performance-beyond-evm-limitations/

### Academic / Technical Papers

1. "SoK: Fully-homomorphic encryption in smart contracts" (2025)
   https://eprint.iacr.org/2025/527.pdf

2. Stylus Security Audit - Trail of Bits (June 2024)
   https://docs.arbitrum.io/assets/files/2024_06_10_trail_of_bits_security_audit_stylus.pdf

3. OpenZeppelin Stylus Rust SDK Audit (August 2024)
   https://blog.openzeppelin.com/stylus-rust-sdk-audit

### GitHub Repositories

- **FHEVM**: https://github.com/zama-ai/fhevm
- **TFHE-rs**: https://github.com/zama-ai/tfhe-rs
- **Stylus SDK (Rust)**: https://github.com/OffchainLabs/stylus-sdk-rs
- **Stylus SDK (C)**: https://github.com/OffchainLabs/stylus-sdk-c
- **Cargo Stylus CLI**: https://github.com/OffchainLabs/cargo-stylus
- **Awesome Stylus**: https://github.com/OffchainLabs/awesome-stylus

### Community Resources

- **Zama Discord**: https://discord.fhe.org
- **Arbitrum Discord**: https://discord.gg/arbitrum
- **Fhenix Discord**: https://discord.gg/FuVgxrvJMY
- **Stylus Examples**: https://docs.arbitrum.io/stylus-by-example/

---

**Document Version:** 1.0
**Last Updated:** 2025-11-11
**Research Conducted By:** Claude (Anthropic)
**Project:** InvisibleGarden - Invisible zkEVM
**Contact:** [Your contact information]
