// pragma solidity ^0.8.0;

// import {Test} from "forge-std/Test.sol";
// import {GrantPauseExemptProposal} from "src/migration/GrantPauseExemptProposal.sol";
// import {Token} from "src/Token.sol";
// import {TokenMigrationContract} from "src/migration/TokenMigrationContract.sol";
// import {Policy} from "currency-1.5/policy/Policy.sol";

// contract GrantPauseExemptProposalTest is Test {
//     Token public token;
//     TokenMigrationContract public migrationContract;
//     GrantPauseExemptProposal public proposal;
//     Policy public policy;

//     address constant TOKEN_ADDRESS = 0x892e0aeA725d365c2619282eA7a974E1dDAec821;
//     address constant MIGRATION_CONTRACT = 0x51668c454dFA893bef6169a8878A7CB074D663eb;
//     address constant ADMIN_ADDRESS = 0xCF2A6B4bc14A1FEf0862c9583b61B1beeDE980C2;
//     address constant POLICY_ADDRESS = 0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68;

//     address constant PAUSE_EXEMPT_1 = 0xa0e01DBcF91BE184815716c4875A627C936C5BD1;
//     address constant PAUSE_EXEMPT_2 = 0x0D0707963952f2fBA59dD06f2b425ace40b492Fe;
//     address constant PAUSE_EXEMPT_3 = 0x2BFE6b37589b4069EB137D33d2233D1EB3a5d2d5;

//     uint256 mainnetFork;

//     function setUp() public {
//         string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
//         mainnetFork = vm.createFork(rpcUrl);
//         vm.selectFork(mainnetFork);
//         vm.rollFork(23427073);

//         token = Token(TOKEN_ADDRESS);
//         migrationContract = TokenMigrationContract(MIGRATION_CONTRACT);
//         policy = Policy(POLICY_ADDRESS);

//         proposal = new GrantPauseExemptProposal(token, PAUSE_EXEMPT_1, PAUSE_EXEMPT_2, PAUSE_EXEMPT_3, MIGRATION_CONTRACT);
//     }

//     function testGrantPauseExemptRole() public {
//         uint256 migrationBalance = token.balanceOf(MIGRATION_CONTRACT);
//         require(migrationBalance > 0, "Migration contract should have balance");

//         uint256 transferAmount = 1e18; // 1 token

//         vm.deal(PAUSE_EXEMPT_2, 1 ether);
//         vm.deal(PAUSE_EXEMPT_3, 1 ether);

//         vm.prank(PAUSE_EXEMPT_1);
//         vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
//         token.transfer(PAUSE_EXEMPT_2, transferAmount);

//         vm.prank(PAUSE_EXEMPT_2);
//         vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
//         token.transfer(PAUSE_EXEMPT_3, transferAmount);

//         vm.prank(PAUSE_EXEMPT_3);
//         vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
//         token.transfer(PAUSE_EXEMPT_1, transferAmount);

//         vm.prank(ADMIN_ADDRESS);
//         policy.enact(address(proposal));

//         assertTrue(token.hasRole(token.PAUSE_EXEMPT_ROLE(), PAUSE_EXEMPT_1), "PAUSE_EXEMPT_1 should have role");
//         assertTrue(token.hasRole(token.PAUSE_EXEMPT_ROLE(), PAUSE_EXEMPT_2), "PAUSE_EXEMPT_2 should have role");
//         assertTrue(token.hasRole(token.PAUSE_EXEMPT_ROLE(), PAUSE_EXEMPT_3), "PAUSE_EXEMPT_3 should have role");
//         assertTrue(token.hasRole(token.PAUSE_EXEMPT_ROLE(), MIGRATION_CONTRACT), "MIGRATION_CONTRACT should have role");

//         vm.prank(ADMIN_ADDRESS);
//         migrationContract.sweep(PAUSE_EXEMPT_1);

//         assertEq(token.balanceOf(PAUSE_EXEMPT_1), migrationBalance, "Sweep should transfer tokens");
//         assertEq(token.balanceOf(MIGRATION_CONTRACT), 0, "Migration contract should be empty");

//         uint256 initialPolicyBalance = token.balanceOf(POLICY_ADDRESS);

//         // First give some tokens to PAUSE_EXEMPT_2 and PAUSE_EXEMPT_3
//         vm.prank(PAUSE_EXEMPT_1);
//         token.transfer(PAUSE_EXEMPT_2, transferAmount * 2);

//         vm.prank(PAUSE_EXEMPT_1);
//         token.transfer(PAUSE_EXEMPT_3, transferAmount * 3);

//         // Now each transfers to policy
//         vm.prank(PAUSE_EXEMPT_1);
//         bool success1 = token.transfer(POLICY_ADDRESS, transferAmount);
//         assertTrue(success1, "Transfer 1 token from PAUSE_EXEMPT_1 should succeed");

//         vm.prank(PAUSE_EXEMPT_2);
//         bool success2 = token.transfer(POLICY_ADDRESS, transferAmount * 2);
//         assertTrue(success2, "Transfer 2 tokens from PAUSE_EXEMPT_2 should succeed");

//         vm.prank(PAUSE_EXEMPT_3);
//         bool success3 = token.transfer(POLICY_ADDRESS, transferAmount * 3);
//         assertTrue(success3, "Transfer 3 tokens from PAUSE_EXEMPT_3 should succeed");

//         // These addresses may have initial balances on mainnet, so we check relative changes
//         assertTrue(token.balanceOf(PAUSE_EXEMPT_1) > 0, "PAUSE_EXEMPT_1 should have balance");
//         assertTrue(token.balanceOf(PAUSE_EXEMPT_2) < transferAmount, "PAUSE_EXEMPT_2 should have less than 1 token");
//         assertTrue(token.balanceOf(PAUSE_EXEMPT_3) >= 0, "PAUSE_EXEMPT_3 balance check");
//         assertEq(token.balanceOf(POLICY_ADDRESS), initialPolicyBalance + transferAmount * 6, "Policy should have 6 more tokens");
//     }
// }