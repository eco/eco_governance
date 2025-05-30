// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ECOx} from "currency-1.5/currency/ECOx.sol";
import {ECOxStakingBurnable} from "src/migration/upgrades/ECOxStakingBurnable.sol";
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
    ECOxStakingBurnable public immutable secox;
    Token public immutable newToken;

    /**
     * @notice Emitted when tokens are migrated for an account
     * @param account The account whose tokens were migrated
     * @param amount The total amount of tokens migrated (ECOx + sECOx)
     */
    event Migrated(address indexed account, uint256 amount);

    /**
     * @notice Constructs the TokenMigrationContract
     * @param _ecox The ECOx token contract to migrate from
     * @param _secox The sECOx staking contract to migrate from
     * @param _newToken The new token contract to mint to
     * @param admin The address to grant admin and migrator roles to
     */
    constructor(
        ECOx _ecox,
        ECOxStakingBurnable _secox,
        Token _newToken,
        address admin
    ) {
        ecox = _ecox;
        secox = _secox;
        newToken = _newToken;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MIGRATOR_ROLE, admin);
    }

    /**
     * @notice Migrates ECOx and sECOx tokens for a single account
     * @dev Burns the account's ECOx and sECOx balances and mints an equal total amount of new tokens
     * @param account The account to migrate tokens for
     */
    function migrate(address account) external onlyRole(MIGRATOR_ROLE) {
        _migrate(account);
    }

    /**
     * @notice Migrates ECOx and sECOx tokens for multiple accounts in a single transaction
     * @dev Burns each account's ECOx and sECOx balances and mints equal total amounts of new tokens
     * @param accounts Array of accounts to migrate tokens for
     */
    function massMigrate(address[] calldata accounts) external onlyRole(MIGRATOR_ROLE) {
        for (uint256 i = 0; i < accounts.length; ++i) {
            _migrate(accounts[i]);
        }
    }

    function upgradeECOx(address newECOx) external onlyRole(MIGRATOR_ROLE) {
        ecox.setImplementation(newECOx);
    }

    function upgradeSECOx(address newSECOx) external onlyRole(MIGRATOR_ROLE) {
        secox.setImplementation(newSECOx);
    }

    /**
     * @notice Internal function to handle the migration logic for a single account
     * @dev Burns ECOx and sECOx tokens, mints new tokens equal to the sum, emits Migrated event
     * @param account The account to migrate tokens for
     */
    function _migrate(address account) internal {
        // Get balances
        uint256 ecoxBalance = ecox.balanceOf(account);
        uint256 secoxBalance = secox.balanceOf(account);

        // Burn ECOx if they have any
        if (ecoxBalance > 0) {
            ecox.burn(account, ecoxBalance);
        }

        // Burn sECOx if they have any  
        // TODO: upgrade sECOx
        if (secoxBalance > 0) {
            secox.burn(account, secoxBalance);
        }

        // Mint new tokens - sum of both balances
        uint256 totalBalance = ecoxBalance + secoxBalance;
        if (totalBalance > 0) {
            newToken.transfer(account, totalBalance); // transfering because it will be preminted 
            emit Migrated(account, totalBalance);
        }
    }
}
