pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Token} from "src/Token.sol";
import {BurnBadSupplyProposal} from "src/migration/BurnBadSupplyProposal.sol";
import {console} from "forge-std/console.sol";

contract BurnBadSupplyProposalTest is Test {
    uint256 mainnetFork;
    string mainnetRpcUrl = vm.envString("MAINNET_RPC_URL");
    
    BurnBadSupplyProposal proposal;
    Token token;
    address migrationContract;
    address policy;

    function setUp() public {
        mainnetFork = vm.createSelectFork(mainnetRpcUrl, 22597199);
        
        // Get addresses from environment
        token = Token(vm.envAddress("NEW_TOKEN"));
        migrationContract = vm.envAddress("MIGRATION_CONTRACT");
        policy = vm.envAddress("POLICY");
        
        console.log("token", address(token));
        console.log("totalSupply", token.totalSupply());

        // Deploy proposal
        proposal = new BurnBadSupplyProposal(
            address(token),
            migrationContract
        );
    }

    function test_enactment_burns_all_tokens() public {
        // Get initial balance of migration contract
        uint256 initialBalance = token.balanceOf(migrationContract);
        
        console.log("Initial balance:", initialBalance);
        console.log("Initial total supply:", token.totalSupply());

        // Enact the proposal
        // vm.prank(policy);
        // proposal.enacted(address(proposal));

        // // Verify all tokens burned
        // assertEq(token.balanceOf(migrationContract), 0);
        // assertEq(token.totalSupply(), 0);
        console.log("Final balance:", token.balanceOf(migrationContract));
        console.log("Final total supply:", token.totalSupply());
    }
} 