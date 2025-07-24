// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";

// These import paths may need to be adjusted based on your repo structure
import {IL2ECOxFreeze} from "src/migration/interfaces/IL2ECOxFreeze.sol";
import {L2ECOxFreeze} from "src/migration/upgrades/L2ECOxFreeze.sol";
import {IL2ECOBridge} from "src/migration/interfaces/IL2ECOBridge.sol";
import {L2ECOBridge as L2ECOBridgeUpgrade} from "lib/op-eco/contracts/bridge/L2ECOBridge.sol";
import {console} from "forge-std/console.sol";


contract DeployL2Contracts is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy the L2 ECOx Freeze contract
        L2ECOxFreeze l2ECOxFreeze = new L2ECOxFreeze();
        console.log("L2ECOxFreeze deployed at:", address(l2ECOxFreeze));

        // Deploy the L2 ECO Bridge upgrade contract from lib.com
        L2ECOBridgeUpgrade l2ECOBridgeUpgrade = new L2ECOBridgeUpgrade();
        console.log("L2ECOBridgeUpgrade deployed at:", address(l2ECOBridgeUpgrade));

        vm.stopBroadcast();
    }
}
