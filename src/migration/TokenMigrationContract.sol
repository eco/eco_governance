// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ECOx} from "currency-1.5/currency/ECOx.sol";
import {ECOxStaking} from "currency-1.5/governance/community/ECOxStaking.sol";
import {Token} from "src/tokens/Token.sol";

/**
 * @title TokenMigrationContract
 * @notice Migrates ECOx and sECOx tokens to the new token system.
 *         1. Burn the user's ECOx balance.
 *         2. Burn the user's sECOx balance.
 *         3. Mint new tokens equal to the sum of both balances.
 */
contract TokenMigrationContract is AccessControl {
    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    ECOx public immutable ecox;
    ECOxStaking public immutable secox;
    Token public immutable newToken;

    constructor(
        ECOx _ecox,
        ECOxStaking _secox,
        Token _newToken,
        address admin
    ) {
        ecox = _ecox;
        secox = _secox;
        newToken = _newToken;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MIGRATOR_ROLE, admin);
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
        // Get balances
        uint256 ecoxBalance = ecox.balanceOf(account);
        uint256 secoxBalance = secox.balanceOf(account);

        // Burn ECOx if they have any
        if (ecoxBalance > 0) {
            ecox.burn(account, ecoxBalance);
        }

        // Burn sECOx if they have any  
        if (secoxBalance > 0) {
            secox.burn(account, secoxBalance);
        }

        // Mint new tokens - sum of both balances
        uint256 totalBalance = ecoxBalance + secoxBalance;
        if (totalBalance > 0) {
            newToken.mint(account, totalBalance); // transfer IF minting happens first on L1
        }
    }
}
