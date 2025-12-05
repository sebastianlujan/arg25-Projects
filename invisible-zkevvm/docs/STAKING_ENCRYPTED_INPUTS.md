# Encrypted Inputs from External Sources - StakingManager

This document specifies which data must come encrypted from outside the contract using Zama FHEVM library, and in which encrypted data type they must come.

## Summary of Simplifications

By receiving already encrypted data from outside, we simplify operations within the contract by eliminating:
- ✅ On-chain address encryption
- ✅ Encryption tracking mappings (`_isAddressEncrypted`, `encryptedAddress`)
- ✅ Conditional initialization logic

## Data That Must Come Encrypted

### 1. **Stake Amount** (`stake()`)
- **Type**: `externalEuint64`
- **Parameter**: `inputEncryptedAmount`
- **Proof**: `inputAmountProof` (bytes)
- **Description**: The amount of tokens the user wants to stake, already encrypted.
- **Simplification**: Eliminates the need to encrypt internally.

### 2. **Owner Address** (`stake()`, `unstake()`, `claimRewards()`)
- **Type**: `externalEuint256`
- **Parameter**: `inputEncryptedOwner`
- **Proof**: `inputOwnerProof` (bytes)
- **Description**: The user's address encrypted as uint256.
- **Simplification**: 
  - Eliminates the `encryptedAddress` mapping
  - Eliminates the `_isAddressEncrypted` mapping
  - Enables fully encrypted ownership verification using `FHE.eq()`

### 3. **Initial Active Status** (`stake()`)
- **Type**: `externalEbool`
- **Parameter**: `inputEncryptedIsActive`
- **Proof**: `inputActiveProof` (bytes)
- **Description**: Initial stake status (active/inactive) encrypted.
- **Simplification**: Allows different initial states without exposing the value.

## Updated Functions

### `stake()`
```solidity
function stake(
    externalEuint64 inputEncryptedAmount,      // ✅ Comes encrypted
    bytes calldata inputAmountProof,
    externalEuint256 inputEncryptedOwner,      // ✅ Comes encrypted
    bytes calldata inputOwnerProof,
    uint256 lockPeriod,                        // Public (not encrypted)
    externalEbool inputEncryptedIsActive,      // ✅ Comes encrypted
    bytes calldata inputActiveProof
) external returns (uint256 stakeId)
```

**Encrypted data received:**
- `inputEncryptedAmount`: `externalEuint64` - Amount to stake
- `inputEncryptedOwner`: `externalEuint256` - Owner address
- `inputEncryptedIsActive`: `externalEbool` - Initial active status

### `unstake()`
```solidity
function unstake(
    uint256 stakeId,                           // Public
    externalEuint256 inputEncryptedOwner,      // ✅ Comes encrypted
    bytes calldata inputOwnerProof
) external returns (euint64 unstakedAmount)
```

**Encrypted data received:**
- `inputEncryptedOwner`: `externalEuint256` - Owner address for verification

### `claimRewards()`
```solidity
function claimRewards(
    uint256 stakeId,                           // Public
    externalEuint256 inputEncryptedOwner,      // ✅ Comes encrypted
    bytes calldata inputOwnerProof
) external returns (euint64 rewardAmount)
```

**Encrypted data received:**
- `inputEncryptedOwner`: `externalEuint256` - Owner address for verification

## Available Encrypted Data Types

According to Zama FHEVM, the available types are:

| Internal Type | External Type | SDK Method | Usage in StakingManager |
|--------------|--------------|------------|----------------------|
| `euint8` | `externalEuint8` | `add8()` | Not used |
| `euint16` | `externalEuint16` | `add16()` | Not used |
| `euint32` | `externalEuint32` | `add32()` | Not used |
| `euint64` | `externalEuint64` | `add64()` | ✅ Stake amount |
| `euint256` | `externalEuint256` | `add256()` | ✅ Owner address |
| `ebool` | `externalEbool` | `addBool()` | ✅ Initial active status |

**Note on addresses**: Ethereum addresses (20 bytes = 160 bits) are encrypted as `externalEuint256` because they are represented as `uint256` in Solidity. The SDK must use `add256()` for addresses.

