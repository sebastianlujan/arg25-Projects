// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EVVMCoreTestBase.sol";

/**
 * @title EVVMCore_Initialization
 * @notice Tests for EVVMCore initialization and basic setup
 */
contract EVVMCore_Initialization is EVVMCoreTestBase {
    
    function test_InitializeVirtualChain() public {
        // Deploy as ADMIN to make ADMIN the owner
        vm.prank(ADMIN);
        EVVMCore newEvvm = new EVVMCore();
        
        vm.prank(ADMIN);
        newEvvm.initializeVirtualChain("NewChain", 2000000);
        
        assertEq(newEvvm.chainName(), "NewChain");
        assertEq(newEvvm.initialGasLimit(), 2000000);
        assertTrue(newEvvm.initialized());
    }
    
    function test_Revert_InitializeTwice() public {
        vm.prank(ADMIN);
        vm.expectRevert("Already initialized");
        evvmCore.initializeVirtualChain("AnotherChain", 3000000);
    }
    
    function test_Revert_InitializeWithZeroGasLimit() public {
        // Deploy as ADMIN to make ADMIN the owner
        vm.prank(ADMIN);
        EVVMCore newEvvm = new EVVMCore();
        
        vm.prank(ADMIN);
        vm.expectRevert("Invalid gas limit");
        newEvvm.initializeVirtualChain("Chain", 0);
    }
    
    function test_Revert_InitializeNotOwner() public {
        EVVMCore newEvvm = new EVVMCore();
        
        vm.prank(USER1);
        vm.expectRevert();
        newEvvm.initializeVirtualChain("Chain", 1000000);
    }
    
    function test_SetEvvmID() public {
        vm.prank(ADMIN);
        evvmCore.setEvvmID(888);
        
        assertEq(evvmCore.evvmID(), 888);
    }
    
    function test_SetEvvmID_TimeWindow() public {
        // Set to 0 first
        vm.prank(ADMIN);
        evvmCore.setEvvmID(0);
        
        // Can change back within 1 day
        vm.warp(block.timestamp + 12 hours);
        vm.prank(ADMIN);
        evvmCore.setEvvmID(999);
        
        assertEq(evvmCore.evvmID(), 999);
    }
    
    function test_Revert_SetEvvmID_TimeWindowExpired() public {
        vm.prank(ADMIN);
        evvmCore.setEvvmID(0);
        
        // Try to change after window expired
        vm.warp(block.timestamp + 2 days);
        vm.prank(ADMIN);
        vm.expectRevert("Window expired");
        evvmCore.setEvvmID(0);
    }
}

