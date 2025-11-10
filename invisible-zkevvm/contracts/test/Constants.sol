// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Constants
 * @notice Shared constants and test data for EVVMCore tests
 */
abstract contract Constants {
    // Token addresses
    address constant ETHER_ADDRESS = address(0);
    address constant PRINCIPAL_TOKEN_ADDRESS = address(1);
    
    // Test accounts (using Foundry default accounts)
    address constant ADMIN = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant USER1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant USER2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address constant VALIDATOR1 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address constant VALIDATOR2 = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    address constant STAKER1 = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
    address constant EXECUTOR = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
    
    // Test token addresses
    address constant TEST_TOKEN1 = address(0x1000);
    address constant TEST_TOKEN2 = address(0x2000);
    
    // Test values
    uint256 constant TEST_EVVM_ID = 777;
    string constant TEST_CHAIN_NAME = "TestChain";
    uint256 constant TEST_GAS_LIMIT = 1000000;
    uint256 constant TEST_AMOUNT = 1000;
    uint256 constant TEST_PRIORITY_FEE = 100;
    uint256 constant TEST_NONCE = 1;
    
    // Helper function to get private keys (for signature testing)
    // Note: In real tests, these would be used with vm.sign() or similar
    uint256 constant ADMIN_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant USER1_PRIVATE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
}

