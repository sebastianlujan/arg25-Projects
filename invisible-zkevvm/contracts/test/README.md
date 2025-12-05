# Tests for EVVMCore

This directory contains tests for the `EVVMCore.sol` contract migrated to the new FHE implementation.

## Test Structure

- `Constants.sol` - Shared constants and test data
- `EVVMCoreTestBase.sol` - Base class with common setup and helpers
- `EVVMCore_Initialization.t.sol` - Initialization tests
- `EVVMCore_Validators.t.sol` - Validator management tests
- `EVVMCore_TokenWhitelist.t.sol` - Token whitelist tests
- `EVVMCore_Payments.t.sol` - Payment and signature verification tests
- `EVVMCore_BlocksAndTransactions.t.sol` - Block and transaction tests
- `EVVMCore_AdminFunctions.t.sol` - Administrative function tests

## ⚠️ Important: Encrypted Values

Current tests use mock values for `externalEuint64` and `externalEuint256`. **These will NOT work with real FHE operations**.

For functional tests with real FHE, see:
- **`FHE_TESTING_GUIDE.md`**: Complete FHE testing guide
- **`test/EVVMCore_Payments_FHE.test.ts`**: Test example with Hardhat + FHE SDK

### Basic FHE SDK Usage

1. **Use the FHE SDK** to generate encrypted values:

```typescript
// In TypeScript/JavaScript tests with Hardhat
import * as hre from "hardhat";

const createEncryptedInput = async (contractAddress: string, userAddress: string) => {
  const encryptedInput = hre.fhevm.createEncryptedInput(contractAddress, userAddress);
  encryptedInput.add64(1000);  // For externalEuint64
  encryptedInput.add256(1000000);  // For externalEuint256
  return await encryptedInput.encrypt();
};

// Usage in test
const encrypted = await createEncryptedInput(evvmCoreAddress, userAddress);
await evvmCore.pay(
  from,
  to,
  "",
  token,
  amountPlaintext,
  encrypted.handles[0],  // externalEuint64
  encrypted.inputProof,
  feePlaintext,
  encrypted.handles[1],  // externalEuint64
  encrypted.inputProof,
  nonce,
  true,
  address(0),
  signature
);
```

2. **Or use Foundry with FHE helpers** (if available)

## Running Tests

```bash
# With Foundry
forge test --match-path contracts/test/*.t.sol

# With Hardhat (for tests with FHE SDK)
npx hardhat test
```

## Notes

- Structure tests are complete and verify contract logic
- For complete functional tests, replace mock values with real encrypted values from the SDK
- Signature verification tests require valid EIP-191 signatures generated with the official EVVM library
