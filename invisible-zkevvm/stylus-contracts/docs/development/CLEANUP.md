# Toxic Waste Cleanup Strategy

**Project**: invisible-zkevvm Stylus Contracts
**Analysis Date**: 2025-11-12
**Status**: Pre-production cleanup required

---

## Executive Summary

This project shows signs of **healthy iteration** but needs **cleanup before production**. The analysis identified 14 categories of toxic waste from different work iterations, with 4 CRITICAL issues that must be fixed before any production deployment.

**Most Dangerous Toxins:**
1. Solidity EVVMCafhe still exists alongside Rust version (deployment confusion risk)
2. View functions returning zero without errors (silent failure)
3. Mock FHE with no production safeguards (security risk)
4. Stub FHE methods that fail at runtime (developer trap)

---

## 🔴 CRITICAL ISSUES (Must Fix Before Production)

### Issue #1: Duplicate EVVMCafhe Implementation

**Severity**: CRITICAL
**Files**:
- `contracts/example/EVVMCafhe.sol` (342 lines)
- `stylus-contracts/evvm-cafhe/src/lib.rs` (398 lines)

**What it is**: The EVVMCafhe contract exists in BOTH Solidity and Rust (Stylus) with identical functionality.

**Why it exists**: Incomplete migration from Solidity to Stylus. The Rust version was ported but the Solidity version was kept.

**Problems**:
- Confusion about which version is authoritative
- Risk of deploying the wrong version
- Maintenance burden (changes need to happen in two places)
- Documentation references both versions inconsistently
- Testing confusion (which version to test?)

**Action Required**:
```bash
# 1. Create legacy directory
mkdir -p contracts/legacy

# 2. Move Solidity version
git mv contracts/example/EVVMCafhe.sol contracts/legacy/

# 3. Create deprecation notice
cat > contracts/legacy/README.md << 'EOF'
# Legacy Solidity Contracts

⚠️ **DEPRECATED**: These contracts have been migrated to Stylus (Rust/WASM).

## EVVMCafhe.sol
**Status**: Deprecated
**Replacement**: `stylus-contracts/evvm-cafhe/src/lib.rs`
**Reason**: Migrated to Arbitrum Stylus for better performance and lower gas costs

DO NOT USE THESE CONTRACTS IN PRODUCTION.
EOF
```

**Estimated Time**: 15 minutes

---

### Issue #2: Silent Failure in View Functions

**Severity**: CRITICAL
**File**: `stylus-contracts/evvm-cafhe/src/lib.rs:364-386`

**What it is**: View functions that always return `FixedBytes::ZERO` instead of actual data.

```rust
pub fn get_amount_of_principal_token_in_shop(&self) -> Euint64 {
    // TODO: This currently can't be implemented because we need to call EVVMCore's
    // view function, but self is immutable. Stylus limitation.
    FixedBytes::ZERO  // ⚠️ ALWAYS RETURNS ZERO!
}

pub fn get_amount_of_ether_in_shop(&self) -> Euint64 {
    FixedBytes::ZERO  // ⚠️ ALWAYS RETURNS ZERO!
}
```

**Why it exists**: Stylus limitation - can't call EVVMCore view functions without mutable reference.

**Problems**:
- Functions appear to work but return wrong data
- Off-chain systems reading this data will see all balances as zero
- Silent failure (no error, just wrong data)
- Could cause financial losses if relied upon for business logic

**Action Required**:

**Option A - Remove Functions** (Recommended):
```rust
// DELETE lines 364-386
// Remove both functions entirely until properly implemented
```

**Option B - Return Errors**:
```rust
pub fn get_amount_of_principal_token_in_shop(&self) -> Result<Euint64, Vec<u8>> {
    Err(b"NOT_IMPLEMENTED: Stylus limitation - cannot call view functions from view context".to_vec())
}

pub fn get_amount_of_ether_in_shop(&self) -> Result<Euint64, Vec<u8>> {
    Err(b"NOT_IMPLEMENTED: Stylus limitation - cannot call view functions from view context".to_vec())
}
```

**Option C - Add Tracking Storage**:
```rust
// Add to EVVMCafhe struct:
principal_token_balance: StorageU256,
ether_balance: StorageU256,

// Update these in withdraw_rewards and withdraw_funds
// Then return from storage instead of calling EVVMCore
```

**Estimated Time**: 30 minutes

---

### Issue #3: Mock FHE Contracts Without Safeguards

**Severity**: CRITICAL SECURITY RISK
**File**: `contracts/test/MockFHE.sol` (139 lines)

**What it is**: Mock implementations of FHE precompiles that bypass actual encryption.

