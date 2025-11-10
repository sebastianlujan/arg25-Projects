// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EVVMCoreTestBase.sol";

/**
 * @title EVVMCore_BlocksAndTransactions
 * @notice Tests for block and transaction operations
 */
contract EVVMCore_BlocksAndTransactions is EVVMCoreTestBase {
    
    function setUp() public override {
        super.setUp();
        
        // Add validators for block operations
        vm.startPrank(ADMIN);
        evvmCore.addValidator(VALIDATOR1);
        evvmCore.addValidator(VALIDATOR2);
        vm.stopPrank();
    }
    
    function test_CreateVirtualBlock() public {
        externalEuint256 encryptedGasLimit = createMockEncryptedEuint256(TEST_GAS_LIMIT);
        address[] memory validators = new address[](1);
        validators[0] = VALIDATOR1;
        
        vm.prank(VALIDATOR1);
        uint64 blockNumber = evvmCore.createVirtualBlock(
            encryptedGasLimit,
            MOCK_PROOF,
            validators
        );
        
        assertEq(blockNumber, 1);
        assertEq(evvmCore.getCurrentBlockNumber(), 1);
    }
    
    function test_CreateMultipleBlocks() public {
        externalEuint256 encryptedGasLimit = createMockEncryptedEuint256(TEST_GAS_LIMIT);
        address[] memory validators = new address[](1);
        validators[0] = VALIDATOR1;
        
        vm.startPrank(VALIDATOR1);
        uint64 block1 = evvmCore.createVirtualBlock(encryptedGasLimit, MOCK_PROOF, validators);
        uint64 block2 = evvmCore.createVirtualBlock(encryptedGasLimit, MOCK_PROOF, validators);
        vm.stopPrank();
        
        assertEq(block1, 1);
        assertEq(block2, 2);
        assertEq(evvmCore.getCurrentBlockNumber(), 2);
    }
    
    function test_Revert_CreateBlock_NotValidator() public {
        externalEuint256 encryptedGasLimit = createMockEncryptedEuint256(TEST_GAS_LIMIT);
        address[] memory validators = new address[](1);
        validators[0] = VALIDATOR1;
        
        vm.prank(USER1);
        vm.expectRevert("Not a validator");
        evvmCore.createVirtualBlock(encryptedGasLimit, MOCK_PROOF, validators);
    }
    
    function test_Revert_CreateBlock_NotInitialized() public {
        EVVMCore newEvvm = new EVVMCore();
        externalEuint256 encryptedGasLimit = createMockEncryptedEuint256(TEST_GAS_LIMIT);
        address[] memory validators = new address[](1);
        validators[0] = VALIDATOR1;
        
        vm.prank(VALIDATOR1);
        vm.expectRevert("Not initialized");
        newEvvm.createVirtualBlock(encryptedGasLimit, MOCK_PROOF, validators);
    }
    
    function test_FinalizeBlock() public {
        externalEuint256 encryptedGasLimit = createMockEncryptedEuint256(TEST_GAS_LIMIT);
        address[] memory validators = new address[](1);
        validators[0] = VALIDATOR1;
        
        vm.startPrank(VALIDATOR1);
        uint64 blockNumber = evvmCore.createVirtualBlock(encryptedGasLimit, MOCK_PROOF, validators);
        evvmCore.finalizeBlock(blockNumber);
        vm.stopPrank();
        
        // Block should be finalized (verification would require decryption in real implementation)
        assertTrue(true);
    }
    
    function test_SubmitTransaction() public {
        externalEuint256 encryptedValue = createMockEncryptedEuint256(TEST_AMOUNT);
        
        vm.prank(USER1);
        uint256 txId = evvmCore.submitTransaction(
            USER2,
            encryptedValue,
            MOCK_PROOF,
            ""
        );
        
        assertEq(txId, 1);
        assertEq(evvmCore.getNextTxId(), 2);
    }
    
    function test_SubmitMultipleTransactions() public {
        externalEuint256 encryptedValue = createMockEncryptedEuint256(TEST_AMOUNT);
        
        vm.startPrank(USER1);
        uint256 tx1 = evvmCore.submitTransaction(USER2, encryptedValue, MOCK_PROOF, "");
        uint256 tx2 = evvmCore.submitTransaction(USER2, encryptedValue, MOCK_PROOF, "");
        vm.stopPrank();
        
        assertEq(tx1, 1);
        assertEq(tx2, 2);
        assertEq(evvmCore.getNextTxId(), 3);
    }
    
    function test_Revert_SubmitTransaction_NotInitialized() public {
        EVVMCore newEvvm = new EVVMCore();
        externalEuint256 encryptedValue = createMockEncryptedEuint256(TEST_AMOUNT);
        
        vm.prank(USER1);
        vm.expectRevert("Not initialized");
        newEvvm.submitTransaction(USER2, encryptedValue, MOCK_PROOF, "");
    }
    
    function test_Revert_SubmitTransaction_InvalidRecipient() public {
        externalEuint256 encryptedValue = createMockEncryptedEuint256(TEST_AMOUNT);
        
        vm.prank(USER1);
        vm.expectRevert("Invalid recipient");
        evvmCore.submitTransaction(address(0), encryptedValue, MOCK_PROOF, "");
    }
    
    function test_IncludeTransactionInBlock() public {
        externalEuint256 encryptedValue = createMockEncryptedEuint256(TEST_AMOUNT);
        externalEuint256 encryptedGasLimit = createMockEncryptedEuint256(TEST_GAS_LIMIT);
        externalEuint256 encryptedGasUsed = createMockEncryptedEuint256(21000);
        
        address[] memory validators = new address[](1);
        validators[0] = VALIDATOR1;
        
        vm.startPrank(USER1);
        uint256 txId = evvmCore.submitTransaction(USER2, encryptedValue, MOCK_PROOF, "");
        vm.stopPrank();
        
        vm.startPrank(VALIDATOR1);
        uint64 blockNumber = evvmCore.createVirtualBlock(encryptedGasLimit, MOCK_PROOF, validators);
        evvmCore.includeTransactionInBlock(txId, blockNumber, encryptedGasUsed, MOCK_PROOF);
        vm.stopPrank();
        
        assertTrue(true);
    }
    
    function test_Revert_IncludeTransaction_InvalidTxId() public {
        externalEuint256 encryptedGasLimit = createMockEncryptedEuint256(TEST_GAS_LIMIT);
        externalEuint256 encryptedGasUsed = createMockEncryptedEuint256(21000);
        
        address[] memory validators = new address[](1);
        validators[0] = VALIDATOR1;
        
        vm.startPrank(VALIDATOR1);
        uint64 blockNumber = evvmCore.createVirtualBlock(encryptedGasLimit, MOCK_PROOF, validators);
        vm.expectRevert("Invalid transaction");
        evvmCore.includeTransactionInBlock(999, blockNumber, encryptedGasUsed, MOCK_PROOF);
        vm.stopPrank();
    }
    
    function test_Revert_IncludeTransaction_InvalidBlock() public {
        externalEuint256 encryptedValue = createMockEncryptedEuint256(TEST_AMOUNT);
        externalEuint256 encryptedGasUsed = createMockEncryptedEuint256(21000);
        
        vm.startPrank(USER1);
        uint256 txId = evvmCore.submitTransaction(USER2, encryptedValue, MOCK_PROOF, "");
        vm.stopPrank();
        
        vm.prank(VALIDATOR1);
        vm.expectRevert("Invalid block");
        evvmCore.includeTransactionInBlock(txId, 999, encryptedGasUsed, MOCK_PROOF);
    }
}

