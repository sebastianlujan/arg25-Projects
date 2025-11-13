# Zama FHE Setup - Setup Guide

This document details the configurations and steps necessary to set up Zama FHE based on the [official template](https://github.com/zama-ai/fhevm-hardhat-template).

## ✅ Changes Made

### 1. `package.json`
- ✅ Added `@fhevm/hardhat-plugin` in devDependencies
- ✅ Added `@zama-fhe/relayer-sdk` in devDependencies
- ✅ Added `@fhevm/solidity` in dependencies
- ✅ Added `encrypted-types` in dependencies
- ✅ Added scripts: `coverage` and `lint`

### 2. `hardhat.config.js`
- ✅ Added `require("@fhevm/hardhat-plugin")` at the top
- ✅ Added `fhevm` configuration section (empty, auto-configured)
- ✅ Set `chainId` to `31337` for Hardhat network (required by FHEVM plugin)
- ✅ Set Solidity version to `0.8.24` (required by Zama FHEVM)

## 📋 Pending Steps

### 1. Install Dependencies

```bash
npm install
```

This will install:

**DevDependencies:**
- `@fhevm/hardhat-plugin` (^0.3.0-0) - Hardhat plugin for FHEVM
- `@zama-fhe/relayer-sdk` (^0.3.0-5) - Zama FHE Relayer SDK

**Dependencies:**
- `@fhevm/solidity` (^0.9.0) - Zama SDK for FHE in Solidity
- `encrypted-types` (^0.0.4) - Encrypted types library

### 2. Configure Environment Variables

Create or update `.env` with the following variables:

```bash
# For local development (optional)
MNEMONIC="your twelve word mnemonic phrase here..."

# For Arbitrum Sepolia (already configured)
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
PRIVATE_KEY=0x...

# For contract verification (optional)
ETHERSCAN_API_KEY=your_etherscan_api_key
```

**Note:** Zama's template uses `npx hardhat vars set` to manage variables securely, but you can also use `.env` with `dotenv`.

### 3. Verify Node.js Version

Zama requires **Node.js >= 20**:

```bash
node --version
```

If you have an earlier version, update Node.js from [nodejs.org](https://nodejs.org/).

### 4. Syntax Differences: Fhenix vs Zama

**⚠️ IMPORTANT:** Your current `VotingFHE.sol` contract uses `@fhenixprotocol/cofhe-contracts`, which is different from Zama FHEVM.

#### Fhenix (current):
```solidity
import {FHE, euint64, InEuint64} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
FHE.euint32 value = FHE.asEuint32(0);
FHE.add(a, b);
```

#### Zama FHEVM (required):
```solidity
import {FHE, euint64, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";
euint64 value = FHE.asEuint64(0);
FHE.add(a, b);
```

**Required action:** You will need to migrate contracts from Fhenix to Zama FHEVM when implementing EVVM Core.

### 5. FHEVM-Compatible Networks

According to Zama's template, compatible networks are:
- **Sepolia Testnet** ✅ (already configured)
- **Localhost** (with FHEVM node)

**Note:** Arbitrum Sepolia may require additional configuration. Check Zama's documentation for Arbitrum support.

### 6. Deploy Scripts

Zama's template uses a `deploy/` folder with deployment scripts. You can create similar scripts:

```javascript
// scripts/deploy-fhe.js
const hre = require("hardhat");

async function main() {
  // The FHEVM plugin handles automatic configuration
  const Contract = await hre.ethers.getContractFactory("YourFHEContract");
  const contract = await Contract.deploy();
  
  await contract.waitForDeployment();
  console.log("Contract deployed to:", await contract.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

### 7. Testing with FHEVM

For tests with FHEVM, you'll need to use the plugin utilities:

```javascript
// test/YourContract.test.js
const { expect } = require("chai");
const hre = require("hardhat");

describe("FHE Contract", function () {
  it("Should work with encrypted values", async function () {
    // The FHEVM plugin provides helpers for testing
    // Check Zama's documentation for specific examples
  });
});
```

## 📚 Resources and Documentation

- **Official template:** https://github.com/zama-ai/fhevm-hardhat-template
- **FHEVM Documentation:** https://docs.zama.org/protocol/solidity-guides/getting-started/overview
- **FHEVM Hardhat Plugin:** https://docs.zama.org/protocol/solidity-guides/hardhat-setup
- **Testing Guide:** https://docs.zama.org/protocol/solidity-guides/testing

## 🔍 Verification

After installing dependencies, verify that everything works:

```bash
# Compile contracts
npm run compile

# If there are errors, verify that dependencies are installed
npm list @fhevm/hardhat-plugin
npm list @zama-fhe/relayer-sdk
npm list @fhevm/solidity
npm list encrypted-types
```

## ⚠️ Important Notes

1. **Fhenix vs Zama:** They are two different FHE implementations. They are not directly compatible.
2. **Arbitrum Support:** Verify if Arbitrum Sepolia is compatible with Zama's FHEVM. You may need to use Sepolia directly.
3. **Migration:** When migrating EVVM Core, you'll need to rewrite contracts to use Zama FHEVM syntax.

## 🚀 Next Steps

1. ✅ Run `npm install` to install dependencies
2. ✅ Configure environment variables
3. ✅ Verify that compilation works
4. ⏳ Clone EVVM repository to analyze original contracts
5. ⏳ Migrate EVVM contracts to Zama FHEVM syntax
6. ⏳ Implement Stylus integration
