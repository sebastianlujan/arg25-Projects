# EVVM Migration MVP - Technical Specifications

## 1. Executive Summary

### 1.1 Objective
Migrate the EVVM.info project to a new hybrid architecture that combines:
- **Zama FHE (Fully Homomorphic Encryption)** for encrypted computation in Solidity
- **Arbitrum Stylus** for high-performance contracts in Rust/WASM
- **Standard Solidity** for contracts that don't require encryption

### 1.2 MVP Scope
This MVP focuses exclusively on the core functionalities of the system:
- ✅ **EVVM Core**: Main contract for the Virtual Blockchain
- ✅ **Staking**: Staking and rewards system
- ✅ **Treasury**: Protocol fund management
- ❌ **Other features**: Will be implemented as mocks or excluded from MVP

---

## 2. System Architecture

### 2.1 Technology Stack

```
┌─────────────────────────────────────────────────────────┐
│                   Frontend (Out of Scope)                │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                    Smart Contracts Layer                 │
│                                                           │
│  ┌───────────────────┐  ┌───────────────────┐          │
│  │   Solidity FHE    │  │  Stylus (Rust)    │          │
│  │   (Zama FHEVM)    │  │   Contracts       │          │
│  │                   │  │                   │          │
│  │ • EVVM Core       │  │ • High-perf       │          │
│  │ • Staking Logic   │  │   Interfaces      │          │
│  │ • Treasury        │  │ • Optimized       │          │
│  │   Management      │  │   Computations    │          │
│  └───────────────────┘  └───────────────────┘          │
│           │                       │                      │
│           └───────────┬───────────┘                      │
│                       │                                  │
│              ┌────────▼────────┐                         │
│              │   Interfaces    │                         │
│              │  Solidity ↔️ Rust│                         │
│              └─────────────────┘                         │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│              Arbitrum Testnet / Mainnet                  │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Main Components

#### 2.2.1 Solidity Contracts with FHE (Zama)
- **EVVMCore.sol**: Main logic for the Virtual Blockchain
- **StakingManager.sol**: Staking management with encrypted data
- **TreasuryVault.sol**: Fund management with privacy

#### 2.2.2 Stylus Contracts (Rust)
- **EVVMInterface.rs**: High-performance interface for external calls
- **ComputationEngine.rs**: Optimized mathematical operations
- **DataBridge.rs**: Data bridge between Solidity and Rust

#### 2.2.3 Mocks and Simplifications
- Governance: Mock contract with basic functions
- Oracles: Hardcoded data
- Frontend: Out of scope for MVP

---

## 3. Feature Specifications

### 3.1 EVVM Core Contract

#### 3.1.1 Main Functionalities
Based on: `src/contracts/evvm/Evvm.sol`

**Contract State:**
```solidity
// Encrypted state using Zama FHE
struct VirtualBlock {
    euint64 blockNumber;      // Encrypted block number
    euint256 timestamp;       // Encrypted timestamp
    euint256 gasLimit;        // Encrypted gas limit
    address[] validators;      // Validator set (public)
    ebool isFinalized;        // Encrypted finalization status
}

struct VirtualTransaction {
    euint256 txId;            // Encrypted transaction ID
    address from;             // Sender (public for auditing)
    address to;               // Recipient (public)
    euint256 value;           // Encrypted value
    euint256 gasUsed;         // Encrypted gas used
    ebytes data;              // Encrypted data payload
}
```

**Core Functions:**
```solidity
// Initialize virtual blockchain
function initializeVirtualChain(
    string memory chainName,
    uint256 initialGasLimit
) external onlyOwner;

// Create new virtual block (FHE encrypted)
function createVirtualBlock(
    euint256 gasLimit,
    address[] calldata validators
) external onlyValidator returns (euint64 blockNumber);

// Submit encrypted transaction
function submitTransaction(
    address to,
    einput encryptedValue,
    ebytes encryptedData,
    bytes calldata inputProof
) external returns (euint256 txId);

// Finalize block (consensus)
function finalizeBlock(
    euint64 blockNumber
) external onlyValidator;

// Query block info (returns encrypted data)
function getBlockInfo(
    euint64 blockNumber
) external view returns (VirtualBlock memory);

// Verify transaction inclusion
function verifyTransaction(
    euint256 txId,
    euint64 blockNumber
) external view returns (ebool isIncluded);
```

**Events:**
```solidity
event VirtualChainInitialized(string chainName, uint256 timestamp);
event VirtualBlockCreated(uint256 indexed blockNumber, address indexed validator);
event TransactionSubmitted(uint256 indexed txId, address indexed from);
event BlockFinalized(uint256 indexed blockNumber, uint256 timestamp);
```

#### 3.1.2 Zama FHE Integration

**FHE Setup:**
```solidity
import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

contract EVVMCore is GatewayCaller {
    // FHE network configuration
    constructor() {
        // Initialize TFHE library
        TFHE.setFHEVM(FHEVMConfig.defaultConfig());
    }
    
    // Request decryption for authorized users
    function requestDecryption(
        euint256 encryptedValue,
        bytes32 requestId
    ) external onlyAuthorized {
        uint256[] memory cts = new uint256[](1);
        cts[0] = TFHE.getValue(encryptedValue);
        Gateway.requestDecryption(
            cts,
            this.callbackDecryption.selector,
            0,
            block.timestamp + 100,
            false
        );
    }
    
    // Callback after decryption
    function callbackDecryption(
        uint256 requestId,
        uint256 decryptedValue
    ) external onlyGateway {
        // Process decrypted value
        emit DecryptionCompleted(requestId, decryptedValue);
    }
}
```

#### 3.1.3 Stylus Interoperability

**Solidity → Stylus Interface:**
```solidity
// Interface for calling Rust contracts
interface IEVVMStylus {
    function computeBlockHash(
        bytes32[] calldata txHashes
    ) external view returns (bytes32);
    
    function validateSignatures(
        bytes[] calldata signatures,
        bytes32 messageHash
    ) external view returns (bool);
}

