# ARG25 Project Submission Template

Welcome to Invisible Garden- ARG25.

Each participant or team will maintain this README throughout the program.  
You’ll update your progress weekly **in the same PR**, so mentors and reviewers can track your journey end-to-end.


##  Project Title
ZKEVVM


## Team
- Team/Individual Name: Sebastian Lujan Artur Vargas
- GitHub Handles: @sebastianlujan @ArturVargas
- Devfolio Handles: sebas_eth 0xVato

## Project Description
ZKEVVM , is an implementation or Integration of an ZKEVM using the infraless infrastructure of the EVVM project, one L1 running a virtual blockchain infrastructure with the corresponding ZKEVM
ZKEVVM = ZKEVM + EVVM

Our project aims to enhance the Ethereum Virtual Virtual Machine (EVVM) by integrating Zama's fully homomorphic encryption (FHE) stack to enable confidential computations. This will allow EVVM to process encrypted data without decryption, ensuring privacy and security for sensitive operations. As a future extension, we plan to incorporate Kakaroth's zkVM into a relayer component for zero-knowledge proofs, enabling verifiable and private transactions. 

The overall architecture separates components like coFHE private services (including staking, payments, and treasury), built on Arbitrum stylus for scalability and because is awesome tech.

## Tech Stack

* Rust mainly ( tokio, serde, stylus sdk )
* Kakaroth ZKVM
* Stylus
* Solidity

## Objectives

Short-term:
Achieve initial FHE integration with EVVM for basic confidential operations.

Medium-term: Add relayer functionality with Kakaroth zkVM for enhanced privacy and verifiability.

Long-term: Deploy a fully functional confidential EVVM system with support for staking, payments, and treasury management, integrated with validators and oracles.


## Weekly Progress

### Week 1 (ends Oct 31)
**Goals:**
- Understand the architecture of the project and plan the implementation.
- Achieve initial FHE integration with EVVM for basic confidential operations.

**Progress Summary:**
- Set up the project repository and initial environment.
- Researched Zama's FHE stack and EVVM documentation.
- Created a high-level architecture diagram outlining components: EVVM on 
    - Arbitrum, coFHE private services (Staking, Payments, Treasury)

- Began initial experiments with Zama's libraries for FHE setup.
- No implementation on Kakaroth yet, as focus was on foundational FHE work.
- Kakaroth relayer, 
- Align layer validator, and supporting elements like Fishers and Oracle ( missing yet ).

Challenges: Understanding EVVM's internals for seamless FHE integration.
Next steps: Implement basic Zama FHE examples within EVVM.


### Week 2 (ends Nov 7)
**Goals:**
Achieve initial FHE integration with EVVM for basic confidential operations.
Understand the integration with stylus and understand the integration with Align Layer for the verification layer.


**Progress Summary:**  
Focused on first implementations of Zama with EVVM.
Research on Kakaroth and Stylus integrations.

### 🗓️ Week 3 (ends Nov 14)
**Goals:**
Finish the happy path 

**Progress Summary:**  



## Final Wrap-Up
_After Week 3, summarize your final state: deliverables, repo links, and outcomes._

- **Main Repository Link:**  
- **Demo / Deployment Link (if any):**  
- **Slides / Presentation (if any):**



## 🧾 Learnings
_What did you learn or improve during ARG25?_

I don't knowif this is related to this project but i increased exponentially my understanding of commitments in zk and how FHE works, also i improved my knowledge in assembly for solidity and defi math.


## Next Steps
_If you plan to continue development beyond ARG25, what’s next?_



_This template is part of the [ARG25 Projects Repository](https://github.com/invisible-garden/arg25-projects)._  
_Update this file weekly by committing and pushing to your fork, then raising a PR at the end of each week._
