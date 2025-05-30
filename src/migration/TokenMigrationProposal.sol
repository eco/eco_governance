import {Proposal} from "currency-1.5/governance/community/proposals/Proposal.sol";
import {ECOx} from "currency-1.5/currency/ECOx.sol";
import {ECOxStaking} from "currency-1.5/governance/community/ECOxStaking.sol";
import {Token} from "src/tokens/Token.sol";
import {TokenMigrationContract} from "./TokenMigrationContract.sol";
import {IL1CrossDomainMessenger} from "@eth-optimism/contracts/L1/messaging/IL1CrossDomainMessenger.sol";
import {ECOxStakingBurnable} from "./upgrades/ECOxStakingBurnable.sol";

contract TokenMigrationProposal is Proposal {
    //L1 Addresses
    ECOx public immutable ecox; // 0xcccD1Ba9f7acD6117834E0D28F25645dECb1736a
    ECOxStaking public immutable secox; // 0x3a16f2Fee32827a9E476d0c87E454aB7C75C92D7
    Token public immutable newToken; // TBD
    TokenMigrationContract public immutable migrationContract; // TBD
    IL1CrossDomainMessenger public immutable messenger; // 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1
    address public immutable ECOxStakingImplementation; // TBD
    address public immutable l1ECOBridge; // TBD

    //L2 Addresses
    address public staticMarket; // 0x6085e45604956A724556135747400e32a0D6603A
    address public migrationOwnerOP; // TBD
    address public l2ECOxFreeze; // old is 0xf805B07ee64f03f0aeb963883f70D0Ac0D0fE242

    //Other
    uint32 public l2gas; // TBD

    // reference proposal : https://etherscan.io/address/0x80CC5F92F93F5227b7057828e223Fc5BAD71b2E7#code

    constructor(
        ECOx _ecox,
        ECOxStaking _secox,
        Token _newToken,
        TokenMigrationContract _migrationContract,
        IL1CrossDomainMessenger _messenger,
        address _l1ECOBridge,
        address _staticMarket,
        address _migrationOwnerOP,
        address _l2ECOxFreeze
    ) {
        ecox = _ecox;
        secox = _secox;
        newToken = _newToken;
        migrationContract = _migrationContract;
        messenger = _messenger;
        l1ECOBridge = _l1ECOBridge;
        staticMarket = _staticMarket;
        migrationOwnerOP = _migrationOwnerOP;
        l2ECOxFreeze = _l2ECOxFreeze;
    }

    function name() public pure virtual override returns (string memory) {
        return "Token Migration Proposal";
    }

    function description() public pure virtual override returns (string memory) {
        return "Migrates the ECO token to a new token on Optimism and Mainnet and sweeps the old static market maker";
    }

    /**
     * A URL where more details can be found.
     */
    function url() public pure override returns (string memory) {
        return "https://forum.eco.com/t/the-next-eco-era-trustee-payouts-fix/404"; // TODO: add url
    }

    function enacted(address _self) public virtual override {
        // MAINNET //
        // ecox operations
        ecox.updateBurners(address(migrationContract), true);
        ecox.updateBurners(address(this), true);
        ecox.setPauser(address(this));
        ecox.pause();
        ecox.burn(address(secox), ecox.balanceOf(address(secox)));
        ecox.burn(address(l1ECOBridge), ecox.balanceOf(address(l1ECOBridge)));

        // newToken operations
        // newToken.grantRole(newToken.MINTER_ROLE(), address(migrationContract)); 
        newToken.pause();

        // secox operations
        secox.setImplementation(ECOxStakingImplementation);
        ECOxStakingBurnable(address(secox)).setBurner(address(migrationContract), true);

        // OPTIMISM //
        bytes memory message =
            abi.encodeWithSelector(bytes4(keccak256("setContractOwner(address,bool)")), migrationOwnerOP, true);
        messenger.sendMessage(staticMarket, message, 0);
        
        // TODO add interface instead here instead of manually calling the upgradeECOx function on the l1ECOBridge to avoid solidity version issues
        (bool success, bytes memory data) = l1ECOBridge.call(
            abi.encodeWithSelector(
                 bytes4(keccak256("upgradeECOx(addr ess,uint32)")),
                 l2ECOxFreeze,
                 l2gas
            )
        );
        require(success, "Call failed");
    }
}