contract EVVMCore {
    IEVVMStylus public stylusEngine;
    
    function setStylusEngine(address _engine) external onlyOwner {
        stylusEngine = IEVVMStylus(_engine);
    }
    
    // Use Stylus for heavy computations
    function finalizeBlockWithValidation(
        uint256 blockNumber,
        bytes[] calldata validatorSignatures
    ) external {
        bytes32 blockHash = stylusEngine.computeBlockHash(txHashes);
        require(
            stylusEngine.validateSignatures(validatorSignatures, blockHash),
            "Invalid signatures"
        );
        // Continue finalization...
    }
}
```

---

### 3.2 Staking System

#### 3.2.1 Main Functionalities
Based on: `src/contracts/staking/`

**Contract State:**
```solidity
struct Stake {
    euint256 amount;          // Encrypted staked amount
    euint256 rewardDebt;      // Encrypted reward tracking
    uint256 lockTimestamp;    // Lock end time (public)
    ebool isActive;           // Encrypted active status
}

struct StakingPool {
    euint256 totalStaked;     // Total encrypted stake
    euint256 rewardPerShare;  // Encrypted reward distribution
    uint256 lastRewardBlock;  // Last reward calculation
    uint256 apr;              // Annual Percentage Rate (public)
}
```

**Core Functions:**
```solidity
// Stake tokens (encrypted amount)
function stake(
    einput encryptedAmount,
    bytes calldata inputProof,
    uint256 lockPeriod
) external returns (uint256 stakeId);

// Unstake tokens
function unstake(
    uint256 stakeId
) external returns (euint256 unstakedAmount);

// Claim rewards
function claimRewards(
    uint256 stakeId
) external returns (euint256 rewardAmount);

// Calculate pending rewards (FHE computation)
function calculatePendingRewards(
    address staker,
    uint256 stakeId
) external view returns (euint256 pendingRewards);

// Emergency unstake (with penalty)
function emergencyUnstake(
    uint256 stakeId
) external returns (euint256 amount, euint256 penalty);

// Update staking pool parameters
function updatePoolParameters(
    uint256 poolId,
    uint256 newAPR,
    uint256 minLockPeriod
) external onlyOwner;
```

**Events:**
```solidity
event Staked(
    address indexed user,
    uint256 indexed stakeId,
    uint256 lockTimestamp
);
event Unstaked(address indexed user, uint256 indexed stakeId);
event RewardsClaimed(address indexed user, uint256 indexed stakeId);
event PoolUpdated(uint256 indexed poolId, uint256 newAPR);
```

#### 3.2.2 Reward Calculation with FHE

```solidity
function _calculateRewards(
    euint256 stakedAmount,
    euint256 rewardPerShare,
    euint256 rewardDebt
) internal view returns (euint256) {
    // All operations on encrypted data
    euint256 accumulatedReward = TFHE.mul(stakedAmount, rewardPerShare);
    accumulatedReward = TFHE.div(accumulatedReward, TFHE.asEuint256(1e18));
    return TFHE.sub(accumulatedReward, rewardDebt);
}

function _updateRewards() internal {
    if (block.number <= lastRewardBlock) return;
    
    // Calculate new rewards in encrypted space
    uint256 blocks = block.number - lastRewardBlock;
    euint256 reward = TFHE.mul(
        pool.totalStaked,
        TFHE.asEuint256((pool.apr * blocks) / BLOCKS_PER_YEAR)
    );
    
    // Update reward per share (encrypted)
    pool.rewardPerShare = TFHE.add(
        pool.rewardPerShare,
        TFHE.div(
            TFHE.mul(reward, TFHE.asEuint256(1e18)),
            pool.totalStaked
        )
    );
    
    lastRewardBlock = block.number;
}
```

---

### 3.3 Treasury Management

#### 3.3.1 Main Functionalities
Based on: `src/contracts/treasury/Treasury.sol`

**Contract State:**
```solidity
struct TreasuryBalance {
    euint256 totalBalance;      // Total encrypted balance
    euint256 reservedFunds;     // Reserved for operations
    euint256 availableFunds;    // Available for distribution
    mapping(address => euint256) allocations; // Token allocations
}

struct WithdrawalRequest {
    euint256 amount;            // Encrypted withdrawal amount
    address recipient;          // Recipient address
    uint256 timestamp;          // Request timestamp
    ebool isApproved;           // Encrypted approval status
    uint256 executionTime;      // Timelock execution time
}
```

**Core Functions:**
```solidity
// Deposit funds to treasury
function deposit(
    address token,
    einput encryptedAmount,
    bytes calldata inputProof
) external payable;

// Request withdrawal (with governance approval)
function requestWithdrawal(
    address token,
    einput encryptedAmount,
    bytes calldata inputProof,
    address recipient
) external onlyGovernance returns (uint256 requestId);

// Execute approved withdrawal (after timelock)
function executeWithdrawal(
    uint256 requestId
) external;

// Allocate funds to specific purpose
function allocateFunds(
    address token,
    einput encryptedAmount,
    bytes calldata inputProof,
    bytes32 purpose
) external onlyGovernance;

// Get treasury balance (encrypted)
function getTreasuryBalance(
    address token
) external view returns (euint256 balance);

