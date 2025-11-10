# Test Cases for EVVMCore

This document describes the test cases based on the original EVVM tests.

## Naming Structure

The original tests use the following nomenclature:
```
test__unit_correct__[function]__[options]
```

Where `[options]` can include:
- **PF**: Includes priority fee
- **nPF**: No priority fee  
- **EX**: Includes executor execution
- **nEX**: Does not include executor execution
- **ID**: Uses a NameService identity
- **AD**: Uses an address

## Test Cases for `pay()`

### Tests without Staker (pay_noStaker)

1. `test__unit_correct__pay_noStaker_sync__nPF_nEX_AD`
   - No priority fee, no executor, using address

2. `test__unit_correct__pay_noStaker_sync__PF_nEX_AD`
   - With priority fee, no executor, using address

3. `test__unit_correct__pay_noStaker_sync__nPF_EX_AD`
   - No priority fee, with executor, using address

4. `test__unit_correct__pay_noStaker_sync__PF_EX_AD`
   - With priority fee, with executor, using address

5. `test__unit_correct__pay_noStaker_sync__nPF_nEX_ID`
   - No priority fee, no executor, using identity

6. `test__unit_correct__pay_noStaker_sync__PF_nEX_ID`
   - With priority fee, no executor, using identity

7. `test__unit_correct__pay_noStaker_sync__nPF_EX_ID`
   - No priority fee, with executor, using identity

8. `test__unit_correct__pay_noStaker_sync__PF_EX_ID`
   - With priority fee, with executor, using identity

### Tests with Staker (pay_staker)

Same cases but with a staker executing the transaction:
- The staker receives the priority fee
- The staker receives rewards

### Async Tests (pay_noStaker_async / pay_staker_async)

Same cases but using async nonces instead of sync.

## Multiple Payments Tests (payMultiple)

Tests that verify multiple payments in a single transaction.

## Disperse Tests (dispersePay)

Tests for dispersed payments to multiple recipients.

## ⚠️ Important Note about FHE

**Current payment tests fail because they use mock encrypted values that don't work with real FHE.**

For these tests to work correctly, you need:

1. **Use the FHE SDK** to generate real encrypted values
2. **Decrypt balances** to verify results
3. **Use valid proofs** from the FHE SDK

The current tests are correctly structured but require real encrypted values from the FHE SDK to execute.

### Resources for FHE Testing

- **`FHE_TESTING_GUIDE.md`**: Complete guide on how to create tests with real FHE
- **`test/EVVMCore_Payments_FHE.test.ts`**: Complete test example with Hardhat + FHE SDK
- **`README.md`**: General test documentation

### Quick Example

```typescript
// Create encrypted value
const encrypted = await fhevm
  .createEncryptedInput(contractAddress, userAddress)
  .add64(1000)
  .encrypt();

// Use in contract
await contract.function(encrypted.handles[0], encrypted.inputProof);

// Decrypt result
const clear = await fhevm.userDecryptEuint(
  FhevmType.euint64,
  encryptedResult,
  contractAddress,
  signer
);
```

## Current Test Status

✅ **Passing Tests:**
- Initialization
- Validators
- Token whitelist
- Administrative functions

❌ **Tests Require Real FHE SDK:**
- Payments (all cases)
- Blocks and transactions (encrypted values)
