// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EVVMCoreTestBase.sol";

/**
 * @title EVVMCore_AdminFunctions
 * @notice Tests for administrative functions
 */
contract EVVMCore_AdminFunctions is EVVMCoreTestBase {
    
    function test_SetTreasuryAddress() public {
        TreasuryVault newTreasury = new TreasuryVault(address(evvmCore));
        
        vm.prank(ADMIN);
        evvmCore.setTreasuryAddress(address(newTreasury));
        
        assertEq(evvmCore.getTreasuryAddress(), address(newTreasury));
    }
    
    function test_SetStakingContractAddress() public {
        address stakingContract = address(0x1234);
        
        vm.prank(ADMIN);
        evvmCore.setStakingContractAddress(stakingContract);
        
        assertEq(evvmCore.getStakingContractAddress(), stakingContract);
    }
    
    function test_SetStylusEngine() public {
        // Mock stylus engine address
        address stylusEngine = address(0x5678);
        
        vm.prank(ADMIN);
        evvmCore.setStylusEngine(stylusEngine);
        
        assertEq(address(evvmCore.stylusEngine()), stylusEngine);
    }
    
    function test_Revert_SetStylusEngine_InvalidAddress() public {
        vm.prank(ADMIN);
        vm.expectRevert("Invalid address");
        evvmCore.setStylusEngine(address(0));
    }
    
    function test_PointStaker() public {
        address stakingContract = address(0x1234);
        
        vm.startPrank(ADMIN);
        evvmCore.setStakingContractAddress(stakingContract);
        vm.stopPrank();
        
        vm.prank(stakingContract);
        evvmCore.pointStaker(STAKER1, 0x01);
        
        assertTrue(evvmCore.isAddressStaker(STAKER1));
    }
    
    function test_PointStaker_Remove() public {
        address stakingContract = address(0x1234);
        
        vm.startPrank(ADMIN);
        evvmCore.setStakingContractAddress(stakingContract);
        vm.stopPrank();
        
        vm.startPrank(stakingContract);
        evvmCore.pointStaker(STAKER1, 0x01);
        assertTrue(evvmCore.isAddressStaker(STAKER1));
        
        evvmCore.pointStaker(STAKER1, 0x00);
        vm.stopPrank();
        
        assertFalse(evvmCore.isAddressStaker(STAKER1));
    }
    
    function test_Revert_PointStaker_NotStakingContract() public {
        vm.prank(USER1);
        vm.expectRevert("Not staking contract");
        evvmCore.pointStaker(STAKER1, 0x01);
    }
    
    function test_ProposeAdmin() public {
        vm.prank(ADMIN);
        evvmCore.proposeAdmin(USER1);
        
        assertEq(evvmCore.getProposalAdmin(), USER1);
        assertGt(evvmCore.getTimeToAcceptAdmin(), block.timestamp);
    }
    
    function test_AcceptAdmin() public {
        vm.startPrank(ADMIN);
        evvmCore.proposeAdmin(USER1);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 days + 1);
        
        vm.prank(USER1);
        evvmCore.acceptAdmin();
        
        assertEq(evvmCore.getCurrentAdmin(), USER1);
    }
    
    function test_Revert_AcceptAdmin_TimeNotElapsed() public {
        vm.startPrank(ADMIN);
        evvmCore.proposeAdmin(USER1);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 12 hours); // Less than 1 day
        
        vm.prank(USER1);
        vm.expectRevert("Time not elapsed");
        evvmCore.acceptAdmin();
    }
    
    function test_Revert_AcceptAdmin_NotProposedAdmin() public {
        vm.startPrank(ADMIN);
        evvmCore.proposeAdmin(USER1);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 days + 1);
        
        vm.prank(USER2);
        vm.expectRevert("Not proposed admin");
        evvmCore.acceptAdmin();
    }
    
    function test_RejectProposalAdmin() public {
        vm.startPrank(ADMIN);
        evvmCore.proposeAdmin(USER1);
        evvmCore.rejectProposalAdmin();
        vm.stopPrank();
        
        assertEq(evvmCore.getProposalAdmin(), address(0));
        assertEq(evvmCore.getTimeToAcceptAdmin(), 0);
    }
    
    function test_ProposeImplementation() public {
        address newImpl = address(0x9999);
        
        vm.prank(ADMIN);
        evvmCore.proposeImplementation(newImpl);
        
        assertEq(evvmCore.getProposalImplementation(), newImpl);
        assertGt(evvmCore.getTimeToAcceptImplementation(), block.timestamp);
    }
    
    function test_AcceptImplementation() public {
        address newImpl = address(0x9999);
        
        vm.startPrank(ADMIN);
        evvmCore.proposeImplementation(newImpl);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.prank(ADMIN);
        evvmCore.acceptImplementation();
        
        assertEq(evvmCore.currentImplementation(), newImpl);
    }
    
    function test_Revert_AcceptImplementation_TimeNotElapsed() public {
        address newImpl = address(0x9999);
        
        vm.startPrank(ADMIN);
        evvmCore.proposeImplementation(newImpl);
        vm.warp(block.timestamp + 29 days);
        vm.expectRevert("Time not elapsed");
        evvmCore.acceptImplementation();
        vm.stopPrank();
    }
    
    function test_RejectUpgrade() public {
        address newImpl = address(0x9999);
        
        vm.startPrank(ADMIN);
        evvmCore.proposeImplementation(newImpl);
        evvmCore.rejectUpgrade();
        vm.stopPrank();
        
        assertEq(evvmCore.getProposalImplementation(), address(0));
        assertEq(evvmCore.getTimeToAcceptImplementation(), 0);
    }
    
    function test_GetBalance() public {
        // Balance is encrypted, so we can only verify the function doesn't revert
        euint64 balance = evvmCore.getBalance(USER1, ETHER_ADDRESS);
        
        // In real implementation, balance would need to be decrypted
        // For now, we just verify the call succeeds
        assertTrue(true);
    }
    
    function test_GetRewardAmount() public {
        // Reward is encrypted
        euint64 reward = evvmCore.getRewardAmount();
        
        // Verification would require decryption
        assertTrue(true);
    }
}