// Emergency withdrawal (multisig required)
function emergencyWithdraw(
    address token,
    einput encryptedAmount,
    address recipient,
    bytes[] calldata signatures
) external onlyEmergency;
```

**Events:**
```solidity
event Deposited(address indexed token, address indexed from);
event WithdrawalRequested(
    uint256 indexed requestId,
    address indexed recipient,
    uint256 executionTime
);
event WithdrawalExecuted(uint256 indexed requestId);
event FundsAllocated(address indexed token, bytes32 indexed purpose);
event EmergencyWithdrawal(address indexed token, address indexed recipient);
```

#### 3.3.2 Timelock and Governance (Mock)

```solidity
// Mock governance for MVP
contract MockGovernance {
    mapping(address => bool) public governors;
    uint256 public constant TIMELOCK_DURATION = 2 days;
    
    modifier onlyGovernance() {
        require(governors[msg.sender], "Not governor");
        _;
    }
    
    function addGovernor(address _governor) external {
        governors[_governor] = true;
    }
    
    // Simplified approval - in production use real governance
    function approveWithdrawal(uint256 requestId) external onlyGovernance {
        // Mock implementation
        emit WithdrawalApproved(requestId, block.timestamp + TIMELOCK_DURATION);
    }
}
```

---

## 4. Stylus Contracts (Rust)

### 4.1 EVVMInterface

**Responsibilities:**
- High-speed signature validation
- Block hash calculation
- Proof verification

**Structure:**
```rust
use stylus_sdk::{
    alloy_primitives::{Address, U256, B256},
    prelude::*,
    call::Call,
};

#[solidity_storage]
#[entrypoint]
pub struct EVVMInterface {
    owner: StorageAddress,
    evvm_core: StorageAddress,
}

#[external]
impl EVVMInterface {
    // Compute Merkle root for block transactions
    pub fn compute_block_hash(
        &self,
        tx_hashes: Vec<B256>
    ) -> Result<B256, Vec<u8>> {
        if tx_hashes.is_empty() {
            return Err("Empty transaction list".into());
        }
        
        // Efficient Merkle tree computation
        let merkle_root = self.build_merkle_tree(&tx_hashes);
        Ok(merkle_root)
    }
    
    // Batch signature validation
    pub fn validate_signatures(
        &self,
        signatures: Vec<Vec<u8>>,
        message_hash: B256
    ) -> Result<bool, Vec<u8>> {
        // Parallel signature validation (more efficient in Rust)
        for signature in signatures {
            if !self.verify_signature(&signature, message_hash) {
                return Ok(false);
            }
        }
        Ok(true)
    }
    
    // Verify inclusion proof
    pub fn verify_merkle_proof(
        &self,
        leaf: B256,
        proof: Vec<B256>,
        root: B256,
        index: usize
    ) -> Result<bool, Vec<u8>> {
        let mut computed_hash = leaf;
        let mut current_index = index;
        
        for proof_element in proof {
            computed_hash = if current_index % 2 == 0 {
                self.hash_pair(computed_hash, proof_element)
            } else {
                self.hash_pair(proof_element, computed_hash)
            };
            current_index /= 2;
        }
        
        Ok(computed_hash == root)
    }
}

impl EVVMInterface {
    fn build_merkle_tree(&self, leaves: &[B256]) -> B256 {
        if leaves.len() == 1 {
            return leaves[0];
        }
        
        let mut next_level = Vec::new();
        for chunk in leaves.chunks(2) {
            let hash = if chunk.len() == 2 {
                self.hash_pair(chunk[0], chunk[1])
            } else {
                chunk[0]
            };
            next_level.push(hash);
        }
        
        self.build_merkle_tree(&next_level)
    }
    
    fn hash_pair(&self, a: B256, b: B256) -> B256 {
        use tiny_keccak::{Hasher, Keccak};
        let mut hasher = Keccak::v256();
        let mut output = [0u8; 32];
        
        hasher.update(a.as_slice());
        hasher.update(b.as_slice());
        hasher.finalize(&mut output);
        
        B256::from(output)
    }
    
    fn verify_signature(
        &self,
        signature: &[u8],
        message_hash: B256
    ) -> bool {
        // Implement ECDSA verification
        // Using secp256k1 library
        // Return true if signature is valid
        true // Placeholder
    }
}
```

### 4.2 ComputationEngine

**Optimized operations:**
```rust
#[solidity_storage]
#[entrypoint]
pub struct ComputationEngine {
    cache: StorageMap<U256, U256>,
}

#[external]
impl ComputationEngine {
    // Optimized gas calculation
    pub fn calculate_gas_used(
        &self,
        tx_data: Vec<u8>,
        execution_steps: U256
    ) -> Result<U256, Vec<u8>> {
        let base_gas = U256::from(21000);
        let data_gas = self.calculate_data_gas(&tx_data);
        let execution_gas = execution_steps * U256::from(10);
        
        Ok(base_gas + data_gas + execution_gas)
    }
    
    // Batch reward calculation
    pub fn batch_calculate_rewards(
        &self,
        stakes: Vec<U256>,
        apr: U256,
        blocks: U256
    ) -> Result<Vec<U256>, Vec<u8>> {
        let mut rewards = Vec::with_capacity(stakes.len());
        
        for stake in stakes {
            let reward = (stake * apr * blocks) / U256::from(31_536_000);
            rewards.push(reward);
        }
        
        Ok(rewards)
    }
    
    fn calculate_data_gas(&self, data: &[u8]) -> U256 {
        let mut gas = U256::ZERO;
        for byte in data {
            gas += if *byte == 0 {
                U256::from(4)
            } else {
                U256::from(16)
            };
        }
        gas
    }
}
```

### 4.3 DataBridge

**Bridge between Solidity and Rust:**
```rust
#[solidity_storage]
#[entrypoint]
pub struct DataBridge {
    solidity_contracts: StorageMap<B256, StorageAddress>,
}

#[external]
impl DataBridge {
    // Call Solidity contract from Rust
    pub fn call_solidity_contract(
        &mut self,
        contract_id: B256,
        calldata: Vec<u8>
    ) -> Result<Vec<u8>, Vec<u8>> {
        let contract_address = self.solidity_contracts.get(contract_id);
        
        match contract_address {
            Some(addr) => {
                // Make external call to Solidity contract
                let result = Call::new()
                    .call(addr, &calldata)?;
                Ok(result)
            },
            None => Err("Contract not found".into())
        }
    }
    
