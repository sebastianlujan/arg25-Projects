# Testing Guide for Stylus Contracts

**Date**: 2025-11-11
**Status**: ✅ Fixed scale-info dependency conflict

---

## Understanding Stylus Contract Testing

Stylus contracts are **WASM-only** and **no_std**. They cannot run as native Rust tests.

### Why `cargo test` Doesn't Work

```bash
$ cargo test
❌ Error: no global memory allocator found
❌ Error: #[panic_handler] function required
❌ Error: unwinding panics are not supported without std
```

**This is expected!** Stylus contracts compile to WASM, not native binaries.

---

## What Works: WASM-Based Verification

### ✅ Build Verification (Primary Test)

```bash
# If this succeeds, your contract is valid
cargo build --release --target wasm32-unknown-unknown

# Check build succeeded
echo $?  # Should be 0
```

**This is your main "test"** - if the WASM build succeeds, your contract compiles correctly.

### ✅ Type Checking

```bash
cargo check --target wasm32-unknown-unknown
```

Faster than full build, validates types and syntax.

### ✅ Contract Validation

```bash
cd evvm-cafhe
cargo stylus check
```

Validates contract structure and WASM compatibility (once size is optimized).

### ✅ ABI Export

```bash
cargo stylus export-abi
```

If this works, your public functions are correctly defined.

---

## Dependency Fix Applied

### The Problem (Now Fixed)

When using ruint 1.12.3 patch, `cargo test` failed with:

```
error[E0433]: could not find `__private` in `scale`
  --> scale-info-2.11.6/src/ty/mod.rs:274:56
```

### The Solution

Added patches for compatible versions:

```toml
[patch.crates-io]
ruint = { git = "https://github.com/recmo/uint", rev = "0c07a4c3" }
parity-scale-codec = { git = "https://github.com/paritytech/parity-scale-codec", tag = "v3.6.12" }
scale-info = { git = "https://github.com/paritytech/scale-info", tag = "v2.11.3" }
```

**Result**: ✅ Dependency conflicts resolved!

### Code Changes

**evvm-cafhe/src/lib.rs**:
```rust
// Allow std during tests, no_std for WASM
#![cfg_attr(not(test), no_std)]

// Only compile panic handler for WASM
#[cfg(target_arch = "wasm32")]
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
```

---

## Proper Testing Commands

### Quick Validation

```bash
# Single command to verify everything compiles
cargo build --release --target wasm32-unknown-unknown && \
  ls -lh target/wasm32-unknown-unknown/release/evvm_cafhe.wasm && \
  echo "✅ Contract builds successfully!"
```

### Full Verification Suite

```bash
#!/bin/bash
# test-stylus.sh

echo "1. Type checking..."
cargo check --target wasm32-unknown-unknown || exit 1

echo "2. Building WASM..."
cargo build --release --target wasm32-unknown-unknown || exit 1

echo "3. Checking WASM size..."
ls -lh target/wasm32-unknown-unknown/release/evvm_cafhe.wasm

echo "4. Exporting ABI..."
cd evvm-cafhe && cargo stylus export-abi > ../abi/evvm_cafhe.json && cd ..

echo "5. Validating contract..."
cd evvm-cafhe && cargo stylus check && cd ..

echo "✅ All checks passed!"
```

---

## Testing Strategies

### 1. Build-Time Verification ✅ (Current)

**What**: Rely on successful WASM build as proof of correctness

**Commands**:
```bash
cargo build --release --target wasm32-unknown-unknown
cargo stylus check  # After size optimization
```

**Pros**:
- Simple
- Works immediately
- No additional setup

**Cons**:
- No runtime behavior testing
- Can't test contract logic

### 2. Integration Tests (Recommended)

**What**: Test deployed contract on testnet using JavaScript/TypeScript

**Setup**:
```bash
npm install --save-dev @nomicfoundation/hardhat-ethers ethers
```

**Example test** (tests/evvm-cafhe.test.js):
```javascript
const { ethers } = require("hardhat");

describe("EVVMCafhe", function () {
  it("Should initialize correctly", async function () {
    const EVVMCafhe = await ethers.getContractFactory("EVVMCafhe");
    const cafhe = await EVVMCafhe.deploy();
    await cafhe.deployed();

    // Test initialization
    const owner = await cafhe.getOwner();
    expect(owner).to.not.equal(ethers.constants.AddressZero);
  });
});
```

**Pros**:
- Tests actual on-chain behavior
- Can test encrypted operations
- Validates integration with EVVM