**Why it exists**: Testing without real FHE infrastructure.

**Problems**:
- **SEVERE SECURITY RISK**: If accidentally used in production, all "encrypted" data is plaintext
- Could be deployed instead of real contracts
- No runtime checks prevent production usage
- Located in test/ but not clearly marked as dangerous

**Action Required**:

```solidity
// Add to MockKMSVerifier, MockACL, MockCoprocessor constructors:

contract MockKMSVerifier {
    constructor() {
        require(
            block.chainid != 1 && block.chainid != 42161 && block.chainid != 421614,
            "MOCK CONTRACT: NOT FOR PRODUCTION USE. This bypasses encryption!"
        );
    }
    // ... rest of contract
}

contract MockACL {
    constructor() {
        require(
            block.chainid != 1 && block.chainid != 42161 && block.chainid != 421614,
            "MOCK CONTRACT: NOT FOR PRODUCTION USE. This bypasses encryption!"
        );
    }
    // ... rest of contract
}

contract MockCoprocessor {
    constructor() {
        require(
            block.chainid != 1 && block.chainid != 42161 && block.chainid != 421614,
            "MOCK CONTRACT: NOT FOR PRODUCTION USE. This bypasses encryption!"
        );
    }
    // ... rest of contract
}
```

**Add to file header**:
```solidity
// ⚠️⚠️⚠️ DANGER: MOCK CONTRACT - TEST ONLY ⚠️⚠️⚠️
//
// This contract BYPASSES ALL ENCRYPTION for testing purposes.
// DO NOT DEPLOY TO MAINNET OR PRODUCTION ENVIRONMENTS.
// All "encrypted" data is stored as PLAINTEXT.
//
// Protected chains:
// - Ethereum Mainnet (1)
// - Arbitrum One (42161)
// - Arbitrum Sepolia (421614)
//
// ⚠️⚠️⚠️ YOU HAVE BEEN WARNED ⚠️⚠️⚠️
```

**Estimated Time**: 15 minutes

---

### Issue #4: Stub FHE Functions That Fail at Runtime

**Severity**: CRITICAL
**File**: `stylus-contracts/fhe-stylus/src/fhe.rs:72-107`

**What it is**: The `FHE` struct contains functions that all return `Err(FHEError::OperationFailed)` - they're documentation-only stubs.

```rust
impl FHE {
    pub fn add(_lhs: Euint64, _rhs: Euint64) -> Result<Euint64, FHEError> {
        Err(FHEError::OperationFailed)
    }

    pub fn sub(_lhs: Euint64, _rhs: Euint64) -> Result<Euint64, FHEError> {
        Err(FHEError::OperationFailed)
    }
    // ... etc
}
```

**Why it exists**: Initial design had a wrapper API, but the team decided to use precompile interfaces directly instead.

**Problems**:
- Developers might try to use `FHE::add()` instead of the correct `IFHEVMPrecompile::fhe_add()`
- Runtime failures that could have been prevented
- Misleading API surface
- Dead code bloat

**Action Required**:

**Option A - Remove Struct** (Recommended):
```rust
// DELETE the entire FHE impl block (lines 72-107)
// Keep only the documentation at the top of the file
```

**Option B - Make Compile-Time Errors**:
```rust
impl FHE {
    #[deprecated = "Use IFHEVMPrecompile::fhe_add() directly via call()"]
    pub fn add(_lhs: Euint64, _rhs: Euint64) -> ! {
        compile_error!("Use IFHEVMPrecompile::fhe_add() instead")
    }

    // ... repeat for all methods
}
```

**Estimated Time**: 10 minutes

---

## 🟡 HIGH PRIORITY CLEANUP

### Issue #5: Unused Imports

**Severity**: HIGH
**File**: `stylus-contracts/fhe-stylus/src/signature.rs:23-24`

**What it is**: Dead imports flagged by compiler.

```rust
use stylus_sdk::alloy_primitives::{Address, keccak256, FixedBytes, B256};  // FixedBytes unused
use alloc::string::{String, ToString};  // String unused
```

**Why it exists**: Refactoring leftovers.

**Action Required**:
```rust
// Line 23: Remove FixedBytes
use stylus_sdk::alloy_primitives::{Address, keccak256, B256};

// Line 24: Remove String
use alloc::string::ToString;
```

**Estimated Time**: 2 minutes

---

### Issue #6: Placeholder Network Configs

**Severity**: HIGH
**File**: `stylus-contracts/fhe-stylus/src/config.rs:113-133`

**What it is**: Network configurations with Address::ZERO placeholders.