    // Register Solidity contract
    pub fn register_contract(
        &mut self,
        contract_id: B256,
        contract_address: Address
    ) -> Result<(), Vec<u8>> {
        self.solidity_contracts.insert(contract_id, contract_address);
        Ok(())
    }
}
```

---

## 5. Mocks and Simplifications

### 5.1 Mock Governance

```solidity
contract MockGovernance {
    address public owner;
    mapping(address => bool) public admins;
    mapping(uint256 => bool) public approvedProposals;
    
    constructor() {
        owner = msg.sender;
        admins[msg.sender] = true;
    }
    
    function propose(bytes calldata) external returns (uint256) {
        return block.timestamp;
    }
    
    function approve(uint256 proposalId) external {
        require(admins[msg.sender], "Not admin");
        approvedProposals[proposalId] = true;
    }
    
    function execute(uint256 proposalId) external {
        require(approvedProposals[proposalId], "Not approved");
        // Mock execution
    }
}
```

### 5.2 Mock Oracle

```solidity
contract MockPriceOracle {
    mapping(address => uint256) public prices;
    
    function setPrice(address token, uint256 price) external {
        prices[token] = price;
    }
    
    function getPrice(address token) external view returns (uint256) {
        return prices[token] > 0 ? prices[token] : 1e18;
    }
}
```

### 5.3 Mock Token

```solidity
contract MockERC20 {
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    
    mapping(address => uint256) public balances;
    
    function mint(address to, uint256 amount) external {
        balances[to] += amount;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }
}
```

---

## 6. Deployment & Testing

### 6.1 Environment Setup

**Required tools:**
- Node.js >= 18
- Foundry (for Solidity)
- Rust toolchain (for Stylus)
- Cargo stylus CLI

**Installation:**
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Cargo Stylus
cargo install --force cargo-stylus

# Install dependencies
npm install
forge install
```

### 6.2 Project Structure

```
evvm-mvp/
├── contracts/
│   ├── solidity/
│   │   ├── core/
│   │   │   └── EVVMCore.sol
│   │   ├── staking/
│   │   │   └── StakingManager.sol
│   │   ├── treasury/
│   │   │   └── TreasuryVault.sol
│   │   ├── mocks/
│   │   │   ├── MockGovernance.sol
│   │   │   ├── MockOracle.sol
│   │   │   └── MockERC20.sol
│   │   └── interfaces/
│   │       └── IEVVMStylus.sol
│   └── stylus/
│       ├── evvm-interface/
│       │   ├── src/
│       │   │   └── lib.rs
│       │   └── Cargo.toml
│       ├── computation-engine/
│       │   └── src/lib.rs
│       └── data-bridge/
│           └── src/lib.rs
├── scripts/
│   ├── deploy-solidity.js
│   ├── deploy-stylus.sh
│   └── setup-system.js
├── test/
│   ├── solidity/
│   │   ├── EVVMCore.t.sol
│   │   ├── Staking.t.sol
│   │   └── Treasury.t.sol
│   └── stylus/
│       └── integration.rs
├── foundry.toml
├── hardhat.config.js
└── README.md
```

### 6.3 Deployment Scripts

**Deploy Solidity (Hardhat):**
```javascript
// scripts/deploy-solidity.js
const { ethers } = require("hardhat");

async function main() {
    console.log("Deploying EVVM MVP contracts...");
    
    // 1. Deploy mocks
    const MockGovernance = await ethers.getContractFactory("MockGovernance");
    const governance = await MockGovernance.deploy();
    await governance.waitForDeployment();
    console.log("MockGovernance:", await governance.getAddress());
    
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const token = await MockERC20.deploy();
    await token.waitForDeployment();
    console.log("MockERC20:", await token.getAddress());
    
    // 2. Deploy core contracts
    const EVVMCore = await ethers.getContractFactory("EVVMCore");
    const evvmCore = await EVVMCore.deploy();
    await evvmCore.waitForDeployment();
    console.log("EVVMCore:", await evvmCore.getAddress());
    
    // 3. Deploy staking
    const StakingManager = await ethers.getContractFactory("StakingManager");
    const staking = await StakingManager.deploy(
        await evvmCore.getAddress(),
        await token.getAddress()
    );
    await staking.waitForDeployment();
    console.log("StakingManager:", await staking.getAddress());
    
    // 4. Deploy treasury
    const TreasuryVault = await ethers.getContractFactory("TreasuryVault");
    const treasury = await TreasuryVault.deploy(
        await governance.getAddress()
    );
    await treasury.waitForDeployment();
    console.log("TreasuryVault:", await treasury.getAddress());
    
    // 5. Initialize system
    await evvmCore.initializeVirtualChain("EVVM-MVP", ethers.parseEther("10000000"));
    console.log("System initialized!");
    
    // Save deployment addresses
    const fs = require("fs");
    const addresses = {
        governance: await governance.getAddress(),
        token: await token.getAddress(),
        evvmCore: await evvmCore.getAddress(),
        staking: await staking.getAddress(),
        treasury: await treasury.getAddress(),
    };
    fs.writeFileSync(
        "deployments.json",
        JSON.stringify(addresses, null, 2)
    );
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

**Deploy Stylus (Bash):**
```bash
#!/bin/bash
# scripts/deploy-stylus.sh

echo "Deploying Stylus contracts..."

# Load RPC URL from env
RPC_URL=${ARBITRUM_RPC_URL:-"https://sepolia-rollup.arbitrum.io/rpc"}
PRIVATE_KEY=${DEPLOYER_PRIVATE_KEY}

# Deploy EVVMInterface
cd contracts/stylus/evvm-interface
cargo stylus deploy \
    --private-key=$PRIVATE_KEY \
    --endpoint=$RPC_URL
EVVM_INTERFACE_ADDRESS=$(cargo stylus deploy --private-key=$PRIVATE_KEY --endpoint=$RPC_URL 2>&1 | grep "deployed at" | awk '{print $NF}')
echo "EVVMInterface deployed at: $EVVM_INTERFACE_ADDRESS"

# Deploy ComputationEngine
cd ../computation-engine
cargo stylus deploy \
    --private-key=$PRIVATE_KEY \
    --endpoint=$RPC_URL
