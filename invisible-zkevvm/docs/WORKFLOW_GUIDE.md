# Stylus FHEVM Project - Workflow Guide

Complete guide to working with the Stylus FHEVM contracts project, including all commands and workflows.

**Last Updated**: 2025-11-11

---

## Table of Contents

1. [Project Setup](#project-setup)
2. [Development Workflow](#development-workflow)
3. [Building & Compilation](#building--compilation)
4. [Testing Workflow](#testing-workflow)
5. [Deployment Workflow](#deployment-workflow)
6. [Git Workflow](#git-workflow)
7. [Common Tasks](#common-tasks)
8. [Troubleshooting](#troubleshooting)
9. [Quick Reference](#quick-reference)

---

## Project Setup

### Initial Environment Setup

```bash
# Navigate to project
cd invisible-zkevvm/stylus-contracts

# Check Rust version
rustc --version
# Should be: rustc 1.93.0-nightly (or as specified in rust-toolchain.toml)

# Verify cargo-stylus is installed
cargo stylus --version
# If not installed:
cargo install --force cargo-stylus

# Add WASM target
rustup target add wasm32-unknown-unknown

# Verify Foundry is installed (for testing)
forge --version
cast --version
# If not installed:
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Project Structure Navigation

```bash
# View project structure
tree -L 3 -I target

# Quick overview of files
ls -lh *.md *.toml
ls -lh fhe-stylus/src/
ls -lh evvm-cafhe/src/

# Read project context (auto-loaded by Claude Code)
cat CLAUDE.md

# Check current status
cat STATUS.md | head -50
```

### Reading Documentation

```bash
# Start here - project overview
cat README.md | less

# Understand current blockers
cat KNOWN_ISSUES.md

# View deployment plan
cat DEPLOYMENT_PLAN.md | less

# Check test specifications
cat TEST_SPEC.md | less

# See all deliverables
cat DELIVERABLES.md | less

# Quick summary
cat SUMMARY.md
```

---

## Development Workflow

### Daily Development Commands

```bash
# 1. Start of day - check status
git status
git log --oneline -5

# 2. Read Claude Code context
cat CLAUDE.md

# 3. Check for build issues
cargo check
# Expected: Fails with ruint 1.17.0 error (see KNOWN_ISSUES.md)

# 4. Make code changes to Rust files
# Edit files in fhe-stylus/src/ or evvm-cafhe/src/

# 5. Format code
cargo fmt

# 6. Run linter
cargo clippy --all-targets --all-features
```

### Working on fhe-stylus Library

```bash
# Navigate to library
cd fhe-stylus

# Check library specifically
cargo check

# Format library code
cargo fmt

# Run clippy on library
cargo clippy

# View library structure
ls -lh src/
# types.rs       - Encrypted types
# interfaces.rs  - FHEVM precompile interfaces
# config.rs      - Network configurations
# signature.rs   - EIP-191 signature verification
# fhe.rs         - FHE operations documentation
# lib.rs         - Public exports

# Return to workspace root
cd ..
```

### Working on evvm-cafhe Contract

```bash
# Navigate to contract
cd evvm-cafhe

# Check contract
cargo check

# View contract code
cat src/lib.rs | less

# Check contract size (when compilation works)
# cargo stylus check

# Export ABI (when compilation works)
# cargo stylus export-abi

# Return to workspace root
cd ..
```

### Code Style & Formatting

```bash
# Format all code in workspace
cargo fmt

# Check formatting without making changes
cargo fmt -- --check

# Run clippy for all packages
cargo clippy --all-targets --all-features

# Fix clippy warnings automatically (careful!)
cargo clippy --fix

# Check for unused dependencies
cargo +nightly udeps
```

---

## Building & Compilation

### Standard Build Commands

```bash
# Type check only (fast)
cargo check

# Build debug version
cargo build

# Build release version
cargo build --release

# Build for WASM target (currently blocked)
cargo build --release --target wasm32-unknown-unknown

# Clean build artifacts
cargo clean

# Clean and rebuild
cargo clean && cargo build
```

### Stylus-Specific Build Commands

**Note**: These currently fail due to ruint 1.17.0 issue. See KNOWN_ISSUES.md.

```bash
# Navigate to contract
cd evvm-cafhe

# Check Stylus compatibility
cargo stylus check
# This validates:
# - Contract compiles to WASM
# - WASM size is under 24KB limit
# - Contract is valid for Stylus

# Check with verbose output
cargo stylus check --verbose

# Export contract ABI
cargo stylus export-abi

# Save ABI to file
cargo stylus export-abi > abi.json

# View exported ABI
cargo stylus export-abi | jq .

# Return to workspace root
cd ..
```

### Handling Build Errors

```bash
# If you see ruint 1.17.0 error:
# 1. This is expected - see KNOWN_ISSUES.md
cat ../KNOWN_ISSUES.md

# 2. Check if there's an update to stylus-sdk
cargo search stylus-sdk --limit 1

# 3. Monitor upstream issues
# - https://github.com/recmo/uint/issues
# - https://github.com/OffchainLabs/stylus-sdk-rs/issues

# 4. Try updating dependencies (may not fix issue)
cargo update

# 5. Verify Rust toolchain
rustc --version
rustup show
```

---

## Testing Workflow

### Unit Tests (Currently Blocked)

```bash
# Run all tests in workspace
cargo test

# Run tests for specific package
cargo test -p fhe-stylus
cargo test -p evvm-cafhe

# Run specific test
cargo test test_euint64_operations

# Run tests with output
cargo test -- --nocapture

# Run tests with backtrace
RUST_BACKTRACE=1 cargo test

# Run tests in release mode
cargo test --release
```

### Test Specifications

```bash
# View all test specifications
cat TEST_SPEC.md | less

# Tests are documented but cannot execute until compilation works
# See TEST_SPEC.md for:
# - Unit test cases for encrypted types
# - Signature verification tests
# - Configuration tests
# - Integration test scenarios
```

### Integration Testing (When Unblocked)

```bash
# Run integration test script
chmod +x tests/integration_test.sh
./tests/integration_test.sh

# The script would:
# 1. Compile all packages
# 2. Run cargo stylus check
# 3. Validate WASM size
# 4. Export and validate ABI
# 5. Run contract-specific tests
```

---

## Deployment Workflow

### Environment Setup

```bash
# Create .env file
cat > .env << 'EOF'
# Private key (NO 0x prefix)
PRIVATE_KEY=your_private_key_here

# RPC endpoint
RPC_URL=https://sepolia-rollup.arbitrum.io/rpc

# Deployed EVVMCore contract address
EVVM_CORE_ADDRESS=0x0000000000000000000000000000000000000000

# Contract owner address
OWNER_ADDRESS=0x0000000000000000000000000000000000000000
EOF

# Load environment variables
source .env

# Verify environment
echo "RPC: $RPC_URL"
echo "Owner: $OWNER_ADDRESS"
```

### Testnet Deployment (When Unblocked)

```bash
# 1. Navigate to contract
cd evvm-cafhe

# 2. Deploy to Arbitrum Sepolia
cargo stylus deploy \
  --private-key $PRIVATE_KEY \
  --endpoint https://sepolia-rollup.arbitrum.io/rpc

# Expected output:
# Deploying contract...
# Contract deployed at: 0x...
# Transaction hash: 0x...

# 3. Save the contract address
CONTRACT_ADDRESS="0x..."  # Replace with deployed address

# 4. Initialize the contract
cast send $CONTRACT_ADDRESS \
  "initialize(address,address)" \
  $EVVM_CORE_ADDRESS \
  $OWNER_ADDRESS \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
  --private-key $PRIVATE_KEY

# 5. Verify initialization
cast call $CONTRACT_ADDRESS \
  "getOwner()" \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc

# Should return your OWNER_ADDRESS

# 6. Verify on explorer
echo "View on explorer:"
echo "https://sepolia.arbiscan.io/address/$CONTRACT_ADDRESS"

# Return to workspace root
cd ..
```

### Post-Deployment Verification

```bash
# Check contract owner
cast call $CONTRACT_ADDRESS "getOwner()" --rpc-url $RPC_URL

# Check EVVM Core address
cast call $CONTRACT_ADDRESS "getEvvmAddress()" --rpc-url $RPC_URL

# Check if nonce is used (should be false)
cast call $CONTRACT_ADDRESS \
  "isThisNonceUsed(address,uint256)" \
  $OWNER_ADDRESS \
  1 \
  --rpc-url $RPC_URL

# Get ETH address constant
cast call $CONTRACT_ADDRESS "getEtherAddress()" --rpc-url $RPC_URL
# Should return: 0x0000000000000000000000000000000000000000

# Get principal token address constant
cast call $CONTRACT_ADDRESS "getPrincipalTokenAddress()" --rpc-url $RPC_URL
# Should return: 0x0000000000000000000000000000000000000001
```

### Deployment Checklist

```bash
# Follow the complete deployment plan
cat DEPLOYMENT_PLAN.md | less

# Key steps:
# 1. Prerequisites (tools, testnet ETH)
# 2. Environment setup (.env file)
# 3. Contract compilation and validation
# 4. Deployment to testnet
# 5. Contract initialization
# 6. Post-deployment verification
# 7. Documentation update
```

---

## Git Workflow

### Daily Git Operations

```bash
# Check current branch
git branch --show-current

# Check status
git status

# View recent commits
git log --oneline --graph -10

# See what changed
git diff

# Stage changes
git add <file>
git add .

# Commit with conventional commit format
git commit -m "feat(component): description"
# Types: feat, fix, docs, test, refactor, chore

# Push to remote
git push origin feat/stylus-port-fix
```

### Branch Management

```bash
# List all branches
git branch -a

# Create new feature branch
git checkout -b feat/new-feature

# Switch branches
git checkout main
git checkout feat/stylus-port-fix

# Pull latest changes
git pull origin main

# Rebase feature branch on main
git checkout feat/stylus-port-fix
git rebase main
```

### Viewing Commit History

```bash
# View all commits for this feature
git log 65ba946..HEAD --oneline

# View detailed commit history
git log --oneline --graph --decorate --all

# View changes in a commit
git show <commit-hash>

# View file changes statistics
git diff --stat 65ba946..HEAD

# View what changed in specific file
git log -p -- fhe-stylus/src/types.rs
```

### Creating Pull Request

```bash
# 1. Ensure all changes are committed
git status

# 2. Push branch to remote
git push origin feat/stylus-port-fix

# 3. Create PR using GitHub CLI
gh pr create \
  --title "feat: Port EVVMCafhe contract to Arbitrum Stylus" \
  --body "$(cat <<'EOF'
## Summary
Complete port of EVVMCafhe Solidity contract to Arbitrum Stylus using Rust.

## Changes
- ✅ fhe-stylus middleware library (6 modules, 608 LOC)
- ✅ evvm-cafhe contract implementation (387 LOC)
- ✅ Comprehensive documentation (8 files, 2,557 LOC)
- ✅ Test specifications ready to execute
- ⚠️ Compilation blocked by ruint 1.17.0 (see KNOWN_ISSUES.md)

## Testing
- Unit tests specified in TEST_SPEC.md
- Integration tests documented
- Cannot execute until upstream issue resolved

## Documentation
- README.md - Complete project guide
- DEPLOYMENT_PLAN.md - Step-by-step deployment
- STATUS.md - Current status and architecture
- KNOWN_ISSUES.md - Dependency blocker details
- CLAUDE.md - Project context for Claude Code

## Related Issues
- Blocks: #<issue-number>
- Depends on: upstream ruint fix

🤖 Generated with Claude Code
EOF
)" \
  --base main

# 4. Or create PR via web interface
echo "Create PR at:"
echo "https://github.com/<org>/<repo>/compare/main...feat/stylus-port-fix"
```

---

## Common Tasks

### Adding a New FHE Operation

```bash
# 1. Edit interfaces.rs to add new interface method
vim fhe-stylus/src/interfaces.rs

# 2. Add documentation for the operation
vim fhe-stylus/src/fhe.rs

# 3. Format and check
cargo fmt
cargo check -p fhe-stylus

# 4. Commit
git add fhe-stylus/src/interfaces.rs fhe-stylus/src/fhe.rs
git commit -m "feat(fhe-stylus): add new FHE operation support"
```

### Updating Network Configuration

```bash
# 1. Edit config.rs with new addresses
vim fhe-stylus/src/config.rs

# 2. Add new network configuration
# Example: Add mainnet config

# 3. Update documentation
vim README.md  # Update network section
vim CLAUDE.md  # Update network configuration section

# 4. Commit changes
git add fhe-stylus/src/config.rs README.md CLAUDE.md
git commit -m "feat(fhe-stylus): add mainnet configuration"
```

### Adding a New Contract Function

```bash
# 1. Edit contract implementation
vim evvm-cafhe/src/lib.rs

# 2. Add the function in the #[public] impl block

# 3. Update documentation
vim README.md  # Update function table
vim CLAUDE.md  # Update if it affects conventions

# 4. Format and check
cargo fmt
cargo check -p evvm-cafhe

# 5. Commit
git add evvm-cafhe/src/lib.rs README.md
git commit -m "feat(evvm-cafhe): add new function for..."
```

### Updating Documentation

```bash
# Update main README
vim README.md

# Update project status
vim STATUS.md

# Update deployment plan
vim DEPLOYMENT_PLAN.md

# Update test specs
vim TEST_SPEC.md

# Update Claude Code context
vim CLAUDE.md

# Format markdown (if you have a formatter)
npx prettier --write "*.md"

# Commit documentation updates
git add *.md
git commit -m "docs: update documentation for..."
```

### Checking Dependencies

```bash
# List all dependencies
cargo tree

# List dependencies for specific package
cargo tree -p fhe-stylus
cargo tree -p evvm-cafhe

# Check for outdated dependencies
cargo outdated

# Update dependencies
cargo update

# Update specific dependency
cargo update -p stylus-sdk

# Audit dependencies for security issues
cargo audit
```

---

## Troubleshooting

### Compilation Errors

```bash
# Problem: ruint 1.17.0 const evaluation error
# Solution: This is expected, see KNOWN_ISSUES.md
cat KNOWN_ISSUES.md

# Problem: Can't find stylus-sdk
# Solution: Ensure it's in workspace dependencies
cat Cargo.toml | grep stylus-sdk

# Problem: WASM target missing
# Solution: Add WASM target
rustup target add wasm32-unknown-unknown

# Problem: Wrong Rust version
# Solution: Use nightly toolchain
rustup override set nightly
rustup show
```

### Git Issues

```bash
# Problem: Merge conflicts
# Solution: Resolve conflicts
git status  # See conflicted files
# Edit files to resolve conflicts
git add <resolved-files>
git commit

# Problem: Need to undo last commit
# Solution: Use git reset
git reset --soft HEAD~1  # Keep changes
git reset --hard HEAD~1  # Discard changes (careful!)

# Problem: Accidentally committed to main
# Solution: Create branch from current state
git branch feat/my-changes
git reset --hard origin/main
git checkout feat/my-changes
```

### Environment Issues

```bash
# Problem: cargo-stylus not found
# Solution: Install it
cargo install --force cargo-stylus

# Problem: Can't connect to RPC
# Solution: Check RPC endpoint
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  https://sepolia-rollup.arbitrum.io/rpc

# Should return: {"jsonrpc":"2.0","id":1,"result":"0x66eee"}  # 421614 in hex

# Problem: Private key not working
# Solution: Ensure no 0x prefix
echo $PRIVATE_KEY | head -c 2  # Should NOT be "0x"
```

### Documentation Issues

```bash
# Problem: Can't find specific info
# Solution: Use grep across docs
grep -r "signature verification" *.md
grep -r "nonce tracking" *.md

# Problem: Documentation out of date
# Solution: Check git history
git log --oneline -- README.md

# Problem: Want to see original Solidity
# Solution: Check reference in docs
ls -lh ../contracts/evvm/cafhe/EVVMCafhe.sol
```

---

## Quick Reference

### Essential Commands

```bash
# Check code
cargo check

# Format code
cargo fmt

# Run tests (when unblocked)
cargo test

# Build for WASM (when unblocked)
cargo build --release --target wasm32-unknown-unknown

# Validate contract (when unblocked)
cd evvm-cafhe && cargo stylus check

# Deploy contract (when unblocked)
cargo stylus deploy --private-key $PRIVATE_KEY --endpoint $RPC_URL
```

### File Locations Quick Reference

```bash
# Core library code
fhe-stylus/src/types.rs        # Encrypted types
fhe-stylus/src/interfaces.rs   # FHEVM precompiles
fhe-stylus/src/signature.rs    # EIP-191 verification
fhe-stylus/src/config.rs       # Network configs

# Contract code
evvm-cafhe/src/lib.rs          # Main contract

# Documentation
README.md                      # Project overview
CLAUDE.md                      # Project context (auto-loaded)
STATUS.md                      # Current status
KNOWN_ISSUES.md               # Blockers and issues
DEPLOYMENT_PLAN.md            # How to deploy
TEST_SPEC.md                  # Test specifications
DELIVERABLES.md               # Complete inventory
SUMMARY.md                    # Quick summary

# Configuration
Cargo.toml                    # Workspace config
rust-toolchain.toml           # Rust toolchain
.env                          # Environment variables (create this)
```

### Network Information

```bash
# Arbitrum Sepolia Testnet
Chain ID: 421614
RPC: https://sepolia-rollup.arbitrum.io/rpc
Explorer: https://sepolia.arbiscan.io/

# Known FHEVM Contract Addresses (Sepolia)
FHEVM Precompile:  0x848B0066793BcC60346Da1F49049357399B8D595
Input Verifier:    0xbc91f3daD1A5F19F8390c400196e58073B6a0BC4
ACL:               0x687820221192C5B662b25367F70076A37bc79b6c
```

### Useful Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# Navigate to project
alias cdstylus='cd ~/path/to/invisible-zkevvm/stylus-contracts'

# Quick checks
alias stycheck='cargo check'
alias styfmt='cargo fmt'
alias stytest='cargo test'

# Quick docs
alias stydocs='cat CLAUDE.md'
alias stystatus='cat STATUS.md'
alias styissues='cat KNOWN_ISSUES.md'

# Git shortcuts
alias gst='git status'
alias glog='git log --oneline --graph -10'
alias gdiff='git diff'
```

### Common Error Messages

```bash
# "BYTES must be equal to Self::BYTES"
# → This is the known ruint 1.17.0 issue
# → See KNOWN_ISSUES.md
cat KNOWN_ISSUES.md

# "profiles for the non root package will be ignored"
# → This is a warning, not an error
# → Profiles in workspace Cargo.toml take precedence

# "can't find crate for `core`"
# → Add WASM target
rustup target add wasm32-unknown-unknown

# "contract size too large"
# → Check WASM size optimization in Cargo.toml
# → See DEPLOYMENT_PLAN.md troubleshooting section
```

---

## Workflow Diagrams

### Development Flow

```
┌─────────────────┐
│ Read CLAUDE.md  │
│  & STATUS.md    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Make Changes    │
│ to Rust Code    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ cargo fmt       │
│ cargo check     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ cargo clippy    │
│ Fix warnings    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ git add & commit│
│ with convention │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update docs if  │
│   needed        │
└─────────────────┘
```

### Deployment Flow (When Unblocked)

```
┌─────────────────┐
│ cargo build     │
│ --target wasm32 │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ cargo stylus    │
│     check       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ cargo stylus    │
│    deploy       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ cast send       │
│  initialize     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Verify on       │
│  explorer       │
└─────────────────┘
```

---

## Additional Resources

### Documentation Links

- **README.md** - Complete project documentation
- **DEPLOYMENT_PLAN.md** - Detailed deployment guide
- **TEST_SPEC.md** - All test specifications
- **STATUS.md** - Architecture and status
- **KNOWN_ISSUES.md** - Current blockers

### External Resources

- **Arbitrum Stylus Docs**: https://docs.arbitrum.io/stylus
- **Cargo Stylus**: https://github.com/OffchainLabs/cargo-stylus
- **Zama FHEVM**: https://docs.zama.ai/fhevm
- **Rust Book**: https://doc.rust-lang.org/book/
- **Arbitrum Sepolia**: https://sepolia.arbiscan.io/

### Getting Help

```bash
# Project-specific help
cat CLAUDE.md          # Quick context
cat README.md | less   # Full guide
cat KNOWN_ISSUES.md    # Current blockers

# Tool help
cargo stylus --help
cargo --help
cast --help

# Community resources
# - Arbitrum Discord: discord.gg/arbitrum
# - Stylus documentation
# - GitHub discussions
```

---

**Last Updated**: 2025-11-11
**Project Status**: Feature Complete (Compilation Blocked)
**For Latest Status**: See STATUS.md
