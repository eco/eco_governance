// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ECOxBurner} from "../../src/migration/ECOxBurner.sol";
import {ECOxZero} from "../../src/migration/upgrades/ECOxZero.sol";
import {ECOxCleanupProposal} from "../../src/migration/ECOxCleanupProposal.sol";
import {Policy} from "../../lib/currency-1.5/contracts/policy/Policy.sol";

contract DeployECOxCleanupScript is Script {
    ECOxBurner public ecoxBurner;
    ECOxZero public ecoxZero;
    ECOxCleanupProposal public cleanupProposal;

    function setUp() public {}

    function run() public {
        // Get deployment parameters from environment or use defaults
        address ecoxAddress = vm.envAddress("ECOX");
        address owner = vm.envAddress("ADMIN");
        address policy = vm.envAddress("POLICY");
        address pauser = vm.envAddress("ADMIN");

        console.log("Deploying ECOx Cleanup contracts...");
        console.log("ECOx address:", ecoxAddress);
        console.log("Owner address:", owner);
        console.log("Policy address:", policy);
        console.log("Pauser address:", pauser);

        vm.startBroadcast();

        // Deploy ECOxZero implementation
        console.log("Deploying ECOxZero implementation...");
        ecoxZero = new ECOxZero(Policy(policy), pauser);
        console.log("ECOxZero implementation deployed at:", address(ecoxZero));

        // Deploy ECOxBurner
        console.log("Deploying ECOxBurner...");
        ecoxBurner = new ECOxBurner(ecoxAddress, owner);
        console.log("ECOxBurner deployed at:", address(ecoxBurner));

        // Deploy ECOxCleanupProposal
        console.log("Deploying ECOxCleanupProposal...");
        cleanupProposal = new ECOxCleanupProposal(
            ecoxAddress,
            address(ecoxBurner),
            address(ecoxZero)
        );
        console.log("ECOxCleanupProposal deployed at:", address(cleanupProposal));

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("ECOxZero implementation:", address(ecoxZero));
        console.log("ECOxBurner:", address(ecoxBurner));
        console.log("ECOxCleanupProposal:", address(cleanupProposal));
        
        // Verification on Etherscan
        console.log("\n=== ETHERSCAN VERIFICATION ===");
        console.log("To verify on Etherscan, run:");
        console.log("forge verify-contract", address(ecoxZero), "src/migration/upgrades/ECOxZero.sol:ECOxZero --chain-id 1 --constructor-args", vm.toString(abi.encode(policy, pauser)));
        console.log("forge verify-contract", address(ecoxBurner), "src/migration/ECOxBurner.sol:ECOxBurner --chain-id 1 --constructor-args", vm.toString(abi.encode(ecoxAddress, owner)));
        console.log("forge verify-contract", address(cleanupProposal), "src/migration/ECOxCleanupProposal.sol:ECOxCleanupProposal --chain-id 1 --constructor-args", vm.toString(abi.encode(ecoxAddress, address(ecoxBurner), address(ecoxZero))));
    }
} 