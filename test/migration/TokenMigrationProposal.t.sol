pragma solidity ^0.8.0;

// Forge
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// Local contracts
import {Token} from "src/tokens/Token.sol";
import {TokenMigrationContract} from "src/migration/TokenMigrationContract.sol";
import {TokenMigrationProposal} from "src/migration/TokenMigrationProposal.sol";

// Currency 1.5 contracts
import {ECOx} from "currency-1.5/currency/ECOx.sol";
import {ECOxStaking} from "currency-1.5/governance/community/ECOxStaking.sol";
import {Policy} from "currency-1.5/policy/Policy.sol";

// OP-ECO contracts 
import {IL1ECOBridge} from "src/migration/interfaces/IL1ECOBridge.sol"; 
import {IL2ECOBridge} from "src/migration/interfaces/IL2ECOBridge.sol";
// https://ethereum.stackexchange.com/questions/153940/how-to-resolve-compiler-version-conflicts-in-foundry-test-contracts
// import {L2ECOx} from "op-eco/token/L2ECOx.sol";

// Optimism contracts
import {IL1CrossDomainMessenger} from "@eth-optimism/contracts/L1/messaging/IL1CrossDomainMessenger.sol";
import {IL2CrossDomainMessenger} from "@eth-optimism/contracts/L2/messaging/IL2CrossDomainMessenger.sol";
import {AddressAliasHelper} from "@eth-optimism/contracts-bedrock/contracts/vendor/AddressAliasHelper.sol";
import {Hashing} from "lib/op-eco/node_modules/@eth-optimism/contracts-bedrock/contracts/libraries/Hashing.sol";


contract TokenMigrationProposalTest is Test {
    uint256 mainnetFork;
    uint256 optimismFork;

    string mainnetRpcUrl = vm.envString("MAINNET_RPC_URL");
    string optimismRpcUrl = vm.envString("OPTIMISM_RPC_URL");

    //L1 Protocol Addresses
    address constant securityCouncil =
        0xCF2A6B4bc14A1FEf0862c9583b61B1beeDE980C2;
    address constant previousMultisig =
        0x99f98ea4A883DB4692Fa317070F4ad2dC94b05CE;
    Policy policy = Policy(0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68);
    ECOx ecox = ECOx(0xcccD1Ba9f7acD6117834E0D28F25645dECb1736a);
    ECOxStaking secox = ECOxStaking(0x3a16f2Fee32827a9E476d0c87E454aB7C75C92D7);
    IL1ECOBridge l1ECOBridge =
        IL1ECOBridge(0xAa029BbdC947F5205fBa0F3C11b592420B58f824);
    IL1CrossDomainMessenger l1Messenger =
        IL1CrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);
    TokenMigrationProposal proposal; 
    Token token;
    TokenMigrationContract migrationContract;
    
}
