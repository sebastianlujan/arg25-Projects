# ARG25 Project Submission Template

Welcome to Invisible Garden- ARG25.

Each participant or team will maintain this README throughout the program.
You'll update your progress weekly **in the same PR**, so mentors and reviewers can track your journey end-to-end.

## Project Title

**zkEvvm - Stylus Smart Contract Project**

## Team

- Team/Individual Name: Sebastian Lujan Artur Vargas
- GitHub Handles: @sebastianlujan @ArturVargas
- Devfolio Handles: sebas_eth 0xVato

## Project Description

_What are you building and why does it matter? Explain the core problem and your proposed solution._

This project implements a complete migration of the **EVVM (Ethereum Virtual Virtual Machine)** protocol to a hybrid architecture that combines **Zama FHEVM** (Fully Homomorphic Encryption) with **Arbitrum Stylus**.

**The Problem:** Public blockchains expose all data transparently, which limits use cases that require privacy (voting, staking, treasury management, etc.). EVVM enables creating virtual blockchains, but needs privacy capabilities for institutional use cases.

**Our Solution:** We migrated EVVM's core contracts (EVVMCore, TreasuryVault, StakingManager, VotingFHE) to use **encrypted data** through Zama FHEVM, enabling operations on encrypted data without exposing sensitive information. Additionally, we created interfaces in **Rust/Stylus** for high-performance interaction with these contracts, leveraging Stylus performance advantages while maintaining ABI compatibility with Solidity.

**Main Components:**

- **EVVMCore with FHE**: Main contract with encrypted balances, rewards, and metadata
- **TreasuryVault with FHE**: Fund management with encrypted amounts
- **StakingManager with FHE**: Staking system with encrypted data
- **VotingFHE**: Voting system with encrypted results
- **Stylus Interfaces**: Rust contracts for optimized interaction
- **EVVM-CAFHE**: Integration example demonstrating Stylus ↔ Solidity-FHE

## Tech Stack

_List all the technologies, frameworks, and tools you are using._

### Smart Contracts & Blockchain

- **Solidity** (^0.8.24) - Main language for FHE contracts
- **Rust** - Language for high-performance Stylus contracts
- **Arbitrum Stylus SDK** - SDK for developing contracts in Rust/WebAssembly
- **cargo-stylus** - CLI tool to compile, verify and deploy Stylus contracts
- **WASM** - Compilation target for Stylus

### Fully Homomorphic Encryption (FHE)

- **Zama FHEVM** - Homomorphic encryption framework for blockchain
- **@fhevm/solidity** (^0.9.0) - Solidity library for FHE operations
- **@fhevm/hardhat-plugin** (^0.3.0-0) - Hardhat plugin for FHE development
- **@zama-fhe/relayer-sdk** (^0.3.0-5) - SDK for FHE operations relayer

### Development Tools

- **Foundry** - Development and testing framework for Solidity
- **Hardhat** - Ethereum development environment
- **TypeScript** - For tests and scripts
- **Node.js** - Runtime for development tools

### Testing & Deployment

- **Forge** - Foundry testing framework
- **Ethers.js** - Library for blockchain interaction
- **Alloy Primitives** (v0.8.20) - Ethereum primitive types for Rust

### Networks

- **Arbitrum Sepolia** - Testnet for deployment and testing

## Objectives

_What are the specific outcomes you aim to achieve by the end of ARG25?_

- Migrate EVVM core contracts (EVVMCore, TreasuryVault, StakingManager, VotingFHE) to Zama FHEVM with encrypted data
- Implement FHE operations (addition, multiplication, comparisons) on encrypted data
- Create Rust/Stylus interfaces for optimized interaction with Solidity-FHE contracts
- Deploy contracts to Arbitrum Sepolia testnet
- Develop unit tests to validate FHE functionality
- Create integration examples (EVVM-CAFHE) demonstrating Stylus ↔ Solidity-FHE
- Document the migration process and hybrid architecture
- Explore performance advantages of Stylus combined with FHE privacy

## Weekly Progress

### Week 1 (ends Oct 31)

**Goals:**

- Define hybrid architecture EVVM + FHE + Stylus
- Analyze components to migrate
- Establish technology stack
- Receive feedback from mentors

**Progress Summary:**

We defined the complete project architecture: migration of EVVM to a hybrid architecture using Zama FHEVM for privacy and Arbitrum Stylus for performance. We analyzed the main components to migrate (EVVMCore, TreasuryVault, StakingManager, VotingFHE) and established the technology stack. We received valuable feedback from mentors on the approach and system design.

### Week 2 (ends Nov 7)

**Goals:**

- Create learning examples with Zama FHE
- Migrate EVVMCore to FHE
- Migrate Treasury and Staking contracts to FHE
- Develop unit tests

**Progress Summary:**

We created learning examples (Counter and Voting) using Zama FHE to understand the workflow with encrypted data. We completed the first version of **EVVMCore migrated to Zama FHE**, with encrypted balances, rewards, and metadata using `euint64`. We migrated the **TreasuryVault** and **StakingManager** contracts to FHE, implementing encrypted operations for deposits, withdrawals, staking, and rewards. We created **unit tests** to validate the functionality of the migrated contracts.


### 🗓️ Week 3 (ends Nov 14)

**Goals:**

- Create Stylus interfaces for interaction with Solidity-FHE contracts
- Develop EVVM-CAFHE integration example
- Document architecture and workflows

**Progress Summary:**

