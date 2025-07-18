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

    function setUp() public {
        //fork networks 22597199 mainnet, 136514625 optimism
        optimismFork = vm.createSelectFork(optimismRpcUrl, 136514625);

        // https://ethereum.stackexchange.com/questions/153940/how-to-resolve-compiler-version-conflicts-in-foundry-test-contracts
        l2ECOxFreeze = IL2ECOxFreeze(deployCode("L2ECOxFreeze.sol:L2ECOxFreeze"));

        //deploy L2ECOBridge using deployCode
        l2ECOBridgeUpgrade = IL2ECOBridge(deployCode("out/L2ECOBridge.sol/L2ECOBridge.json"));

        mainnetFork = vm.createSelectFork(mainnetRpcUrl, 22597199);

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
        //ensure that the migration contract is deployed with the correct constructor
        assertEq(address(migrationContract.ecox()), address(ecox));
        assertEq(address(migrationContract.secox()), address(secox));
        assertEq(address(migrationContract.newToken()), address(token));
        assertEq(migrationContract.hasRole(migrationContract.MIGRATOR_ROLE(), address(securityCouncil)), true);
        assertEq(migrationContract.hasRole(migrationContract.DEFAULT_ADMIN_ROLE(), address(securityCouncil)), true);
    }

    function test_ECOxStakingBurnable_deployment() public {
        assertEq(address(secoxBurnable.policy()), address(policy));
        assertEq(address(secoxBurnable.ecoXToken()), address(ecox));
    }

    function test_proposal_deployment() public {
        assertEq(address(proposal.ecox()), address(ecox));
        assertEq(address(proposal.secox()), address(secox));
        assertEq(address(proposal.newToken()), address(token));
        assertEq(address(proposal.migrationContract()), address(migrationContract));
        assertEq(address(proposal.messenger()), address(l1Messenger));
        assertEq(address(proposal.l1ECOBridge()), address(l1ECOBridge));
        assertEq(address(proposal.staticMarket()), address(staticMarket));
        assertEq(address(proposal.migrationOwnerOP()), address(migrationOwnerOP));
        assertEq(address(proposal.l2ECOxFreeze()), address(l2ECOxFreeze));
        assertEq(proposal.l2gas(), l2gas);
        assertEq(address(proposal.ECOxStakingImplementation()), address(secoxBurnable));
        assertEq(address(proposal.minter()), address(minter));
        assertEq(address(proposal.l1ECOBridgeUpgrade()), address(l1ECOBridgeUpgrade));
        assertEq(address(proposal.l2ECOBridgeUpgrade()), address(l2ECOBridgeUpgrade));
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
    }

    function test_L1_to_L2_messages_and_enactment() public {
        // check that the active fork is mainnet
        assertEq(vm.activeFork(), mainnetFork);

        uint32 localBlock = uint32(block.number);

        // L2 BRIDGE UPGRADE //
        // should emit SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit);
        bytes memory message =
            abi.encodeWithSelector(l2ECOBridge.upgradeSelf.selector, address(l2ECOBridgeUpgrade), localBlock);

        (bool success, bytes memory returnData) = address(l1Messenger).call(abi.encodeWithSignature("messageNonce()"));

        require(success, "call to messageNonce() failed");
        uint256 currentNonce = abi.decode(returnData, (uint256));

        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessage(address(l2ECOBridge), address(l1ECOBridge), message, currentNonce, l2gas);

        // should emit SentMessageExtension1(msg.sender, msg.value);
        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessageExtension1(address(l1ECOBridge), 0);

        // should emit UpgradeL2ECOx(_impl);
        vm.expectEmit(address(l1ECOBridge));
        emit UpgradeL2Bridge(address(l2ECOBridgeUpgrade));

        // should call CrossDomainMessenger.sendMessage
        bytes memory data =
            abi.encodeWithSelector(l1Messenger.sendMessage.selector, address(l2ECOBridge), message, l2gas);
        vm.expectCall(address(l1Messenger), data);

        // L2 ECOX UPGRADE //
        bytes memory message2 =
            abi.encodeWithSelector(l2ECOBridge.upgradeECOx.selector, address(l2ECOxFreeze), localBlock);

        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessage(address(l2ECOBridge), address(l1ECOBridge), message2, currentNonce + 1, l2gas);

        // should emit SentMessageExtension1(msg.sender, msg.value);
        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessageExtension1(address(l1ECOBridge), 0);

        // should emit UpgradeL2ECOx(_impl);
        vm.expectEmit(address(l1ECOBridge));
        emit UpgradeL2ECOx(address(l2ECOxFreeze));

        // should call CrossDomainMessenger.sendMessage
        bytes memory data2 =
            abi.encodeWithSelector(l1Messenger.sendMessage.selector, address(l2ECOBridge), message2, l2gas);
        vm.expectCall(address(l1Messenger), data2);

        // L2 Static Market Message  //
        bytes memory message3 =
            abi.encodeWithSelector(bytes4(keccak256("setContractOwner(address,bool)")), migrationOwnerOP, true);

        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessage(address(staticMarket), address(policy), message3, currentNonce + 2, l2gas);

        // should emit SentMessageExtension1(msg.sender, msg.value);
        vm.expectEmit(true, false, false, true, address(l1Messenger));
        emit SentMessageExtension1(address(policy), 0);

        // should call CrossDomainMessenger.sendMessage
        bytes memory data3 =
            abi.encodeWithSelector(l1Messenger.sendMessage.selector, address(staticMarket), message3, l2gas);
        vm.expectCall(address(l1Messenger), data3);

        //enact the proposal
        vm.prank(securityCouncil);
        policy.enact(address(proposal));

        //switch to optimism fork
        vm.selectFork(optimismFork);

        // check that the active fork is optimism
        assertEq(vm.activeFork(), optimismFork);

        // convert L1 messenger to L2 aliased messenger address
        address aliasedL1Caller = AddressAliasHelper.applyL1ToL2Alias(address(l1Messenger));

        // should emit relayedMessage(msgHash)
        bytes32 msgHash =
            Hashing.hashCrossDomainMessage(currentNonce, address(l1ECOBridge), address(l2ECOBridge), 0, l2gas, message);

        bytes32 msgHash2 = Hashing.hashCrossDomainMessage(
            currentNonce + 1, address(l1ECOBridge), address(l2ECOBridge), 0, l2gas, message2
        );

        bytes32 msgHash3 =
            Hashing.hashCrossDomainMessage(currentNonce + 2, address(policy), address(staticMarket), 0, l2gas, message3);

        vm.expectEmit(true, false, false, false, address(l2ECOBridge));
        emit UpgradeSelf(address(l2ECOBridgeUpgrade));

        vm.expectEmit(true, false, false, false, address(l2Messenger));
        emit RelayedMessage(msgHash);

        // should call l2ECOBridge.upgradeSelf
        bytes memory call =
            abi.encodeWithSelector(l2ECOBridge.upgradeSelf.selector, address(l2ECOBridgeUpgrade), localBlock);
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
        bytes memory call2 = abi.encodeWithSelector(l2ECOBridge.upgradeECOx.selector, address(l2ECOxFreeze), localBlock);
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
        vm.expectEmit(true, false, false, true, address(staticMarket));
        emit NewContractOwner(migrationOwnerOP, true);

        vm.expectEmit(true, false, false, false, address(l2Messenger));
        emit RelayedMessage(msgHash3);

        // should call staticMarket.setContractOwner
        bytes memory call3 =
            abi.encodeWithSelector(bytes4(keccak256("setContractOwner(address,bool)")), migrationOwnerOP, true);
        vm.expectCall(address(staticMarket), call3);

        vm.prank(aliasedL1Caller);
        address(l2Messenger).call(
            abi.encodeWithSignature(
                "relayMessage(uint256,address,address,uint256,uint256,bytes)",
                currentNonce + 2,
                address(policy),
                address(staticMarket),
                0,
                l2gas,
                message3
            )
        );

        //check that the bridge has been upgraded
        bytes32 implementationSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        bytes32 l2BridgeImpl = vm.load(address(l2ECOBridge), implementationSlot);
        assertEq(address(uint160(uint256(l2BridgeImpl))), address(l2ECOBridgeUpgrade));

        //check that the ecox has been upgraded
        bytes32 l2ECOxImpl = vm.load(address(l2ECOx), implementationSlot);
        assertEq(address(uint160(uint256(l2ECOxImpl))), address(l2ECOxFreeze));

        //check that new contract owner and L2 flag are set correctly
        assertEq(IStaticMarket(staticMarket).contractOwner(), address(migrationOwnerOP));
        assertEq(IStaticMarket(staticMarket).isContractOwnerL2(), true);

        vm.prank(migrationOwnerOP);
        IL2ECOxFreeze(address(l2ECOx)).reinitializeV2();

        //check that the new token is paused
        assertEq(IL2ECOxFreeze(address(l2ECOx)).paused(), true);
        //check security council is pauser
        assertEq(IL2ECOxFreeze(address(l2ECOx)).pausers(securityCouncil), true);
    }

    function test_migration_contract_migration() public {
        //check all the migration script addresses are set correctly
        assertEq(address(migrationContract.ecox()), address(ecox));
        assertEq(address(migrationContract.secox()), address(secox));
        assertEq(address(migrationContract.newToken()), address(token));

        //make sure the owner of the migration contract is the security council
        assertEq(migrationContract.hasRole(migrationContract.DEFAULT_ADMIN_ROLE(), address(securityCouncil)), true);
        //make sure the security council is the migrator
        assertEq(migrationContract.hasRole(migrationContract.MIGRATOR_ROLE(), address(securityCouncil)), true);

        //enact the proposal
        vm.prank(securityCouncil);
        policy.enact(address(proposal));

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

        address wallet1 = 0xED83D2f20cF2d218Adbe0a239C0F8AbDca8Fc499; //staked ECOx and ECOx
        address wallet2 = 0xc9bd798473c03AE3215E8bbeA6b8888C141BF050; //ECOx only
        address wallet3 = 0x35FDFe53b3817dde163dA82deF4F586450EDf893; //sECOx only

        //check the sECOx and ECOx balances of the wallets and add them together for each wallet
        uint256 wallet1Entitled = ecox.balanceOf(wallet1) + secox.balanceOf(wallet1);
        uint256 wallet2Entitled = ecox.balanceOf(wallet2) + secox.balanceOf(wallet2);
        uint256 wallet3Entitled = ecox.balanceOf(wallet3) + secox.balanceOf(wallet3);

        //check that the migration contract can migrate tokens
        vm.startPrank(securityCouncil);
        migrationContract.migrate(wallet1); //migrate wallet 1
        migrationContract.migrate(wallet2); //migrate wallet 2
        migrationContract.migrate(wallet3); //migrate wallet 3
        vm.stopPrank();

        //check that the secox and ecox balances of the wallets are 0
        assertEq(ecox.balanceOf(wallet1), 0);
        assertEq(secox.balanceOf(wallet1), 0);
        assertEq(token.balanceOf(wallet1), wallet1Entitled);

        assertEq(ecox.balanceOf(wallet2), 0);
        assertEq(secox.balanceOf(wallet2), 0);
        assertEq(token.balanceOf(wallet2), wallet2Entitled);

        assertEq(ecox.balanceOf(wallet3), 0);
        assertEq(secox.balanceOf(wallet3), 0);
        assertEq(token.balanceOf(wallet3), wallet3Entitled);

        // Test lockup contract functionality
        address[] memory lockupContracts = new address[](7);
        lockupContracts[0] = 0x35FDFe53b3817dde163dA82deF4F586450EDf893; // sECOx only
        lockupContracts[1] = 0x4ee22Fe220c2dCa1462B0836bE536A5e65c97cC5; // ECOx only
        lockupContracts[2] = 0x48457B805F8Ec0213F5432489A281318069223FD; // ECOx only
        lockupContracts[3] = 0x70483473D714e23D6C03b0aa52f98Ec30A81bF94; // ECOx only
        lockupContracts[4] = 0xEE4bD3ec22c81Cb2E62A55dB757A64d101C70a8b; // ECOx only
        lockupContracts[5] = 0x4923438A972Fe8bDf1994B276525d89F5DE654c9; // sECOx only
        lockupContracts[6] = 0x0cCF53Bc6354889682020bbD2C440f8265aBe1E1; // sECOx only

        // Test adding lockup contracts
        vm.startPrank(securityCouncil);

        // Verify contracts are not initially marked as lockup contracts
        for (uint256 i = 0; i < lockupContracts.length; i++) {
            assertEq(migrationContract.isLockupContract(lockupContracts[i]), false);
        }

        // Add lockup contracts
        migrationContract.addLockupContracts(lockupContracts);

        // Verify contracts are now marked as lockup contracts
        for (uint256 i = 0; i < lockupContracts.length; i++) {
            assertEq(migrationContract.isLockupContract(lockupContracts[i]), true);
        }

        // Test removing some lockup contracts
        address[] memory contractsToRemove = new address[](2);
        contractsToRemove[0] = lockupContracts[0]; // Remove first one
        contractsToRemove[1] = lockupContracts[6]; // Remove last one

        migrationContract.removeLockupContracts(contractsToRemove);

        // Verify removed contracts are no longer marked as lockup contracts
        assertEq(migrationContract.isLockupContract(contractsToRemove[0]), false);
        assertEq(migrationContract.isLockupContract(contractsToRemove[1]), false);

        // Verify remaining contracts are still marked as lockup contracts
        for (uint256 i = 1; i < lockupContracts.length - 1; i++) {
            assertEq(migrationContract.isLockupContract(lockupContracts[i]), true);
        }

        vm.stopPrank();

        // Re-add the removed contracts for migration testing
        vm.prank(securityCouncil);
        migrationContract.addLockupContracts(contractsToRemove);

        // Get balances before migration for lockup contracts
        uint256[] memory ecoxBalancesBefore = new uint256[](lockupContracts.length);
        uint256[] memory secoxBalancesBefore = new uint256[](lockupContracts.length);
        address[] memory beneficiaries = new address[](lockupContracts.length);

        for (uint256 i = 0; i < lockupContracts.length; i++) {
            ecoxBalancesBefore[i] = ecox.balanceOf(lockupContracts[i]);
            secoxBalancesBefore[i] = secox.balanceOf(lockupContracts[i]);

            // Get the real beneficiary from each lockup contract
            if (ecoxBalancesBefore[i] > 0 || secoxBalancesBefore[i] > 0) {
                beneficiaries[i] = ILockupContract(lockupContracts[i]).beneficiary();
            }
        }

        // Test migration of lockup contracts with different token types
        vm.startPrank(securityCouncil);

        // Get beneficiary token balances before migration
        uint256[] memory beneficiaryTokenBalancesBefore = new uint256[](lockupContracts.length);
        for (uint256 i = 0; i < lockupContracts.length; i++) {
            if (beneficiaries[i] != address(0)) {
                beneficiaryTokenBalancesBefore[i] = token.balanceOf(beneficiaries[i]);
            }
        }

        // Migrate lockup contracts one by one to test individual scenarios
        for (uint256 i = 0; i < lockupContracts.length; i++) {
            address lockupContract = lockupContracts[i];
            uint256 totalEntitled = ecoxBalancesBefore[i] + secoxBalancesBefore[i];

            if (totalEntitled > 0) {
                // Migrate the lockup contract
                migrationContract.migrate(lockupContract);

                // Verify tokens were burned from the lockup contract
                assertEq(ecox.balanceOf(lockupContract), 0);
                assertEq(secox.balanceOf(lockupContract), 0);

                // Verify tokens were minted to the real beneficiary
                uint256 expectedNewBalance = beneficiaryTokenBalancesBefore[i] + totalEntitled;
                assertEq(token.balanceOf(beneficiaries[i]), expectedNewBalance);

                // Update the beneficiary balance for next iteration
                beneficiaryTokenBalancesBefore[i] = expectedNewBalance;
            }
        }

        vm.stopPrank();

        // Test mass migration of remaining contracts (none should have tokens left)
        vm.prank(securityCouncil);
        migrationContract.massMigrate(lockupContracts);

        // Verify all lockup contracts have zero balances
        for (uint256 i = 0; i < lockupContracts.length; i++) {
            assertEq(ecox.balanceOf(lockupContracts[i]), 0);
            assertEq(secox.balanceOf(lockupContracts[i]), 0);
        }
    }

    function test_lockup_contract_access_control() public {
        enactment_sequence();

        address[] memory lockupContracts = new address[](1);
        lockupContracts[0] = 0x35FDFe53b3817dde163dA82deF4F586450EDf893;

        // Test that non-admin cannot add lockup contracts
        vm.prank(alice);
        vm.expectRevert();
        migrationContract.addLockupContracts(lockupContracts);

        // Test that non-admin cannot remove lockup contracts
        vm.prank(securityCouncil);
        migrationContract.addLockupContracts(lockupContracts);

        vm.prank(alice);
        vm.expectRevert();
        migrationContract.removeLockupContracts(lockupContracts);

        // Test that non-migrator cannot migrate
        vm.prank(alice);
        vm.expectRevert();
        migrationContract.migrate(lockupContracts[0]);
    }

    function test_lockup_contract_edge_cases() public {
        enactment_sequence();

        address[] memory lockupContracts = new address[](1);
        lockupContracts[0] = 0x35FDFe53b3817dde163dA82deF4F586450EDf893;

        vm.startPrank(securityCouncil);

        // Test adding the same contract twice should revert
        migrationContract.addLockupContracts(lockupContracts);
        vm.expectRevert("Lockup contract already added");
        migrationContract.addLockupContracts(lockupContracts);

        // Test removing a contract that wasn't added should revert
        address[] memory nonExistentContracts = new address[](1);
        nonExistentContracts[0] = 0x1234567890123456789012345678901234567890;
        vm.expectRevert("Lockup contract not found");
        migrationContract.removeLockupContracts(nonExistentContracts);

        // Test migrating a contract without beneficiary should revert
        address invalidContract = 0x23683733A1f66f737154E9612BE1e158126993B2;
        lockupContracts[0] = invalidContract;
        migrationContract.addLockupContracts(lockupContracts);

        // Mock some balance
        deal(address(ecox), invalidContract, 1000);

        vm.mockCallRevert(invalidContract, abi.encodeWithSignature("beneficiary()"), "Contract has no beneficiary");

        vm.expectRevert("Contract has no beneficiary");
        migrationContract.migrate(invalidContract);

        vm.stopPrank();
    }
}