```rust
pub const fn arbitrum_mainnet() -> Self {
    Self {
        // TODO: Update with actual addresses once deployed
        fhevm_precompile: Address::ZERO,
        input_verifier: Address::ZERO,
        // ...
    }
}
```

**Why it exists**: FHEVM not deployed on Arbitrum mainnet yet.

**Problems**:
- Could be deployed to mainnet by mistake
- Would fail silently (calls to Address::ZERO)
- No runtime check to prevent usage

**Action Required**:

**Option A - Runtime Panic**:
```rust
pub const fn arbitrum_mainnet() -> ! {
    panic!("FHEVM not yet deployed on Arbitrum Mainnet. Use arbitrum_sepolia() instead.")
}
```

**Option B - Compile-Time Guard**:
```rust
// In Cargo.toml, add features:
[features]
arbitrum-mainnet = []
arbitrum-sepolia = []

// In config.rs:
#[cfg(feature = "arbitrum-mainnet")]
compile_error!("Arbitrum mainnet not yet supported. Use arbitrum-sepolia feature.");
```

**Estimated Time**: 10 minutes

---

### Issue #7: Documentation Sprawl

**Severity**: MEDIUM
**Location**: `stylus-contracts/*.md` (14 files, 5,136 lines)

**What it is**: Accumulation of documentation from different work iterations.

```
CARGO_STYLUS_CHECK_RESULTS.md
CLAUDE.md
DELIVERABLES.md
DEPLOYMENT_PLAN.md
EXECUTION_RESULTS.md
FIX_APPLIED.md
KNOWN_ISSUES.md
OPTIMIZATION_STATUS.md
README.md
README_TESTING.md
STATUS.md
SUMMARY.md
TESTING_GUIDE.md
TEST_SPEC.md
```

**Why it exists**: Each development phase created new docs without consolidating old ones.

**Problems**:
- Overwhelming for new developers
- Duplicate/conflicting information
- Hard to find canonical source
- Several files cover overlapping topics (3 testing files, 2 status files)

**Action Required**:

```bash
# 1. Create docs structure
mkdir -p docs/archive

# 2. Consolidate main docs
cat README.md STATUS.md SUMMARY.md > docs/README.md
cat TESTING_GUIDE.md README_TESTING.md TEST_SPEC.md > docs/TESTING.md
mv DEPLOYMENT_PLAN.md docs/DEPLOYMENT.md

# 3. Archive historical docs
mv CARGO_STYLUS_CHECK_RESULTS.md docs/archive/
mv DELIVERABLES.md docs/archive/
mv EXECUTION_RESULTS.md docs/archive/
mv FIX_APPLIED.md docs/archive/
mv OPTIMIZATION_STATUS.md docs/archive/

# 4. Keep at root
# - README.md (link to docs/)
# - CLAUDE.md (AI context)
# - CLEANUP.md (this file)

# 5. Create new structure
cat > README.md << 'EOF'
# Invisible zkEVM - Stylus Contracts

Fully Homomorphic Encryption (FHE) contracts for Arbitrum Stylus.

## Documentation

- [Getting Started](docs/README.md)
- [Testing Guide](docs/TESTING.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Architecture](docs/ARCHITECTURE.md)

## Quick Start

\`\`\`bash
# Test
cargo test

# Build
cargo build --target wasm32-unknown-unknown --release

# Deploy
cargo stylus deploy --private-key $PRIVATE_KEY
\`\`\`

## Status

✅ Tests passing: 10/10
✅ Build successful: 65KB WASM
✅ Deployed: Arbitrum Sepolia

See [STATUS.md](docs/STATUS.md) for details.
EOF
```

**Estimated Time**: 45 minutes

---

## 🟢 MEDIUM PRIORITY CLEANUP

### Issue #8: Unused Cargo Profile Configs

**Severity**: MEDIUM
**File**: `stylus-contracts/fhe-stylus/Cargo.toml:22-26`

**What it is**: Profile configs in workspace member that are ignored.

```toml
[profile.dev]
panic = "abort"

[profile.release]
panic = "abort"
```

**Why it exists**: Copy-pasted from workspace root before understanding Cargo workspaces.

**Problems**: Generates compiler warnings, confusing to developers.

**Action Required**:
```toml
# Delete lines 22-26 from fhe-stylus/Cargo.toml
# Profiles only apply at workspace root
```

**Estimated Time**: 2 minutes

---

### Issue #9: Duplicate Signature Libraries

**Severity**: MEDIUM
**Files**:
- `contracts/library/SignatureRecover.sol` (77 lines)
- `stylus-contracts/fhe-stylus/src/signature.rs` (286 lines)

