pragma solidity ^0.8.0;

import {Proposal} from "../../lib/currency-1.5/contracts/governance/community/proposals/Proposal.sol";
import {ECOx} from "../../lib/currency-1.5/contracts/currency/ECOx.sol";

interface IECOxProxy {
    function setImplementation(address newImplementation) external;
}

/**
 * @title ECOxCleanupProposal
 * @dev A governance proposal to clean up ECOx balances and upgrade the implementation
 * @notice This proposal upgrades the ECOx implementation to ECOxZero and grants burner permissions
 */
contract ECOxCleanupProposal is Proposal {
    address public immutable ecox;
    address public immutable burnerContract;
    address public immutable ecoxZeroImpl;

    /**
     * @notice Constructor for ECOxCleanupProposal
     * @param _ecox The address of the ECOx proxy contract
     * @param _burnerContract The address of the ECOxBurner contract
     * @param _ecoxZeroImpl The address of the ECOxZero implementation contract
     */
    constructor(address _ecox, address _burnerContract, address _ecoxZeroImpl) {
        ecox = _ecox;
        burnerContract = _burnerContract;
        ecoxZeroImpl = _ecoxZeroImpl;
    }

    /**
     * @notice Returns the name of this proposal
     * @return The proposal name
     */
    function name() public pure override returns (string memory) {
        return "ECOx Cleanup Proposal";
    }

    /**
     * @notice Returns the description of this proposal
     * @return The proposal description
     */
    function description() public pure override returns (string memory) {
        return "Upgrade ECOx implementation to ECOxZero and grant burner permissions for cleanup";
    }

    /**
     * @notice Returns the URL for this proposal
     * @return The proposal URL
     */
    function url() public pure override returns (string memory) {
        return "";
    }

    /**
     * @notice Executes the proposal when enacted
     * @param _self The address of this proposal contract
     * @dev Upgrades the ECOx implementation to ECOxZero and grants burner permissions
     */
    function enacted(address _self) public virtual override {
        // Upgrade ECOx implementation to ECOxZero
        IECOxProxy(ecox).setImplementation(ecoxZeroImpl);

        // Grant permissions
        ECOx(ecox).updateBurners(burnerContract, true);
        ECOx(ecox).setPauser(address(burnerContract));
    }
}
