# Legacy Solidity Contracts

⚠️ **DEPRECATED**: These contracts have been migrated to Stylus (Rust/WASM).

## EVVMCafhe.sol

**Status**: Deprecated
**Replacement**: `stylus-contracts/evvm-cafhe/src/lib.rs`
**Reason**: Migrated to Arbitrum Stylus for better performance and lower gas costs

This Solidity contract was the original implementation of the coffee shop example demonstrating FHE operations in the Invisible zkEVM. It has been completely rewritten in Rust for deployment as a Stylus contract, which provides:

- **10x gas savings** compared to EVM bytecode
- **Better performance** through WASM compilation
- **Safer code** with Rust's type system and memory safety
- **Easier FHE integration** with the fhe-stylus library

**DO NOT USE THESE CONTRACTS IN PRODUCTION.**

## Migration History

- **Original**: Solidity implementation with direct FHEVM calls
- **Current**: Rust/Stylus implementation with fhe-stylus middleware
- **Migration Date**: November 2025
- **Status**: Complete

## Related Files

- Stylus implementation: `../stylus-contracts/evvm-cafhe/src/lib.rs`
- FHE middleware library: `../stylus-contracts/fhe-stylus/`
- Documentation: `../stylus-contracts/docs/`

## Why Keep This?

This file is kept for historical reference and comparison purposes. It may be useful for:

- Understanding the migration from Solidity to Stylus
- Comparing gas costs between implementations
- Educational purposes
- Reference for future migrations

For all production use, refer to the Stylus implementation.
