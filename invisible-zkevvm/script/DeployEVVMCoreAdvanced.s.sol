// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/core/EVVMCore.sol";

/**
 * @title Advanced Deploy EVVMCore Script
 * @notice Advanced Foundry deployment script with full configuration options
 * @dev Usage:
 *   Deploy with custom configuration:
 *   forge script script/DeployEVVMCoreAdvanced.s.sol:DeployEVVMCoreAdvanced \
 *     --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
 *     --broadcast \
 *     --verify \
 *     -vvvv \
 *     --sig "run(string,uint256,address[])" \
 *     "My EVVM Chain" \
 *     50000000 \
 *     "[0x...,0x...]"
 */
contract DeployEVVMCoreAdvanced is Script {
    // Arbitrum Sepolia Chain ID
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

    // Default configuration
    string public defaultChainName = "EVVM Chain";
    uint256 public defaultGasLimit = 30_000_000;

    /**
     * @notice Deploy with default configuration
     */
    function run() external {
        address[] memory validators = new address[](0);
        _deploy(defaultChainName, defaultGasLimit, validators);
    }

    /**
     * @notice Deploy with custom configuration
     * @param chainName Name of the virtual chain
     * @param initialGasLimit Initial gas limit for blocks
     * @param additionalValidators Array of validator addresses to add (beyond deployer)
     */
    function run(
        string memory chainName,
        uint256 initialGasLimit,
        address[] memory additionalValidators
    ) external {
        _deploy(chainName, initialGasLimit, additionalValidators);
    }

    /**
     * @notice Internal deployment function
     */
    function _deploy(
        string memory chainName,
        uint256 initialGasLimit,
        address[] memory additionalValidators
    ) internal {
        // Verify we're on Arbitrum Sepolia
        require(
            block.chainid == ARBITRUM_SEPOLIA_CHAIN_ID,
            "Not on Arbitrum Sepolia network"
        );

        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=================================================");
        console.log("Advanced EVVMCore Deployment");
        console.log("=================================================");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        console.log("Chain ID:", block.chainid);
        console.log("Chain Name:", chainName);
        console.log("Gas Limit:", initialGasLimit);
        console.log("Additional Validators:", additionalValidators.length);
        console.log("=================================================");

        require(deployer.balance > 0, "Deployer has no balance");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy EVVMCore
        console.log("\n[1/4] Deploying EVVMCore...");
        EVVMCore evvmCore = new EVVMCore();
        console.log("    Deployed at:", address(evvmCore));

        // Initialize virtual chain
        console.log("\n[2/4] Initializing virtual chain...");
        evvmCore.initializeVirtualChain(chainName, initialGasLimit);
        console.log("    Initialized successfully");

        // Add deployer as validator
        console.log("\n[3/4] Adding deployer as validator...");
        evvmCore.addValidator(deployer);
        console.log("    Deployer added");

        // Add additional validators
        console.log("\n[4/4] Adding additional validators...");
        for (uint256 i = 0; i < additionalValidators.length; i++) {
            if (additionalValidators[i] != address(0) && additionalValidators[i] != deployer) {
                evvmCore.addValidator(additionalValidators[i]);
                console.log("    Added validator:", additionalValidators[i]);
            }
        }

        vm.stopBroadcast();

        // Display deployment summary
        _logDeploymentSummary(evvmCore, deployer, additionalValidators);

        // Save deployment information
        _saveDeploymentInfo(evvmCore, deployer, additionalValidators);
    }

    /**
     * @notice Log deployment summary
     */
    function _logDeploymentSummary(
        EVVMCore evvmCore,
        address deployer,
        address[] memory additionalValidators
    ) internal view {
        console.log("\n=================================================");
        console.log("Deployment Summary");
        console.log("=================================================");
        console.log("Contract Address:", address(evvmCore));
        console.log("Owner:", evvmCore.owner());
        console.log("Chain Name:", evvmCore.chainName());
        console.log("Gas Limit:", evvmCore.initialGasLimit());
        console.log("Initialized:", evvmCore.initialized());
        console.log("Block Number:", evvmCore.getCurrentBlockNumber());
        console.log("Next Tx ID:", evvmCore.getNextTxId());
        console.log("\nValidators:");
        console.log("  - Deployer:", deployer);
        for (uint256 i = 0; i < additionalValidators.length; i++) {
            if (additionalValidators[i] != address(0) && additionalValidators[i] != deployer) {
                console.log("  - Validator:", additionalValidators[i]);
            }
        }
        console.log("=================================================");
    }

    /**
     * @notice Save deployment information to files
     */
    function _saveDeploymentInfo(
        EVVMCore evvmCore,
        address deployer,
        address[] memory additionalValidators
    ) internal {
        string memory timestamp = vm.toString(block.timestamp);

        // Save to text file
        string memory textContent = string.concat(
            "=================================================\n",
            "EVVM Core Deployment - Arbitrum Sepolia\n",
            "=================================================\n",
            "Deployment Time: ", timestamp, "\n",
            "Contract Address: ", vm.toString(address(evvmCore)), "\n",
            "Owner: ", vm.toString(deployer), "\n",
            "Chain Name: ", evvmCore.chainName(), "\n",
            "Gas Limit: ", vm.toString(evvmCore.initialGasLimit()), "\n",
            "\nValidators:\n",
            "  - ", vm.toString(deployer), " (deployer)\n"
        );

        for (uint256 i = 0; i < additionalValidators.length; i++) {
            if (additionalValidators[i] != address(0) && additionalValidators[i] != deployer) {
                textContent = string.concat(
                    textContent,
                    "  - ", vm.toString(additionalValidators[i]), "\n"
                );
            }
        }

        vm.writeFile("./deployments/arbitrum-sepolia-latest.txt", textContent);

        // Save to env file
        string memory envContent = string.concat(
            "EVVM_CORE_ADDRESS=", vm.toString(address(evvmCore)), "\n",
            "EVVM_OWNER_ADDRESS=", vm.toString(deployer), "\n",
            "EVVM_CHAIN_NAME=\"", evvmCore.chainName(), "\"\n",
            "EVVM_GAS_LIMIT=", vm.toString(evvmCore.initialGasLimit()), "\n"
        );

        vm.writeFile("./deployments/arbitrum-sepolia-latest.env", envContent);

        console.log("\nDeployment info saved:");
        console.log("  - ./deployments/arbitrum-sepolia-latest.txt");
        console.log("  - ./deployments/arbitrum-sepolia-latest.env");
    }
}
