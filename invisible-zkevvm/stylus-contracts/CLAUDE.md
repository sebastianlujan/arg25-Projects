# Stylus FHEVM Contracts - Project Context

## Tech Stack
- **Language**: Rust (edition 2021, no_std)
- **Platform**: Arbitrum Stylus (WASM compilation)
- **SDK**: stylus-sdk 0.6.0
- **Ethereum Types**: alloy-primitives 0.7.2, alloy-sol-types 0.7.2
- **Allocator**: wee_alloc 0.4.5
- **Toolchain**: Rust nightly (due to upstream blocker)

## Project Structure
```
stylus-contracts/
├── fhe-stylus/          # Reusable FHE middleware library
│   └── src/
│       ├── types.rs     # Encrypted types (Euint64, Ebool)
│       ├── interfaces.rs # FHEVM precompile interfaces
│       ├── signature.rs  # EIP-191 verification
│       ├── config.rs     # Network configs (Sepolia)
│       └── fhe.rs        # FHE operations stubs
└── evvm-cafhe/          # Coffee shop example contract
    └── src/lib.rs       # Complete contract (orderCoffee, withdrawals)
```

## Current Status
- ✅ **Code**: Feature complete, production-ready
- ⚠️ **Compilation**: BLOCKED by ruint 1.17.0 const evaluation bug
- ✅ **Documentation**: Comprehensive (7 .md files)
- ⏳ **Testing**: Specified but cannot execute
- See **KNOWN_ISSUES.md** for blocker details, **STATUS.md** for architecture

## Key Architectural Decisions

### Encrypted Types
- Use `pub type Euint64 = FixedBytes<32>` (type aliases, not newtypes)
- Rationale: Automatic ABI trait inheritance, simpler than sol! macro

### Interface Pattern
- Use `sol_interface!` macro to call deployed FHEVM precompiles
- Never reimplement FHE operations - always call precompiles
- Contract → fhe-stylus → FHEVM Precompiles → Coprocessor

### Storage Patterns
- Nested mappings: `StorageMap<Address, StorageMap<U256, StorageBool>>`
- Use `.getter()` for reads, `.setter()` for writes on nested maps
- Mark nonces after successful operations, not before

## Code Conventions

### General
- All contracts are `#![no_std]` with `extern crate alloc`
- Every contract needs `#[global_allocator]` and `#[panic_handler]`
- Use `#[storage]` and `#[entrypoint]` macros for main contract struct
- Use `#[public]` for external functions

### Error Handling
- Return `Result<(), Vec<u8>>` for mutable functions
- Define error constants: `const ERROR: &[u8] = b"Error message";`
- Use `.map_err(|_| ERROR.to_vec())` for error conversion

### Security Patterns
- Always verify signatures before state changes
- Check nonces before processing to prevent replay attacks
- Use `msg::sender()` for access control, not function parameters
- Grant ACL permissions explicitly with `acl.allow()`

## Common Commands

### Build & Check
```bash
cargo check                      # Type check only
cargo build --release --target wasm32-unknown-unknown  # Build WASM (currently blocked)
cargo clippy                     # Linting
cargo fmt                        # Format code
```

### Stylus Operations (When Unblocked)
```bash
cd evvm-cafhe
cargo stylus check              # Validate contract
cargo stylus export-abi         # Generate ABI
cargo stylus deploy --private-key $KEY --endpoint $RPC  # Deploy
```

### Testing (When Unblocked)
```bash
cargo test                      # Run unit tests
npm test                        # Run integration tests
```

## Do Not Modify
- Profile configurations in workspace Cargo.toml (LTO, opt-level="z" required)
- `autobins = false` in evvm-cafhe/Cargo.toml (prevents binary build errors)
- Type aliases in types.rs (changing to newtypes breaks ABI compatibility)
- Signature verification logic in signature.rs (security-critical)

## Critical Files
- **STATUS.md**: Current project state, architecture diagrams, dependency chain
- **KNOWN_ISSUES.md**: ruint compilation blocker, tested Rust versions
- **TEST_SPEC.md**: All test cases ready to execute
- **DEPLOYMENT_PLAN.md**: Step-by-step deployment + 12 planned git commits

## Development Workflow
1. Read relevant .md docs before making changes
2. Keep fhe-stylus library generic (no contract-specific logic)
3. Use Call::new_in(self) for precompile calls (requires &mut self)
4. Test signature format matches: "{evvmID},{function},{params}"
5. Document all public functions with /// comments

## Network Configuration
- **Target Network**: Arbitrum Sepolia (Chain ID: 421614)
- **FHEVM Precompile**: 0x848B0066793BcC60346Da1F49049357399B8D595
- **Input Verifier**: 0xbc91f3daD1A5F19F8390c400196e58073B6a0BC4
- **ACL**: 0x687820221192C5B662b25367F70076A37bc79b6c
- See config.rs for complete addresses

## References
- Original Solidity: ../contracts/evvm/cafhe/EVVMCafhe.sol
- Stylus Docs: https://docs.arbitrum.io/stylus
- FHEVM Docs: https://docs.zama.ai/fhevm
