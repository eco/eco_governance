// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BurnBadSupplyProposal} from "../../src/migration/BurnBadSupplyProposal.sol";

contract DeployBurnBadSupplyProposalScript is Script {
    BurnBadSupplyProposal public burnBadSupplyProposal;

    function setUp() public {}

    function run() public {
        // Get deployment parameters from environment or use defaults
        address newToken = vm.envAddress("NEW_TOKEN");
        address migrationContract = vm.envAddress("MIGRATION_CONTRACT");

        console.log("Deploying BurnBadSupplyProposal...");
        console.log("New Token address:", newToken);
        console.log("Migration Contract address:", migrationContract);

        vm.startBroadcast();

        // Deploy the BurnBadSupplyProposal contract
        burnBadSupplyProposal = new BurnBadSupplyProposal(newToken, migrationContract);
        console.log("BurnBadSupplyProposal deployed at:", address(burnBadSupplyProposal));

        vm.stopBroadcast();

        console.log("Deployment complete!");
        console.log("BurnBadSupplyProposal:", address(burnBadSupplyProposal));
        console.log("New Token:", burnBadSupplyProposal.newToken());
        console.log("Migration Contract:", burnBadSupplyProposal.migrationContract());
        console.log("Proposal name:", burnBadSupplyProposal.name());
        console.log("Proposal description:", burnBadSupplyProposal.description());
        console.log("Proposal URL:", burnBadSupplyProposal.url());
        
        // Verification on Etherscan
        console.log("\n=== ETHERSCAN VERIFICATION ===");
        console.log("To verify on Etherscan, run:");
        console.log("forge verify-contract", address(burnBadSupplyProposal), "src/migration/BurnBadSupplyProposal.sol:BurnBadSupplyProposal --chain-id 1 --constructor-args", vm.toString(abi.encode(newToken, migrationContract)));
    }
} 