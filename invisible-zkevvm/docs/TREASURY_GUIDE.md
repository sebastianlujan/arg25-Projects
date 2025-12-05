# Treasury Vault - User Guide

This document explains how the Treasury Vault contract works and how to interact with it using encrypted inputs from Zama FHEVM.

## Overview

The Treasury Vault is a smart contract that manages encrypted treasury balances with private amounts. It supports:
- Encrypted deposits (ETH and ERC20 tokens)
- Governance-controlled withdrawals with timelock
- Fund allocations to specific purposes
- Encrypted balance tracking

## Key Features

### 1. **Encrypted Balances**
All treasury balances are stored encrypted using FHE, ensuring privacy of treasury amounts.

### 2. **Governance Control**
Withdrawals and allocations require governance approval, providing security and control.

### 3. **Timelock Protection**
Withdrawal requests have a 2-day timelock before execution, preventing immediate withdrawals.

### 4. **Purpose-Based Allocations**
Funds can be allocated to specific purposes (identified by `bytes32`), enabling budget tracking.

## Encrypted Inputs Required

The contract expects encrypted inputs from external sources. All amounts must come encrypted:

| Function | Encrypted Input | Type | SDK Method |
|----------|----------------|------|-------------|
| `deposit()` | Amount | `externalEuint64` | `add64()` |
| `requestWithdrawal()` | Amount | `externalEuint64` | `add64()` |
| `allocateFunds()` | Amount | `externalEuint64` | `add64()` |

**IMPORTANT**: Types must match exactly: `externalEuint64` → `euint64` (use `add64()` in SDK)

## Contract Functions

### Deposit Functions

#### `deposit()`
Deposit funds to the treasury with encrypted amount.

```solidity
function deposit(
    address token,                      // Token address (address(0) for ETH)
    externalEuint64 inputEncryptedAmount, // Encrypted deposit amount
    bytes calldata inputProof           // Proof for encrypted amount
) external payable
```

**Parameters:**
- `token`: Token address (`address(0)` for ETH deposits)
- `inputEncryptedAmount`: Encrypted deposit amount (`externalEuint64`)
- `inputProof`: Proof for the encrypted amount

**Behavior:**
- For ETH: `msg.value` must match the encrypted amount (verified externally)
- For ERC20: Token must be approved beforehand, amount verified externally
- Updates `totalBalance` and `availableFunds` in encrypted space

**Example Usage:**
```typescript
// Deposit ETH
const depositInput = hre.fhevm.createEncryptedInput(treasuryAddress, userAddress);
depositInput.add64(ethers.parseEther("1.0")); // 1 ETH
const encrypted = await depositInput.encrypt();

await treasury.deposit(
    ethers.ZeroAddress,  // ETH
    encrypted.handles[0],
    encrypted.inputProof,
    { value: ethers.parseEther("1.0") }
);

// Deposit ERC20
await token.approve(treasuryAddress, amount);
const depositInput = hre.fhevm.createEncryptedInput(treasuryAddress, userAddress);
depositInput.add64(amount);
const encrypted = await depositInput.encrypt();

await treasury.deposit(
    tokenAddress,
    encrypted.handles[0],
    encrypted.inputProof
);
```

### Withdrawal Functions

#### `requestWithdrawal()`
Request a withdrawal with governance approval. Only governance addresses can call this.

```solidity
function requestWithdrawal(
    address token,                      // Token address
    externalEuint64 inputEncryptedAmount, // Encrypted withdrawal amount
    bytes calldata inputProof,          // Proof for encrypted amount
    address recipient                   // Recipient address
) external onlyGovernance returns (uint256 requestId)
```

**Parameters:**
- `token`: Token address to withdraw
- `inputEncryptedAmount`: Encrypted withdrawal amount (`externalEuint64`)
- `inputProof`: Proof for the encrypted amount
- `recipient`: Address that will receive the funds

**Returns:**
- `requestId`: Unique identifier for the withdrawal request

**Behavior:**
- Creates a withdrawal request with 2-day timelock
- Reserves funds (moves from `availableFunds` to `reservedFunds`)
- Auto-approves for governance (no additional approval needed)
- Emits `WithdrawalRequested` event

**Example Usage:**
```typescript
// Request withdrawal (must be governance)
const withdrawalInput = hre.fhevm.createEncryptedInput(treasuryAddress, governorAddress);
withdrawalInput.add64(ethers.parseEther("0.5")); // 0.5 ETH
const encrypted = await withdrawalInput.encrypt();

const tx = await treasury.connect(governor).requestWithdrawal(
    ethers.ZeroAddress,  // ETH
    encrypted.handles[0],
    encrypted.inputProof,
    recipientAddress
);
await tx.wait();

const receipt = await tx.wait();
const event = receipt.logs.find(log => {
    const parsed = treasury.interface.parseLog(log);
    return parsed?.name === "WithdrawalRequested";
});
const requestId = event.args.requestId;
```

