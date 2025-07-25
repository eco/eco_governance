// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Policy} from "../../../lib/currency-1.5/contracts/policy/Policy.sol";
import {TotalSupplySnapshots} from "../../../lib/currency-1.5/contracts/currency/TotalSupplySnapshots.sol";
import {ERC20Pausable} from "../../../lib/currency-1.5/contracts/currency/ERC20Pausable.sol";

/**
 * @title An ERC20 token interface for ECOxZero
 * @dev Identical to ECOx, but with name and symbol set to '0xgone'.
 */
contract ECOxZero is TotalSupplySnapshots {
       //////////////////////////////////////////////
    //////////////////// VARS ////////////////////
    //////////////////////////////////////////////

    /**
     * @dev Mapping storing contracts able to rebase the token
     */
    mapping(address => bool) public snapshotters;

    //////////////////////////////////////////////
    /////////////////// ERRORS ///////////////////
    //////////////////////////////////////////////

    /**
     * error for when transfer returns false
     * used by contracts that import this contract
     */
    error TransferFailed();

    /**
     * error for when an address tries to snapshot without permission
     */
    error OnlySnapshotters();

    //////////////////////////////////////////////
    /////////////////// EVENTS ///////////////////
    //////////////////////////////////////////////

    /**
     * emits when the snapshotters permissions are changed
     * @param actor denotes the new address whose permissions are being updated
     * @param newPermission denotes the new ability of the actor address (true for can snapshot, false for cannot)
     */
    event UpdatedSnapshotters(address actor, bool newPermission);

    //////////////////////////////////////////////
    ////////////////// MODIFIERS /////////////////
    //////////////////////////////////////////////

    /**
     * @dev Modifier for checking if the sender is a snapshotter
     */
    modifier onlySnapshotterRole() {
        if (!snapshotters[msg.sender]) {
            revert OnlySnapshotters();
        }
        _;
    }

    constructor(
        Policy _policy,
        address _pauser
    ) TotalSupplySnapshots(_policy, "0xgone", "0xgone", _pauser) {}

    function initialize(
        address _self
    ) public virtual override onlyConstruction {
        super.initialize(_self);
        pauser = ERC20Pausable(_self).pauser();
    }

    function snapshot() public onlySnapshotterRole {
        _snapshot();
    }

    /**
     * @dev change the rebasing permissions for an address
     * only callable by tokenRoleAdmin
     * @param _key the address to change permissions for
     * @param _value the new permission. true = can snapshot, false = cannot snapshot
     */
    function updateSnapshotters(address _key, bool _value) public onlyPolicy {
        snapshotters[_key] = _value;
        emit UpdatedSnapshotters(_key, _value);
    }
} 