**What it is**: The signature verification logic exists in both Solidity and Rust.

**Why it exists**: Port from Solidity ecosystem to Stylus ecosystem.

**Problems**: If bugs are found, need to fix in both places.

**Action Required**:
```solidity
// Add to SignatureRecover.sol header:
/// @notice Signature recovery utilities for ECDSA signatures
/// @dev This is the Solidity version. Rust equivalent: stylus-contracts/fhe-stylus/src/signature.rs
/// @dev IMPORTANT: Keep both implementations in sync. Changes here should be reflected in Rust.
```

```rust
// Add to signature.rs module doc:
//! ECDSA signature verification and recovery
//!
//! This is the Rust/Stylus version. Solidity equivalent: contracts/library/SignatureRecover.sol
//!
//! IMPORTANT: Keep both implementations in sync. Changes here should be reflected in Solidity.
```

**Estimated Time**: 5 minutes

---

### Issue #10: Untracked Directories in Git

**Severity**: MEDIUM
**Location**: Root directory

```
?? docs/SPEC.md
?? relayer/
```

**What it is**: Directories mentioned in git status but not in the stylus-contracts tree.

**Why it exists**: Work from different iterations left uncommitted.

**Action Required**:

```bash
# Investigate relayer
ls -la relayer/
# If it's part of the project:
git add relayer/
git commit -m "Add relayer implementation"

# If it's experimental:
git checkout -b experimental/relayer
git add relayer/
git commit -m "WIP: Relayer exploration"

# Investigate docs/SPEC.md
cat docs/SPEC.md
# If needed:
git add docs/SPEC.md
git commit -m "Add specification document"

# If not needed:
rm -rf relayer/
rm docs/SPEC.md
```

**Estimated Time**: 15 minutes

---

## 🔵 LOW PRIORITY CLEANUP

### Issue #11: Unused StorageU256 Import

**Severity**: LOW
**File**: `stylus-contracts/evvm-cafhe/src/lib.rs:27`

```rust
use stylus_sdk::storage::{StorageMap, StorageAddress, StorageBool, StorageU256};
```

**Action Required**:
```rust
use stylus_sdk::storage::{StorageMap, StorageAddress, StorageBool};
```

**Estimated Time**: 1 minute

---

### Issue #12: Unused evvm_core Variables

**Severity**: LOW
**File**: `stylus-contracts/evvm-cafhe/src/lib.rs:366, 380`

```rust
let evvm_core = IEVVMCore::new(evvm_core_addr);  // unused
```

**Action Required**:
```rust
let _evvm_core = IEVVMCore::new(evvm_core_addr);  // prefix with underscore
```

**Estimated Time**: 1 minute

---

### Issue #13: Snake_case Warnings in Solidity Interfaces

**Severity**: LOW
**File**: `stylus-contracts/fhe-stylus/src/interfaces.rs` (50+ warnings)

**What it is**: Solidity-style camelCase in Rust code generates warnings.

**Why it exists**: Direct port of Solidity interfaces using `sol_interface!` macro.

**Action Required**:
```rust
// Add at top of file:
#![allow(non_snake_case)]

// Or wrap each interface:
#[allow(non_snake_case)]
sol_interface! {
    interface IFHEVMPrecompile {
        // ...
    }
}
```

**Estimated Time**: 5 minutes

---

### Issue #14: Hex Literal Casing Inconsistency

**Severity**: LOW
**File**: `stylus-contracts/fhe-stylus/src/config.rs:99`

**What it is**: Mixed case in hex bytes.

```rust
0x05, 0xfD, 0x2B, 0x95  // Mixed 0xfD with lowercase
```

**Action Required**:
```rust
0x05, 0xfd, 0x2b, 0x95  // All lowercase
```

**Estimated Time**: 2 minutes

---

## Cleanup Automation Script

Create and run this script to automate safe fixes:

