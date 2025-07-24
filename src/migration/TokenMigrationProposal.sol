pragma solidity ^0.8.0;

import {Proposal} from "currency-1.5/governance/community/proposals/Proposal.sol";
import {ECOx} from "currency-1.5/currency/ECOx.sol";
import {ECOxStaking} from "currency-1.5/governance/community/ECOxStaking.sol";
import {Token} from "src/Token.sol";
import {TokenMigrationContract} from "./TokenMigrationContract.sol";
import {IL1CrossDomainMessenger} from "@eth-optimism/contracts/L1/messaging/IL1CrossDomainMessenger.sol";
import {ECOxStakingBurnable} from "./upgrades/ECOxStakingBurnable.sol";
import {IL1ECOBridge} from "src/migration/interfaces/IL1ECOBridge.sol";

contract TokenMigrationProposal is Proposal {
    //L1 Addresses
    ECOx public immutable ecox;
    ECOxStaking public immutable secox;
    Token public immutable newToken;
    TokenMigrationContract public immutable migrationContract;
    IL1CrossDomainMessenger public immutable messenger;
    address public immutable ECOxStakingImplementation;
    IL1ECOBridge public immutable l1ECOBridge;
    address public immutable l1ECOBridgeUpgrade;
    address public immutable l2ECOBridgeUpgrade;
    address public immutable claimContract;

    //L2 Addresses
    address public immutable staticMarket; // 0x6085e45604956A724556135747400e32a0D6603A
    address public immutable migrationOwnerOP;
    address public immutable l2ECOxFreeze; // original L2EcoX is 0xf805B07ee64f03f0aeb963883f70D0Ac0D0fE242

    //Other
    uint32 public immutable l2gas;
    address public immutable minter;


    constructor(
        ECOx _ecox,
        ECOxStaking _secox,
        Token _newToken,
        TokenMigrationContract _migrationContract,
        IL1CrossDomainMessenger _messenger,
        IL1ECOBridge _l1ECOBridge,
        address _staticMarket,
        address _migrationOwnerOP,
        address _l2ECOxFreeze,
        uint32 _l2gas,
        address _ECOxStakingImplementation,
        address _minter,
        address _l1ECOBridgeUpgrade,
        address _l2ECOBridgeUpgrade,
        address _claimContract
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
        l2gas = _l2gas;
        ECOxStakingImplementation = _ECOxStakingImplementation;
        minter = _minter;
        l1ECOBridgeUpgrade = _l1ECOBridgeUpgrade;
        l2ECOBridgeUpgrade = _l2ECOBridgeUpgrade;
        claimContract = _claimContract;
    }

    function name() public pure virtual override returns (string memory) {
        return "Token Migration Proposal";
    }

    function description() public pure virtual override returns (string memory) {
        return "Migrates the ECOx token to a new token on Optimism and Mainnet and sweeps the old static market maker";
    }

    /**
     * A URL where more details can be found.
     */
    function url() public pure override returns (string memory) {
        return "https://forum.eco.com/t/the-next-eco-era-token-migration-part-2/440";
    }

    function enacted(address _self) public virtual override {
        // MAINNET //
        // ecox operations
        ecox.updateBurners(address(migrationContract), true);
        ecox.updateBurners(address(this), true);
        ecox.burn(address(secox), ecox.balanceOf(address(secox)));
        ecox.burn(address(l1ECOBridge), ecox.balanceOf(address(l1ECOBridge)));
        ecox.burn(address(claimContract), ecox.balanceOf(address(claimContract)));
        ecox.setPauser(address(this));
        ecox.pause();
        ecox.setPauser(address(migrationContract));

        // newToken operations
        newToken.grantRole(newToken.MINTER_ROLE(), minter);
        newToken.grantRole(newToken.PAUSE_EXEMPT_ROLE(), address(migrationContract));
        newToken.pause();

        // secox operations
        secox.setImplementation(ECOxStakingImplementation);
        ECOxStakingBurnable(address(secox)).setBurner(address(migrationContract), true);

        // OPTIMISM //
        // need to upgrade the bridge implementations
        l1ECOBridge.upgradeL2Bridge(l2ECOBridgeUpgrade, l2gas);
        l1ECOBridge.upgradeSelf(l1ECOBridgeUpgrade);

        // need to upgrade the ecox implementations
        l1ECOBridge.upgradeECOx(l2ECOxFreeze, l2gas);

        // set new static
        bytes memory message =
            abi.encodeWithSelector(bytes4(keccak256("setContractOwner(address,bool)")), migrationOwnerOP, true);
        messenger.sendMessage(staticMarket, message, l2gas);
    }
}