#### `executeWithdrawal()`
Execute an approved withdrawal after the timelock period has expired.

```solidity
function executeWithdrawal(
    uint256 requestId,  // The withdrawal request ID
    address token        // Token address to withdraw
) external
```

**Parameters:**
- `requestId`: The withdrawal request ID from `requestWithdrawal()`
- `token`: Token address to withdraw

**Behavior:**
- Checks that timelock has expired (2 days)
- Updates balances (removes from `reservedFunds` and `totalBalance`)
- **Note**: Actual token transfer requires external decryption of amount
- Emits `WithdrawalExecuted` event

**Example Usage:**
```typescript
// Wait for timelock (2 days)
await time.increase(2 * 24 * 60 * 60);

// Execute withdrawal
await treasury.executeWithdrawal(requestId, ethers.ZeroAddress);

// Note: Actual token transfer must be handled externally after decrypting the amount
```

### Allocation Functions

#### `allocateFunds()`
Allocate funds to a specific purpose. Only governance can call this.

```solidity
function allocateFunds(
    address token,                      // Token address
    externalEuint64 inputEncryptedAmount, // Encrypted allocation amount
    bytes calldata inputProof,          // Proof for encrypted amount
    bytes32 purpose                     // Purpose identifier
) external onlyGovernance
```

**Parameters:**
- `token`: Token address
- `inputEncryptedAmount`: Encrypted allocation amount (`externalEuint64`)
- `inputProof`: Proof for the encrypted amount
- `purpose`: Purpose identifier (e.g., `keccak256("MARKETING")`)

**Behavior:**
- Moves funds from `availableFunds` to `reservedFunds`
- Tracks allocation in `allocations[token][purpose]`
- Emits `FundsAllocated` event

**Example Usage:**
```typescript
const purpose = ethers.id("MARKETING"); // keccak256("MARKETING")

const allocationInput = hre.fhevm.createEncryptedInput(treasuryAddress, governorAddress);
allocationInput.add64(ethers.parseEther("10.0")); // 10 tokens
const encrypted = await allocationInput.encrypt();

await treasury.connect(governor).allocateFunds(
    tokenAddress,
    encrypted.handles[0],
    encrypted.inputProof,
    purpose
);
```

### View Functions

#### `getTreasuryBalance()`
Get encrypted treasury balance for a token.

```solidity
function getTreasuryBalance(address token) external view returns (
    euint64 totalBalance,
    euint64 reservedFunds,
    euint64 availableFunds
)
```

**Returns:**
- `totalBalance`: Encrypted total balance
- `reservedFunds`: Encrypted reserved funds
- `availableFunds`: Encrypted available funds

**Example Usage:**
```typescript
const [total, reserved, available] = await treasury.getTreasuryBalance(tokenAddress);

// Decrypt to see actual values
const totalDecrypted = await hre.fhevm.userDecryptEuint(
    FhevmType.euint64,
    total,
    treasuryAddress,
    userSigner
);
console.log("Total Balance:", totalDecrypted);
```

#### `getAllocation()`
Get allocation amount for a token and purpose.

```solidity
function getAllocation(address token, bytes32 purpose) external view returns (euint64)
```

**Example Usage:**
```typescript
const purpose = ethers.id("MARKETING");
const allocation = await treasury.getAllocation(tokenAddress, purpose);

const allocationDecrypted = await hre.fhevm.userDecryptEuint(
    FhevmType.euint64,
    allocation,
    treasuryAddress,
    userSigner
);
console.log("Marketing Allocation:", allocationDecrypted);
```

#### `getWithdrawalRequest()`
Get withdrawal request details.

```solidity
function getWithdrawalRequest(uint256 requestId) external view returns (
    euint64 amount,
    address recipient,
    uint256 timestamp,
    ebool isApproved,
    uint256 executionTime
)
```

**Example Usage:**
```typescript
const request = await treasury.getWithdrawalRequest(requestId);
console.log("Recipient:", request.recipient);
console.log("Execution Time:", new Date(Number(request.executionTime) * 1000));

// Decrypt amount
const amountDecrypted = await hre.fhevm.userDecryptEuint(
    FhevmType.euint64,
    request.amount,
    treasuryAddress,
    userSigner
);
console.log("Amount:", amountDecrypted);
```

### Admin Functions

#### `addGovernor()`
Add a governance address (only owner).

```solidity
function addGovernor(address governor) external onlyOwner
```

#### `removeGovernor()`
Remove a governance address (only owner).

```solidity
function removeGovernor(address governor) external onlyOwner
```

## Complete Example: Deposit and Withdraw Flow

