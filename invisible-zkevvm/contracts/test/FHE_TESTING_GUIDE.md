# FHE Testing Guide for EVVMCore

This guide explains how to create functional tests with real FHE using Zama's SDK.

## Test Structure

### Tests with Foundry (Current Structure)

Current tests in `contracts/test/` use Foundry and mock values. These tests:
- ✅ Verify contract structure and logic
- ✅ Validate permissions and access controls
- ❌ Do NOT work with real FHE operations (use mock values)

### Tests with Hardhat + FHE SDK (Recommended for FHE)

For functional tests with real FHE, use Hardhat with the `@fhevm/hardhat-plugin` plugin.

## FHE Test Example

See `test/EVVMCore_Payments_FHE.test.ts` for a complete example.

### Basic Pattern

```typescript
import { fhevm } from "hardhat";
import { FhevmType } from "@fhevm/hardhat-plugin";

// 1. Create encrypted value
const encryptedAmount = await fhevm
  .createEncryptedInput(contractAddress, userAddress)
  .add64(1000)  // For externalEuint64
  .encrypt();

// 2. Use in contract call
await contract.function(
  encryptedAmount.handles[0],  // externalEuint64
  encryptedAmount.inputProof   // proof
);

// 3. Decrypt result
const encryptedResult = await contract.getBalance(userAddress, token);
const clearResult = await fhevm.userDecryptEuint(
  FhevmType.euint64,
  encryptedResult,
  contractAddress,
  signer
);
```

## FHE Data Types

| Internal Type | External Type | SDK Method | Usage in EVVMCore |
|--------------|--------------|------------|-----------------|
| `euint64` | `externalEuint64` | `add64()` | ✅ Payment amounts, balances |
| `euint256` | `externalEuint256` | `add256()` | ✅ Gas limits, transaction values |
| `ebool` | `externalEbool` | `addBool()` | Not used in EVVMCore |

## Test Cases to Implement

Based on the original tests, these are the main cases:

### 1. Payments without Staker (pay_noStaker)

- `nPF_nEX_AD`: No priority fee, no executor, using address
- `PF_nEX_AD`: With priority fee, no executor, using address
- `nPF_EX_AD`: No priority fee, with executor, using address
- `PF_EX_AD`: With priority fee, with executor, using address
- `nPF_nEX_ID`: No priority fee, no executor, using identity
- `PF_nEX_ID`: With priority fee, no executor, using identity
- `nPF_EX_ID`: No priority fee, with executor, using identity
- `PF_EX_ID`: With priority fee, with executor, using identity

### 2. Payments with Staker (pay_staker)

Same cases but with a staker executing the transaction.

### 3. Async Payments (pay_async)

Same cases but using async nonces.

## Recommended Helpers

```typescript
// Helper to create encrypted values
async function createEncryptedEuint64(
  contractAddress: string,
  userAddress: string,
  value: number
) {
  return await fhevm
    .createEncryptedInput(contractAddress, userAddress)
    .add64(value)
    .encrypt();
}

// Helper to decrypt balances
async function decryptBalance(
  contractAddress: string,
  userAddress: string,
  tokenAddress: string,
  signer: HardhatEthersSigner
): Promise<number> {
  const encryptedBalance = await evvmCore.getBalance(userAddress, tokenAddress);
  return await fhevm.userDecryptEuint(
    FhevmType.euint64,
    encryptedBalance,
    contractAddress,
    signer
  );
}

// Helper to add balance
async function addBalanceToUser(
  userAddress: string,
  tokenAddress: string,
  amount: number
) {
  const encrypted = await createEncryptedEuint64(
    treasuryAddress,
    userAddress,
    amount
  );
  await treasury
    .connect(admin)
    .addAmountToUser(
      userAddress,
      tokenAddress,
      encrypted.handles[0],
      encrypted.inputProof
    );
}
```

## Signature Verification

For tests with signature verification, you need:

1. **Enable signature verification**:
```typescript
await evvmCore.connect(admin).setSignatureVerificationRequired(true);
```

2. **Create EIP-191 signature**:
```typescript
const evvmID = await evvmCore.evvmID();
const message = `${evvmID},pay,${to},${token},${amount},${fee},${nonce},${priorityFlag},${executor}`;
const signature = await signer.signMessage(ethers.getBytes(ethers.toUtf8Bytes(message)));
```

3. **Include in PaymentParams**:
```typescript
const paymentParams = {
  // ... other parameters
  amountPlaintext: amount,  // Required for verification
  priorityFeePlaintext: fee, // Required for verification
  signature: signature,
};
```

## Supported Networks

- ✅ **Sepolia Testnet**: FHE SDK works completely
- ❌ **Hardhat Local**: Mock only (no real FHE)
- ⚠️ **Other networks**: Verify FHE support

## Running Tests

```bash
# Tests with Hardhat (real FHE)
npx hardhat test test/EVVMCore_Payments_FHE.test.ts --network sepolia

# Tests with Foundry (structure, no real FHE)
forge test
```

## Important Notes

1. **Execution time**: FHE tests are slower (30-40s per test)
2. **Gas cost**: FHE operations consume more gas
3. **Privacy**: With signature verification enabled, `amountPlaintext` and `priorityFeePlaintext` are visible in calldata
4. **Decryption**: Only the authorized user can decrypt their balances
