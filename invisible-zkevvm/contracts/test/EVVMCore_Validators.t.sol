// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EVVMCoreTestBase.sol";

/**
 * @title EVVMCore_Validators
 * @notice Tests for validator management
 */
contract EVVMCore_Validators is EVVMCoreTestBase {
    
    function test_AddValidator() public {
        vm.prank(ADMIN);
        evvmCore.addValidator(VALIDATOR1);
        
        assertTrue(evvmCore.validators(VALIDATOR1));
        address[] memory validators = evvmCore.getValidators();
        assertEq(validators.length, 1);
        assertEq(validators[0], VALIDATOR1);
    }
    
    function test_AddMultipleValidators() public {
        vm.startPrank(ADMIN);
        evvmCore.addValidator(VALIDATOR1);
        evvmCore.addValidator(VALIDATOR2);
        vm.stopPrank();
        
        address[] memory validators = evvmCore.getValidators();
        assertEq(validators.length, 2);
    }
    
    function test_Revert_AddValidator_NotOwner() public {
        vm.prank(USER1);
        vm.expectRevert();
        evvmCore.addValidator(VALIDATOR1);
    }
    
    function test_Revert_AddValidator_InvalidAddress() public {
        vm.prank(ADMIN);
        vm.expectRevert("Invalid validator");
        evvmCore.addValidator(address(0));
    }
    
    function test_Revert_AddValidator_AlreadyValidator() public {
        vm.startPrank(ADMIN);
        evvmCore.addValidator(VALIDATOR1);
        vm.expectRevert("Already a validator");
        evvmCore.addValidator(VALIDATOR1);
        vm.stopPrank();
    }
    
    function test_RemoveValidator() public {
        vm.startPrank(ADMIN);
        evvmCore.addValidator(VALIDATOR1);
        evvmCore.addValidator(VALIDATOR2);
        evvmCore.removeValidator(VALIDATOR1);
        vm.stopPrank();
        
        assertFalse(evvmCore.validators(VALIDATOR1));
        assertTrue(evvmCore.validators(VALIDATOR2));
        
        address[] memory validators = evvmCore.getValidators();
        assertEq(validators.length, 1);
    }
    
    function test_Revert_RemoveValidator_NotValidator() public {
        vm.prank(ADMIN);
        vm.expectRevert("Not a validator");
        evvmCore.removeValidator(VALIDATOR1);
    }
}

