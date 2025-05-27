// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {L2ECOx} from "op-eco/token/L2ECOx.sol";
import {Token} from "src/tokens/SuperchainToken.sol";
import {IStaticMarket} from "src/migration/interfaces/IStaticMarket.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


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

    /**
     * @notice Emitted when tokens are migrated for an account
     * @param account The account whose tokens were migrated
     * @param amount The amount of tokens migrated
     */
    event Migrated(address indexed account, uint256 amount);

    /**
     * @notice Constructs the TokenMigrationContractOptimism
     * @param _ecox The L2ECOx token contract to migrate from
     * @param _newToken The new Superchain token contract to migrate to
     * @param admin The address to grant admin and migrator roles to
     */
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

    /**
     * @notice Migrates ECOx tokens for a single account
     * @dev Burns the account's ECOx balance and transfers an equal amount of new tokens
     * @param account The account to migrate tokens for
     */
    function migrate(address account) external onlyRole(MIGRATOR_ROLE) {
        _migrate(account);
    }

    /**
     * @notice Migrates ECOx tokens for multiple accounts in a single transaction
     * @dev Burns each account's ECOx balance and transfers equal amounts of new tokens
     * @param accounts Array of accounts to migrate tokens for
     */
    function massMigrate(address[] calldata accounts) external onlyRole(MIGRATOR_ROLE) {
        for (uint256 i = 0; i < accounts.length; ++i) {
            _migrate(accounts[i]);
        }
    }

    /**
     * @notice Internal function to handle the migration logic for a single account
     * @dev Burns ECOx tokens and transfers new tokens, emits Migrated event
     * @param account The account to migrate tokens for
     */
    function _migrate(address account) internal {
        uint256 ecoxBal = ecox.balanceOf(account);
        if (ecoxBal == 0) return;
        ecox.burn(account, ecoxBal);
        newToken.transfer(account, ecoxBal);
        emit Migrated(account, ecoxBal);
    }

    /**
     * @notice Migrates USDC from the static market maker contract to the caller
     * @dev Transfers all USDC held by the static market contract to the caller
     * @param staticMarket The static market maker contract to migrate from
     * @param usdc The USDC token contract address
     */
    function migrateStatic(IStaticMarket staticMarket, IERC20 usdc) external onlyRole(MIGRATOR_ROLE) {
        uint256 usdcBalance = usdc.balanceOf(address(staticMarket));
        if (usdcBalance > 0) {
            staticMarket.transferTokens(address(usdc), msg.sender, usdcBalance);
        }
    }
}
