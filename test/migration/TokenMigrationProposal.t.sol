pragma solidity ^0.8.0;

// Forge and utils
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Utilities} from "test/utils/Utilities.sol";
import {UnsafeUpgrades as Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

// Local contracts
import {Token} from "src/tokens/Token.sol";
import {TokenMigrationContract} from "src/migration/TokenMigrationContract.sol";
import {TokenMigrationProposal} from "src/migration/TokenMigrationProposal.sol";
import {ECOxStakingBurnable} from "src/migration/upgrades/ECOxStakingBurnable.sol";

// Currency 1.5 contracts
import {ECOx} from "currency-1.5/currency/ECOx.sol";
import {ECOxStaking} from "currency-1.5/governance/community/ECOxStaking.sol";
import {Policy} from "currency-1.5/policy/Policy.sol";
import {IERC20} from "@openzeppelin-currency/contracts/token/ERC20/IERC20.sol";

// OP-ECO contracts
import {IL1ECOBridge} from "src/migration/interfaces/IL1ECOBridge.sol";
import {IL2ECOBridge} from "src/migration/interfaces/IL2ECOBridge.sol";
import {IL2ECOx} from "src/migration/interfaces/IL2ECOx.sol";
import {IL2ECOxFreeze} from "src/migration/interfaces/IL2ECOxFreeze.sol"; // doing this due to compatibility issues with op-eco, will deploy other way in test

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
    Policy policy = Policy(0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68);
    ECOx ecox = ECOx(0xcccD1Ba9f7acD6117834E0D28F25645dECb1736a);
    ECOxStaking secox = ECOxStaking(0x3a16f2Fee32827a9E476d0c87E454aB7C75C92D7);
    IL1ECOBridge l1ECOBridge =
        IL1ECOBridge(0xAa029BbdC947F5205fBa0F3C11b592420B58f824);
    IL1CrossDomainMessenger l1Messenger =
        IL1CrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);

    // L1 To Set
    TokenMigrationProposal proposal;
    Token token;
    TokenMigrationContract migrationContract;
    ECOxStakingBurnable secoxBurnable;

    //L1 Users
    address payable[] users;
    address minter;
    address alice;
    address bob;

    //L2 Protocol Addresses
    address constant staticMarket = 0x6085e45604956A724556135747400e32a0D6603A;
    IL2ECOx l2ECOx = IL2ECOx(0xf805B07ee64f03f0aeb963883f70D0Ac0D0fE242);

    // L2 To Set
    IL2ECOxFreeze l2ECOxFreeze;
    address migrationOwnerOP;
    uint32 l2gas;

    function setUp() public {
        //fork networks 22597199 mainnet, 136514625 optimism
        optimismFork = vm.createSelectFork(optimismRpcUrl, 136514625);

        // https://ethereum.stackexchange.com/questions/153940/how-to-resolve-compiler-version-conflicts-in-foundry-test-contracts
        l2ECOxFreeze = IL2ECOxFreeze(deployCode("L2ECOxFreeze.sol:L2ECOxFreeze"));
        
        mainnetFork = vm.createSelectFork(mainnetRpcUrl, 22597199);
        
        Utilities utilities = new Utilities();

        // Create users
        users = utilities.createUsers(4); 
        minter = users[0];
        migrationOwnerOP = users[1];
        alice = users[2];
        bob = users[3];

        // deploy token contract
        Token tokenImplementation = new Token();
        address tokenProxy = Upgrades.deployTransparentProxy(
            address(tokenImplementation),
            address(securityCouncil),
            abi.encodeWithSelector(Token.initialize.selector, address(policy), address(securityCouncil), "TOKEN", "TKN")
        );
        token = Token(tokenProxy);

        // deploy migration contract with no proxy
        migrationContract = new TokenMigrationContract(
            ecox,
            ECOxStakingBurnable(address(secox)),
            token,
            address(securityCouncil)
        );

        // deploy ECOxStakingImplementation contract with no proxy
        secoxBurnable = new ECOxStakingBurnable(
            policy,
            IERC20(address(ecox))
        );
        

        // deploy proposal contract with no proxy
        proposal = new TokenMigrationProposal(
            ECOx(address(ecox)),
            ECOxStaking(address(secox)),
            Token(address(token)),
            TokenMigrationContract(address(migrationContract)),
            IL1CrossDomainMessenger(address(l1Messenger)),
            address(l1ECOBridge),
            address(staticMarket),
            address(migrationOwnerOP),
            address(l2ECOxFreeze),
            l2gas,
            address(secoxBurnable),
            address(minter)
        );
        assertEq(vm.activeFork(), mainnetFork);
    }

    function test_token_deployment() public {

        // assert that the token is deployed with the correct
        assertEq(token.name(), "TOKEN");
        assertEq(token.symbol(), "TKN");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);

        assertEq(token.totalSupply(), 0);
        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(policy)), true);
        assertEq(token.hasRole(token.MINTER_ROLE(), address(policy)), true);
        assertEq(token.hasRole(token.BURNER_ROLE(), address(policy)), true);
        assertEq(token.hasRole(token.PAUSER_ROLE(), address(policy)), true);
        assertEq(token.hasRole(token.PAUSER_ROLE(), address(securityCouncil)), true);

        assertEq(token.paused(), false);
    }

    function test_migration_contract_deployment() public {
    }

    function test_proposal_deployment() public {
    }

    function test_ECOxStakingBurnable_deployment() public {
    }

    function test_l2ECOxFreeze_deployment() public {
    }

    function test_setup() public {
        // ensure that the migration contract is not a burner
        // ensure that ECOx is not paused
        // ensure that the new token is not paused
        // ensure that the ECOxStaking contract is not paused
        
        // check the balance of ECOx in the sECOx contract
        // check the balance of ECOx in the l1ECOBridge contract

        // 
    }
    
    function test_enactment() public {
    }
}