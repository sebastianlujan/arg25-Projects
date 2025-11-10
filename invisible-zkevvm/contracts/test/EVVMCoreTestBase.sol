// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {externalEuint64, externalEuint256} from "@fhevm/solidity/lib/FHE.sol";
import "../core/EVVMCore.sol";
import "../treasury/TreasuryVault.sol";
import "./Constants.sol";

/**
 * @title EVVMCoreTestBase
 * @notice Base test contract with common setup and helper functions
 * @dev NOTE: In real tests, encrypted values (externalEuint64, externalEuint256) 
 *      must be generated using the FHE SDK. These are placeholders for test structure.
 */
abstract contract EVVMCoreTestBase is Test, Constants {
    EVVMCore public evvmCore;
    TreasuryVault public treasury;
    
    // Mock proof (in real tests, this would be a valid FHE proof)
    bytes constant MOCK_PROOF = hex"00";
    
    function setUp() public virtual {
        // Deploy EVVMCore as ADMIN to make ADMIN the owner
        vm.prank(ADMIN);
        evvmCore = new EVVMCore();
        
        // Deploy Treasury
        treasury = new TreasuryVault(address(evvmCore));
        
        // Initialize EVVM Core
        vm.startPrank(ADMIN);
        evvmCore.initializeVirtualChain(TEST_CHAIN_NAME, TEST_GAS_LIMIT);
        evvmCore.setEvvmID(TEST_EVVM_ID);
        evvmCore.setTreasuryAddress(address(treasury));
        vm.stopPrank();
    }
    
    /**
     * @notice Helper to create mock externalEuint64 for testing
     * @dev WARNING: This is a placeholder. Real tests must use FHE SDK to generate
     *      proper encrypted values. This will not work with actual FHE operations.
     *      In production tests, use: hre.fhevm.createEncryptedInput().add64(value).encrypt()
     *      
     *      NOTE: This function will NOT work with actual FHE operations.
     *      It's only for test structure. Real encrypted values must come from FHE SDK.
     */
    function createMockEncryptedEuint64(uint64 value) internal pure returns (externalEuint64) {
        // This is a placeholder - will cause errors if used with actual FHE operations
        // Real tests MUST use FHE SDK to generate proper encrypted values
        // For now, we use unsafe casting that only works for compilation, not runtime
        bytes32 encoded = bytes32(uint256(value));
        return externalEuint64.wrap(encoded);
    }
    
    /**
     * @notice Helper to create mock externalEuint256 for testing
     * @dev WARNING: This is a placeholder. Real tests must use FHE SDK to generate
     *      proper encrypted values.
     *      In production tests, use: hre.fhevm.createEncryptedInput().add256(value).encrypt()
     */
    function createMockEncryptedEuint256(uint256 value) internal pure returns (externalEuint256) {
        // This is a placeholder - will cause errors if used with actual FHE operations
        // Real tests MUST use FHE SDK to generate proper encrypted values
        bytes32 encoded = bytes32(value);
        return externalEuint256.wrap(encoded);
    }
    
    /**
     * @notice Helper to add balance to a user (via treasury)
     * @dev NOTE: This requires real encrypted values from FHE SDK in production tests
     */
    function addBalanceToUser(
        address user,
        address token,
        uint256 amount
    ) internal {
        // In real tests, this would use properly encrypted amounts from FHE SDK
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(amount));
        vm.prank(address(treasury));
        evvmCore.addAmountToUser(
            user,
            token,
            encryptedAmount,
            MOCK_PROOF
        );
    }
    
    /**
     * @notice Helper to create PaymentParams struct for testing
     */
    function createPaymentParams(
        address from,
        address to,
        string memory toIdentity,
        address token,
        uint256 amountPlaintext,
        externalEuint64 encryptedAmount,
        bytes memory amountProof,
        uint256 priorityFeePlaintext,
        externalEuint64 encryptedFee,
        bytes memory feeProof,
        uint256 nonce,
        bool priorityFlag,
        address executor,
        bytes memory signature
    ) internal pure returns (EVVMCore.PaymentParams memory) {
        return EVVMCore.PaymentParams({
            from: from,
            to: to,
            toIdentity: toIdentity,
            token: token,
            amountPlaintext: amountPlaintext,
            inputEncryptedAmount: encryptedAmount,
            inputAmountProof: amountProof,
            priorityFeePlaintext: priorityFeePlaintext,
            inputEncryptedPriorityFee: encryptedFee,
            inputFeeProof: feeProof,
            nonce: nonce,
            priorityFlag: priorityFlag,
            executor: executor,
            signature: signature
        });
    }
}

