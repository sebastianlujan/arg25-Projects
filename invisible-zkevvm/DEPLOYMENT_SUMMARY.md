# EVVMCore Deployment Setup - Summary

This document summarizes the Foundry deployment infrastructure created for deploying EVVMCore to Arbitrum Sepolia.

## Created Files

### 1. Deployment Scripts

#### `script/DeployEVVMCore.s.sol`
- **Purpose**: Basic deployment script for EVVMCore
- **Features**:
  - Deploys EVVMCore contract
  - Initializes virtual chain with default configuration
  - Adds deployer as initial validator
  - Saves deployment addresses to files
- **Usage**: `forge script script/DeployEVVMCore.s.sol:DeployEVVMCore --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast`

#### `script/DeployEVVMCoreAdvanced.s.sol`
- **Purpose**: Advanced deployment with custom configuration
- **Features**:
  - Custom chain name and gas limit
  - Multiple validators can be added during deployment
  - Detailed deployment logging
  - Flexible configuration options
- **Usage**: `forge script script/DeployEVVMCoreAdvanced.s.sol:DeployEVVMCoreAdvanced --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast`

### 2. Documentation

#### `script/README.md`
- Deployment guide
- Environment setup instructions
- Post-deployment configuration steps
- Troubleshooting tips

#### `script/DEPLOYMENT.md`
- Comprehensive deployment documentation
- Multiple deployment methods
- Detailed post-deployment setup
- Security best practices
- Network information

### 3. Build Tools

#### `Makefile.foundry`
- **Purpose**: Convenient deployment commands
- **Key Targets**:
  - `make -f Makefile.foundry help` - Show all commands
  - `make -f Makefile.foundry deploy` - Deploy contract
  - `make -f Makefile.foundry deploy-verify` - Deploy and verify
  - `make -f Makefile.foundry simulate` - Test deployment
  - `make -f Makefile.foundry check-balance` - Check deployer balance
  - `make -f Makefile.foundry status` - Show deployment status

### 4. Configuration

#### `.env.example` (updated)
- Added Foundry-specific environment variables
- PRIVATE_KEY for deployer
- ARBITRUM_SEPOLIA_RPC_URL for network connection
- ETHERSCAN_API_KEY for contract verification

### 5. Directory Structure

```
invisible-zkevvm/
├── script/
│   ├── DeployEVVMCore.s.sol         # Basic deployment script
│   ├── DeployEVVMCoreAdvanced.s.sol # Advanced deployment script
│   ├── README.md                     # Quick deployment guide
│   └── DEPLOYMENT.md                 # Comprehensive documentation
├── deployments/
│   └── .gitkeep                      # Deployment files will be saved here
├── Makefile.foundry                  # Build and deployment commands
├── .env.example                      # Example environment configuration
└── DEPLOYMENT_SUMMARY.md             # This file
```

## Quick Start Guide

### 1. Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install
npm install
```

### 2. Configuration

```bash
# Create .env file
cp .env.example .env

# Edit .env and add:
# - PRIVATE_KEY (your deployer private key)
# - ARBITRUM_SEPOLIA_RPC_URL (RPC endpoint)
# - ETHERSCAN_API_KEY (optional, for verification)
```

### 3. Get Testnet Funds

1. Get Sepolia ETH from https://sepoliafaucet.com/
2. Bridge to Arbitrum Sepolia at https://bridge.arbitrum.io/

### 4. Deploy

```bash
# Method 1: Using Makefile (recommended)
make -f Makefile.foundry deploy

# Method 2: Direct forge command
forge script script/DeployEVVMCore.s.sol:DeployEVVMCore \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv

# Method 3: Deploy with verification
make -f Makefile.foundry deploy-verify
```

### 5. Verify Deployment

```bash
# Check deployment status
make -f Makefile.foundry status

# Query contract (replace with your deployed address)
make -f Makefile.foundry call-is-initialized CONTRACT_ADDRESS=0x...
```

## Deployment Features

### What the Script Does

1. **Validates Environment**
   - Checks you're on Arbitrum Sepolia (chain ID 421614)
   - Verifies deployer has sufficient balance
   - Loads configuration from environment variables

2. **Deploys Contract**
   - Deploys EVVMCore with deployer as owner
   - Constructor initializes admin and timestamp window

3. **Initializes Chain**
   - Calls `initializeVirtualChain()` with:
     - Chain Name: "EVVM Test Chain"
     - Initial Gas Limit: 30,000,000

4. **Sets Up Validators**
   - Adds deployer as initial validator
   - (Advanced script) Can add additional validators

5. **Saves Information**
   - Creates `deployments/arbitrum-sepolia.txt` with deployment details
   - Creates `deployments/arbitrum-sepolia.env` with environment variables
   - Logs transaction details to `broadcast/` directory

### Post-Deployment Configuration

After deployment, you can configure:

- **Add Validators**: `addValidator(address)`
- **Set Stylus Engine**: `setStylusEngine(address)`
- **Configure Treasury**: `setTreasuryAddress(address)`
- **Configure Staking**: `setStakingContractAddress(address)`
- **Token Whitelist**: `addTokenToWhitelist(address)`, `setWhitelistEnabled(bool)`
- **EVVM Metadata**: `setEvvmMetadata(EvvmMetadata)`, `initializeEncryptedMetadata(...)`

See `script/DEPLOYMENT.md` for detailed post-deployment instructions.

## Network Information

**Arbitrum Sepolia**
- Chain ID: 421614
- RPC: https://sepolia-rollup.arbitrum.io/rpc
- Explorer: https://sepolia.arbiscan.io/
- Bridge: https://bridge.arbitrum.io/

## Key Files After Deployment

```
deployments/
├── arbitrum-sepolia.txt           # Human-readable deployment info
├── arbitrum-sepolia.env           # Environment variables
└── arbitrum-sepolia-latest.txt   # Latest deployment (advanced script)

broadcast/
└── DeployEVVMCore.s.sol/
    └── 421614/
        └── run-latest.json        # Complete deployment transaction log
```

## Security Notes

⚠️ **Important Security Considerations**:

1. Never commit `.env` file or private keys to git
2. Use a burner/test wallet for testnet deployments
3. Deployer address becomes contract owner with full privileges
4. Always verify contracts on Arbiscan after deployment
5. Test thoroughly before mainnet deployment

## Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| Insufficient balance | Get testnet ETH from faucet and bridge |
| RPC connection failed | Try alternative RPC (Alchemy, Infura) |
| Gas estimation failed | Add `--gas-limit 10000000` flag |
| Verification failed | Wait 1-2 minutes, then verify manually |
| FHEVM dependencies | Run `npm install` |

See `script/DEPLOYMENT.md` for detailed troubleshooting.

## Support & Resources

- **Foundry**: https://book.getfoundry.sh/
- **Arbitrum**: https://docs.arbitrum.io/
- **FHEVM**: https://docs.zama.ai/fhevm
- **Cast Reference**: https://book.getfoundry.sh/reference/cast/

## Next Steps

1. ✅ Deploy EVVMCore contract
2. ⬜ Deploy or integrate Stylus contracts
3. ⬜ Set up Treasury and Staking contracts
4. ⬜ Configure EVVM metadata with encrypted values
5. ⬜ Add validators
6. ⬜ Enable token whitelist if needed
7. ⬜ Test virtual block and transaction creation
8. ⬜ Integrate with frontend/SDK

---

**Created**: $(date)
**Network**: Arbitrum Sepolia (Testnet)
**Deployment Tool**: Foundry
