// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Proposal} from "../../lib/currency-1.5/contracts/governance/community/proposals/Proposal.sol";
import {IL1ECOBridge} from "./interfaces/IL1ECOBridge.sol";

/**
 * @title KillL2EcoXProposal
 * @dev A governance proposal to upgrade the L2ECOx token implementation to L2ECOxZero
 * @notice This proposal calls upgradeECOx on the L1ECOBridge to upgrade the L2ECOx token to the zero implementation
 */
contract KillL2EcoXProposal is Proposal {
    IL1ECOBridge public immutable l1ECOBridge;
    address public immutable l2ECOxZeroImpl;
    uint32 public immutable l2Gas;

    /**
     * @notice Constructor for KillL2EcoXProposal
     * @param _l1ECOBridge The address of the L1ECOBridge contract
     * @param _l2ECOxZeroImpl The address of the L2ECOxZero implementation contract
     * @param _l2Gas The gas limit for the L2 upgrade transaction
     */
    constructor(
        address _l1ECOBridge,
        address _l2ECOxZeroImpl,
        uint32 _l2Gas
    ) {
        l1ECOBridge = IL1ECOBridge(_l1ECOBridge);
        l2ECOxZeroImpl = _l2ECOxZeroImpl;
        l2Gas = _l2Gas;
    }

    /**
     * @notice Returns the name of this proposal
     * @return The proposal name
     */
    function name() public pure override returns (string memory) {
        return "Kill L2ECOx Proposal";
    }

    /**
     * @notice Returns the description of this proposal
     * @return The proposal description
     */
    function description() public pure override returns (string memory) {
        return "Upgrade L2ECOx token implementation to L2ECOxZero to sunset the token";
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
     * @dev Calls upgradeECOx on the L1ECOBridge to upgrade the L2ECOx token implementation
     */
    function enacted(address _self) public virtual override {
        // Upgrade L2ECOx implementation to L2ECOxZero via the L1ECOBridge
        l1ECOBridge.upgradeECOx(l2ECOxZeroImpl, l2Gas);
    }
}
