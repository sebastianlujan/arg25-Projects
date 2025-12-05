#!/bin/bash

# Contract Verification Script for Arbitrum Sepolia
# Usage: ./scripts/verify-contracts.sh <ARBISCAN_API_KEY>

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if API key is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Arbiscan API key required${NC}"
    echo "Usage: ./scripts/verify-contracts.sh <ARBISCAN_API_KEY>"
    echo ""
    echo "Get your API key from: https://arbiscan.io/myapikey"
    exit 1
fi

ARBISCAN_API_KEY="$1"

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Contract Verification - Arbitrum Sepolia ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Contract addresses from deployments
EVVM_CORE_ADDRESS="0xd2c09694f325B821060560A13d538b5B51befC79"
EVVM_CAFHE_ADDRESS="0x06ea9df0472d12d9b3398b5eff2057bfe6da45e8"

RPC_URL="https://sepolia-rollup.arbitrum.io/rpc"
CHAIN_ID="421614"

# Verify EVVMCore (Solidity)
echo -e "${YELLOW}[1/2] Verifying EVVMCore (Solidity)...${NC}"
echo "Address: $EVVM_CORE_ADDRESS"
echo ""

forge verify-contract \
  --chain-id $CHAIN_ID \
  --compiler-version 0.8.24 \
  --num-of-optimizations 200 \
  --via-ir \
  --verifier etherscan \
  --etherscan-api-key "$ARBISCAN_API_KEY" \
  --rpc-url $RPC_URL \
  $EVVM_CORE_ADDRESS \
  contracts/core/EVVMCore.sol:EVVMCore \
  --watch

echo -e "${GREEN}✅ EVVMCore verified!${NC}"
echo "View on Arbiscan: https://sepolia.arbiscan.io/address/$EVVM_CORE_ADDRESS#code"
echo ""

# Verify EVVMCafhe (Stylus)
echo -e "${YELLOW}[2/2] Verifying EVVMCafhe (Stylus Rust contract)...${NC}"
echo "Address: $EVVM_CAFHE_ADDRESS"
echo ""

cd stylus-contracts/evvm-cafhe

cargo stylus verify \
  --deployment-tx $(cast receipt $EVVM_CAFHE_ADDRESS --rpc-url $RPC_URL --field transactionHash) \
  --endpoint $RPC_URL

echo -e "${GREEN}✅ EVVMCafhe verified!${NC}"
echo "View on Arbiscan: https://sepolia.arbiscan.io/address/$EVVM_CAFHE_ADDRESS#code"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✅ All Contracts Verified!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Contract URLs:"
echo "• EVVMCore:  https://sepolia.arbiscan.io/address/$EVVM_CORE_ADDRESS#code"
echo "• EVVMCafhe: https://sepolia.arbiscan.io/address/$EVVM_CAFHE_ADDRESS#code"