## Conversion of External to Internal Data

All external data is converted using `FHE.fromExternal()`:

```solidity
euint64 encryptedAmount = FHE.fromExternal(inputEncryptedAmount, inputAmountProof);
euint256 encryptedOwner = FHE.fromExternal(inputEncryptedOwner, inputOwnerProof);
ebool encryptedIsActive = FHE.fromExternal(inputEncryptedIsActive, inputActiveProof);
```

## Encrypted Ownership Verification

Ownership verification is done by comparing encrypted addresses:

```solidity
euint256 callerEncrypted = FHE.fromExternal(inputEncryptedOwner, inputOwnerProof);
euint256 ownerEncrypted = stakeOwner[stakeId];
ebool isOwner = FHE.eq(callerEncrypted, ownerEncrypted);
```

**Note**: Decryption of `isOwner` must be done externally. For the MVP, we maintain a public verification as fallback.

## Benefits of Receiving Encrypted Data

1. **Improved Privacy**: Data is never exposed in plain text
2. **Less Gas**: No on-chain encryption
3. **Simpler Code**: We eliminate conditional initialization logic
4. **Flexibility**: The client can encrypt data with different parameters
5. **Encrypted Verification**: Enables completely private comparisons

## Data That Does NOT Come Encrypted (Public)

By design, these data remain public:
- `stakeId`: Stake ID (public for indexing)
- `lockPeriod`: Lock period in seconds (public for transparency)
- `lockTimestamp`: Lock timestamp (public for time verification)

## Type Correspondence: External → Internal

**IMPORTANT**: External types must exactly match internal types after `FHE.fromExternal()`:

| External Type (Input) | SDK Method | Internal Type (Storage) | Verification |
|---------------------|------------|------------------------|--------------|
| `externalEuint64` | `add64()` | `euint64` | ✅ Matches |
| `externalEuint256` | `add256()` | `euint256` | ✅ Matches |
| `externalEbool` | `addBool()` | `ebool` | ✅ Matches |

## Client Usage Example (TypeScript)

```typescript
import { FhevmType } from "@fhevm/hardhat-plugin";
import * as hre from "hardhat";

// Helper function to create encrypted inputs
const createStakeInput = async (
  targetContract: string,
  userAddress: string,
  amount: number,
  ownerAddress: string,
  isActive: boolean
) => {
  const stakeInput = hre.fhevm.createEncryptedInput(targetContract, userAddress);
  
  // IMPORTANT: Methods must match the contract's external types
  stakeInput.add64(amount);        // → externalEuint64
  stakeInput.add256(ownerAddress);  // → externalEuint256 (address as uint256)
  stakeInput.addBool(isActive);     // → externalEbool
  
  return await stakeInput.encrypt();
};

// Usage in test/script
const stake = async (signer: HardhatEthersSigner, amount: number) => {
  const encryptedInput = await createStakeInput(
    stakingManagerAddress,
    signer.address,
    amount,
    signer.address,  // owner address
    true             // isActive
  );
  
  const stakeTx = await stakingManager.connect(signer).stake(
    encryptedInput.handles[0],      // externalEuint64 (amount)
    encryptedInput.inputProof,
    encryptedInput.handles[1],       // externalEuint256 (owner)
    encryptedInput.inputProof,
    86400,                           // lockPeriod (1 day)
    encryptedInput.handles[2],       // externalEbool (isActive)
    encryptedInput.inputProof
  );
  
  await stakeTx.wait();
};
```

## Type Verification in Contract

The contract verifies type correspondence at compile time:

```solidity
// ✅ CORRECT: externalEuint64 → euint64
euint64 encryptedAmount = FHE.fromExternal(inputEncryptedAmount, inputAmountProof);

// ✅ CORRECT: externalEuint256 → euint256
euint256 encryptedOwner = FHE.fromExternal(inputEncryptedOwner, inputOwnerProof);

// ✅ CORRECT: externalEbool → ebool
ebool encryptedIsActive = FHE.fromExternal(inputEncryptedIsActive, inputActiveProof);
```

**If types don't match, the Solidity compiler will throw a type error.**
