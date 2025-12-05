# Monorepo Structure

This project is a monolithic repository that contains both **Solidity** smart contracts (using Hardhat) and **Stylus** contracts (using Rust).

## Folder Structure

```
invisible-zkevvm/
├── contracts/          # Solidity contracts
├── scripts/            # Deployment scripts (Hardhat)
├── test/               # Tests for Solidity contracts
├── src/                # Stylus source code (Rust)
├── examples/           # Stylus examples
├── hardhat.config.js   # Hardhat configuration
├── package.json        # Node.js/Hardhat dependencies
├── Cargo.toml          # Rust/Stylus dependencies
└── rust-toolchain.toml # Rust toolchain version
```

## Working with Solidity (Hardhat)

### Installation

```bash
npm install
```

### Compile contracts

```bash
npm run compile
# or
npx hardhat compile
```

### Run tests

```bash
npm test
# or
npx hardhat test
```

### Deploy contracts

```bash
npm run deploy -- --network arbitrumSepolia
# or
npx hardhat run scripts/deploy.js --network arbitrumSepolia
```

### Available networks

- `hardhat`: Local development network
- `arbitrumSepolia`: Arbitrum Sepolia testnet
- `arbitrumOne`: Arbitrum One mainnet

**Note**: You'll need to configure environment variables in a `.env` file:
```
PRIVATE_KEY=your_private_key
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
ARBITRUM_ONE_RPC_URL=https://arb1.arbitrum.io/rpc
```

## Working with Stylus (Rust)

### Compile Stylus contracts

```bash
cargo stylus build
```

### Verify contracts

```bash
cargo stylus check
```

### Deploy Stylus contracts

```bash
cargo stylus deploy
```

### Run tests

```bash
cargo test
```

## Workflow

### Solidity Development

1. Write your contracts in `contracts/`
2. Create tests in `test/`
3. Run `npm test` to test
4. Deploy with `npm run deploy`

### Stylus Development

1. Write your contracts in `src/lib.rs` or `examples/`
2. Create tests in the same file using `#[cfg(test)]`
3. Run `cargo test` to test
4. Compile with `cargo stylus build`
5. Deploy with `cargo stylus deploy`

## Advantages of this Monorepo

- ✅ Single repository for both contract types
- ✅ Share code and utilities between projects
- ✅ Unified testing
- ✅ Centralized dependency management
- ✅ Easy comparison between Solidity and Stylus implementations

## Example: Counter

This monorepo includes Counter contract implementations in both Solidity (`contracts/Counter.sol`) and Stylus (`src/lib.rs`), allowing comparison of both approaches.