COMPUTATION_ENGINE_ADDRESS=$(cargo stylus deploy --private-key=$PRIVATE_KEY --endpoint=$RPC_URL 2>&1 | grep "deployed at" | awk '{print $NF}')
echo "ComputationEngine deployed at: $COMPUTATION_ENGINE_ADDRESS"

# Deploy DataBridge
cd ../data-bridge
cargo stylus deploy \
    --private-key=$PRIVATE_KEY \
    --endpoint=$RPC_URL
DATA_BRIDGE_ADDRESS=$(cargo stylus deploy --private-key=$PRIVATE_KEY --endpoint=$RPC_URL 2>&1 | grep "deployed at" | awk '{print $NF}')
echo "DataBridge deployed at: $DATA_BRIDGE_ADDRESS"

# Save addresses
cd ../../..
cat > stylus-deployments.json <<EOF
{
  "evvmInterface": "$EVVM_INTERFACE_ADDRESS",
  "computationEngine": "$COMPUTATION_ENGINE_ADDRESS",
  "dataBridge": "$DATA_BRIDGE_ADDRESS"
}
EOF

echo "Stylus contracts deployed successfully!"
```

### 6.4 Testing Strategy

**Unit Tests (Foundry):**
```solidity
// test/solidity/EVVMCore.t.sol
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../contracts/solidity/core/EVVMCore.sol";
import "../../contracts/solidity/mocks/MockGovernance.sol";

contract EVVMCoreTest is Test {
    EVVMCore public evvmCore;
    MockGovernance public governance;
    address public validator1;
    address public validator2;
    
    function setUp() public {
        validator1 = address(0x1);
        validator2 = address(0x2);
        
        governance = new MockGovernance();
        evvmCore = new EVVMCore();
        
        evvmCore.initializeVirtualChain("TestChain", 10000000);
        evvmCore.addValidator(validator1);
        evvmCore.addValidator(validator2);
    }
    
    function testInitialization() public {
        assertEq(evvmCore.chainName(), "TestChain");
        assertTrue(evvmCore.isValidator(validator1));
    }
    
    function testCreateVirtualBlock() public {
        vm.prank(validator1);
        
        address[] memory validators = new address[](2);
        validators[0] = validator1;
        validators[1] = validator2;
        
        // Create encrypted gas limit (mock for testing)
        euint256 encryptedGasLimit = TFHE.asEuint256(10000000);
        
        uint256 blockNumber = evvmCore.createVirtualBlock(
            encryptedGasLimit,
            validators
        );
        
        assertTrue(blockNumber > 0);
    }
    
    function testSubmitTransaction() public {
        address recipient = address(0x3);
        
        // Create encrypted value
        bytes memory inputProof = hex"1234"; // Mock proof
        
        vm.prank(address(this));
        uint256 txId = evvmCore.submitTransaction(
            recipient,
            TFHE.asEuint256(1 ether),
            TFHE.asEbytes(hex"abcd"),
            inputProof
        );
        
        assertTrue(txId > 0);
    }
    
    function testFinalizeBlock() public {
        // Create block first
        vm.prank(validator1);
        address[] memory validators = new address[](1);
        validators[0] = validator1;
        
        euint256 encryptedGasLimit = TFHE.asEuint256(10000000);
        uint256 blockNumber = evvmCore.createVirtualBlock(
            encryptedGasLimit,
            validators
        );
        
        // Finalize
        vm.prank(validator1);
        evvmCore.finalizeBlock(blockNumber);
        
        // Verify finalized
        VirtualBlock memory block = evvmCore.getBlockInfo(blockNumber);
        assertTrue(TFHE.decrypt(block.isFinalized));
    }
    
    function testCannotFinalizeWithoutValidatorRole() public {
        vm.prank(validator1);
        address[] memory validators = new address[](1);
        validators[0] = validator1;
        
        euint256 encryptedGasLimit = TFHE.asEuint256(10000000);
        uint256 blockNumber = evvmCore.createVirtualBlock(
            encryptedGasLimit,
            validators
        );
        
        // Try to finalize as non-validator
        vm.prank(address(0x999));
        vm.expectRevert("Not a validator");
        evvmCore.finalizeBlock(blockNumber);
    }
}

// test/solidity/Staking.t.sol
contract StakingManagerTest is Test {
    StakingManager public staking;
    MockERC20 public token;
    EVVMCore public evvmCore;
    address public user1;
    address public user2;
    
    function setUp() public {
        user1 = address(0x1);
        user2 = address(0x2);
        
        token = new MockERC20();
        evvmCore = new EVVMCore();
        staking = new StakingManager(address(evvmCore), address(token));
        
        // Mint tokens to users
        token.mint(user1, 1000 ether);
        token.mint(user2, 1000 ether);
        
        // Approve staking contract
        vm.prank(user1);
        token.approve(address(staking), type(uint256).max);
        vm.prank(user2);
        token.approve(address(staking), type(uint256).max);
    }
    
    function testStake() public {
        vm.prank(user1);
        
        bytes memory inputProof = hex"1234";
        uint256 lockPeriod = 30 days;
        
        uint256 stakeId = staking.stake(
            TFHE.asEuint256(100 ether),
            inputProof,
            lockPeriod
        );
        
        assertTrue(stakeId > 0);
        assertEq(token.balances(user1), 900 ether);
    }
    
    function testCalculateRewards() public {
        // Stake tokens
        vm.prank(user1);
        bytes memory inputProof = hex"1234";
        uint256 stakeId = staking.stake(
            TFHE.asEuint256(100 ether),
            inputProof,
            30 days
        );
        
        // Fast forward time
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 216000); // ~30 days of blocks
        
        // Calculate rewards
        euint256 pendingRewards = staking.calculatePendingRewards(user1, stakeId);
        
        // Rewards should be > 0 (encrypted)
        assertTrue(TFHE.decrypt(pendingRewards) > 0);
    }
    
    function testUnstake() public {
        // Stake
        vm.prank(user1);
        bytes memory inputProof = hex"1234";
        uint256 stakeId = staking.stake(
            TFHE.asEuint256(100 ether),
            inputProof,
            30 days
        );
        
        // Fast forward past lock period
        vm.warp(block.timestamp + 31 days);
        
        // Unstake
        vm.prank(user1);
        euint256 unstakedAmount = staking.unstake(stakeId);
        
        // Should receive original stake back
        assertEq(TFHE.decrypt(unstakedAmount), 100 ether);
    }
    
    function testCannotUnstakeBeforeLockPeriod() public {
        vm.prank(user1);
        bytes memory inputProof = hex"1234";
        uint256 stakeId = staking.stake(
            TFHE.asEuint256(100 ether),
            inputProof,
            30 days
        );
        
        // Try to unstake before lock period
        vm.prank(user1);
        vm.expectRevert("Lock period not ended");
        staking.unstake(stakeId);
    }
    
    function testEmergencyUnstake() public {
        vm.prank(user1);
        bytes memory inputProof = hex"1234";
        uint256 stakeId = staking.stake(
            TFHE.asEuint256(100 ether),
            inputProof,
            30 days
        );
        
        // Emergency unstake (with 10% penalty)
        vm.prank(user1);
        (euint256 amount, euint256 penalty) = staking.emergencyUnstake(stakeId);
        
        assertEq(TFHE.decrypt(amount), 90 ether); // 90% returned
        assertEq(TFHE.decrypt(penalty), 10 ether); // 10% penalty
    }
}

