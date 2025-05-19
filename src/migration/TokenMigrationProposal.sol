import {Proposal} from "currency-1.5/governance/community/proposals/Proposal.sol";
import {IL1CrossDomainMessenger} from "@eth-optimism/contracts/L1/messaging/IL1CrossDomainMessenger.sol";
import {ECOx} from "currency-1.5/currency/ECOx.sol";
import {ECOxStaking} from "currency-1.5/governance/community/ECOxStaking.sol";
import {L2ECOx} from "op-eco/token/L2ECOx.sol";

contract TokenMigrationProposal is Proposal {
    //L1 Addresses
    ECOx public immutable ecox; // 0xcccD1Ba9f7acD6117834E0D28F25645dECb1736a
    ECOxStaking public immutable secox; // 0x3a16f2Fee32827a9E476d0c87E454aB7C75C92D7
    address public newToken; // TBD
    address public migrationContract; // TBD
    IL1CrossDomainMessenger public messenger; // 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1

    //L2 Addresses
    address public staticMarket; // 0x6085e45604956A724556135747400e32a0D6603A
    address public migrationContractOP; // TBD
    address public newTokenOP; // TBD
    L2ECOx public l2ECOx; // 0xf805B07ee64f03f0aeb963883f70D0Ac0D0fE242

    // reference proposal : https://etherscan.io/address/0x80CC5F92F93F5227b7057828e223Fc5BAD71b2E7#code

    constructor(
        address _ecox,
        address _secox,
        address _newToken,
        address _migrationContract,
        address _staticMarket,
        address _migrationContractOP,
        address _newTokenOP
    ) {
        //L1
        ecox = _ecox;
        secox = _secox;
        newToken = _newToken;
        migrationContract = _migrationContract;

        //L2
        staticMarket = _staticMarket;
        migrationContractOP = _migrationContractOP;
        newTokenOP = _newTokenOP;
    }

    function name() public pure virtual override returns (string memory) {
        return "Token Migration Proposal";
    }

    function description()
        public
        pure
        virtual
        override
        returns (string memory)
    {
        return
            "Migrates the ECO token to a new token on Optimism and Mainnet and sweeps the old static market maker";
    }

    /** A URL where more details can be found.
     */
    function url() public pure override returns (string memory) {
        return
            "https://forum.eco.com/t/the-next-eco-era-trustee-payouts-fix/404"; // TODO: add url
    }

    function enacted(address _self) public virtual override {
        // MAINNET
        // need the address of the migration contract
        // need to give burn permission on ECOx to the migration contract
        // need to give mint permission on the new token to the migration contract
        // give permission to the migration contract to own ECOX and maybe change it up?
        // give permission to the migration contract to own sECOx and maybe change it up?

        // ----- OPTIMISM -----
        // 1) send message to static market to transfer contract ownership to the migration contract on Optimism
        bytes memory message = abi.encodeWithSelector(
            bytes4(keccak256("setContractOwner(address,bool)")),
            migrationContractOP,
            true
        );
        messenger.sendMessage(staticMarket, message, 0);

        // 2) bind new implimentations of L1ECOBridge and L2ECOBridge to themselves (which allow the ownership of ECOx to be transferred to the security council)
        // 3) send message to the ECOx contract to renounce ownership to the security council

    }
}
