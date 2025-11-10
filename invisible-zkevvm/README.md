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

This project is an implementation of a Counter smart contract in Rust using Arbitrum Stylus SDK. The contract allows:
- Store and query a number
- Set a specific number
- Increment the counter
- Perform mathematical operations (multiplication and addition)
- Accept payments in wei and add them to the counter

Stylus allows writing smart contracts in Rust and compiling them to WASM, offering better performance and access to Rust features while maintaining ABI compatibility with Solidity.

## Tech Stack
_List all the technologies, frameworks, and tools you are using._

- **Rust** - Main programming language
- **Arbitrum Stylus SDK** (v0.9.0) - SDK for developing contracts in Stylus
- **Alloy Primitives** (v0.8.20) - Ethereum primitive types
- **cargo-stylus** - CLI tool to compile, verify and deploy Stylus contracts
- **WASM** - Compilation target for Stylus
- **Ethers.rs** - To interact with the contract from Rust

## Objectives
_What are the specific outcomes you aim to achieve by the end of ARG25?_

- Implement and deploy a functional smart contract on Arbitrum Stylus
- Understand the complete Stylus development flow (compilation, verification, deployment)
- Explore the advantages of writing contracts in Rust vs Solidity
- Interact with the deployed contract using Ethereum tools
- Document the process and share knowledge with the community

## Weekly Progress

### Week 1 (ends Oct 31)
**Goals:**
- Set up Stylus development environment
- Implement the basic Counter contract
- Compile and verify the contract

**Progress Summary:**  
Project initialized with cargo-stylus. Counter contract implemented with basic functions (set_number, increment, add_number, mul_number). Code successfully compiled to WASM. Stylus compatibility verification completed.


### Week 2 (ends Nov 7)
**Goals:**  
- Deploy the contract to testnet
- Test the contract functions
- Create interaction examples

**Progress Summary:**  


### 🗓️ Week 3 (ends Nov 14)
**Goals:**  

**Progress Summary:**  



## Final Wrap-Up
_After Week 3, summarize your final state: deliverables, repo links, and outcomes._

- **Main Repository Link:** https://github.com/sebastianlujan/arg25-Projects/tree/main/invisible-zkevvm
- **Demo / Deployment Link (if any):**  
- **Slides / Presentation (if any):**



## 🧾 Learnings
_What did you learn or improve during ARG25?_

- Smart contract development in Rust using Stylus SDK
- Rust to WASM compilation for blockchain execution
- Deployment flow on Arbitrum Stylus testnet
- Integration of development tools for Stylus (cargo-stylus)



## Next Steps
_If you plan to continue development beyond ARG25, what's next?_

- Deploy the contract to testnet and perform exhaustive testing
- Implement more complex functions and explore advanced Stylus features
- Optimize WASM binary size
- Create a user interface to interact with the contract
- Explore more advanced use cases for Stylus


## Technical Documentation

For more details on how to use this project, see [assets/README-original.md](assets/README-original.md).


_This template is part of the [ARG25 Projects Repository](https://github.com/invisible-garden/arg25-projects)._  
_Update this file weekly by committing and pushing to your fork, then raising a PR at the end of each week._

