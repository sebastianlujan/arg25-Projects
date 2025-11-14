require("@nomicfoundation/hardhat-toolbox");
// Plugin Fhenix CoFHE
require("cofhe-hardhat-plugin");

// Cargar variables de entorno si dotenv está disponible
try {
  require("dotenv").config();
} catch (e) {
  // dotenv no está instalado, continuar sin él
}

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.25",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true, // Required to fix "Stack too deep" errors
    },
  },
  networks: {
    // Red local de CoFHE
    localcofhe: {
      url: process.env.LOCAL_COFHE_RPC_URL || "http://localhost:8545",
      chainId: 9000,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    // Arbitrum Sepolia con CoFHE
    "arb-sepolia": {
      url: process.env.ARB_SEPOLIA_RPC_URL || process.env.ARBITRUM_SEPOLIA_RPC_URL || "https://sepolia-rollup.arbitrum.io/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 421614,
    },
    // Ethereum Sepolia con CoFHE
    "eth-sepolia": {
      url: process.env.ETH_SEPOLIA_RPC_URL || "https://rpc.sepolia.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111,
    },
    // Arbitrum One (mainnet) - mantener para compatibilidad
    arbitrumOne: {
      url: process.env.ARBITRUM_ONE_RPC_URL || "https://arb1.arbitrum.io/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 42161,
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

