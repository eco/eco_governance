// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {L2ECOx} from "op-eco/token/L2ECOx.sol";
import {Token} from "src/tokens/SuperchainToken.sol";

/**
 * @title TokenMigrationContractOptimism
 * @notice On Optimism we only migrate L2 ECOx → the new Superchain token.
 *         1. Burn the user's ECOx.
 *         2. Transfer an equal amount of the *pre-minted* Superchain token
 *            that is held by this contract.
 */
contract TokenMigrationContractOptimism is AccessControl {
    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    L2ECOx public immutable ecox;
    Token  public immutable newToken;

    constructor(
        L2ECOx _ecox,
        Token  _newToken,
        address admin
    ) {
        ecox     = _ecox;
        newToken = _newToken;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MIGRATOR_ROLE,      admin);
    }

    function migrate(address account) external onlyRole(MIGRATOR_ROLE) {
        _migrate(account);
    }

    function massMigrate(address[] calldata accounts) external onlyRole(MIGRATOR_ROLE) {
        for (uint256 i = 0; i < accounts.length; ++i) {
            _migrate(accounts[i]);
        }
    }

    function _migrate(address account) internal {
        uint256 ecoxBal = ecox.balanceOf(account);
        if (ecoxBal == 0) return;
        ecox.burn(account, ecoxBal);
        newToken.transfer(account, ecoxBal);
    }
}
