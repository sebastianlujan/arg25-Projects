# EVVM Core Deployment Documentation

Complete guide for deploying EVVMCore contracts to Arbitrum Sepolia using Foundry.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Configuration](#configuration)
4. [Deployment Methods](#deployment-methods)
5. [Post-Deployment Setup](#post-deployment-setup)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

## Quick Start

```bash
# 1. Install dependencies
forge install
npm install

# 2. Configure environment
cp .env.example .env
# Edit .env and add your PRIVATE_KEY and RPC URL

# 3. Deploy
make -f Makefile.foundry deploy

# Or with verification
make -f Makefile.foundry deploy-verify
```

## Prerequisites

### 1. Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Install Dependencies

```bash
# Foundry dependencies
forge install

# Node dependencies (for FHEVM)
npm install
```

### 3. Get Testnet Funds

1. **Get Sepolia ETH**: Visit https://sepoliafaucet.com/
2. **Bridge to Arbitrum Sepolia**: Use https://bridge.arbitrum.io/

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```bash
# Required: Deployer private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Required: Arbitrum Sepolia RPC URL
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc

# Optional: For contract verification
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

### Alternative RPC Providers

```bash
# Alchemy
ARBITRUM_SEPOLIA_RPC_URL=https://arb-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Infura
ARBITRUM_SEPOLIA_RPC_URL=https://arbitrum-sepolia.infura.io/v3/YOUR_API_KEY

# QuickNode
ARBITRUM_SEPOLIA_RPC_URL=https://your-endpoint.arbitrum-sepolia.quiknode.pro/YOUR_TOKEN/
```

## Deployment Methods

### Method 1: Using Makefile (Recommended)

The Makefile provides convenient commands for deployment:

```bash
# Check your configuration
make -f Makefile.foundry check-env

# Check deployer balance
make -f Makefile.foundry check-balance

# Simulate deployment (dry run)
make -f Makefile.foundry simulate

# Deploy without verification
make -f Makefile.foundry deploy

# Deploy with verification
make -f Makefile.foundry deploy-verify

# View all available commands
make -f Makefile.foundry help
```

### Method 2: Direct Forge Script

#### Basic Deployment

```bash
forge script script/DeployEVVMCore.s.sol:DeployEVVMCore \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

#### Deploy with Verification

```bash
forge script script/DeployEVVMCore.s.sol:DeployEVVMCore \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

### Method 3: Advanced Deployment

The advanced script allows custom configuration:

```bash
# Deploy with custom chain name and gas limit
forge script script/DeployEVVMCoreAdvanced.s.sol:DeployEVVMCoreAdvanced \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

## Deployment Output

After successful deployment, you'll find:

### 1. Deployment Files

- `deployments/arbitrum-sepolia.txt` - Human-readable deployment info
- `deployments/arbitrum-sepolia.env` - Environment variables format
- `broadcast/DeployEVVMCore.s.sol/<chain-id>/run-latest.json` - Full deployment log

### 2. Contract Address

The deployed contract address will be shown in the console and saved to files:

```
=================================================
Deployment Summary
=================================================
EVVMCore Address: 0x...
Owner: 0x...
Chain Name: EVVM Test Chain
Initial Gas Limit: 30000000
Initialized: true
Current Block Number: 0
=================================================
```

## Post-Deployment Setup

### 1. Verify Deployment

```bash
# Using Makefile
make -f Makefile.foundry call-is-initialized CONTRACT_ADDRESS=0x...
make -f Makefile.foundry call-chain-name CONTRACT_ADDRESS=0x...

# Using cast directly
cast call 0xYourContractAddress "initialized()(bool)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast call 0xYourContractAddress "chainName()(string)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

### 2. Add Validators

```bash
cast send 0xYourContractAddress \
  "addValidator(address)" 0xValidatorAddress \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 3. Set Stylus Engine (Optional)

```bash
cast send 0xYourContractAddress \
  "setStylusEngine(address)" 0xStylusEngineAddress \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 4. Configure Treasury and Staking

```bash
# Set treasury address
cast send 0xYourContractAddress \
  "setTreasuryAddress(address)" 0xTreasuryAddress \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# Set staking contract address
cast send 0xYourContractAddress \
  "setStakingContractAddress(address)" 0xStakingAddress \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 5. Enable Token Whitelist (Optional)

```bash
# Enable whitelist
cast send 0xYourContractAddress \
  "setWhitelistEnabled(bool)" true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# Add token to whitelist
cast send 0xYourContractAddress \
  "addTokenToWhitelist(address)" 0xTokenAddress \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 6. Set EVVM Metadata

This requires encrypted inputs using the FHEVM SDK. Example workflow:

```javascript
// Using FHEVM SDK
import { createInstance } from 'fhevmjs';

// Initialize FHEVM instance
const instance = await createInstance({
  chainId: 421614,
  publicKey: '...', // From FHE gateway
});

// Encrypt metadata values
const encryptedTotalSupply = await instance.encrypt64(1000000);
const encryptedEraTokens = await instance.encrypt64(500000);
const encryptedReward = await instance.encrypt64(100);

// Call initializeEncryptedMetadata with encrypted inputs
```

## Verification

### Automatic Verification

Use the `--verify` flag during deployment:

```bash
forge script script/DeployEVVMCore.s.sol:DeployEVVMCore \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

### Manual Verification

If automatic verification fails:

```bash
# Using Makefile
make -f Makefile.foundry verify-contract CONTRACT_ADDRESS=0x...

# Using forge directly
forge verify-contract \
  --chain-id 421614 \
  --num-of-optimizations 200 \
  --watch \
  --compiler-version v0.8.24 \
  --via-ir \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  0xYourContractAddress \
  contracts/core/EVVMCore.sol:EVVMCore
```

### Check Verification Status

Visit Arbiscan: https://sepolia.arbiscan.io/address/0xYourContractAddress

## Troubleshooting

### Common Issues

#### 1. Insufficient Balance

**Error**: `Deployer has no balance`

**Solution**:
```bash
# Check balance
make -f Makefile.foundry check-balance

# Get testnet funds from faucet
# Then bridge to Arbitrum Sepolia
```

#### 2. RPC Connection Issues

**Error**: `Could not connect to RPC`

**Solution**:
- Try alternative RPC endpoints (Alchemy, Infura, QuickNode)
- Check if the RPC URL is correct in `.env`
- Verify network connectivity

#### 3. Gas Estimation Failed

**Error**: `Gas estimation failed`

**Solution**:
```bash
# Add explicit gas limit
forge script script/DeployEVVMCore.s.sol:DeployEVVMCore \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --gas-limit 10000000 \
  -vvvv
```

#### 4. Verification Failed

**Error**: `Verification failed`

**Solution**:
- Wait 1-2 minutes after deployment
- Try manual verification
- Ensure all constructor arguments are correct
- Check that you're using the correct compiler version and settings

#### 5. FHEVM Dependencies

**Error**: `Cannot find module '@fhevm/solidity'`

**Solution**:
```bash
npm install
forge remappings > remappings.txt
```

### Debug Mode

For detailed debugging information:

```bash
forge script script/DeployEVVMCore.s.sol:DeployEVVMCore \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvvv  # Five v's for maximum verbosity
```

### Get Transaction Receipt

```bash
# Get transaction details
cast receipt <TX_HASH> --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

## Network Information

### Arbitrum Sepolia

- **Chain ID**: 421614
- **Currency**: ETH
- **RPC URL**: https://sepolia-rollup.arbitrum.io/rpc
- **Explorer**: https://sepolia.arbiscan.io/
- **Bridge**: https://bridge.arbitrum.io/
- **Faucet**: Bridge from Sepolia (get Sepolia ETH first)

### Useful Links

- **Sepolia Faucet**: https://sepoliafaucet.com/
- **Arbitrum Docs**: https://docs.arbitrum.io/
- **Foundry Book**: https://book.getfoundry.sh/
- **FHEVM Docs**: https://docs.zama.ai/fhevm

## Security Best Practices

1. **Never commit `.env` file** - It contains your private key
2. **Use burner wallet for testnet** - Don't use mainnet wallets
3. **Verify contract code** - Always verify on Arbiscan
4. **Test thoroughly** - Use simulation before broadcasting
5. **Keep private key secure** - Use hardware wallet for production
6. **Review transaction before signing** - Check gas and parameters

## Support

For issues or questions:

- **Foundry**: https://github.com/foundry-rs/foundry/issues
- **Arbitrum**: https://discord.gg/arbitrum
- **FHEVM**: https://discord.gg/zama

## Additional Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Arbitrum Documentation](https://docs.arbitrum.io/)
- [FHEVM Documentation](https://docs.zama.ai/fhevm)
- [Cast Reference](https://book.getfoundry.sh/reference/cast/)
- [Forge Script Tutorial](https://book.getfoundry.sh/tutorials/solidity-scripting)
