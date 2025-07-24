// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {UnsafeUpgrades as Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract TokenTest is Test {
    // Test addresses
    address admin = address(0x1);
    address pauser = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);

    // Token instance
    Token token;
    ProxyAdmin proxyAdmin;

    // Constants
    string constant NAME = "Test Token";
    string constant SYMBOL = "TEST";
    uint256 constant INITIAL_SUPPLY = 0;

    // Role constants
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 constant PAUSE_EXEMPT_ROLE = keccak256("PAUSE_EXEMPT_ROLE");

    // Event signatures from AccessControlUpgradeable
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    // Event signatures from PausableUpgradeable
    event Paused(address account);
    event Unpaused(address account);

    // Event signatures from ERC20
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Foundry default test account 0
    address constant FOUNDRY_OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant FOUNDRY_OWNER_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function setUp() public {
        // Deploy implementation
        Token implementation = new Token();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(Token.initialize.selector, admin, pauser, NAME, SYMBOL);

        address tokenProxy = Upgrades.deployTransparentProxy(address(implementation), admin, initData);

        // Set token instance to proxy
        token = Token(tokenProxy);
    }

    function test_InitializerCanRunOnce() public {
        // First initialize should revert (already initialized)
        bytes memory initData = abi.encodeWithSelector(Token.initialize.selector, admin, pauser, NAME, SYMBOL);
        // Try to call initialize again via proxy
        vm.expectRevert("Initializable: contract is already initialized");
        (bool success,) = address(token).call(initData);
        assertTrue(!success, "Should not be able to initialize twice");
    }

    function test_ConstructorIsDisabled() public {
        // Deploy implementation directly
        Token implementation = new Token();
        // Try to initialize the implementation contract
        bytes memory initData = abi.encodeWithSelector(Token.initialize.selector, admin, pauser, NAME, SYMBOL);
        // Expect revert when trying to initialize the implementation
        vm.expectRevert("Initializable: contract is not initializing");
        (bool success,) = address(implementation).call(initData);
        assertTrue(!success, "Implementation should not be initializable");
    }

    function test_RoleAssignmentsOnInit() public {
        // admin gets all roles
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(MINTER_ROLE, admin));
        assertTrue(token.hasRole(BURNER_ROLE, admin));
        assertTrue(token.hasRole(PAUSER_ROLE, admin));
        // pauser gets only PAUSER_ROLE
        assertTrue(token.hasRole(PAUSER_ROLE, pauser));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), pauser));
        assertFalse(token.hasRole(MINTER_ROLE, pauser));
        assertFalse(token.hasRole(BURNER_ROLE, pauser));
        // No one has PAUSE_EXEMPT_ROLE by default
        assertFalse(token.hasRole(PAUSE_EXEMPT_ROLE, admin));
        assertFalse(token.hasRole(PAUSE_EXEMPT_ROLE, pauser));
    }

    function test_ERC20Metadata() public {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
    }

    function test_EIP2612DomainSeparatorAndVersion() public {
        // DOMAIN_SEPARATOR encodes correct chainId, contract address, name, version "1"
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 expectedDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(NAME)),
                keccak256(bytes("1")),
                chainId,
                address(token)
            )
        );
        assertEq(token.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }

    function test_OnlyAdminCanGrantRoles() public {
        // Non-admin address fails to grantRole
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)", user1, token.DEFAULT_ADMIN_ROLE()
            )
        );
        token.grantRole(MINTER_ROLE, user2);
        vm.stopPrank();
        // Admin can grant and revoke each custom role
        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, user2);
        assertTrue(token.hasRole(MINTER_ROLE, user2));
        token.revokeRole(MINTER_ROLE, user2);
        assertFalse(token.hasRole(MINTER_ROLE, user2));
        vm.stopPrank();
    }

    function test_RoleBasedModifiers() public {
        // Functions protected by onlyRole(X) revert if caller lacks role X
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", user1, MINTER_ROLE)
        );
        token.mint(user2, 100);
        vm.stopPrank();
        // After revokeRole, access is revoked immediately
        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, user1);
        assertTrue(token.hasRole(MINTER_ROLE, user1));
        token.revokeRole(MINTER_ROLE, user1);
        assertFalse(token.hasRole(MINTER_ROLE, user1));
        vm.stopPrank();
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", user1, MINTER_ROLE)
        );
        token.mint(user2, 100);
        vm.stopPrank();
    }

    function test_RoleEvents() public {
        // RoleGranted & RoleRevoked emit correct role hash, account, sender
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(MINTER_ROLE, user1, admin);
        token.grantRole(MINTER_ROLE, user1);
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(MINTER_ROLE, user1, admin);
        token.revokeRole(MINTER_ROLE, user1);
        vm.stopPrank();
    }

    function test_StandardTransfers() public {
        // Mint some tokens to user1
        vm.startPrank(admin);
        token.mint(user1, 100);
        vm.stopPrank();
        // Transfer tokens from user1 to user2
        vm.startPrank(user1);
        token.transfer(user2, 50);
        assertEq(token.balanceOf(user1), 50);
        assertEq(token.balanceOf(user2), 50);
        // Transfer should revert if sender balance < amount
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", user1, 50, 100));
        token.transfer(user2, 100);
        // Transfer should revert if recipient is address(0)
        vm.expectRevert(abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0)));
        token.transfer(address(0), 10);
        vm.stopPrank();
    }

    function test_ApprovalsAndAllowances() public {
        // Mint some tokens to user1
        vm.startPrank(admin);
        token.mint(user1, 100);
        vm.stopPrank();
        // Approve user2 to spend tokens from user1
        vm.startPrank(user1);
        token.approve(user2, 50);
        assertEq(token.allowance(user1, user2), 50);
        // TransferFrom should succeed and reduce allowance
        vm.stopPrank();
        vm.startPrank(user2);
        token.transferFrom(user1, user2, 30);
        assertEq(token.balanceOf(user2), 30);
        assertEq(token.allowance(user1, user2), 20);
        // Re-use with exact allowance succeeds
        token.transferFrom(user1, user2, 20);
        assertEq(token.balanceOf(user2), 50);
        assertEq(token.allowance(user1, user2), 0);
        // One wei over allowance fails
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientAllowance(address,uint256,uint256)", user2, 0, 1));
        token.transferFrom(user1, user2, 1);
        vm.stopPrank();
    }

    function test_InvariantSumOfBalancesEqualsTotalSupply() public {
        // Mint tokens to user1 and user2
        vm.startPrank(admin);
        token.mint(user1, 100);
        token.mint(user2, 200);
        vm.stopPrank();
        // Transfer some tokens
        vm.startPrank(user1);
        token.transfer(user2, 30);
        vm.stopPrank();
        // Check invariant
        assertEq(token.balanceOf(user1) + token.balanceOf(user2), token.totalSupply());
    }

    function test_OnlyMinterCanMint() public {
        // Non-minter cannot mint
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", user1, MINTER_ROLE)
        );
        token.mint(user1, 100);
        vm.stopPrank();
        // Minter can mint
        vm.startPrank(admin);
        token.mint(user1, 100);
        assertEq(token.balanceOf(user1), 100);
        assertEq(token.totalSupply(), 100);
        vm.stopPrank();
    }

    function test_MintToZeroReverts() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0)));
        token.mint(address(0), 100);
        vm.stopPrank();
    }

    function test_OnlyBurnerCanBurn() public {
        // Mint tokens to user1
        vm.startPrank(admin);
        token.mint(user1, 100);
        vm.stopPrank();
        // Non-burner cannot burn
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", user1, BURNER_ROLE)
        );
        token.burn(user1, 50);
        vm.stopPrank();
        // Burner can burn
        vm.startPrank(admin);
        token.burn(user1, 50);
        assertEq(token.balanceOf(user1), 50);
        assertEq(token.totalSupply(), 50);
        vm.stopPrank();
    }

    function test_BurnMoreThanBalanceReverts() public {
        // Mint tokens to user1
        vm.startPrank(admin);
        token.mint(user1, 100);
        // Try to burn more than balance
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", user1, 100, 200));
        token.burn(user1, 200);
        vm.stopPrank();
    }

    function test_BurnFromZeroReverts() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("ERC20InvalidSender(address)", address(0)));
        token.burn(address(0), 100);
        vm.stopPrank();
    }

    function test_MintAndBurnWhilePausedAllowed() public {
        // Pause the contract
        vm.startPrank(admin);
        token.pause();
        // Mint and burn should still work
        token.mint(user1, 100);
        token.burn(user1, 50);
        assertEq(token.balanceOf(user1), 50);
        assertEq(token.totalSupply(), 50);
        vm.stopPrank();
    }

    function test_OnlyPauserCanPauseAndUnpause() public {
        // Non-pauser cannot pause
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", user1, PAUSER_ROLE)
        );
        token.pause();
        vm.stopPrank();
        // Pauser can pause
        vm.startPrank(pauser);
        token.pause();
        assertTrue(token.paused());
        vm.stopPrank();
        // Non-pauser cannot unpause
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", user1, PAUSER_ROLE)
        );
        token.unpause();
        vm.stopPrank();
        // Pauser can unpause
        vm.startPrank(pauser);
        token.unpause();
        assertFalse(token.paused());
        vm.stopPrank();
    }

    function test_PauseStateToggling() public {
        vm.startPrank(pauser);
        token.pause();
        assertTrue(token.paused());
        // Pausing again should revert
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.pause();
        // Unpause
        token.unpause();
        assertFalse(token.paused());
        // Unpause again should revert
        vm.expectRevert(abi.encodeWithSignature("ExpectedPause()"));
        token.unpause();
        vm.stopPrank();
    }

    function test_TransfersBlockedWhenPaused() public {
        // Mint tokens to user1
        vm.startPrank(admin);
        token.mint(user1, 100);
        vm.stopPrank();
        // Pause the contract
        vm.startPrank(pauser);
        token.pause();
        vm.stopPrank();
        // Transfers should revert
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.transfer(user2, 10);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        token.transferFrom(user1, user2, 10);
        vm.stopPrank();
    }

    function test_PausedTransferFailsIfNotPaused() public {
        // Grant PAUSE_EXEMPT_ROLE to user1
        vm.startPrank(admin);
        token.grantRole(PAUSE_EXEMPT_ROLE, user1);
        token.mint(user1, 1000);
        vm.stopPrank();
        // pausedTransfer should fail if not paused
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("ExpectedPause()"));
        token.pausedTransfer(user2, 10);
        vm.stopPrank();
    }

    function test_PausedTransferFailsIfLacksRole() public {
        // Ensure contract is paused
        vm.startPrank(pauser);
        token.pause();
        vm.stopPrank();
        // pausedTransfer should fail if caller lacks role
        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", user2, PAUSE_EXEMPT_ROLE)
        );
        token.pausedTransfer(user1, 10);
        vm.stopPrank();
    }

    function test_PausedTransferSucceedsWithRole() public {
        // Grant PAUSE_EXEMPT_ROLE and mint tokens to user1
        vm.startPrank(admin);
        token.grantRole(PAUSE_EXEMPT_ROLE, user1);
        token.mint(user1, 100);
        vm.stopPrank();

        // Pause the contract
        vm.startPrank(pauser);
        token.pause();
        vm.stopPrank();

        // Verify paused transfer works with role
        vm.startPrank(user1);
        token.pausedTransfer(user2, 50);
        assertEq(token.balanceOf(user1), 50);
        assertEq(token.balanceOf(user2), 50);
        vm.stopPrank();
    }

    function test_PausedTransferFailsIfInsufficientBalance() public {
        // Grant PAUSE_EXEMPT_ROLE to user1
        vm.startPrank(admin);
        token.grantRole(PAUSE_EXEMPT_ROLE, user1);
        token.mint(user1, 50);
        vm.stopPrank();
        // Ensure contract is paused
        vm.startPrank(pauser);
        token.pause();
        vm.stopPrank();
        // pausedTransfer should fail if insufficient balance
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", user1, 50, 100));
        token.pausedTransfer(user2, 100);
        vm.stopPrank();
    }

    function test_PausedAndUnpausedEvents() public {
        vm.startPrank(pauser);
        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);
        token.pause();
        vm.expectEmit(true, false, false, false);
        emit Unpaused(pauser);
        token.unpause();
        vm.stopPrank();
    }

    function test_Permit_ValidSignatureFlow() public {
        address owner = FOUNDRY_OWNER;
        address spender = address(2); // private key 2
        uint256 value = 123;
        uint256 deadline = block.timestamp + 1 days;
        vm.startPrank(admin);
        token.mint(owner, value);
        vm.stopPrank();
        // Prepare permit signature
        uint256 nonce = token.nonces(owner);
        bytes32 digest = getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(FOUNDRY_OWNER_PK, digest);
        // Call permit
        vm.prank(spender);
        token.permit(owner, spender, value, deadline, v, r, s);
        // Check allowance and nonce
        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), nonce + 1);
    }

    function test_Permit_ReplayProtection() public {
        address owner = FOUNDRY_OWNER;
        address spender = address(2);
        uint256 value = 123;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = token.nonces(owner);
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(FOUNDRY_OWNER_PK, digest);

        // First permit should succeed
        vm.prank(spender);
        token.permit(owner, spender, value, deadline, v, r, s);

        // Second permit with same signature should fail
        vm.prank(spender);
        // Recompute digest for the incremented nonce (which is what the contract will use)
        uint256 newNonce = token.nonces(owner); // should be incremented by 1
        bytes32 structHash2 = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                newNonce,
                deadline
            )
        );
        bytes32 digest2 = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash2));
        address recoveredSigner = ecrecover(digest2, v, r, s);
        vm.expectRevert(abi.encodeWithSignature("ERC2612InvalidSigner(address,address)", recoveredSigner, owner));
        token.permit(owner, spender, value, deadline, v, r, s);
    }

    function test_Permit_DeadlineEnforcement() public {
        address owner = FOUNDRY_OWNER;
        address spender = address(2); // private key 2
        uint256 value = 123;
        uint256 deadline = block.timestamp - 1; // expired
        vm.startPrank(admin);
        token.mint(owner, value);
        vm.stopPrank();
        uint256 nonce = token.nonces(owner);
        bytes32 digest = getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(FOUNDRY_OWNER_PK, digest);
        vm.prank(spender);
        vm.expectRevert(abi.encodeWithSignature("ERC2612ExpiredSignature(uint256)", deadline));
        token.permit(owner, spender, value, deadline, v, r, s);
    }

    function test_Permit_ZeroAddressEdgeCases() public {
        // Test with zero owner
        vm.expectRevert(abi.encodeWithSignature("ECDSAInvalidSignature()"));
        token.permit(address(0), address(2), 123, block.timestamp + 1 days, 0, bytes32(0), bytes32(0));

        // Test with zero spender
        vm.expectRevert(abi.encodeWithSignature("ECDSAInvalidSignature()"));
        token.permit(FOUNDRY_OWNER, address(0), 123, block.timestamp + 1 days, 0, bytes32(0), bytes32(0));
    }

    function test_Permit_MaxDeadline() public {
        address owner = FOUNDRY_OWNER;
        address spender = address(2); // private key 2
        uint256 value = 123;
        uint256 deadline = type(uint256).max;
        vm.startPrank(admin);
        token.mint(owner, value);
        vm.stopPrank();
        uint256 nonce = token.nonces(owner);
        bytes32 digest = getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(FOUNDRY_OWNER_PK, digest);
        vm.prank(spender);
        token.permit(owner, spender, value, deadline, v, r, s);
        assertEq(token.allowance(owner, spender), value);
        assertEq(token.nonces(owner), nonce + 1);
    }

    function test_Permit_GaslessTransferFrom() public {
        address owner = FOUNDRY_OWNER;
        address spender = address(2); // private key 2
        uint256 value = 123;
        uint256 deadline = block.timestamp + 1 days;
        vm.startPrank(admin);
        token.mint(owner, value);
        vm.stopPrank();
        uint256 nonce = token.nonces(owner);
        bytes32 digest = getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(FOUNDRY_OWNER_PK, digest);
        // Permit
        vm.prank(spender);
        token.permit(owner, spender, value, deadline, v, r, s);
        // Gasless transferFrom
        vm.prank(spender);
        token.transferFrom(owner, spender, value);
        assertEq(token.balanceOf(spender), value);
        assertEq(token.allowance(owner, spender), 0);
    }

    function test_EventEmissions() public {
        // Test Transfer event
        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, 100);
        token.mint(user1, 100);
        vm.stopPrank();

        // Test Approval event
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit Approval(user1, user2, 50);
        token.approve(user2, 50);
        vm.stopPrank();

        // Test Transfer event from transfer
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, 30);
        token.transfer(user2, 30);
        vm.stopPrank();

        // Test Transfer event from transferFrom
        vm.startPrank(user2);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, 20);
        token.transferFrom(user1, user2, 20);
        vm.stopPrank();

        // Test Transfer event from burn
        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user2, address(0), 50);
        token.burn(user2, 50);
        vm.stopPrank();

        // Test Transfer event from pausedTransfer
        vm.startPrank(admin);
        token.grantRole(PAUSE_EXEMPT_ROLE, user1);
        token.mint(user1, 100);
        token.pause();
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, 40);
        token.pausedTransfer(user2, 40);
        vm.stopPrank();
    }

    function test_MintAndBurnEvents() public {
        // Test single mint event
        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, 100);
        token.mint(user1, 100);
        vm.stopPrank();

        // Test multiple mint events
        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, 50);
        token.mint(user1, 50);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user2, 75);
        token.mint(user2, 75);
        vm.stopPrank();

        // Test single burn event
        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), 50);
        token.burn(user1, 50);
        vm.stopPrank();

        // Test multiple burn events
        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), 50);
        token.burn(user1, 50);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user2, address(0), 75);
        token.burn(user2, 75);
        vm.stopPrank();

        // Test mint-burn-mint sequence
        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, 200);
        token.mint(user1, 200);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), 100);
        token.burn(user1, 100);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, 50);
        token.mint(user1, 50);
        vm.stopPrank();

        // Test mint-burn sequence with multiple users
        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, 100);
        token.mint(user1, 100);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user2, 100);
        token.mint(user2, 100);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), 50);
        token.burn(user1, 50);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user2, address(0), 50);
        token.burn(user2, 50);
        vm.stopPrank();
    }

    function test_EventEmissionsEdgeCases() public {
        // Test no events emitted on failed operations
        vm.startPrank(admin);
        token.mint(user1, 100);
        vm.stopPrank();

        // Failed transfer due to insufficient balance
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", user1, 100, 200));
        token.transfer(user2, 200);
        vm.stopPrank();

        // Failed transferFrom due to insufficient allowance
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientAllowance(address,uint256,uint256)", user2, 0, 50));
        token.transferFrom(user1, user2, 50);
        vm.stopPrank();

        // Failed mint to zero address
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0)));
        token.mint(address(0), 100);
        vm.stopPrank();

        // Failed burn from zero address
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("ERC20InvalidSender(address)", address(0)));
        token.burn(address(0), 100);
        vm.stopPrank();

        // Test permit event emissions
        address owner = FOUNDRY_OWNER;
        address spender = address(2);
        uint256 value = 123;
        uint256 deadline = block.timestamp + 1 days;
        vm.startPrank(admin);
        token.mint(owner, value);
        vm.stopPrank();

        uint256 nonce = token.nonces(owner);
        bytes32 digest = getPermitDigest(owner, spender, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(FOUNDRY_OWNER_PK, digest);

        // Expect Approval event from permit
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, value);
        vm.prank(spender);
        token.permit(owner, spender, value, deadline, v, r, s);

        // Test role change event emissions
        vm.startPrank(admin);
        // Grant role
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(PAUSE_EXEMPT_ROLE, user1, admin);
        token.grantRole(PAUSE_EXEMPT_ROLE, user1);

        // Revoke role
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(PAUSE_EXEMPT_ROLE, user1, admin);
        token.revokeRole(PAUSE_EXEMPT_ROLE, user1);
        vm.stopPrank();

        // Test pause/unpause event emissions
        vm.startPrank(pauser);
        // Pause
        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);
        token.pause();

        // Unpause
        vm.expectEmit(true, false, false, false);
        emit Unpaused(pauser);
        token.unpause();
        vm.stopPrank();
    }

    // Helper for EIP-2612 permit digest
    function getPermitDigest(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
    }
}

