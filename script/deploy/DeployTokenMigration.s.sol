// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {TokenMigrationContract} from "src/migration/TokenMigrationContract.sol";
import {TokenMigrationProposal} from "src/migration/TokenMigrationProposal.sol";
import {ECOxStakingBurnable} from "src/migration/upgrades/ECOxStakingBurnable.sol";
import {ECOx} from "lib/currency-1.5/contracts/currency/ECOx.sol";
import {ECOxStaking} from "currency-1.5/governance/community/ECOxStaking.sol";
import {IL1ECOBridge} from "src/migration/interfaces/IL1ECOBridge.sol";
import {Token} from "src/Token.sol";

import {IL1CrossDomainMessenger} from "@eth-optimism/contracts/L1/messaging/IL1CrossDomainMessenger.sol";



contract DeployTokenMigration is Script {
    function setUp() public {}

    function run() public {
        // --- 1. Load constructor arguments from environment ---
        ECOx ecox = ECOx(vm.envAddress("ECOX"));
        ECOxStaking secox = ECOxStaking(vm.envAddress("SECOX"));
        Token newToken = Token(vm.envAddress("NEW_TOKEN"));
        address admin = vm.envAddress("ADMIN");

        // Proposal args
        IL1CrossDomainMessenger l1Messenger = IL1CrossDomainMessenger(vm.envAddress("L1_MESSENGER"));
        IL1ECOBridge l1ECOBridge = IL1ECOBridge(vm.envAddress("L1_ECO_BRIDGE"));
        address staticMarket = vm.envAddress("STATIC_MARKET");
        address migrationOwnerOP = vm.envAddress("MIGRATOR_OP");
        address l2ECOxFreeze = vm.envAddress("L2_ECOX_FREEZE");
        uint32 l2gas = uint32(vm.envUint("L2GAS"));
        address secoxBurnable = vm.envAddress("SECOX_BURNABLE");
        address minter = vm.envAddress("MINTER");
        address l1ECOBridgeUpgrade = vm.envAddress("L1_ECO_BRIDGE_UPGRADE");
        address l2ECOBridgeUpgrade = vm.envAddress("L2_ECO_BRIDGE_UPGRADE");
        address claimContract = vm.envAddress("CLAIM_CONTRACT");

        // --- 2. Deploy TokenMigrationContract ---
        vm.startBroadcast();
        TokenMigrationContract migrationContract = new TokenMigrationContract(
            ecox,
            ECOxStakingBurnable(secoxBurnable),
            newToken,
            admin
        );
        console.log("TokenMigrationContract deployed at:", address(migrationContract));

        // --- 3. Deploy TokenMigrationProposal ---
        TokenMigrationProposal proposal = new TokenMigrationProposal(
            ecox,
            secox,
            newToken,
            TokenMigrationContract(address(migrationContract)),
            l1Messenger,
            l1ECOBridge,
            staticMarket,
            migrationOwnerOP, // new owner of static market maker
            l2ECOxFreeze,
            l2gas,
            secoxBurnable,
            minter,
            l1ECOBridgeUpgrade,
            l2ECOBridgeUpgrade,
            claimContract
        );
        vm.stopBroadcast();
        console.log("TokenMigrationProposal deployed at:", address(proposal));
    }
} 