```typescript
import { FhevmType } from "@fhevm/hardhat-plugin";
import * as hre from "hardhat";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Treasury Vault Flow", function () {
    let treasury: TreasuryVault;
    let token: IERC20;
    let user: Signer;
    let governor: Signer;

    beforeEach(async function () {
        // Deploy contracts...
        treasury = await deployTreasury();
        token = await deployToken();
        [user, governor] = await ethers.getSigners();
        
        // Add governor
        await treasury.addGovernor(await governor.getAddress());
    });

    it("Complete deposit and withdrawal flow", async function () {
        const depositAmount = ethers.parseEther("100.0");
        
        // 1. Deposit
        await token.approve(await treasury.getAddress(), depositAmount);
        
        const depositInput = hre.fhevm.createEncryptedInput(
            await treasury.getAddress(),
            await user.getAddress()
        );
        depositInput.add64(depositAmount);
        const encryptedDeposit = await depositInput.encrypt();
        
        await treasury.connect(user).deposit(
            await token.getAddress(),
            encryptedDeposit.handles[0],
            encryptedDeposit.inputProof
        );
        
        // 2. Verify balance
        const [total] = await treasury.getTreasuryBalance(await token.getAddress());
        const totalDecrypted = await hre.fhevm.userDecryptEuint(
            FhevmType.euint64,
            total,
            await treasury.getAddress(),
            user
        );
        expect(totalDecrypted).to.equal(depositAmount);
        
        // 3. Request withdrawal
        const withdrawalAmount = ethers.parseEther("50.0");
        const recipient = await user.getAddress();
        
        const withdrawalInput = hre.fhevm.createEncryptedInput(
            await treasury.getAddress(),
            await governor.getAddress()
        );
        withdrawalInput.add64(withdrawalAmount);
        const encryptedWithdrawal = await withdrawalInput.encrypt();
        
        const tx = await treasury.connect(governor).requestWithdrawal(
            await token.getAddress(),
            encryptedWithdrawal.handles[0],
            encryptedWithdrawal.inputProof,
            recipient
        );
        const receipt = await tx.wait();
        
        // Extract requestId from event
        const event = receipt.logs.find(log => {
            try {
                const parsed = treasury.interface.parseLog(log);
                return parsed?.name === "WithdrawalRequested";
            } catch {
                return false;
            }
        });
        const requestId = event.args.requestId;
        
        // 4. Wait for timelock
        await time.increase(2 * 24 * 60 * 60);
        
        // 5. Execute withdrawal
        await treasury.executeWithdrawal(requestId, await token.getAddress());
        
        // Note: Actual token transfer requires external decryption
        // In production, decrypt amount and transfer tokens accordingly
    });
});
```

## Important Notes

### 1. **Type Correspondence**
All encrypted amounts must use `externalEuint64` (SDK method: `add64()`). The contract stores them as `euint64` internally.

### 2. **Decryption Required for Transfers**
Actual token transfers require decrypting the encrypted amount externally. The contract updates encrypted balances, but the actual transfer must be handled after decryption.

### 3. **Governance Control**
Only addresses added as governors can:
- Request withdrawals
- Allocate funds

### 4. **Timelock Protection**
Withdrawal requests have a 2-day timelock (`TIMELOCK_DURATION`). This prevents immediate withdrawals and provides a security buffer.

### 5. **Balance Tracking**
The treasury tracks three types of balances:
- `totalBalance`: Total funds in treasury
- `reservedFunds`: Funds reserved for withdrawals/allocations
- `availableFunds`: Funds available for new operations

### 6. **Purpose Allocations**
Funds can be allocated to specific purposes using `bytes32` identifiers. Common patterns:
```typescript
const MARKETING = ethers.id("MARKETING");
const DEVELOPMENT = ethers.id("DEVELOPMENT");
const OPERATIONS = ethers.id("OPERATIONS");
```

## Security Considerations

1. **Encrypted Amounts**: All amounts are encrypted, providing privacy but requiring external verification
2. **Governance Control**: Only trusted addresses can request withdrawals and allocations
3. **Timelock**: 2-day delay prevents immediate fund extraction
4. **Owner Control**: Only owner can add/remove governors

## Events

The contract emits the following events:

- `Deposited(address indexed token, address indexed from)`
- `WithdrawalRequested(uint256 indexed requestId, address indexed recipient, uint256 executionTime)`
- `WithdrawalExecuted(uint256 indexed requestId)`
- `FundsAllocated(address indexed token, bytes32 indexed purpose)`
- `EmergencyWithdrawal(address indexed token, address indexed recipient)` (if implemented)

## See Also

- [Staking Manager Guide](./STAKING_ENCRYPTED_INPUTS.md) - Similar encrypted input patterns
- [FHE Setup Guide](./FHE_SETUP.md) - Zama FHEVM setup instructions
- [EVVM Migration Specs](./evvm_migration_specs.md) - Complete system architecture

