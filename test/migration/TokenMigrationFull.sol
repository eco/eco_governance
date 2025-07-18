pragma solidity ^0.8.0;

// Forge and utils
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Utilities} from "test/utils/Utilities.sol";
import {UnsafeUpgrades as Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// Local contracts
import {Token} from "src/tokens/Token.sol";
import {TokenMigrationContract} from "src/migration/TokenMigrationContract.sol";
import {TokenMigrationProposal} from "src/migration/TokenMigrationProposal.sol";
import {ECOxStakingBurnable} from "src/migration/upgrades/ECOxStakingBurnable.sol";
import {ILockupContract} from "src/migration/TokenMigrationContract.sol";

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
import {IStaticMarket} from "src/migration/interfaces/IStaticMarket.sol";

// Optimism contracts
import {IL1CrossDomainMessenger} from "@eth-optimism/contracts/L1/messaging/IL1CrossDomainMessenger.sol";
import {IL2CrossDomainMessenger} from "@eth-optimism/contracts/L2/messaging/IL2CrossDomainMessenger.sol";
import {AddressAliasHelper} from "@eth-optimism/contracts-bedrock/contracts/vendor/AddressAliasHelper.sol";
import {Hashing} from "lib/op-eco/node_modules/@eth-optimism/contracts-bedrock/contracts/libraries/Hashing.sol";
import {AddressAliasHelper} from "@eth-optimism/contracts-bedrock/contracts/vendor/AddressAliasHelper.sol";

contract TokenMigrationProposalTest is Test {
    uint256 mainnetFork;
    uint256 optimismFork;

    string mainnetRpcUrl = vm.envString("MAINNET_RPC_URL");
    string optimismRpcUrl = vm.envString("OPTIMISM_RPC_URL");

    //L1 Protocol Addresses
    address constant securityCouncil = 0xCF2A6B4bc14A1FEf0862c9583b61B1beeDE980C2;
    Policy policy = Policy(0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68);
    ECOx ecox = ECOx(0xcccD1Ba9f7acD6117834E0D28F25645dECb1736a);
    ECOxStaking secox = ECOxStaking(0x3a16f2Fee32827a9E476d0c87E454aB7C75C92D7);
    IL1ECOBridge l1ECOBridge = IL1ECOBridge(0xAa029BbdC947F5205fBa0F3C11b592420B58f824);
    IL2ECOBridge l2ECOBridge = IL2ECOBridge(0xAa029BbdC947F5205fBa0F3C11b592420B58f824);
    IL1CrossDomainMessenger l1Messenger = IL1CrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);
    address claimContract = 0xa28f219BF1e15f5217B8Eb5f406BcbE8f13d16DC;

    // L1 To Set
    TokenMigrationProposal proposal;
    Token token;
    TokenMigrationContract migrationContract;
    ECOxStakingBurnable secoxBurnable;

    //bridge upgrades
    IL1ECOBridge l1ECOBridgeUpgrade;
    IL2ECOBridge l2ECOBridgeUpgrade;

    //L1 Users
    address payable[] users;
    address minter;
    address alice;
    address bob;

    //L2 Protocol Addresses
    address constant staticMarket = 0x6085e45604956A724556135747400e32a0D6603A;
    IL2ECOx l2ECOx = IL2ECOx(0xf805B07ee64f03f0aeb963883f70D0Ac0D0fE242);
    IL2CrossDomainMessenger l2Messenger = IL2CrossDomainMessenger(0x4200000000000000000000000000000000000007);

    // L2 To Set
    IL2ECOxFreeze l2ECOxFreeze;
    address migrationOwnerOP;
    uint32 l2gas = 10000;

    // State variable for excluded ECOx calculation
    uint256 public excludedECOx;

    //events
    event UpgradeL2Bridge(address proposal);
    event UpgradeL2ECOx(address proposal);

    event SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit);
    event SentMessageExtension1(address indexed sender, uint256 value);
    event RelayedMessage(bytes32 indexed msgHash);
    event UpgradeSelf(address _newBridgeImpl);
    event UpgradeECOxImplementation(address _newEcoImpl);
    event Upgraded(address indexed implementation);
    event NewContractOwner(address indexed contractOwner, bool isContractOwnerL2);

    mapping(address => bool) public excludedWallets;

    function setUp() public {
        //fork networks 22597199 mainnet, 136514625 optimism
        optimismFork = vm.createSelectFork(optimismRpcUrl, 137415601);

        // https://ethereum.stackexchange.com/questions/153940/how-to-resolve-compiler-version-conflicts-in-foundry-test-contracts
        l2ECOxFreeze = IL2ECOxFreeze(deployCode("L2ECOxFreeze.sol:L2ECOxFreeze"));

        //deploy L2ECOBridge using deployCode
        l2ECOBridgeUpgrade = IL2ECOBridge(deployCode("out/L2ECOBridge.sol/L2ECOBridge.json"));

        mainnetFork = vm.createSelectFork(mainnetRpcUrl, 22746288); // 22746288 for this test

        //deploy L1ECOBridge using deployCode
        l1ECOBridgeUpgrade = IL1ECOBridge(deployCode("out/L1ECOBridge.sol/L1ECOBridge.json"));

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
            address(policy),
            abi.encodeWithSelector(Token.initialize.selector, address(policy), address(securityCouncil), "TOKEN", "TKN")
        );
        token = Token(tokenProxy);

        ProxyAdmin proxyAdmin = ProxyAdmin(Upgrades.getAdminAddress(tokenProxy));

        assertEq(proxyAdmin.owner(), address(policy));

        assertEq(
            vm.load(tokenProxy, 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103),
            bytes32(uint256(uint160(address(proxyAdmin))))
        );

        // deploy migration contract with no proxy
        migrationContract =
            new TokenMigrationContract(ecox, ECOxStakingBurnable(address(secox)), token, address(securityCouncil));

        // deploy ECOxStakingImplementation contract with no proxy
        secoxBurnable = new ECOxStakingBurnable(policy, IERC20(address(ecox)));

        // deploy proposal contract with no proxy
        proposal = new TokenMigrationProposal(
            ECOx(address(ecox)),
            ECOxStaking(address(secox)),
            Token(address(token)),
            TokenMigrationContract(address(migrationContract)),
            IL1CrossDomainMessenger(address(l1Messenger)),
            l1ECOBridge,
            address(staticMarket),
            address(migrationOwnerOP),
            address(l2ECOxFreeze),
            l2gas,
            address(secoxBurnable),
            address(minter),
            address(l1ECOBridgeUpgrade),
            address(l2ECOBridgeUpgrade),
            address(claimContract)
        );
        assertEq(vm.activeFork(), mainnetFork);

        // get total supply of ecox in claim, l1ECOBridge
        excludedECOx = ecox.balanceOf(address(claimContract)) + ecox.balanceOf(address(l1ECOBridge));
        console.log("excludedECOx", excludedECOx);

    }

    // does not test l1 messages sent to l2
    function enactment_sequence() public {
        bytes32 slot = vm.load(address(l1ECOBridge), 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);
        console.logBytes32(slot);
        console.log(address(staticMarket));

        //select optimism fork
        vm.selectFork(optimismFork);
        bytes32 slot2 = vm.load(address(l2ECOx), 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103);
        console.logBytes32(slot2);
        
        //select mainnet fork
        vm.selectFork(mainnetFork);

        vm.prank(address(securityCouncil));
        policy.enact(address(proposal));

        // ensure that the migration contract and policy addresses are burners
        assertEq(ecox.burners(address(migrationContract)), true);
        assertEq(ecox.burners(address(policy)), true);

        // ensure that the policy address is a pauser
        assertEq(ecox.pauser(), address(migrationContract));

        // ensure that ECOx is paused
        assertEq(ecox.paused(), true);

        //ensure that the ECOx in the bridge and secox are both burned
        assertEq(ecox.balanceOf(address(l1ECOBridge)), 0);
        assertEq(ecox.balanceOf(address(secox)), 0);
        assertEq(ecox.balanceOf(address(claimContract)), 0);

        //ensure that the minter address is a minter of the new token
        console.log(address(minter));
        console.log(token.hasRole(token.MINTER_ROLE(), address(minter)));
        assertEq(token.hasRole(token.MINTER_ROLE(), address(minter)), true);

        //ensure that the migration contract is a pause exempt role
        assertEq(token.hasRole(token.PAUSE_EXEMPT_ROLE(), address(migrationContract)), true);

        //ensure that the newToken contract is paused
        assertEq(token.paused(), true);

        //ensure that the secox contract has a new implementation
        assertEq(secox.implementation(), address(secoxBurnable));

        //ensure that the migration contract is a burner
        assertEq(ecox.burners(address(migrationContract)), true);

        //assert that the l1ECOBridge has the correct implementation
        // Get implementation address from EIP-1967 storage slot
        bytes32 implementationSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        bytes32 l1BridgeImpl = vm.load(address(l1ECOBridge), implementationSlot);
        assertEq(address(uint160(uint256(l1BridgeImpl))), address(l1ECOBridgeUpgrade));
    }

    function test_enactment() public {
        // ensure that the migration contract is not a burner
        assertEq(ecox.burners(address(migrationContract)), false);

        // check to make sure the policy address is not a pauser
        assertNotEq(ecox.pauser(), address(policy));

        // check to make sure the migration address is not a pauser
        assertNotEq(ecox.pauser(), address(migrationContract));

        // ensure that ECOx is not paused
        assertEq(ecox.paused(), false);

        // check that the minter address is not a minter of the new token yet
        // check that the migration contract is not pause exempt role yet
        assertEq(token.hasRole(token.MINTER_ROLE(), address(minter)), false);
        assertEq(token.hasRole(token.PAUSE_EXEMPT_ROLE(), address(migrationContract)), false);

        // ensure that the newToken contract is not paused
        assertEq(token.paused(), false);

        // get sECOx implimentation address
        address secoxImplementation = secox.implementation();

        enactment_sequence();
        migration_contract_migration();
    }

    function migration_contract_migration() public {
        //check all the migration script addresses are set correctly
        assertEq(address(migrationContract.ecox()), address(ecox));
        assertEq(address(migrationContract.secox()), address(secox));
        assertEq(address(migrationContract.newToken()), address(token));

        //make sure the owner of the migration contract is the security council
        assertEq(migrationContract.hasRole(migrationContract.DEFAULT_ADMIN_ROLE(), address(securityCouncil)), true);
        //make sure the security council is the migrator
        assertEq(migrationContract.hasRole(migrationContract.MIGRATOR_ROLE(), address(securityCouncil)), true);

        //check that the migration contract can burn ecox and secox
        assertEq(ECOxStakingBurnable(address(secox)).burners(address(migrationContract)), true);
        assertEq(ecox.burners(address(migrationContract)), true);

        // mint the new token to the migration contract
        uint256 totalSupply = 1_000_000_000 * 10 ** 18; // 1 billion tokens
        vm.prank(minter);
        token.mint(address(migrationContract), totalSupply);

        //check that total supply is 1 billion tokens and the migration contract has all the tokens
        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.balanceOf(address(migrationContract)), totalSupply);

        //get total supply of sECOx and ECOx
        uint256 totalSupplyECOx = ecox.totalSupply();
        uint256 totalSupplySECOx = secox.totalSupply();
        console.log("totalSupplyECOx", totalSupplyECOx);
        console.log("totalSupplySECOx", totalSupplySECOx);

        // excluded wallets
        // claim, l1bridge, secox
        excludedWallets[address(claimContract)] = true;
        excludedWallets[address(l1ECOBridge)] = true;
        excludedWallets[address(secox)] = true;

        // Test lockup contract functionality
        // Read lockup contracts from CSV file
        // First, count the number of lines to determine array size
        uint256 lineCount = 0;
        string memory line;
        while (bytes(line = vm.readLine("test/migration/files/lockups.csv")).length > 0) {
            lineCount++;
        }
        
        // Create array with correct size (subtract 1 for header)
        address[] memory lockupContracts = new address[](lineCount - 1);
        
        // Reset file pointer and read again to populate array
        vm.closeFile("test/migration/files/lockups.csv");
        vm.readFile("test/migration/files/lockups.csv");
        
        // Skip header line
        vm.readLine("test/migration/files/lockups.csv");
        
        // Read and parse addresses
        for (uint256 i = 0; i < lineCount - 1; i++) {
            line = vm.readLine("test/migration/files/lockups.csv");
            if (bytes(line).length > 0) {
                lockupContracts[i] = vm.parseAddress(line);
            }
        }

        vm.startPrank(securityCouncil);
        for (uint256 i = 0; i < lockupContracts.length; i++) {
            assertEq(migrationContract.isLockupContract(lockupContracts[i]), false);
        }
        migrationContract.addLockupContracts(lockupContracts);

        for (uint256 i = 0; i < lockupContracts.length; i++) {
            assertEq(migrationContract.isLockupContract(lockupContracts[i]), true);
        }

        // TODO migrate all the normal wallets
        // here we need to read all the addresses from test/migration/files/ecox.csv and test/migration/files/secox.csv
        // and we need to read them into two arrays
        // if the address is in the excluded wallets array, we need to skip it

        // Read ECOx addresses from CSV file
        uint256 ecoxLineCount = 0;
        string memory ecoxLine;
        while (bytes(ecoxLine = vm.readLine("test/migration/files/ecox.csv")).length > 0) {
            ecoxLineCount++;
        }
        
        // Create array with correct size (subtract 1 for header)
        address[] memory ecoxAddresses = new address[](ecoxLineCount - 1);
        
        // Reset file pointer and read again to populate array
        vm.closeFile("test/migration/files/ecox.csv");
        vm.readFile("test/migration/files/ecox.csv");
        
        // Skip header line
        vm.readLine("test/migration/files/ecox.csv");
        
        // Read and parse addresses, skipping excluded wallets
        uint256 validAddressCount = 0;
        for (uint256 i = 0; i < ecoxLineCount - 1; i++) {
            ecoxLine = vm.readLine("test/migration/files/ecox.csv");
            if (bytes(ecoxLine).length > 0) {
                address addr = vm.parseAddress(ecoxLine);
                if (!excludedWallets[addr]) {
                    ecoxAddresses[validAddressCount] = addr;
                    validAddressCount++;
                }
            }
        }

        // Read sECOx addresses from CSV file
        uint256 secoxLineCount = 0;
        string memory secoxLine;
        while (bytes(secoxLine = vm.readLine("test/migration/files/secox.csv")).length > 0) {
            secoxLineCount++;
        }
        
        // Create array with correct size (subtract 1 for header)
        address[] memory secoxAddresses = new address[](secoxLineCount - 1);
        
        // Reset file pointer and read again to populate array
        vm.closeFile("test/migration/files/secox.csv");
        vm.readFile("test/migration/files/secox.csv");
        
        // Skip header line
        vm.readLine("test/migration/files/secox.csv");
        
        // Read and parse addresses
        for (uint256 i = 0; i < secoxLineCount - 1; i++) {
            secoxLine = vm.readLine("test/migration/files/secox.csv");
            if (bytes(secoxLine).length > 0) {
                secoxAddresses[i] = vm.parseAddress(secoxLine);
            }
        }

        vm.startPrank(securityCouncil);
        //migrate all the lockups
        uint256 batchSize = 50;
        
        // Migrate lockup contracts in batches
        uint256 numBatches = (lockupContracts.length + batchSize - 1) / batchSize;
        for (uint256 batch = 0; batch < numBatches; batch++) {
            address[] memory batchAddresses = new address[](batchSize);
            uint256 start = batch * batchSize;
            uint256 end = start + batchSize;
            if (end > lockupContracts.length) {
                end = lockupContracts.length;
            }
            
            uint256 currentBatchSize = end - start;
            for (uint256 i = 0; i < currentBatchSize; i++) {
                batchAddresses[i] = lockupContracts[start + i];
            }
            
            migrationContract.massMigrate(batchAddresses);
        }

        // Migrate ECOx addresses in batches
        numBatches = (ecoxAddresses.length + batchSize - 1) / batchSize;
        for (uint256 batch = 0; batch < numBatches; batch++) {
            address[] memory batchAddresses = new address[](batchSize);
            uint256 start = batch * batchSize;
            uint256 end = start + batchSize;
            if (end > ecoxAddresses.length) {
                end = ecoxAddresses.length;
            }
            
            uint256 currentBatchSize = end - start;
            for (uint256 i = 0; i < currentBatchSize; i++) {
                batchAddresses[i] = ecoxAddresses[start + i];
            }
            
            migrationContract.massMigrate(batchAddresses);
        }

        // Migrate sECOx addresses in batches
        numBatches = (secoxAddresses.length + batchSize - 1) / batchSize;
        for (uint256 batch = 0; batch < numBatches; batch++) {
            address[] memory batchAddresses = new address[](batchSize);
            uint256 start = batch * batchSize;
            uint256 end = start + batchSize;
            if (end > secoxAddresses.length) {
                end = secoxAddresses.length;
            }
            
            uint256 currentBatchSize = end - start;
            for (uint256 i = 0; i < currentBatchSize; i++) {
                batchAddresses[i] = secoxAddresses[start + i];
            }
            
            migrationContract.massMigrate(batchAddresses);
        }

        //print total supply of ecox and secox balances after migration
        console.log("totalSupplyECOx after migration", ecox.totalSupply());
        console.log("totalSupplySECOx after migration", secox.totalSupply());
        
        // Assert both token supplies are 0 after migration
        assertEq(ecox.totalSupply(), 0, "ECOx supply should be 0 after migration");
        assertEq(secox.totalSupply(), 0, "sECOx supply should be 0 after migration");

        // Check that migration contract's new token balance equals initial supply minus migrated amounts
        uint256 expectedRemainingSupply = totalSupply - (totalSupplyECOx + totalSupplySECOx);
        assertEq(token.balanceOf(address(migrationContract)), expectedRemainingSupply, "Migration contract should have correct remaining balance");
        console.log("Migration contract remaining balance", expectedRemainingSupply);

        uint256 ecoxBurnedTotal=1000000000000000000000000000-998366082182504042918163346;
        
        assertEq(excludedECOx, token.balanceOf(address(migrationContract))-ecoxBurnedTotal, "ECOx supply in excluded contracts should equal the total supply of ecox in the migration contract");

        // Final sweep - transfer remaining tokens to policy
        uint256 migrationContractBalanceBeforeSweep = token.balanceOf(address(migrationContract));
        uint256 policyBalanceBeforeSweep = token.balanceOf(address(policy));
        
        migrationContract.sweep(address(policy));
        
        // Verify migration contract has no tokens left
        assertEq(token.balanceOf(address(migrationContract)), 0, "Migration contract should have no tokens after sweep");
        
        // Verify policy received the swept tokens
        uint256 policyBalanceAfterSweep = token.balanceOf(address(policy));
        assertEq(policyBalanceAfterSweep, policyBalanceBeforeSweep + migrationContractBalanceBeforeSweep, "Policy should receive all remaining tokens from sweep");
        
        vm.stopPrank();
    }
} 