// test/solidity/Treasury.t.sol
contract TreasuryVaultTest is Test {
    TreasuryVault public treasury;
    MockGovernance public governance;
    MockERC20 public token;
    address public governor1;
    address public recipient;
    
    function setUp() public {
        governor1 = address(0x1);
        recipient = address(0x2);
        
        governance = new MockGovernance();
        governance.addAdmin(governor1);
        
        token = new MockERC20();
        treasury = new TreasuryVault(address(governance));
        
        // Mint tokens to treasury
        token.mint(address(treasury), 1000000 ether);
    }
    
    function testDeposit() public {
        vm.prank(address(this));
        
        bytes memory inputProof = hex"1234";
        treasury.deposit(
            address(token),
            TFHE.asEuint256(100 ether),
            inputProof
        );
        
        euint256 balance = treasury.getTreasuryBalance(address(token));
        assertTrue(TFHE.decrypt(balance) >= 100 ether);
    }
    
    function testRequestWithdrawal() public {
        vm.prank(governor1);
        
        bytes memory inputProof = hex"1234";
        uint256 requestId = treasury.requestWithdrawal(
            address(token),
            TFHE.asEuint256(50 ether),
            inputProof,
            recipient
        );
        
        assertTrue(requestId > 0);
    }
    
    function testExecuteWithdrawal() public {
        // Request withdrawal
        vm.prank(governor1);
        bytes memory inputProof = hex"1234";
        uint256 requestId = treasury.requestWithdrawal(
            address(token),
            TFHE.asEuint256(50 ether),
            inputProof,
            recipient
        );
        
        // Approve
        vm.prank(governor1);
        governance.approve(requestId);
        
        // Fast forward past timelock
        vm.warp(block.timestamp + 3 days);
        
        // Execute
        treasury.executeWithdrawal(requestId);
        
        // Verify recipient received tokens
        assertEq(token.balances(recipient), 50 ether);
    }
    
    function testCannotExecuteBeforeTimelock() public {
        vm.prank(governor1);
        bytes memory inputProof = hex"1234";
        uint256 requestId = treasury.requestWithdrawal(
            address(token),
            TFHE.asEuint256(50 ether),
            inputProof,
            recipient
        );
        
        vm.prank(governor1);
        governance.approve(requestId);
        
        // Try to execute immediately
        vm.expectRevert("Timelock not expired");
        treasury.executeWithdrawal(requestId);
    }
}
```

**Integration Tests (Stylus + Solidity):**
```rust
// test/stylus/integration.rs
#[cfg(test)]
mod tests {
    use super::*;
    use stylus_sdk::alloy_primitives::{Address, U256, B256};
    
    #[test]
    fn test_compute_block_hash() {
        let interface = EVVMInterface::default();
        
        let tx_hashes = vec![
            B256::from([1u8; 32]),
            B256::from([2u8; 32]),
            B256::from([3u8; 32]),
        ];
        
        let result = interface.compute_block_hash(tx_hashes);
        assert!(result.is_ok());
        
        let block_hash = result.unwrap();
        assert_ne!(block_hash, B256::ZERO);
    }
    
    #[test]
    fn test_validate_signatures() {
        let interface = EVVMInterface::default();
        
        // Mock signatures
        let signatures = vec![
            vec![1u8; 65],
            vec![2u8; 65],
        ];
        
        let message_hash = B256::from([42u8; 32]);
        
        let result = interface.validate_signatures(signatures, message_hash);
        assert!(result.is_ok());
    }
    
    #[test]
    fn test_verify_merkle_proof() {
        let interface = EVVMInterface::default();
        
        let leaf = B256::from([1u8; 32]);
        let proof = vec![
            B256::from([2u8; 32]),
            B256::from([3u8; 32]),
        ];
        let root = B256::from([4u8; 32]);
        
        let result = interface.verify_merkle_proof(leaf, proof, root, 0);
        assert!(result.is_ok());
    }
    
