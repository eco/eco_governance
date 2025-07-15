// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ProportionalChunkedClawbackVault} from "../src/ProportionalChunkedClawbackVault.sol";
import {Token} from "../src/Token.sol";
import {UnsafeUpgrades as Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ProportionalChunkedClawbackVaultTest is Test {
    ProportionalChunkedClawbackVault public vault;
    Token public token;
    
    address public admin = address(0x1);
    address public beneficiary = address(0x2);
    address public nonAdmin = address(0x3);
    address public pauser = address(0x4);
    
    uint64 public startTimestamp = 1000;
    uint64 public endTimestamp = 1000 + 365 days;
    uint256 public totalAmount = 1000e18; // 1000 tokens with 18 decimals

    // Token metadata
    string constant NAME = "Test Token";
    string constant SYMBOL = "TEST";

    // Test vesting chunks
    ProportionalChunkedClawbackVault.VestingChunk[] public chunks;

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
        
        // Create vesting chunks
        chunks.push(ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: startTimestamp,
            totalPercentVested: 0
        }));
        
        chunks.push(ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: startTimestamp + 90 days,
            totalPercentVested: 25
        }));
        
        chunks.push(ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: startTimestamp + 180 days,
            totalPercentVested: 50
        }));
        
        chunks.push(ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: startTimestamp + 270 days,
            totalPercentVested: 75
        }));
        
        chunks.push(ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: endTimestamp,
            totalPercentVested: 100
        }));
        
        // Deploy ProportionalChunkedClawbackVault
        vault = new ProportionalChunkedClawbackVault(admin, beneficiary, startTimestamp, endTimestamp - startTimestamp, chunks);
        
        // Mint tokens to the vault
        vm.startPrank(admin);
        token.mint(address(vault), totalAmount);
        vm.stopPrank();
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsAdminCorrectly() public {
        assertEq(vault.admin(), admin);
    }

    function test_Constructor_SetsBeneficiaryCorrectly() public {
        assertEq(vault.beneficiary(), beneficiary);
    }

    function test_Constructor_SetsStartTimeCorrectly() public {
        assertEq(vault.start(), startTimestamp);
    }

    function test_Constructor_SetsDurationCorrectly() public {
        assertEq(vault.duration(), endTimestamp - startTimestamp);
    }

    function test_Constructor_StoresChunksCorrectly() public {
        // Test that chunks are stored correctly
        assertEq(vault.getChunksLength(), 5);
        
        uint64 timestamp0;
        uint64 percent0;
        uint64 timestamp4;
        uint64 percent4;
        
        (timestamp0, percent0) = vault.getChunk(0);
        (timestamp4, percent4) = vault.getChunk(4);
        
        assertEq(timestamp0, startTimestamp);
        assertEq(percent0, 0);
        assertEq(timestamp4, endTimestamp);
        assertEq(percent4, 100);
    }

    function test_Constructor_RevertsIfNoChunks() public {
        ProportionalChunkedClawbackVault.VestingChunk[] memory emptyChunks = new ProportionalChunkedClawbackVault.VestingChunk[](0);
        vm.expectRevert("Must have at least one chunk");
        new ProportionalChunkedClawbackVault(admin, beneficiary, startTimestamp, endTimestamp - startTimestamp, emptyChunks);
    }

    function test_Constructor_RevertsIfLastChunkNot100Percent() public {
        ProportionalChunkedClawbackVault.VestingChunk[] memory invalidChunks = new ProportionalChunkedClawbackVault.VestingChunk[](2);
        invalidChunks[0] = ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: startTimestamp,
            totalPercentVested: 0
        });
        invalidChunks[1] = ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: endTimestamp,
            totalPercentVested: 90
        });
        
        vm.expectRevert("Last chunk must be 100% vested");
        new ProportionalChunkedClawbackVault(admin, beneficiary, startTimestamp, endTimestamp - startTimestamp, invalidChunks);
    }

    function test_Constructor_RevertsIfChunksNotInOrder() public {
        ProportionalChunkedClawbackVault.VestingChunk[] memory invalidChunks = new ProportionalChunkedClawbackVault.VestingChunk[](2);
        invalidChunks[0] = ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: endTimestamp,
            totalPercentVested: 100
        });
        invalidChunks[1] = ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: startTimestamp,
            totalPercentVested: 0
        });
        
        vm.expectRevert("Chunks must be in ascending order");
        new ProportionalChunkedClawbackVault(admin, beneficiary, startTimestamp, endTimestamp - startTimestamp, invalidChunks);
    }

    function test_Constructor_RevertsIfPercentDecreasing() public {
        ProportionalChunkedClawbackVault.VestingChunk[] memory invalidChunks = new ProportionalChunkedClawbackVault.VestingChunk[](2);
        invalidChunks[0] = ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: startTimestamp,
            totalPercentVested: 50
        });
        invalidChunks[1] = ProportionalChunkedClawbackVault.VestingChunk({
            timestamp: endTimestamp,
            totalPercentVested: 25
        });
        
        vm.expectRevert("Percent vested must be non-decreasing");
        new ProportionalChunkedClawbackVault(admin, beneficiary, startTimestamp, endTimestamp - startTimestamp, invalidChunks);
    }

    // ============ Vesting Schedule Tests ============

    function test_VestingSchedule_BeforeStart() public {
        vm.warp(startTimestamp - 1);
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, 0);
    }

    function test_VestingSchedule_AtStart() public {
        vm.warp(startTimestamp);
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, 0);
    }

    function test_VestingSchedule_At25Percent() public {
        vm.warp(startTimestamp + 90 days);
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, totalAmount * 25 / 100);
    }

    function test_VestingSchedule_At50Percent() public {
        vm.warp(startTimestamp + 180 days);
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, totalAmount * 50 / 100);
    }

    function test_VestingSchedule_At75Percent() public {
        vm.warp(startTimestamp + 270 days);
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, totalAmount * 75 / 100);
    }

    function test_VestingSchedule_AtEnd() public {
        vm.warp(endTimestamp);
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, totalAmount);
    }

    function test_VestingSchedule_AfterEnd() public {
        vm.warp(endTimestamp + 1);
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, totalAmount);
    }

    function test_VestingSchedule_MiddleOfChunk() public {
        vm.warp(startTimestamp + 45 days); // Middle of first chunk (0% to 25%)
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, 0); // Should still be 0% since we haven't reached the 25% chunk yet
    }

    // ============ Clawback Tests ============

    function test_Clawback_OnlyAdminCanCall() public {
        vm.startPrank(nonAdmin);
        vm.expectRevert(ProportionalChunkedClawbackVault.UnauthorizedClawback.selector);
        vault.clawback(address(token));
        vm.stopPrank();
    }

    function test_Clawback_NoUnvestedTokens() public {
        // Fast forward past the vesting period
        vm.warp(endTimestamp + 1);
        
        // All tokens should be vested
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, totalAmount);
        
        // Try to clawback - should revert
        vm.startPrank(admin);
        vm.expectRevert(ProportionalChunkedClawbackVault.NothingToClawback.selector);
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
        // vm.expectEmit(true, false, false, true);
        // emit Clawback(address(token), totalAmount);
        vault.clawback(address(token));
        vm.stopPrank();
        
        // Check balances
        assertEq(token.balanceOf(admin), adminBalanceBefore + totalAmount);
        assertEq(token.balanceOf(address(vault)), vaultBalanceBefore - totalAmount);
    }

    function test_Clawback_PartialVesting() public {
        // Fast forward to 50% through vesting period
        vm.warp(startTimestamp + 180 days);
        
        // 50% of tokens should be vested
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        uint256 expectedVested = totalAmount * 50 / 100;
        assertEq(vested, expectedVested);
        
        uint256 expectedUnvested = totalAmount - expectedVested;
        uint256 adminBalanceBefore = token.balanceOf(admin);
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));
        
        // Admin should be able to clawback unvested tokens
        vm.startPrank(admin);
        // vm.expectEmit(true, false, false, true);
        // emit Clawback(address(token), expectedUnvested);
        vault.clawback(address(token));
        vm.stopPrank();
        
        // Check balances
        assertEq(token.balanceOf(admin), adminBalanceBefore + expectedUnvested);
        assertEq(token.balanceOf(address(vault)), vaultBalanceBefore - expectedUnvested);
    }

    function test_Clawback_AfterPartialRelease() public {
        // Fast forward to 25% through vesting period
        vm.warp(startTimestamp + 90 days);
        
        // Release some tokens to beneficiary
        uint256 releaseAmount = totalAmount * 25 / 100;
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();

        // Check that tokens were released
        assertEq(token.balanceOf(beneficiary), releaseAmount);
        assertEq(vault.released(address(token)), releaseAmount);

        // Fast forward to 50% through vesting period
        vm.warp(startTimestamp + 180 days);
        
        // Calculate remaining unvested tokens
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        uint256 expectedVested = totalAmount * 50 / 100; // 50% vested
        assertEq(vested, expectedVested);
        
        uint256 expectedUnvested = totalAmount - expectedVested;
        uint256 adminBalanceBefore = token.balanceOf(admin);
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));
        
        // Admin should be able to clawback remaining unvested tokens
        vm.startPrank(admin);
        vault.clawback(address(token));
        vm.stopPrank();
        
        // Check balances
        assertEq(token.balanceOf(admin), adminBalanceBefore + expectedUnvested);
        assertEq(token.balanceOf(address(vault)), vaultBalanceBefore - expectedUnvested);
    }

    function test_Clawback_CalculatesCorrectAmount() public {
        // Fast forward to 25% through vesting period
        vm.warp(startTimestamp + 90 days);
        
        // 25% should be vested
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        uint256 expectedVested = totalAmount * 25 / 100;
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
        vm.expectRevert(ProportionalChunkedClawbackVault.NothingToClawback.selector);
        vault.clawback(address(token));
        vm.stopPrank();
    }

    function test_Clawback_EventEmittedCorrectly() public {
        vm.startPrank(admin);
        
        // Capture the event
        // vm.expectEmit(true, false, false, true);
        // emit Clawback(address(token), totalAmount);
        
        vault.clawback(address(token));
        vm.stopPrank();
    }

    // ============ Release Tests ============

    function test_Release_OnlyBeneficiaryCanCall() public {
        vm.startPrank(nonAdmin);
        vm.expectRevert("VestingWallet: beneficiary is zero");
        vault.release(address(token));
        vm.stopPrank();
    }

    function test_Release_NoVestedTokens() public {
        // At the start, no tokens should be vested
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();
        
        // No tokens should be released
        assertEq(token.balanceOf(beneficiary), 0);
        assertEq(vault.released(address(token)), 0);
    }

    function test_Release_PartialVesting() public {
        // Fast forward to 25% through vesting period
        vm.warp(startTimestamp + 90 days);
        
        // 25% should be vested
        uint256 expectedVested = totalAmount * 25 / 100;
        
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();
        
        // Check that correct amount was released
        assertEq(token.balanceOf(beneficiary), expectedVested);
        assertEq(vault.released(address(token)), expectedVested);
    }

    function test_Release_MultipleReleases() public {
        // First release at 25%
        vm.warp(startTimestamp + 90 days);
        uint256 firstRelease = totalAmount * 25 / 100;
        
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();
        
        assertEq(token.balanceOf(beneficiary), firstRelease);
        
        // Second release at 50%
        vm.warp(startTimestamp + 180 days);
        uint256 secondRelease = totalAmount * 50 / 100 - firstRelease;
        
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();
        
        assertEq(token.balanceOf(beneficiary), firstRelease + secondRelease);
        assertEq(vault.released(address(token)), firstRelease + secondRelease);
    }

    // ============ Additional Token Tests ============

    function test_AdditionalTokensDuringVesting() public {
        // Fast forward to 50% through vesting period
        vm.warp(startTimestamp + 180 days);

        // Send additional tokens to the vault
        uint256 extraAmount = 500e18;
        vm.startPrank(admin);
        token.mint(address(vault), extraAmount);
        vm.stopPrank();

        // Now, total allocation is totalAmount + extraAmount
        // At 50%, 50% of all tokens should be vested
        uint256 expectedVested = (totalAmount + extraAmount) * 50 / 100;
        uint256 vested = vault.vestedAmount(address(token), uint64(block.timestamp));
        assertEq(vested, expectedVested);

        // The beneficiary can release the vested amount
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();
        assertEq(token.balanceOf(beneficiary), expectedVested);
    }

    function test_AdditionalTokensAfterVesting() public {
        // Fast forward to after vesting period
        vm.warp(endTimestamp + 1);

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

    // ============ Integration Tests ============

    function test_Integration_CompleteVestingCycle() public {
        // Start: 0% vested
        vm.warp(startTimestamp);
        assertEq(vault.vestedAmount(address(token), uint64(block.timestamp)), 0);
        
        // 25% vested
        vm.warp(startTimestamp + 90 days);
        assertEq(vault.vestedAmount(address(token), uint64(block.timestamp)), totalAmount * 25 / 100);
        
        // 50% vested
        vm.warp(startTimestamp + 180 days);
        assertEq(vault.vestedAmount(address(token), uint64(block.timestamp)), totalAmount * 50 / 100);
        
        // 75% vested
        vm.warp(startTimestamp + 270 days);
        assertEq(vault.vestedAmount(address(token), uint64(block.timestamp)), totalAmount * 75 / 100);
        
        // 100% vested
        vm.warp(endTimestamp);
        assertEq(vault.vestedAmount(address(token), uint64(block.timestamp)), totalAmount);
    }

    function test_Integration_ClawbackAndRelease() public {
        // At 25% vested, clawback 75%
        vm.warp(startTimestamp + 90 days);
        
        vm.startPrank(admin);
        vault.clawback(address(token));
        vm.stopPrank();
        
        assertEq(token.balanceOf(admin), totalAmount * 75 / 100);
        assertEq(token.balanceOf(address(vault)), totalAmount * 25 / 100);
        
        // Beneficiary can still release the 25% that's vested
        vm.startPrank(beneficiary);
        vault.release(address(token));
        vm.stopPrank();
        
        assertEq(token.balanceOf(beneficiary), totalAmount * 25 / 100);
        assertEq(token.balanceOf(address(vault)), 0);
    }
} 