require("@nomicfoundation/hardhat-toolbox");
require("@fhevm/hardhat-plugin");

// Cargar variables de entorno si dotenv está disponible
try {
  require("dotenv").config();
} catch (e) {
  // dotenv no está instalado, continuar sin él
}

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 31337, // Required by FHEVM plugin
    },
    // Arbitrum Sepolia (testnet)
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_RPC_URL || "https://sepolia-rollup.arbitrum.io/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 421614,
    },
    // Arbitrum One (mainnet)
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
  // Configuración de FHEVM (Zama)
  fhevm: {
    // Configuración automática para redes compatibles con FHEVM
    // Sepolia testnet es compatible con FHEVM
  },
};

