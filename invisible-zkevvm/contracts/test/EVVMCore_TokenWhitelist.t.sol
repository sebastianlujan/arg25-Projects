// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EVVMCoreTestBase.sol";

/**
 * @title EVVMCore_TokenWhitelist
 * @notice Tests for token whitelist functionality
 */
contract EVVMCore_TokenWhitelist is EVVMCoreTestBase {
    
    function test_WhitelistDisabled_AllowsAnyToken() public {
        // Whitelist is disabled by default
        assertFalse(evvmCore.whitelistEnabled());
        assertTrue(evvmCore.isTokenWhitelisted(TEST_TOKEN1));
        assertTrue(evvmCore.isTokenWhitelisted(TEST_TOKEN2));
        assertTrue(evvmCore.isTokenWhitelisted(address(0x9999)));
    }
    
    function test_AddTokenToWhitelist() public {
        vm.prank(ADMIN);
        evvmCore.addTokenToWhitelist(TEST_TOKEN1);
        
        assertTrue(evvmCore.tokenWhitelist(TEST_TOKEN1));
    }
    
    function test_EnableWhitelist() public {
        vm.startPrank(ADMIN);
        evvmCore.addTokenToWhitelist(TEST_TOKEN1);
        evvmCore.setWhitelistEnabled(true);
        vm.stopPrank();
        
        assertTrue(evvmCore.whitelistEnabled());
        assertTrue(evvmCore.isTokenWhitelisted(TEST_TOKEN1));
        assertFalse(evvmCore.isTokenWhitelisted(TEST_TOKEN2));
    }
    
    function test_RemoveTokenFromWhitelist() public {
        vm.startPrank(ADMIN);
        evvmCore.addTokenToWhitelist(TEST_TOKEN1);
        evvmCore.addTokenToWhitelist(TEST_TOKEN2);
        evvmCore.setWhitelistEnabled(true);
        evvmCore.removeTokenFromWhitelist(TEST_TOKEN1);
        vm.stopPrank();
        
        assertFalse(evvmCore.tokenWhitelist(TEST_TOKEN1));
        assertTrue(evvmCore.tokenWhitelist(TEST_TOKEN2));
        assertFalse(evvmCore.isTokenWhitelisted(TEST_TOKEN1));
    }
    
    function test_Revert_AddToken_NotOwner() public {
        vm.prank(USER1);
        vm.expectRevert();
        evvmCore.addTokenToWhitelist(TEST_TOKEN1);
    }
    
    function test_Revert_AddToken_AlreadyWhitelisted() public {
        vm.startPrank(ADMIN);
        evvmCore.addTokenToWhitelist(TEST_TOKEN1);
        vm.expectRevert("Token already whitelisted");
        evvmCore.addTokenToWhitelist(TEST_TOKEN1);
        vm.stopPrank();
    }
    
    function test_Revert_RemoveToken_NotWhitelisted() public {
        vm.prank(ADMIN);
        vm.expectRevert("Token not whitelisted");
        evvmCore.removeTokenFromWhitelist(TEST_TOKEN1);
    }
}

