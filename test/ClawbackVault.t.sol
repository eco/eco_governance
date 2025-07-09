// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ClawbackVault} from "../src/ClawbackVault.sol";
import {Token} from "../src/Token.sol";
import {UnsafeUpgrades as Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ClawbackVaultTest is Test {
    ClawbackVault public vault;
    Token public token;
    
    address public admin = address(0x1);
    address public beneficiary = address(0x2);
    address public nonAdmin = address(0x3);
    address public pauser = address(0x4);
    
    uint64 public startTimestamp = 1000;
    uint64 public durationSeconds = 365 days;
    uint256 public totalAmount = 1000e18; // 1000 tokens with 18 decimals

    // Token metadata
    string constant NAME = "Test Token";
    string constant SYMBOL = "TEST";

    event Clawback(address indexed token, uint256 amount);

    function setUp() public {
        // Deploy Token implementation
        Token implementation = new Token();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            Token.initialize.selector, 
            admin, 
            pauser, 
            NAME, 
            SYMBOL
        );

        address tokenProxy = Upgrades.deployTransparentProxy(
            address(implementation), 
            admin, 
            initData
        );

        // Set token instance to proxy
        token = Token(tokenProxy);
        
        // Deploy ClawbackVault
        vault = new ClawbackVault(admin, beneficiary, startTimestamp, durationSeconds);
        
        // Mint tokens to the vault
        vm.startPrank(admin);
        token.mint(address(vault), totalAmount);
        vm.stopPrank();
    }

    function test_Clawback_OnlyAdminCanCall() public {
        // Non-admin should not be able to clawback
        vm.startPrank(nonAdmin);
        vm.expectRevert(ClawbackVault.UnauthorizedClawback.selector);
        vault.clawback(address(token));
        vm.stopPrank();
    }

    function test_Clawback_NoUnvestedTokens() public {
        // Fast forward past the vesting period
        vm.warp(startTimestamp + durationSeconds + 1);
        
        // All tokens should be vested
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, totalAmount);
        
        // Try to clawback - should revert
        vm.startPrank(admin);
        vm.expectRevert(ClawbackVault.NothingToClawback.selector);
        vault.clawback(address(token));
        vm.stopPrank();
    }

    function test_Clawback_AllTokensUnvested() public {
        // At the start, no tokens should be vested
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, 0);
        
        uint256 adminBalanceBefore = token.balanceOf(admin);
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));
        
        // Admin should be able to clawback all tokens
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, true);
        emit Clawback(address(token), totalAmount);
        vault.clawback(address(token));
        vm.stopPrank();
        
        // Check balances
        assertEq(token.balanceOf(admin), adminBalanceBefore + totalAmount);
        assertEq(token.balanceOf(address(vault)), vaultBalanceBefore - totalAmount);
    }

    function test_Clawback_PartialVesting() public {
        // Fast forward to middle of vesting period
        uint64 middleTimestamp = startTimestamp + (durationSeconds / 2);
        vm.warp(middleTimestamp);
        
        // Half of tokens should be vested
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        uint256 expectedVested = totalAmount / 2;
        assertEq(vested, expectedVested);
        
        uint256 expectedUnvested = totalAmount - expectedVested;
        uint256 adminBalanceBefore = token.balanceOf(admin);
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));
        
        // Admin should be able to clawback unvested tokens
        vm.startPrank(admin);
        vm.expectEmit(true, false, false, true);
        emit Clawback(address(token), expectedUnvested);
        vault.clawback(address(token));
        vm.stopPrank();
        
        // Check balances
        assertEq(token.balanceOf(admin), adminBalanceBefore + expectedUnvested);
        assertEq(token.balanceOf(address(vault)), vaultBalanceBefore - expectedUnvested);
    }

    function test_Clawback_AfterPartialRelease() public {
        // Fast forward to middle of vesting period
        uint64 quarterTimestamp = startTimestamp + (durationSeconds / 4);
        vm.warp(quarterTimestamp);
        
        // Release some tokens to beneficiary
        uint256 releaseAmount = totalAmount / 4; // 25% of total
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();

        
        // Check that tokens were released
        assertEq(token.balanceOf(beneficiary), releaseAmount);
        assertEq(vault.released(address(token)), releaseAmount);

        uint64 middleTimestamp = startTimestamp + (durationSeconds / 2);
        vm.warp(middleTimestamp);
        
        // Calculate remaining unvested tokens
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        uint256 expectedVested = totalAmount / 2; // 50% vested
        assertEq(vested, expectedVested);
        
        uint256 expectedUnvested = totalAmount - expectedVested;
        uint256 adminBalanceBefore = token.balanceOf(admin);
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));
        
        // Admin should be able to clawback remaining unvested tokens
        vm.startPrank(admin);
        // vm.expectEmit(true, false, false, true);
        // emit Clawback(address(token), expectedUnvested);
        vault.clawback(address(token));
        vm.stopPrank();
        
        // Check balances
        assertEq(token.balanceOf(admin), adminBalanceBefore + expectedUnvested);
        assertEq(token.balanceOf(address(vault)), vaultBalanceBefore - expectedUnvested);
    }

    function test_Clawback_CalculatesCorrectAmount() public {
        // Fast forward to 25% through vesting period
        uint64 quarterTimestamp = startTimestamp + (durationSeconds / 4);
        vm.warp(quarterTimestamp);
        
        // 25% should be vested
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        uint256 expectedVested = totalAmount / 4;
        assertEq(vested, expectedVested);
        
        // Calculate expected unvested amount
        uint256 expectedUnvested = totalAmount - expectedVested;
        
        // Verify the clawback calculation
        uint256 totalAllocation = token.balanceOf(address(vault)) + vault.released();
        uint256 calculatedUnvested = totalAllocation > vested ? totalAllocation - vested : 0;
        assertEq(calculatedUnvested, expectedUnvested);
        
        // Perform clawback
        vm.startPrank(admin);
        vault.clawback(address(token));
        vm.stopPrank();
        
        // Verify the correct amount was transferred
        assertEq(token.balanceOf(admin), expectedUnvested);
    }

    function test_Clawback_EdgeCaseZeroBalance() public {
        // Transfer all tokens out of vault
        vm.startPrank(address(vault));
        token.transfer(beneficiary, totalAmount);
        vm.stopPrank();
        
        // Try to clawback - should revert
        vm.startPrank(admin);
        vm.expectRevert(ClawbackVault.NothingToClawback.selector);
        vault.clawback(address(token));
        vm.stopPrank();
    }

    function test_Clawback_EventEmittedCorrectly() public {
        vm.startPrank(admin);
        
        // Capture the event
        vm.expectEmit(true, false, false, true);
        emit Clawback(address(token), totalAmount);
        
        vault.clawback(address(token));
        vm.stopPrank();
    }

    function test_Clawback_AdminAddressCorrect() public {
        assertEq(vault.admin(), admin);
    }

    function test_Clawback_TokenTransferWorks() public {
        // Test that token transfers work correctly
        vm.startPrank(admin);
        token.mint(beneficiary, 100e18);
        vm.stopPrank();
        
        assertEq(token.balanceOf(beneficiary), 100e18);
        
        vm.startPrank(beneficiary);
        token.transfer(admin, 50e18);
        vm.stopPrank();
        
        assertEq(token.balanceOf(beneficiary), 50e18);
        assertEq(token.balanceOf(admin), 50e18);
    }

    function test_Clawback_AdditionalTokensDuringVesting() public {
        // Fast forward to 50% through vesting period
        uint64 halfway = startTimestamp + (durationSeconds / 2);
        vm.warp(halfway);

        // Send additional tokens to the vault
        uint256 extraAmount = 500e18;
        vm.startPrank(admin);
        token.mint(address(vault), extraAmount);
        vm.stopPrank();

        // Now, total allocation is totalAmount + extraAmount
        // At halfway, 50% of all tokens should be vested
        uint256 expectedVested = (totalAmount + extraAmount) / 2;
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, expectedVested);

        // The beneficiary can release the vested amount
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();
        assertEq(token.balanceOf(beneficiary), expectedVested);
    }

    function test_Clawback_AdditionalTokensAfterVesting() public {
        // Fast forward to after vesting period
        uint64 afterEnd = startTimestamp + durationSeconds + 1;
        vm.warp(afterEnd);

        // Send additional tokens to the vault
        uint256 extraAmount = 500e18;
        vm.startPrank(admin);
        token.mint(address(vault), extraAmount);
        vm.stopPrank();

        // All tokens should be immediately vested
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, totalAmount + extraAmount);

        // The beneficiary can release all tokens
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();
        assertEq(token.balanceOf(beneficiary), totalAmount + extraAmount);
    }

    function test_Clawback_AdditionalTokensAfterRelease() public {
        // Fast forward to 50% through vesting period
        uint64 halfway = startTimestamp + (durationSeconds / 2);
        vm.warp(halfway);

        // Release vested tokens to beneficiary
        uint256 vestedBefore = vault.vestedAmount(address(token), uint64(block.timestamp));
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();
        assertEq(token.balanceOf(beneficiary), vestedBefore);
        assertEq(vault.released(address(token)), vestedBefore);

        // Mint additional tokens to the vault
        uint256 extraAmount = 500e18;
        vm.startPrank(admin);
        token.mint(address(vault), extraAmount);
        vm.stopPrank();

        // At halfway, 50% of the new total allocation should be vested,
        // but we've already released vestedBefore, so only the difference is releasable
        uint256 newTotalAllocation = (totalAmount + extraAmount);
        uint256 expectedVested = newTotalAllocation / 2;
        uint256 releasableNow = expectedVested - vestedBefore;

        // Beneficiary releases again
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();

        // Beneficiary should now have all vested tokens
        assertEq(token.balanceOf(beneficiary), expectedVested);
        assertEq(vault.released(address(token)), expectedVested);

        // The vault should still hold the unvested portion
        assertEq(token.balanceOf(address(vault)), newTotalAllocation - expectedVested);
    }
} 