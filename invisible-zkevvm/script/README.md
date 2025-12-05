# EVVMCore Deployment Guide

This guide covers deploying the EVVMCore contract to Arbitrum Sepolia using Foundry.

## Prerequisites

1. **Foundry**: Install Foundry if you haven't already
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Dependencies**: Install project dependencies
   ```bash
   forge install
   npm install  # For FHEVM dependencies
   ```

3. **Environment Setup**: Create a `.env` file in the project root

## Environment Configuration

Create a `.env` file in the project root with the following variables:

```bash
# Deployer private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Arbitrum Sepolia RPC URL
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
# Alternative: Use Alchemy or Infura
# ARBITRUM_SEPOLIA_RPC_URL=https://arb-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Etherscan API key for contract verification (optional)
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

## Getting Testnet Funds

You'll need Arbitrum Sepolia ETH to deploy:

1. **Get Sepolia ETH**: https://sepoliafaucet.com/
2. **Bridge to Arbitrum Sepolia**: https://bridge.arbitrum.io/

## Deployment Steps

### 1. Dry Run (Simulation)

Test the deployment without broadcasting transactions:

```bash
forge script script/DeployEVVMCore.s.sol:DeployEVVMCore \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  -vvvv
```

### 2. Deploy to Arbitrum Sepolia

Deploy the contract (this will broadcast transactions):

```bash
forge script script/DeployEVVMCore.s.sol:DeployEVVMCore \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv
```

### 3. Deploy and Verify

Deploy and verify the contract on Arbiscan:

```bash
forge script script/DeployEVVMCore.s.sol:DeployEVVMCore \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

## What Gets Deployed

The deployment script performs the following actions:

1. **Deploys EVVMCore**: Creates a new instance of the EVVMCore contract
2. **Initializes Chain**: Calls `initializeVirtualChain()` with:
   - Chain Name: "EVVM Test Chain"
   - Initial Gas Limit: 30,000,000
3. **Adds Validator**: Adds the deployer address as the first validator
4. **Saves Addresses**: Writes deployment addresses to:
   - `deployments/arbitrum-sepolia.txt`
   - `deployments/arbitrum-sepolia.env`

## Post-Deployment Configuration

After deployment, you may want to:

### 1. Set Stylus Engine (Optional)
```bash
cast send <EVVM_CORE_ADDRESS> \
  "setStylusEngine(address)" <STYLUS_ENGINE_ADDRESS> \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 2. Add More Validators
```bash
cast send <EVVM_CORE_ADDRESS> \
  "addValidator(address)" <VALIDATOR_ADDRESS> \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 3. Set EVVM Metadata
```bash
# First prepare encrypted metadata using FHEVM SDK
# Then call setEvvmMetadata with the prepared data
```

### 4. Configure Token Whitelist
```bash
# Enable whitelist
cast send <EVVM_CORE_ADDRESS> \
  "setWhitelistEnabled(bool)" true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# Add tokens to whitelist
cast send <EVVM_CORE_ADDRESS> \
  "addTokenToWhitelist(address)" <TOKEN_ADDRESS> \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

## Verification

### Manual Verification

If automatic verification fails, verify manually:

```bash
forge verify-contract \
  --chain-id 421614 \
  --num-of-optimizations 200 \
  --watch \
  --compiler-version v0.8.24 \
  --via-ir \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  <CONTRACT_ADDRESS> \
  contracts/core/EVVMCore.sol:EVVMCore
```

### Check Deployment

Verify the deployment was successful:

```bash
# Check owner
cast call <EVVM_CORE_ADDRESS> "owner()(address)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check if initialized
cast call <EVVM_CORE_ADDRESS> "initialized()(bool)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check chain name
cast call <EVVM_CORE_ADDRESS> "chainName()(string)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL

# Check current block number
cast call <EVVM_CORE_ADDRESS> "getCurrentBlockNumber()(uint64)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

## Troubleshooting

### Common Issues

1. **Insufficient Funds**: Make sure your deployer address has enough Arbitrum Sepolia ETH
2. **RPC Issues**: Try alternative RPC endpoints (Alchemy, Infura, QuickNode)
3. **Verification Failed**: Wait a few minutes and try manual verification
4. **Gas Estimation Failed**: The contract uses FHEVM which may cause estimation issues. Try adding `--gas-limit 10000000`

### Get Help

- Foundry Book: https://book.getfoundry.sh/
- Arbitrum Docs: https://docs.arbitrum.io/
- FHEVM Docs: https://docs.zama.ai/fhevm

## Deployment Artifacts

After successful deployment, find:

- Transaction receipts: `broadcast/DeployEVVMCore.s.sol/<chain-id>/run-latest.json`
- Deployment addresses: `deployments/arbitrum-sepolia.txt`
- Environment variables: `deployments/arbitrum-sepolia.env`

## Network Information

**Arbitrum Sepolia**
- Chain ID: 421614
- RPC URL: https://sepolia-rollup.arbitrum.io/rpc
- Explorer: https://sepolia.arbiscan.io/
- Faucet: Bridge from Sepolia ETH

## Security Notes

⚠️ **Important**:
- Never commit your `.env` file
- Keep your private key secure
- Use a burner wallet for testnet deployments
- The deployer address becomes the contract owner
- The owner has privileged access to critical functions
