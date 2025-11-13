# Quick Deploy - EVVMCore to Arbitrum Sepolia

One-page quick reference for deploying EVVMCore using Foundry.

## Prerequisites Checklist

- [ ] Foundry installed (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)
- [ ] Dependencies installed (`forge install && npm install`)
- [ ] `.env` file configured with `PRIVATE_KEY` and `ARBITRUM_SEPOLIA_RPC_URL`
- [ ] Testnet ETH in deployer wallet (from https://sepoliafaucet.com/ + bridge)

## Deploy in 3 Commands

```bash
# 1. Check your balance
make -f Makefile.foundry check-balance

# 2. Test deployment (simulation)
make -f Makefile.foundry simulate

# 3. Deploy for real
make -f Makefile.foundry deploy
```

## Alternative: Deploy with Verification

```bash
make -f Makefile.foundry deploy-verify
```

## Alternative: Direct Forge Command

```bash
forge script script/DeployEVVMCore.s.sol:DeployEVVMCore \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

## After Deployment

Your contract addresses are saved in:
- `deployments/arbitrum-sepolia.txt`
- `deployments/arbitrum-sepolia.env`

## Verify Deployment

```bash
# Check status
make -f Makefile.foundry status

# Or manually
CONTRACT_ADDRESS=<your_address>
cast call $CONTRACT_ADDRESS "initialized()(bool)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
cast call $CONTRACT_ADDRESS "chainName()(string)" --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

## Common Post-Deployment Tasks

### Add a Validator
```bash
cast send $CONTRACT_ADDRESS \
  "addValidator(address)" <validator_address> \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Set Stylus Engine
```bash
cast send $CONTRACT_ADDRESS \
  "setStylusEngine(address)" <stylus_address> \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Enable Token Whitelist
```bash
cast send $CONTRACT_ADDRESS \
  "setWhitelistEnabled(bool)" true \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

## Troubleshooting Quick Fixes

| Problem | Solution |
|---------|----------|
| No balance | Get Sepolia ETH from faucet, then bridge to Arbitrum Sepolia |
| RPC error | Use alternative: Alchemy or Infura RPC URL |
| Gas failed | Add flag: `--gas-limit 10000000` |
| Verify failed | Wait 2 min, then: `make -f Makefile.foundry verify-contract CONTRACT_ADDRESS=0x...` |

## Environment Variables (.env)

```bash
PRIVATE_KEY=your_key_here_without_0x
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
ETHERSCAN_API_KEY=your_api_key_here
```

## Network Info

- **Chain ID**: 421614
- **Explorer**: https://sepolia.arbiscan.io/
- **Bridge**: https://bridge.arbitrum.io/
- **Faucet**: https://sepoliafaucet.com/ (get Sepolia ETH first)

## Get Help

- Full docs: `script/DEPLOYMENT.md`
- All commands: `make -f Makefile.foundry help`
- Foundry book: https://book.getfoundry.sh/

---

**That's it!** 🚀 Your EVVMCore contract is ready to deploy to Arbitrum Sepolia.