    #[test]
    fn test_batch_calculate_rewards() {
        let engine = ComputationEngine::default();
        
        let stakes = vec![
            U256::from(100) * U256::from(10u128.pow(18)),
            U256::from(200) * U256::from(10u128.pow(18)),
            U256::from(300) * U256::from(10u128.pow(18)),
        ];
        
        let apr = U256::from(5); // 5% APR
        let blocks = U256::from(216000); // ~30 days
        
        let result = engine.batch_calculate_rewards(stakes, apr, blocks);
        assert!(result.is_ok());
        
        let rewards = result.unwrap();
        assert_eq!(rewards.len(), 3);
        assert!(rewards[0] > U256::ZERO);
        assert!(rewards[1] > rewards[0]); // Higher stake = higher reward
        assert!(rewards[2] > rewards[1]);
    }
}
```

---

## 7. Security and Auditing

### 7.1 Security Considerations

#### 7.1.1 FHE Security
- **Encryption**: All sensitive values must be encrypted
- **Decryption Gates**: Only authorized users can request decryption
- **Key Management**: FHE keys must be handled securely
- **Gas Costs**: FHE operations are expensive, optimize usage

#### 7.1.2 Stylus Security
- **Memory Safety**: Rust prevents many common errors
- **Overflow Checks**: Use checked arithmetic
- **Reentrancy**: Rust makes reentrancy harder but still possible
- **Storage Access**: Validate all storage accesses

#### 7.1.3 Bridge Security
- **Interface Validation**: Validate all data crossing Solidity ↔️ Rust
- **Type Safety**: Ensure correct type conversion
- **Authorization**: Only authorized contracts can call bridges

### 7.2 Audit Checklist

#### Pre-Audit Checklist:
- [ ] All Solidity contracts compiled without warnings
- [ ] All Stylus contracts pass clippy
- [ ] 100% unit test coverage
- [ ] Integration tests passing
- [ ] Static analysis with Slither (Solidity)
- [ ] Static analysis with cargo-audit (Rust)
- [ ] Complete NatSpec documentation
- [ ] README with deployment instructions
- [ ] Deployment scripts tested on testnet

#### Security Patterns Implemented:
- [ ] Checks-Effects-Interactions in Solidity
- [ ] ReentrancyGuard on critical functions
- [ ] Access control (Ownable, roles)
- [ ] Pausable for emergencies
- [ ] Timelock on Treasury
- [ ] Rate limiting on expensive operations
- [ ] Input validation on all parameters
- [ ] Event logging for auditing

### 7.3 Known Attack Vectors

| Vector | Mitigation | Priority |
|--------|------------|----------|
| FHE key leakage | Gateway encryption, secure key storage | HIGH |
| Bridge manipulation | Signature verification, allowlists | HIGH |
| Reentrancy in Treasury | ReentrancyGuard, checks-effects-interactions | HIGH |
| Overflow in FHE calculations | Use TFHE operations, validate ranges | MEDIUM |
| Gas griefing in Stylus | Rate limiting, gas limits | MEDIUM |
| Front-running stakes | Commit-reveal if necessary | LOW |
| Validator collusion | Quorum requirements, slashing (future) | MEDIUM |

---

## 8. Implementation Roadmap

### 8.1 Phase 1: Setup and Infrastructure (Week 1)
**Objective**: Prepare development environment

**Tasks:**
- [ ] Configure Git repository with folder structure
- [ ] Install Foundry, Rust, Cargo Stylus
- [ ] Configure Hardhat with Zama FHE plugin
- [ ] Create base deployment scripts
- [ ] Setup CI/CD pipeline (GitHub Actions)
- [ ] Document setup process

**Deliverables:**
- Functional repository
- Setup documentation
- Working CI pipeline

### 8.2 Phase 2: Core Contracts (Week 2-3)
**Objective**: Implement main functionality

**Tasks:**
- [ ] Implement EVVMCore.sol with FHE
- [ ] Create IEVVMStylus.sol interfaces
- [ ] Develop EVVMInterface.rs (Stylus)
- [ ] EVVMCore unit tests
- [ ] Solidity ↔️ Stylus integration tests
- [ ] Deploy on Arbitrum Sepolia testnet

**Deliverables:**
- EVVMCore functional with FHE
- Stylus interface working
- Tests passing (>80% coverage)

### 8.3 Phase 3: Staking System (Week 3-4)
**Objective**: Privacy-enabled staking system

**Tasks:**
- [ ] Implement StakingManager.sol
- [ ] Integrate FHE for private amounts
- [ ] Create ComputationEngine.rs for calculations
- [ ] Staking tests (stake, unstake, rewards)
- [ ] Optimize gas costs
- [ ] Deploy and test on testnet

**Deliverables:**
- Functional staking
- Accurate reward calculation
- Optimized gas

### 8.4 Phase 4: Treasury (Week 4-5)
**Objective**: Secure fund management

**Tasks:**
- [ ] Implement TreasuryVault.sol
- [ ] Integrate MockGovernance
- [ ] Timelock for withdrawals
- [ ] Emergency procedures
- [ ] Treasury tests
- [ ] Deploy on testnet

**Deliverables:**
- Functional Treasury with timelock
- Basic governance
- Tested emergency procedures

### 8.5 Phase 5: Integration & Testing (Week 5-6)
**Objective**: Complete system working

**Tasks:**
- [ ] Complete end-to-end tests
- [ ] Load testing (simulate real usage)
- [ ] Preliminary security audit
- [ ] Gas optimization
- [ ] Complete technical documentation
- [ ] MVP demo video

**Deliverables:**
- Integrated working system
- Complete documentation
- Functional demo

### 8.6 Phase 6: Demo & Presentation (Week 6)
**Objective**: MVP ready to showcase

**Tasks:**
- [ ] Deploy on mainnet (if budget allows)
- [ ] Create interactive demo
- [ ] Prepare presentation
- [ ] Generate performance metrics
- [ ] Document next steps

**Deliverables:**
- Deployed MVP
- Presentation ready
- Roadmap v2

---

## 9. Success Metrics

### 9.1 Technical KPIs

| Metric | Target | Measurement |
|---------|--------|----------|
| Test Coverage | >80% | Foundry + cargo test |
| Gas Cost (stake) | <200k gas | Average on testnet |
| Gas Cost (create block) | <300k gas | Average on testnet |
| FHE operations | <5 per tx | Manual counter |
| Stylus call latency | <100ms | Benchmarks |
| Deployment success | 100% | On Arbitrum Sepolia |

### 9.2 Functional KPIs

| Feature | Success Criteria |
|---------|-------------------|
| EVVM Core | Create/finalize blocks, submit encrypted tx |
| Staking | Functional stake/unstake, rewards calculated |
| Treasury | Deposit/withdraw with timelock, basic governance |
| FHE Integration | At least 3 FHE operations working |
| Stylus Bridge | Bidirectional calls Solidity ↔️ Rust |

### 9.3 Demo Requirements

For the MVP demo, we must be able to show:
1. ✅ **Create Virtual Blockchain**: Init chain with parameters
2. ✅ **Submit Encrypted Transaction**: Send tx with encrypted value
3. ✅ **Stake Tokens**: Stake with private amount
4. ✅ **Calculate Rewards**: View accumulated rewards (encrypted)
5. ✅ **Treasury Deposit**: Deposit funds to treasury
6. ✅ **Request Withdrawal**: Request withdrawal with timelock

---

## 10. Risks and Mitigations

### 10.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|--------|--------------|---------|------------|
| FHE gas costs too high | MEDIUM | HIGH | Optimize operations, use Stylus for heavy calculations |
| Stylus-Solidity incompatibility | LOW | HIGH | Early integration tests, interface validation |
| Bugs in FHE contracts | MEDIUM | HIGH | Exhaustive tests, audit, use Zama docs |
| Performance issues on testnet | MEDIUM | MEDIUM | Load testing, optimization before demo |
| Deploy failures | LOW | MEDIUM | Robust scripts, fallbacks, testnet testing |

### 10.2 Project Risks

| Risk | Probability | Impact | Mitigation |
|--------|--------------|---------|------------|
| Implementation delays | MEDIUM | MEDIUM | Buffer time in roadmap, prioritize core features |
| Dependencies unavailable | LOW | HIGH | Verify all deps at start, backups |
| Scope creep | HIGH | MEDIUM | Strict MVP scope, document "out of scope" |
| Lack of Zama/Stylus documentation | MEDIUM | MEDIUM | Community, forums, direct support |

---

## 11. Resources and References

### 11.1 Official Documentation

- **Zama FHE**: https://docs.zama.org/protocol/solidity-guides/getting-started/overview
- **Arbitrum Stylus**: https://docs.arbitrum.io/stylus/stylus-gentle-introduction
- **Foundry Book**: https://book.getfoundry.sh/
- **Rust Stylus SDK**: https://github.com/OffchainLabs/stylus-sdk-rs

### 11.2 Reference Repositories

- **EVVM Original**: https://github.com/EVVM-org/Playground-Contracts
- **Zama fhevm**: https://github.com/zama-ai/fhevm
- **Stylus Examples**: https://github.com/OffchainLabs/stylus-workshop

### 11.3 Tools

- **Foundry**: Testing framework for Solidity
- **Cargo Stylus**: CLI for deploying Rust contracts
- **Hardhat**: Alternative deployment tool
- **Slither**: Static analysis for Solidity
- **cargo-audit**: Security audit for Rust

---

## 12. Glossary

| Term | Definition |
|---------|------------|
| **FHE** | Fully Homomorphic Encryption - allows computing on encrypted data |
| **Stylus** | Arbitrum VM that allows executing WASM (Rust, C++) on L2 |
| **EVVM** | Ethereum Virtual Virtual Machine - virtual blockchain within Ethereum |
| **euint256** | Encrypted 256-bit data type (Zama FHE) |
| **Gateway** | Zama service for decryption requests |
| **Mock** | Simplified contract implementation for testing/demo |
| **Timelock** | Delay mechanism for transaction execution |

---

## 13. Contact and Support

### 13.1 Development Team
- **Lead Developer**: [TBD]
- **Smart Contract Dev**: [TBD]
- **Stylus Dev**: [TBD]

### 13.2 Communication Channels
- **GitHub Issues**: For bugs and feature requests
- **Discord/Telegram**: For technical discussions
- **Email**: For official communication

### 13.3 Development Schedule
- **Sprint Planning**: Monday 9:00 AM
- **Daily Standups**: Tuesday-Friday 9:30 AM
- **Demo Reviews**: Friday 4:00 PM

---

## Appendices

### A. Useful Commands

```bash
# Compile Solidity contracts
forge build