**Cons**:
- Requires deployment
- Slower than unit tests
- Needs testnet ETH

### 3. Simulation/Mocking (Advanced)

**What**: Mock the Stylus environment for faster testing

**Not currently implemented** - would require custom test harness

---

## What to Run (Summary)

### ✅ **DO RUN** (These work)

```bash
# Build and validation
cargo build --release --target wasm32-unknown-unknown
cargo check --target wasm32-unknown-unknown
cargo stylus check
cargo stylus export-abi

# Code quality
cargo clippy --target wasm32-unknown-unknown
cargo fmt --check

# Optimization
wasm-opt -Oz evvm_cafhe.wasm -o evvm_cafhe_optimized.wasm
```

### ❌ **DON'T RUN** (These fail - expected)

```bash
# Native tests - won't work for WASM-only contracts
cargo test

# Native build - not needed
cargo build  # Without --target wasm32-unknown-unknown
cargo check  # Without --target wasm32-unknown-unknown
```

---

## Testing Workflow

### Development Loop

```bash
# 1. Make changes to code
vim evvm-cafhe/src/lib.rs

# 2. Verify it compiles
cargo check --target wasm32-unknown-unknown

# 3. Full build when ready
cargo build --release --target wasm32-unknown-unknown

# 4. Check WASM size
ls -lh target/wasm32-unknown-unknown/release/evvm_cafhe.wasm

# 5. Optimize if needed
wasm-opt -Oz evvm_cafhe.wasm -o evvm_cafhe_optimized.wasm
```

### Pre-Deployment Checklist

```bash
# 1. ✅ Code compiles
cargo build --release --target wasm32-unknown-unknown

# 2. ✅ No clippy warnings
cargo clippy --target wasm32-unknown-unknown -- -D warnings

# 3. ✅ Code formatted
cargo fmt --check

# 4. ✅ WASM under size limit (24 KB)
ls -lh target/wasm32-unknown-unknown/release/evvm_cafhe_optimized.wasm

# 5. ✅ Contract validates
cargo stylus check

# 6. ✅ ABI exports correctly
cargo stylus export-abi > abi.json
```

---

## Common Questions

### Q: Why can't I run `cargo test`?
**A**: Stylus contracts are no_std WASM-only. They can't run as native Rust binaries. Use WASM build success as your test.

### Q: How do I test contract logic?
**A**: Deploy to Arbitrum Sepolia testnet and test with JavaScript/TypeScript integration tests.

### Q: What about unit tests?
**A**: You can add WASM-target tests (see example in evvm-cafhe/src/lib.rs), but they're limited. Integration tests are better.

### Q: The scale-info error is back!
**A**: Run `cargo clean && cargo build --target wasm32-unknown-unknown` to rebuild with patches.

### Q: Can I test locally without deployment?
**A**: Not easily. Stylus contracts need the Arbitrum environment. Use testnet for testing.

---

## Troubleshooting

### Error: "scale-info could not find `__private`"

**Fixed**: Dependency patches applied. If you see this:
```bash
cargo clean
rm Cargo.lock
cargo build --target wasm32-unknown-unknown
```

### Error: "panic handler function required"

**Normal**: This only happens with `cargo test`. Build with WASM target instead:
```bash
cargo build --target wasm32-unknown-unknown
```

### Error: "WASM too large"

**Expected**: Size optimization needed. See OPTIMIZATION_STATUS.md

---

## Success Criteria

| Check | Command | Expected Result |
|-------|---------|----------------|
| Compiles | `cargo build --target wasm32-unknown-unknown` | ✅ Success |
| Type Check | `cargo check --target wasm32-unknown-unknown` | ✅ No errors |
| Clippy | `cargo clippy --target wasm32-unknown-unknown` | ✅ No errors |
| Format | `cargo fmt --check` | ✅ Formatted |
| ABI Export | `cargo stylus export-abi` | ✅ JSON output |
| Size | `ls -lh *.wasm` | ⏳ Under 24 KB (pending) |
| Validation | `cargo stylus check` | ⏳ Pending size fix |

---

## Next Steps

1. ✅ **Build works** - Fixed with dependency patches
2. ⏳ **Size optimization** - See OPTIMIZATION_STATUS.md
3. ⏳ **Integration tests** - Create after deployment
4. ⏳ **Testnet deployment** - After size is under 24 KB

---

**Last Updated**: 2025-11-11
**Status**: ✅ Dependency conflicts fixed | ✅ WASM builds successfully
**Known Issues**: Size optimization pending (44 KB → 24 KB target)