We created **Stylus (Rust) interfaces** for optimized interaction with EVVM Solidity-FHE contracts, enabling high-performance calls from Rust contracts. We developed the **EVVM-CAFHE** example that demonstrates the complete interaction between Stylus and EVVM with FHE, showing the encrypted data flow between both layers. We documented the hybrid architecture, workflows, and implementation guides in the `docs/` folder.

## Final Wrap-Up

_After Week 3, summarize your final state: deliverables, repo links, and outcomes._

- **Main Repository Link:** [GitHub Repository](https://github.com/sebastianlujan/arg25-Projects/tree/main/invisible-zkevvm)

- **Demo / Deployment Link (if any):**

  - **EVVMCore Contract (Arbitrum Sepolia):** `0xd2c09694f325B821060560A13d538b5B51befC79`
  - **Explorer:** [Arbiscan](https://sepolia.arbiscan.io/address/0xd2c09694f325B821060560A13d538b5B51befC79)
  - **Network:** Arbitrum Sepolia (Chain ID: 421614)

- **Slides / Presentation (if any):**
  - Technical documentation available in `docs/`
  - Implementation guides: `docs/FHE_SETUP.md`, `docs/TREASURY_GUIDE.md`, `docs/STAKING_ENCRYPTED_INPUTS.md`
  - Implementation plan: `docs/IMPLEMENTATION_PLAN.md`

**Completed Deliverables:**

- ✅ 4 main contracts migrated to FHE (EVVMCore, TreasuryVault, StakingManager, VotingFHE)
- ✅ Stylus interfaces for interaction with Solidity-FHE contracts
- ✅ EVVM-CAFHE integration example
- ✅ Unit test suite
- ✅ Deployment scripts for Foundry
- ✅ Complete technical documentation

## 🧾 Learnings

_What did you learn or improve during ARG25?_

### Fully Homomorphic Encryption (FHE)

- **Zama FHEVM**: We learned to use homomorphic encryption in blockchain, enabling operations on encrypted data without exposing sensitive information
- **Encrypted types**: We mastered the use of `euint64`, `ebool`, `externalEuint64` and their operations (FHE.add, FHE.mul, FHE.select)
- **Encryption/decryption flow**: We understood the complete cycle from frontend (fhevmjs) to on-chain operations
- **Limitations and workarounds**: We learned about current limitations (FHE.div not available) and how to design alternative solutions

### Hybrid Architecture

- **Stylus + Solidity**: We explored how to combine high-performance Rust contracts with Solidity contracts that use FHE
- **Cross-language interfaces**: We implemented interfaces that enable communication between Stylus and Solidity while maintaining ABI compatibility
- **Privacy design**: We learned to design systems where sensitive data remains encrypted at all times

### Development and Testing

- **Foundry + Hardhat**: We mastered the use of both frameworks for different aspects of the project
- **Testing with FHE**: We developed strategies to test contracts with encrypted data
- **Arbitrum deployment**: We learned the complete deployment flow on Arbitrum Sepolia with contract verification

### EVVM Protocol

- **Virtual Blockchains**: We understood how EVVM enables creating virtual blockchains on any chain
- **Protocol migration**: We learned to migrate complex protocols while maintaining functionality and adding new capabilities (privacy)

## Next Steps

_If you plan to continue development beyond ARG25, what's next?_

### Short Term

- Complete integration tests between Stylus and Solidity-FHE contracts
- Implement additional EVVMCore functions (`payMultiple`, `dispersePay`, `caPay`)
- Optimize FHE operations to reduce gas consumption
- Deploy Stylus contracts to testnet and validate complete interaction

### Medium Term

- Develop frontend/SDK for interaction with FHE contracts
- Implement fully encrypted era transition system
- Create complete API documentation for developers
- Conduct security audit of migrated contracts

### Long Term

- Explore integration with NameService for identity resolution
- Investigate advanced WASM optimizations for Stylus
- Evaluate mainnet migration after exhaustive testing
- Contribute to open source community with developed improvements

## Technical Documentation

For more technical details about the project, see the documentation in the `docs/` folder:

- **[FHE_SETUP.md](docs/FHE_SETUP.md)** - Complete Zama FHE setup guide
- **[TREASURY_GUIDE.md](docs/TREASURY_GUIDE.md)** - TreasuryVault usage guide with FHE
- **[STAKING_ENCRYPTED_INPUTS.md](docs/STAKING_ENCRYPTED_INPUTS.md)** - Encrypted inputs guide for Staking
- **[IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)** - Detailed implementation plan
- **[PROGRESS.md](docs/PROGRESS.md)** - Detailed progress report
- **[SPEC.md](docs/SPEC.md)** - Technical specifications of the project
- **[DEPLOYMENT_SUMMARY.md](DEPLOYMENT_SUMMARY.md)** - Deployment summary
- **[QUICK_DEPLOY.md](QUICK_DEPLOY.md)** - Quick deployment guide

## References

- **EVVM Documentation:** [evvm.org](https://www.evvm.org/)
- **Arbitrum Stylus Resources:** [awesome-stylus](https://github.com/OffchainLabs/awesome-stylus)
- **Zama FHEVM Documentation:** [docs.zama.ai](https://docs.zama.ai/fhevm)
- **Arbitrum Documentation:** [docs.arbitrum.io](https://docs.arbitrum.io/)

---

_This template is part of the [ARG25 Projects Repository](https://github.com/invisible-garden/arg25-projects)._
_Update this file weekly by committing and pushing to your fork, then raising a PR at the end of each week._
