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
import {AddressAliasHelper} from "@eth-optimism/contracts-bedrock/contracts/vendor/AddressAliasHelper.sol";

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
    IL2ECOBridge l2ECOBridge =
        IL2ECOBridge(0xAa029BbdC947F5205fBa0F3C11b592420B58f824);
    IL1CrossDomainMessenger l1Messenger =
        IL1CrossDomainMessenger(0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1);

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
    IL2CrossDomainMessenger l2Messenger =
        IL2CrossDomainMessenger(0x4200000000000000000000000000000000000007);

    // L2 To Set
    IL2ECOxFreeze l2ECOxFreeze;
    address migrationOwnerOP;
    uint32 l2gas = 10000;

    //events
    event UpgradeL2Bridge(address proposal);
    event UpgradeL2ECOx(address proposal);

    event SentMessage(
        address indexed target,
        address sender,
        bytes message,
        uint256 messageNonce,
        uint256 gasLimit
    );
    event SentMessageExtension1(address indexed sender, uint256 value);
    event RelayedMessage(bytes32 indexed msgHash);
    event UpgradeSelf(address _newBridgeImpl);
    event UpgradeECOxImplementation(address _newEcoImpl);
    event Upgraded(address indexed implementation);

    function setUp() public {
        //fork networks 22597199 mainnet, 136514625 optimism
        optimismFork = vm.createSelectFork(optimismRpcUrl, 136514625);

        // https://ethereum.stackexchange.com/questions/153940/how-to-resolve-compiler-version-conflicts-in-foundry-test-contracts
        l2ECOxFreeze = IL2ECOxFreeze(
            deployCode("L2ECOxFreeze.sol:L2ECOxFreeze")
        );

        //deploy L2ECOBridge using deployCode
        l2ECOBridgeUpgrade = IL2ECOBridge(
            deployCode("out/L2ECOBridge.sol/L2ECOBridge.json")
        );

        mainnetFork = vm.createSelectFork(mainnetRpcUrl, 22597199);

        //deploy L1ECOBridge using deployCode
        l1ECOBridgeUpgrade = IL1ECOBridge(
            deployCode("out/L1ECOBridge.sol/L1ECOBridge.json")
        );

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
            abi.encodeWithSelector(
                Token.initialize.selector,
                address(policy),
                address(securityCouncil),
                "TOKEN",
                "TKN"
            )
        );
        token = Token(tokenProxy);

        ProxyAdmin proxyAdmin = ProxyAdmin(
            Upgrades.getAdminAddress(tokenProxy)
        );

        assertEq(proxyAdmin.owner(), address(policy));

        assertEq(
            vm.load(
                tokenProxy,
                0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
            ),
            bytes32(uint256(uint160(address(proxyAdmin))))
        );

        // deploy migration contract with no proxy
        migrationContract = new TokenMigrationContract(
            ecox,
            ECOxStakingBurnable(address(secox)),
            token,
            address(securityCouncil)
        );

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
            address(l2ECOBridgeUpgrade)
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
        assertEq(
            token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(policy)),
            true
        );
        assertEq(token.hasRole(token.MINTER_ROLE(), address(policy)), true);
        assertEq(token.hasRole(token.BURNER_ROLE(), address(policy)), true);
        assertEq(token.hasRole(token.PAUSER_ROLE(), address(policy)), true);
        assertEq(
            token.hasRole(token.PAUSER_ROLE(), address(securityCouncil)),
            true
        );

        assertEq(token.paused(), false);
    }

    function test_migration_contract_deployment() public {
        //ensure that the migration contract is deployed with the correct constructor
        assertEq(address(migrationContract.ecox()), address(ecox));
        assertEq(address(migrationContract.secox()), address(secox));
        assertEq(address(migrationContract.newToken()), address(token));
        assertEq(
            migrationContract.hasRole(
                migrationContract.MIGRATOR_ROLE(),
                address(securityCouncil)
            ),
            true
        );
        assertEq(
            migrationContract.hasRole(
                migrationContract.DEFAULT_ADMIN_ROLE(),
                address(securityCouncil)
            ),
            true
        );
    }

    function test_ECOxStakingBurnable_deployment() public {
        assertEq(address(secoxBurnable.policy()), address(policy));
        assertEq(address(secoxBurnable.ecoXToken()), address(ecox));
    }

    function test_proposal_deployment() public {
        assertEq(address(proposal.ecox()), address(ecox));
        assertEq(address(proposal.secox()), address(secox));
        assertEq(address(proposal.newToken()), address(token));
        assertEq(
            address(proposal.migrationContract()),
            address(migrationContract)
        );
        assertEq(address(proposal.messenger()), address(l1Messenger));
        assertEq(address(proposal.l1ECOBridge()), address(l1ECOBridge));
        assertEq(address(proposal.staticMarket()), address(staticMarket));
        assertEq(
            address(proposal.migrationOwnerOP()),
            address(migrationOwnerOP)
        );
        assertEq(address(proposal.l2ECOxFreeze()), address(l2ECOxFreeze));
        assertEq(proposal.l2gas(), l2gas);
        assertEq(
            address(proposal.ECOxStakingImplementation()),
            address(secoxBurnable)
        );
        assertEq(address(proposal.minter()), address(minter));
        assertEq(
            address(proposal.l1ECOBridgeUpgrade()),
            address(l1ECOBridgeUpgrade)
        );
        assertEq(
            address(proposal.l2ECOBridgeUpgrade()),
            address(l2ECOBridgeUpgrade)
        );
    }

    // does not test l1 messages sent to l2
    function enactment_sequence() public {
        bytes32 slot = vm.load(
            address(l1ECOBridge),
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
        );
        console.logBytes32(slot);
        console.log(address(staticMarket));

        //select optimism fork
        vm.selectFork(optimismFork);
        bytes32 slot2 = vm.load(
            address(l2ECOx),
            0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
        );
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

        //ensure that the minter address is a minter of the new token
        console.log(address(minter));
        console.log(token.hasRole(token.MINTER_ROLE(), address(minter)));
        assertEq(token.hasRole(token.MINTER_ROLE(), address(minter)), true);

        //ensure that the migration contract is a pause exempt role
        assertEq(
            token.hasRole(
                token.PAUSE_EXEMPT_ROLE(),
                address(migrationContract)
            ),
            true
        );

        //ensure that the newToken contract is paused
        assertEq(token.paused(), true);

        //ensure that the secox contract has a new implementation
        assertEq(secox.implementation(), address(secoxBurnable));

        //ensure that the migration contract is a burner
        assertEq(ecox.burners(address(migrationContract)), true);

        //assert that the l1ECOBridge has the correct implementation
        // Get implementation address from EIP-1967 storage slot
        bytes32 implementationSlot = bytes32(
            uint256(keccak256("eip1967.proxy.implementation")) - 1
        );
        bytes32 l1BridgeImpl = vm.load(
            address(l1ECOBridge),
            implementationSlot
        );
        assertEq(
            address(uint160(uint256(l1BridgeImpl))),
            address(l1ECOBridgeUpgrade)
        );
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

        uint256 secoxBalance = ecox.balanceOf(address(secox));
        uint256 bridgeBalance = ecox.balanceOf(address(l1ECOBridge));

        // check that the minter address is not a minter of the new token yet
        // check that the migration contract is not pause exempt role yet
        assertEq(token.hasRole(token.MINTER_ROLE(), address(minter)), false);
        assertEq(
            token.hasRole(
                token.PAUSE_EXEMPT_ROLE(),
                address(migrationContract)
            ),
            false
        );

        // ensure that the newToken contract is not paused
        assertEq(token.paused(), false);

        // get sECOx implimentation address
        address secoxImplementation = secox.implementation();

        enactment_sequence();
    }

    function test_L1_to_L2_messages_and_enactment() public {
        // check that the active fork is mainnet
        assertEq(vm.activeFork(), mainnetFork);

        uint32 localBlock = uint32(block.number);

        // L2 BRIDGE UPGRADE //
        // should emit SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit);
        bytes memory message = abi.encodeWithSelector(
            l2ECOBridge.upgradeSelf.selector,
            address(l2ECOBridgeUpgrade),
            localBlock
        );

        (bool success, bytes memory returnData) = address(l1Messenger).call(
            abi.encodeWithSignature("messageNonce()")
        );

        require(success, "call to messageNonce() failed");
        uint256 currentNonce = abi.decode(returnData, (uint256));

        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessage(
            address(l2ECOBridge),
            address(l1ECOBridge),
            message,
            currentNonce,
            l2gas
        );

        // should emit SentMessageExtension1(msg.sender, msg.value);
        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessageExtension1(address(l1ECOBridge), 0);

        // should emit UpgradeL2ECOx(_impl);
        vm.expectEmit(address(l1ECOBridge));
        emit UpgradeL2Bridge(address(l2ECOBridgeUpgrade));

        // should call CrossDomainMessenger.sendMessage
        bytes memory data = abi.encodeWithSelector(
            l1Messenger.sendMessage.selector,
            address(l2ECOBridge),
            message,
            l2gas
        );
        vm.expectCall(address(l1Messenger), data);

        // L2 ECOX UPGRADE //
        bytes memory message2 = abi.encodeWithSelector(
            l2ECOBridge.upgradeECOx.selector,
            address(l2ECOxFreeze),
            localBlock
        );

        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessage(
            address(l2ECOBridge),
            address(l1ECOBridge),
            message2,
            currentNonce + 1,
            l2gas
        );

        // should emit SentMessageExtension1(msg.sender, msg.value);
        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessageExtension1(address(l1ECOBridge), 0);

        // should emit UpgradeL2ECOx(_impl);
        vm.expectEmit(address(l1ECOBridge));
        emit UpgradeL2ECOx(address(l2ECOxFreeze));

        // should call CrossDomainMessenger.sendMessage
        bytes memory data2 = abi.encodeWithSelector(
            l1Messenger.sendMessage.selector,
            address(l2ECOBridge),
            message2,
            l2gas
        );
        vm.expectCall(address(l1Messenger), data2);

        // L2 Static Market Message  //
        bytes memory message3 = abi.encodeWithSelector(
            bytes4(keccak256("setContractOwner(address,bool)")),
            migrationOwnerOP,
            true
        );

        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessage(
            address(staticMarket),
            address(policy),
            message3,
            currentNonce + 2,
            l2gas
        );

        // should emit SentMessageExtension1(msg.sender, msg.value);
        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessageExtension1(address(policy), 0);

        // should call CrossDomainMessenger.sendMessage
        bytes memory data3 = abi.encodeWithSelector(
            l1Messenger.sendMessage.selector,
            address(staticMarket),
            message3,
            l2gas
        );
        vm.expectCall(address(l1Messenger), data3);

        //enact the proposal
        vm.prank(securityCouncil);
        policy.enact(address(proposal));

        //switch to optimism fork
        vm.selectFork(optimismFork);

        // check that the active fork is optimism
        assertEq(vm.activeFork(), optimismFork);

        // convert L1 messenger to L2 aliased messenger address
        address aliasedL1Caller = AddressAliasHelper.applyL1ToL2Alias(
            address(l1Messenger)
        );

        // should emit relayedMessage(msgHash)
        bytes32 msgHash = Hashing.hashCrossDomainMessage(
            currentNonce,
            address(l1ECOBridge),
            address(l2ECOBridge),
            0,
            l2gas,
            message
        );

        bytes32 msgHash2 = Hashing.hashCrossDomainMessage(
            currentNonce + 1,
            address(l1ECOBridge),
            address(l2ECOBridge),
            0,
            l2gas,
            message2
        );

        bytes32 msgHash3 = Hashing.hashCrossDomainMessage(
            currentNonce + 2,
            address(policy),
            address(staticMarket),
            0,
            l2gas,
            message3
        );

        vm.expectEmit(true, false, false, false, address(l2ECOBridge));
        emit UpgradeSelf(address(l2ECOBridgeUpgrade));

        vm.expectEmit(true, false, false, false, address(l2Messenger));
        emit RelayedMessage(msgHash);

        // should call l2ECOBridge.upgradeSelf
        bytes memory call = abi.encodeWithSelector(
            l2ECOBridge.upgradeSelf.selector,
            address(l2ECOBridgeUpgrade),
            localBlock
        );
        vm.expectCall(address(l2ECOBridge), call);

        vm.prank(aliasedL1Caller);
        address(l2Messenger).call(
            abi.encodeWithSignature(
                "relayMessage(uint256,address,address,uint256,uint256,bytes)",
                currentNonce,
                address(l1ECOBridge),
                address(l2ECOBridge),
                0,
                l2gas,
                message
            )
        );

        //upgrade l2ECOx

        vm.expectEmit(true, false, false, false, address(l2ECOx));
        emit Upgraded(address(l2ECOxFreeze));

        vm.expectEmit(false, false, false, true, address(l2ECOBridge));
        emit UpgradeECOxImplementation(address(l2ECOxFreeze));

        vm.expectEmit(true, false, false, false, address(l2Messenger));
        emit RelayedMessage(msgHash2);

        // should call l2ECOBridge.upgradeSelf
        bytes memory call2 = abi.encodeWithSelector(
            l2ECOBridge.upgradeECOx.selector,
            address(l2ECOxFreeze),
            localBlock
        );
        vm.expectCall(address(l2ECOBridge), call2);

        vm.prank(aliasedL1Caller);
        address(l2Messenger).call(
            abi.encodeWithSignature(
                "relayMessage(uint256,address,address,uint256,uint256,bytes)",
                currentNonce + 1,
                address(l1ECOBridge),
                address(l2ECOBridge),
                0,
                l2gas,
                message2
            )
        );



        //static market change



    }

}
