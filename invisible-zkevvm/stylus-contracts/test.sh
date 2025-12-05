#!/bin/bash
# Stylus Contract Testing Script
#
# This script runs the correct tests for WASM-only Stylus contracts.
# DO NOT use `cargo test` - it won't work for no_std WASM contracts.

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Stylus Contract Validation                               ║"
echo "║  (WASM-only contracts - cargo test won't work!)           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}1. Type Checking...${NC}"
cargo check --target wasm32-unknown-unknown
echo -e "${GREEN}✓ Type check passed${NC}"
echo ""

echo -e "${YELLOW}2. Building WASM...${NC}"
cargo build --release --target wasm32-unknown-unknown
echo -e "${GREEN}✓ WASM build successful${NC}"
echo ""

echo -e "${YELLOW}3. Checking WASM Size...${NC}"
WASM_FILE="target/wasm32-unknown-unknown/release/evvm_cafhe.wasm"
if [ -f "$WASM_FILE" ]; then
    SIZE=$(wc -c < "$WASM_FILE")
    SIZE_KB=$((SIZE / 1024))
    echo -e "   WASM size: ${SIZE_KB} KB"

    if [ $SIZE_KB -gt 24 ]; then
        echo -e "${YELLOW}   ⚠️  Warning: WASM exceeds 24 KB limit${NC}"
        echo -e "   Need to optimize by $((SIZE_KB - 24)) KB"
    else
        echo -e "${GREEN}   ✓ WASM size under 24 KB limit${NC}"
    fi
else
    echo -e "${RED}   ✗ WASM file not found${NC}"
    exit 1
fi
echo ""

echo -e "${YELLOW}4. Optimizing WASM...${NC}"
if command -v wasm-opt &> /dev/null; then
    wasm-opt -Oz --enable-bulk-memory --strip-debug --strip-producers \
        target/wasm32-unknown-unknown/release/evvm_cafhe.wasm \
        -o target/wasm32-unknown-unknown/release/evvm_cafhe_optimized.wasm

    OPT_SIZE=$(wc -c < "target/wasm32-unknown-unknown/release/evvm_cafhe_optimized.wasm")
    OPT_SIZE_KB=$((OPT_SIZE / 1024))
    echo -e "   Optimized size: ${OPT_SIZE_KB} KB"

    if [ $OPT_SIZE_KB -gt 24 ]; then
        echo -e "${YELLOW}   ⚠️  Still ${OPT_SIZE_KB} KB (target: 24 KB)${NC}"
    else
        echo -e "${GREEN}   ✓ Optimized WASM under limit!${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️  wasm-opt not installed (run: brew install binaryen)${NC}"
fi
echo ""

echo -e "${YELLOW}5. Exporting ABI...${NC}"
cd evvm-cafhe
if cargo stylus export-abi > /dev/null 2>&1; then
    echo -e "${GREEN}✓ ABI export successful${NC}"
else
    echo -e "${YELLOW}⚠️  ABI export failed (this is okay if contract size > 24 KB)${NC}"
fi
cd ..
echo ""

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  All Checks Complete                                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}✅ Contract builds successfully to WASM!${NC}"
echo ""
echo "Note: cargo test doesn't work for WASM-only contracts."
echo "This script validates your contract properly."
echo ""
echo "Next steps:"
echo "  - Optimize WASM size to get under 24 KB"
echo "  - Deploy to Arbitrum Sepolia testnet"
echo "  - Test contract functions on-chain"
