import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Policy is Initializable, OwnableUpgradeable {
    /**
     * for when a part of enacting a proposal reverts without a readable error
     * @param proposal the proposal address that got reverted during enaction
     */
    error FailedProposal(address proposal);

    /**
     * emits when enaction happens to keep record of enaction
     * @param proposal the proposal address that got successfully enacted
     * @param governor the contract which was the source of the proposal, source for looking up the calldata
     */
    event EnactedGovernanceProposal(address proposal, address governor);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // if I'm thinking about this correctly, then the policy contract owns itself and 
    // the governor address can upgrade it's implementation via proposals 

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
    }

    function enact(address proposal) external virtual onlyOwner {
        // solhint-disable-next-line avoid-low-level-calls
        (bool _success, bytes memory returndata) = proposal.delegatecall(
            abi.encodeWithSignature("enacted(address)", proposal)
        );
        if (!_success) {
            if (returndata.length == 0) revert FailedProposal(proposal);
            assembly {
                revert(add(32, returndata), mload(returndata))
            }
        }

        emit EnactedGovernanceProposal(proposal, msg.sender);
    }
}