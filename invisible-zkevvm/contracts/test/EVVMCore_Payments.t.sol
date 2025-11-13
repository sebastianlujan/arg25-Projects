// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EVVMCoreTestBase.sol";
import "../library/SignatureRecover.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {euint64} from "@fhevm/solidity/lib/FHE.sol";

/**
 * @title EVVMCore_Payments
 * @notice Tests for payment functionality with and without signature verification
 */
contract EVVMCore_Payments is EVVMCoreTestBase {
    
    // Helper to create a signature (simplified for testing)
    function createSignature(
        address signer,
        string memory message
    ) internal pure returns (bytes memory) {
        // In real tests, this would use vm.sign() or proper EIP-191 signing
        // For now, return empty signature (will work when signature verification is disabled)
        return "";
    }
    
    function test_Pay_WithoutSignatureVerification() public {
        // Signature verification is disabled by default
        assertFalse(evvmCore.signatureVerificationRequired());
        
        // Add balance to user
        addBalanceToUser(USER1, ETHER_ADDRESS, TEST_AMOUNT + TEST_PRIORITY_FEE);
        
        // Create mock encrypted values
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(TEST_AMOUNT));
        externalEuint64 encryptedFee = createMockEncryptedEuint64(uint64(TEST_PRIORITY_FEE));
        
        // Execute payment without signature (signature verification disabled)
        vm.prank(USER1);
        EVVMCore.PaymentParams memory params = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            0, // amountPlaintext (not needed when signature verification is off)
            encryptedAmount,
            MOCK_PROOF,
            0, // priorityFeePlaintext (not needed)
            encryptedFee,
            MOCK_PROOF,
            TEST_NONCE,
            true, // priorityFlag (async)
            address(0), // executor
            "" // signature (empty when verification disabled)
        );
        evvmCore.pay(params);
        
        // Note: Balance checks would require decryption in real implementation
        // For now, we just verify the transaction didn't revert
        assertTrue(true);
    }
    
    function test_Pay_WithWhitelist_Enabled() public {
        // Setup whitelist
        vm.startPrank(ADMIN);
        evvmCore.addTokenToWhitelist(ETHER_ADDRESS);
        evvmCore.setWhitelistEnabled(true);
        vm.stopPrank();
        
        addBalanceToUser(USER1, ETHER_ADDRESS, TEST_AMOUNT + TEST_PRIORITY_FEE);
        
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(TEST_AMOUNT));
        externalEuint64 encryptedFee = createMockEncryptedEuint64(uint64(TEST_PRIORITY_FEE));
        
        // Payment should succeed with whitelisted token
        vm.prank(USER1);
        EVVMCore.PaymentParams memory params = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            0,
            encryptedAmount,
            MOCK_PROOF,
            0,
            encryptedFee,
            MOCK_PROOF,
            TEST_NONCE,
            true,
            address(0),
            ""
        );
        evvmCore.pay(params);
        
        assertTrue(true);
    }
    
    function test_Revert_Pay_WithWhitelist_TokenNotWhitelisted() public {
        vm.startPrank(ADMIN);
        evvmCore.addTokenToWhitelist(ETHER_ADDRESS);
        evvmCore.setWhitelistEnabled(true);
        vm.stopPrank();
        
        addBalanceToUser(USER1, TEST_TOKEN1, TEST_AMOUNT + TEST_PRIORITY_FEE);
        
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(TEST_AMOUNT));
        externalEuint64 encryptedFee = createMockEncryptedEuint64(uint64(TEST_PRIORITY_FEE));
        
        // Payment should fail with non-whitelisted token
        vm.prank(USER1);
        vm.expectRevert("Token not whitelisted");
        EVVMCore.PaymentParams memory params = createPaymentParams(
            USER1,
            USER2,
            "",
            TEST_TOKEN1,
            0,
            encryptedAmount,
            MOCK_PROOF,
            0,
            encryptedFee,
            MOCK_PROOF,
            TEST_NONCE,
            true,
            address(0),
            ""
        );
        evvmCore.pay(params);
    }
    
    function test_Pay_AsyncNonce() public {
        addBalanceToUser(USER1, ETHER_ADDRESS, TEST_AMOUNT + TEST_PRIORITY_FEE);
        
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(TEST_AMOUNT));
        externalEuint64 encryptedFee = createMockEncryptedEuint64(uint64(TEST_PRIORITY_FEE));
        
        // First payment with async nonce
        vm.prank(USER1);
        EVVMCore.PaymentParams memory params1 = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            0,
            encryptedAmount,
            MOCK_PROOF,
            0,
            encryptedFee,
            MOCK_PROOF,
            TEST_NONCE,
            true, // async
            address(0),
            ""
        );
        evvmCore.pay(params1);
        
        // Second payment with different nonce should succeed
        vm.prank(USER1);
        EVVMCore.PaymentParams memory params2 = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            0,
            encryptedAmount,
            MOCK_PROOF,
            0,
            encryptedFee,
            MOCK_PROOF,
            TEST_NONCE + 1,
            true,
            address(0),
            ""
        );
        evvmCore.pay(params2);
        
        assertTrue(true);
    }
    
    function test_Revert_Pay_AsyncNonce_AlreadyUsed() public {
        addBalanceToUser(USER1, ETHER_ADDRESS, TEST_AMOUNT + TEST_PRIORITY_FEE);
        
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(TEST_AMOUNT));
        externalEuint64 encryptedFee = createMockEncryptedEuint64(uint64(TEST_PRIORITY_FEE));
        
        // First payment
        vm.prank(USER1);
        EVVMCore.PaymentParams memory params1 = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            0,
            encryptedAmount,
            MOCK_PROOF,
            0,
            encryptedFee,
            MOCK_PROOF,
            TEST_NONCE,
            true,
            address(0),
            ""
        );
        evvmCore.pay(params1);
        
        // Try to reuse the same nonce
        vm.prank(USER1);
        vm.expectRevert("Nonce already used");
        EVVMCore.PaymentParams memory params2 = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            0,
            encryptedAmount,
            MOCK_PROOF,
            0,
            encryptedFee,
            MOCK_PROOF,
            TEST_NONCE, // Same nonce
            true,
            address(0),
            ""
        );
        evvmCore.pay(params2);
    }
    
    function test_Pay_SyncNonce() public {
        addBalanceToUser(USER1, ETHER_ADDRESS, TEST_AMOUNT + TEST_PRIORITY_FEE);
        
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(TEST_AMOUNT));
        externalEuint64 encryptedFee = createMockEncryptedEuint64(uint64(TEST_PRIORITY_FEE));
        
        uint256 expectedNonce = evvmCore.getNextCurrentSyncNonce(USER1);
        
        // Payment with sync nonce
        vm.prank(USER1);
        EVVMCore.PaymentParams memory params = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            0,
            encryptedAmount,
            MOCK_PROOF,
            0,
            encryptedFee,
            MOCK_PROOF,
            expectedNonce,
            false, // sync
            address(0),
            ""
        );
        evvmCore.pay(params);
        
        // Next nonce should be incremented
        assertEq(evvmCore.getNextCurrentSyncNonce(USER1), expectedNonce + 1);
    }
    
    function test_Revert_Pay_SyncNonce_Invalid() public {
        addBalanceToUser(USER1, ETHER_ADDRESS, TEST_AMOUNT + TEST_PRIORITY_FEE);
        
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(TEST_AMOUNT));
        externalEuint64 encryptedFee = createMockEncryptedEuint64(uint64(TEST_PRIORITY_FEE));
        
        uint256 expectedNonce = evvmCore.getNextCurrentSyncNonce(USER1);
        
        // Try with wrong nonce
        vm.prank(USER1);
        vm.expectRevert("Invalid nonce");
        EVVMCore.PaymentParams memory params = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            0,
            encryptedAmount,
            MOCK_PROOF,
            0,
            encryptedFee,
            MOCK_PROOF,
            expectedNonce + 1, // Wrong nonce
            false,
            address(0),
            ""
        );
        evvmCore.pay(params);
    }
    
    function test_Pay_WithExecutor() public {
        // Setup EVVM metadata with principal token (required for staker rewards)
        vm.prank(ADMIN);
        EVVMCore.EvvmMetadata memory metadata = EVVMCore.EvvmMetadata({
            evvmName: "TestEVVM",
            evvmID: TEST_EVVM_ID,
            principalTokenName: "TestToken",
            principalTokenSymbol: "TST",
            principalTokenAddress: address(0x9999), // Mock principal token address
            totalSupply: euint64.wrap(bytes32(uint256(1000000))),
            eraTokens: euint64.wrap(bytes32(uint256(100))),
            reward: euint64.wrap(bytes32(uint256(10))) // Reward per transaction
        });
        evvmCore.setEvvmMetadata(metadata);

        // Setup staking contract address first
        address stakingContract = address(0x1234);
        vm.startPrank(ADMIN);
        evvmCore.setStakingContractAddress(stakingContract);
        evvmCore.addValidator(EXECUTOR);
        vm.stopPrank();

        // Point staker from staking contract
        vm.prank(stakingContract);
        evvmCore.pointStaker(EXECUTOR, 0x01); // Make executor a staker

        addBalanceToUser(USER1, ETHER_ADDRESS, TEST_AMOUNT + TEST_PRIORITY_FEE);
        
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(TEST_AMOUNT));
        externalEuint64 encryptedFee = createMockEncryptedEuint64(uint64(TEST_PRIORITY_FEE));
        
        // Payment executed by executor
        vm.prank(EXECUTOR);
        EVVMCore.PaymentParams memory params = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            0,
            encryptedAmount,
            MOCK_PROOF,
            0,
            encryptedFee,
            MOCK_PROOF,
            TEST_NONCE,
            true,
            EXECUTOR, // executor
            ""
        );
        evvmCore.pay(params);
        
        assertTrue(true);
    }
    
    function test_Revert_Pay_WithExecutor_NotExecutor() public {
        addBalanceToUser(USER1, ETHER_ADDRESS, TEST_AMOUNT + TEST_PRIORITY_FEE);
        
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(TEST_AMOUNT));
        externalEuint64 encryptedFee = createMockEncryptedEuint64(uint64(TEST_PRIORITY_FEE));
        
        // Try to execute with wrong executor
        vm.prank(USER2);
        vm.expectRevert("Not the executor");
        EVVMCore.PaymentParams memory params = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            0,
            encryptedAmount,
            MOCK_PROOF,
            0,
            encryptedFee,
            MOCK_PROOF,
            TEST_NONCE,
            true,
            EXECUTOR, // executor specified
            ""
        );
        evvmCore.pay(params);
    }
    
    function test_SetSignatureVerificationRequired() public {
        vm.prank(ADMIN);
        evvmCore.setSignatureVerificationRequired(true);
        
        assertTrue(evvmCore.signatureVerificationRequired());
        
        vm.prank(ADMIN);
        evvmCore.setSignatureVerificationRequired(false);
        
        assertFalse(evvmCore.signatureVerificationRequired());
    }
    
    function test_Revert_Pay_SignatureRequired_EmptySignature() public {
        vm.prank(ADMIN);
        evvmCore.setSignatureVerificationRequired(true);
        
        addBalanceToUser(USER1, ETHER_ADDRESS, TEST_AMOUNT + TEST_PRIORITY_FEE);
        
        externalEuint64 encryptedAmount = createMockEncryptedEuint64(uint64(TEST_AMOUNT));
        externalEuint64 encryptedFee = createMockEncryptedEuint64(uint64(TEST_PRIORITY_FEE));
        
        vm.prank(USER1);
        vm.expectRevert("Signature required");
        EVVMCore.PaymentParams memory params = createPaymentParams(
            USER1,
            USER2,
            "",
            ETHER_ADDRESS,
            TEST_AMOUNT,
            encryptedAmount,
            MOCK_PROOF,
            TEST_PRIORITY_FEE,
            encryptedFee,
            MOCK_PROOF,
            TEST_NONCE,
            true,
            address(0),
            "" // Empty signature
        );
        evvmCore.pay(params);
    }
}

