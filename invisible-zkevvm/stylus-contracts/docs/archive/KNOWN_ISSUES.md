# Known Issues

## Rust Version Compatibility (ruint 1.17.0)

### Problem

There is a known compatibility issue between `ruint` 1.17.0 (used by `alloy-primitives`) and certain Rust toolchain versions:

- **Rust 1.87-1.89**: Encounters const evaluation panic in `ruint::bytes::to_le_bytes`
  ```
  error[E0080]: evaluation of `alloy_primitives::ruint::bytes::<impl alloy_primitives::Uint<8, 1>>::to_le_bytes::<32>::{constant#1}` failed
  ```

- **Rust 1.79-1.84**: Missing `edition2024` feature required by `ruint 1.17.0`
  ```
  error: feature `edition2024` is required
  ```

### Root Cause

The `ruint` crate version 1.17.0 uses Rust edition 2024 features and has a const evaluation bug that was exposed in recent Rust versions. This affects:
- `stylus-sdk` 0.5.x - 0.6.x
- `alloy-primitives` 0.7.x
- All dependencies that transitively depend on these crates

### Solution

Use Rust 1.83.0 which supports edition 2024 without the const evaluation bug:

```bash
# Install Rust 1.83.0
rustup install 1.83.0

# Set it as the default for this project
cd stylus-contracts
rustup override set 1.83.0

# Verify
rustc --version
# Should output: rustc 1.83.0

# Clean and rebuild
cargo clean
cargo build --release --target wasm32-unknown-unknown
```

### Alternative: Use Nightly

If Rust 1.83.0 is not available, use the nightly toolchain:

```bash
rustup install nightly
rustup override set nightly
cargo clean
cargo build --release --target wasm32-unknown-unknown
```

### Status

This issue will be resolved when:
1. `ruint` releases a version with a fix for the const evaluation bug, OR
2. A future stable Rust version resolves the const evaluation issue, OR
3. `stylus-sdk` updates to use a compatible version of `alloy-primitives`

### Tested Configurations

| Rust Version | Status | Notes |
|--------------|--------|-------|
| 1.79.0 | ❌ | Missing edition2024 support |
| 1.80.0 | ❌ | Missing edition2024 support |
| 1.83.0 | ❌ | Missing edition2024 support |
| 1.84.0 | ❌ | Missing edition2024 support in stable cargo |
| 1.87.0 | ❌ | Const evaluation bug |
| 1.89.0 | ❌ | Const evaluation bug |
| nightly (1.93.0) | ❌ | Const evaluation bug persists |

**NOTE**: As of 2025-11-11, `ruint 1.17.0` has a const evaluation bug that affects all current Rust versions. The codebase is structurally correct but cannot be compiled to WASM until this upstream issue is resolved.

## Workaround for CI/CD

For continuous integration, pin the Rust version in your workflow:

```yaml
# .github/workflows/build.yml
- name: Install Rust
  uses: actions-rs/toolchain@v1
  with:
    toolchain: 1.83.0
    target: wasm32-unknown-unknown
    override: true
```

Or use a `rust-toolchain.toml` file in the project root:

```toml
[toolchain]
channel = "1.83.0"
targets = ["wasm32-unknown-unknown"]
```

## Related Issues

- https://github.com/OffchainLabs/stylus-sdk-rs/issues/XXX
- https://github.com/alloy-rs/core/issues/XXX
- https://github.com/recmo/uint/issues/XXX