```bash
#!/bin/bash
# cleanup.sh - Automated toxic waste removal

set -e

echo "🧹 Starting toxic waste cleanup..."

# Issue #5: Remove unused imports
echo "Fixing unused imports..."
sed -i '' 's/Address, keccak256, FixedBytes, B256/Address, keccak256, B256/' stylus-contracts/fhe-stylus/src/signature.rs
sed -i '' 's/String, ToString/ToString/' stylus-contracts/fhe-stylus/src/signature.rs

# Issue #8: Remove unused profile configs
echo "Removing duplicate profile configs..."
sed -i '' '22,26d' stylus-contracts/fhe-stylus/Cargo.toml

# Issue #11: Remove unused StorageU256
echo "Removing unused storage import..."
sed -i '' 's/StorageMap, StorageAddress, StorageBool, StorageU256/StorageMap, StorageAddress, StorageBool/' stylus-contracts/evvm-cafhe/src/lib.rs

# Issue #12: Prefix unused variables
echo "Fixing unused variables..."
sed -i '' 's/let evvm_core =/let _evvm_core =/' stylus-contracts/evvm-cafhe/src/lib.rs

# Issue #13: Suppress snake_case warnings
echo "Adding allow directive for Solidity interfaces..."
sed -i '' '1i\
#![allow(non_snake_case)]\
' stylus-contracts/fhe-stylus/src/interfaces.rs

# Issue #14: Standardize hex literals
echo "Standardizing hex literal casing..."
sed -i '' 's/0xfD/0xfd/' stylus-contracts/fhe-stylus/src/config.rs
sed -i '' 's/0x2B/0x2b/' stylus-contracts/fhe-stylus/src/config.rs

echo "✅ Automated cleanup complete!"
echo ""
echo "⚠️  Manual steps still required:"
echo "  1. Archive Solidity EVVMCafhe (Issue #1)"
echo "  2. Fix or remove broken view functions (Issue #2)"
echo "  3. Add safeguards to mock FHE contracts (Issue #3)"
echo "  4. Remove stub FHE methods (Issue #4)"
echo "  5. Add runtime guards to mainnet config (Issue #6)"
echo "  6. Consolidate documentation (Issue #7)"
echo ""
echo "Run: cargo test && cargo build --release --target wasm32-unknown-unknown"
```

---

## Cleanup Timeline

### Phase 1: Critical Fixes (1-2 hours)
- [ ] Issue #1: Archive Solidity EVVMCafhe
- [ ] Issue #2: Fix/remove broken view functions
- [ ] Issue #3: Add mock contract safeguards
- [ ] Issue #4: Remove stub FHE methods

### Phase 2: High Priority (1 hour)
- [ ] Issue #5: Remove unused imports
- [ ] Issue #6: Guard mainnet config
- [ ] Issue #7: Consolidate documentation

### Phase 3: Medium Priority (1 hour)
- [ ] Issue #8: Remove duplicate profiles
- [ ] Issue #9: Document signature library sync
- [ ] Issue #10: Resolve untracked directories

### Phase 4: Low Priority (30 minutes)
- [ ] Issue #11-14: Minor code cleanup
- [ ] Run automated cleanup script
- [ ] Verify all tests pass
- [ ] Update CHANGELOG

**Total Estimated Time**: 3.5-4.5 hours

---

## Verification Checklist

After cleanup, verify:

```bash
# 1. All tests pass
cargo test
forge test

# 2. Build succeeds with no warnings
cargo build --target wasm32-unknown-unknown --release 2>&1 | grep -c "warning: " || echo "Clean build!"

# 3. Stylus check passes
cargo stylus check --wasm-file target/wasm32-unknown-unknown/release/evvm_cafhe.wasm

# 4. Git status is clean
git status

# 5. Documentation is consolidated
ls -1 *.md | wc -l  # Should be ≤ 3 files at root

# 6. No mock contracts in deployments
grep -r "MockFHE\|MockKMS\|MockACL\|MockCoprocessor" deployments/ && echo "⚠️  DANGER: Mock in deployments!" || echo "✅ Clean"
```

---

## Post-Cleanup Maintenance

To prevent toxic waste accumulation:

1. **Archive before replacing**: When porting code, move old versions to `legacy/` immediately
2. **Delete placeholder TODOs**: If not implemented within 2 sprints, remove the stub
3. **Consolidate docs weekly**: Merge status updates into main docs, don't create new files
4. **Run cleanup script**: Include in CI/CD to catch unused imports
5. **Code review checklist**: Check for duplicates, stubs, and incomplete migrations

---

## Questions & Decisions Log

| Issue | Question | Decision | Date |
|-------|----------|----------|------|
| #1 | Keep Solidity EVVMCafhe? | Archive to legacy/ | TBD |
| #2 | Remove or fix view functions? | Remove until implemented | TBD |
| #4 | Delete FHE stub struct? | Remove entire impl | TBD |
| #7 | How many docs to keep? | 3 root + docs/ folder | TBD |

---

## References

- [Stylus Best Practices](https://docs.arbitrum.io/stylus/stylus-gentle-introduction)
- [Cargo Workspace Documentation](https://doc.rust-lang.org/cargo/reference/workspaces.html)
- [FHEVM Documentation](https://docs.zama.ai/fhevm)

---

**Last Updated**: 2025-11-12
**Next Review**: Before production deployment