# Run tests
forge test -vvv

# Deploy Solidity
npx hardhat run scripts/deploy-solidity.js --network arbitrumSepolia

# Compile Stylus
cd contracts/stylus/evvm-interface
cargo stylus check

# Deploy Stylus
./scripts/deploy-stylus.sh

# Verify contracts
forge verify-contract <ADDRESS> <CONTRACT> --chain arbitrum-sepolia

# Gas report
forge test --gas-report
```

### B. Environment Variables

```bash
# .env.example
ARBITRUM_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
DEPLOYER_PRIVATE_KEY=0x...
ETHERSCAN_API_KEY=...
FHEVM_GATEWAY_URL=https://gateway.zama.org
```

### C. Foundry Configuration

```toml
# foundry.toml
[profile.default]
src = "contracts/solidity"
out = "out"
libs = ["lib"]
solc = "0.8.24"
optimizer = true
optimizer_runs = 200

[profile.ci]
fuzz = { runs = 5000 }
invariant = { runs = 1000 }

[fuzz]
runs = 256
max_test_rejects = 65536

[invariant]
runs = 256
depth = 15
```

---

**Document prepared for**: EVVM MVP Migration  
**Version**: 1.0  
**Date**: November 2025  
**Status**: Draft - Ready for Review

---

## Final Notes

This document is a **living document** and should be updated as the project progresses. All significant changes must be:

1. Documented in the corresponding section
2. Communicated to the team
3. Reflected in code/tests
4. Versioned in Git

**Immediate Next Steps:**
1. Review this spec by the team
2. Repository setup (Phase 1)
3. Kick-off meeting to assign responsibilities
4. Begin EVVMCore implementation

Good luck with the MVP! 🚀
