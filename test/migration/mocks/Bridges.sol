pragma solidity ^0.8.19;

import {L2ECOBridge} from "lib/op-eco/contracts/bridge/L2ECOBridge.sol";
import {L1ECOBridge} from "lib/op-eco/contracts/bridge/L1ECOBridge.sol";

// we have to make this throw away file so foundry builds these contacts in /out
// this is a workaround so we can deploy them using deployCode in the test
// see https://ethereum.stackexchange.com/questions/153940/how-to-resolve-compiler-version-conflicts-in-foundry-test-contracts
