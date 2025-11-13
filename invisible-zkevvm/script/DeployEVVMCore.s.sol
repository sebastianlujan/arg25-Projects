// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/core/EVVMCore.sol";

/**
 * @title Deploy EVVMCore Script
 * @notice Foundry deployment script for EVVMCore contract on Arbitrum Sepolia
 * @dev Usage:
 *   1. Set environment variables in .env file:
 *      - PRIVATE_KEY: Deployer private key
 *      - ARBITRUM_SEPOLIA_RPC_URL: RPC endpoint for Arbitrum Sepolia
 *      - ETHERSCAN_API_KEY (optional): For contract verification
 *
 *   2. Deploy:
 *      forge script script/DeployEVVMCore.s.sol:DeployEVVMCore --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast --verify -vvvv
 *
 *   3. Or using the helper command:
 *      forge script script/DeployEVVMCore.s.sol:DeployEVVMCore --rpc-url arbitrum-sepolia --broadcast --verify -vvvv
 */
contract DeployEVVMCore is Script {
    // Deployment configuration
    string constant CHAIN_NAME = "EVVM Test Chain";
    uint256 constant INITIAL_GAS_LIMIT = 30_000_000; // 30M gas limit for virtual blocks

    // Arbitrum Sepolia Chain ID
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

    function run() external {
        // Verify we're on Arbitrum Sepolia
        require(
            block.chainid == ARBITRUM_SEPOLIA_CHAIN_ID,
            "Not on Arbitrum Sepolia network"
        );

        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=================================================");
        console.log("Deploying EVVMCore Contract");
        console.log("=================================================");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Chain ID:", block.chainid);
        console.log("Chain Name:", CHAIN_NAME);
        console.log("Initial Gas Limit:", INITIAL_GAS_LIMIT);
        console.log("=================================================");

        // Ensure deployer has enough balance
        require(deployer.balance > 0, "Deployer has no balance");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy EVVMCore contract
        console.log("\nDeploying EVVMCore...");
        EVVMCore evvmCore = new EVVMCore();
        console.log("EVVMCore deployed at:", address(evvmCore));

        // Initialize the virtual chain
        console.log("\nInitializing virtual chain...");
        evvmCore.initializeVirtualChain(CHAIN_NAME, INITIAL_GAS_LIMIT);
        console.log("Virtual chain initialized successfully");

        // Add deployer as initial validator
        console.log("\nAdding deployer as initial validator...");
        evvmCore.addValidator(deployer);
        console.log("Deployer added as validator");

        vm.stopBroadcast();

        // Log deployment information
        console.log("\n=================================================");
        console.log("Deployment Summary");
        console.log("=================================================");
        console.log("EVVMCore Address:", address(evvmCore));
        console.log("Owner:", evvmCore.owner());
        console.log("Chain Name:", evvmCore.chainName());
        console.log("Initial Gas Limit:", evvmCore.initialGasLimit());
        console.log("Initialized:", evvmCore.initialized());
        console.log("Current Block Number:", evvmCore.getCurrentBlockNumber());
        console.log("=================================================");

        // Save deployment addresses to file
        string memory deploymentInfo = string.concat(
            "EVVMCore=",
            vm.toString(address(evvmCore)),
            "\n"
        );

        vm.writeFile("./deployments/arbitrum-sepolia.txt", deploymentInfo);
        console.log("\nDeployment addresses saved to: ./deployments/arbitrum-sepolia.txt");

        // Export as environment variables format
        string memory envFormat = string.concat(
            "EVVM_CORE_ADDRESS=",
            vm.toString(address(evvmCore)),
            "\n"
        );

        vm.writeFile("./deployments/arbitrum-sepolia.env", envFormat);
        console.log("Environment variables saved to: ./deployments/arbitrum-sepolia.env");
    }
}
