// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ECOx} from "currency-1.5/currency/ECOx.sol";
import {ECOxStakingBurnable} from "src/migration/upgrades/ECOxStakingBurnable.sol";
import {Token} from "src/Token.sol";

/**
 * @title ILockupContract
 * @notice Interface for lockup contracts to get the beneficiary
 */
interface ILockupContract {
    /**
     * @notice Returns the beneficiary of the lockup contract
     * @dev This could be implemented as `owner()` in VestingWallet or a custom function
     * @return The address of the beneficiary
     */
    function beneficiary() external view returns (address);
}
/**
 * @title TokenMigrationContract
 * @notice Migrates ECOx and sECOx tokens to the new token system.
 *         1. Burn the user's ECOx balance.
 *         2. Burn the user's sECOx balance.
 *         3. Mint new tokens equal to the sum of both balances.
 *         4. Special handling for lockup contracts - burns from lockup, mints to beneficiary.
 */

contract TokenMigrationContract is AccessControl {
    bytes32 public constant MIGRATOR_ROLE = keccak256("MIGRATOR_ROLE");

    ECOx public immutable ecox;
    ECOxStakingBurnable public immutable secox;
    Token public immutable newToken;

    mapping(address => bool) public isLockupContract;

    /**
     * @notice Emitted when a lockup contract is added to the list
     * @param lockupContract The address of the lockup contract added
     */
    event LockupContractAdded(address indexed lockupContract);

    /**
     * @notice Emitted when a lockup contract is removed from the list
     * @param lockupContract The address of the lockup contract removed
     */
    event LockupContractRemoved(address indexed lockupContract);

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
    constructor(ECOx _ecox, ECOxStakingBurnable _secox, Token _newToken, address admin) {
        ecox = _ecox;
        secox = _secox;
        newToken = _newToken;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MIGRATOR_ROLE, admin);
    }

    /**
     * @notice Adds a lockup contract to the list
     * @param lockupContracts The address of the lockup contract to add
     */
    function addLockupContracts(address[] calldata lockupContracts) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < lockupContracts.length; ++i) {
            address lockupContract = lockupContracts[i];
            require(!isLockupContract[lockupContract], "Lockup contract already added");
            isLockupContract[lockupContract] = true;
            emit LockupContractAdded(lockupContract);
        }
    }

    /**
     * @notice Removes a lockup contract from the list
     * @param lockupContracts The address of the lockup contract to remove
     */
    function removeLockupContracts(address[] calldata lockupContracts) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < lockupContracts.length; ++i) {
            address lockupContract = lockupContracts[i];
            require(isLockupContract[lockupContract], "Lockup contract not found");
            isLockupContract[lockupContract] = false;
            emit LockupContractRemoved(lockupContract);
        }
    }

    /**
     * @notice Migrates ECOx and sECOx tokens for a single account
     * @dev Burns the account's ECOx and sECOx balances and mints an equal total amount of new tokens
     * @param account The account to migrate tokens for
     */
    function migrate(address account) external onlyRole(MIGRATOR_ROLE) {
        ecox.unpause();
        if (isLockupContract[account]) {
            _migrateLockup(account);
        } else {
            _migrate(account);
        }
        ecox.pause();
    }

    /**
     * @notice Migrates ECOx and sECOx tokens for multiple accounts in a single transaction
     * @dev Burns each account's ECOx and sECOx balances and mints equal total amounts of new tokens
     * @param accounts Array of accounts to migrate tokens for
     */
    function massMigrate(address[] calldata accounts) external onlyRole(MIGRATOR_ROLE) {
        ecox.unpause();
        for (uint256 i = 0; i < accounts.length; ++i) {
            if (isLockupContract[accounts[i]]) {
                _migrateLockup(accounts[i]);
            } else {
                _migrate(accounts[i]);
            }
        }
        ecox.pause();
    }

    /**
     * @notice Internal function to handle the migration logic for a single account
     * @dev Burns ECOx and sECOx tokens, mints new tokens equal to the sum, emits Migrated event
     * @param account The account to migrate tokens for
     */
    function _migrate(address account) internal {
        uint256 totalBalance = _migrationBurn(account);

        if (totalBalance > 0) {
            newToken.pausedTransfer(account, totalBalance); // paused transfer because it will be preminted
            emit Migrated(account, totalBalance);
        }
    }

    function _migrateLockup(address account) internal {
        uint256 totalBalance = _migrationBurn(account);

        //get beneficiary
        address beneficiary = ILockupContract(account).beneficiary();

        if (totalBalance > 0) {
            newToken.pausedTransfer(beneficiary, totalBalance); // paused transfer because it will be preminted
            emit Migrated(account, totalBalance);
        }
    }

    function migrateSpecialCase(address _oldLockup, address _newLockup) external onlyRole(MIGRATOR_ROLE) {
        ecox.unpause();
        uint256 totalBalance = _migrationBurn(_oldLockup);
        address beneficiary = ILockupContract(_oldLockup).beneficiary();

        if(_oldLockup == 0xF003A542cCD8e37c836AFF3b7Fab528eF82285A6) {
            // 176k anchorage lockup
            address SAFTSafe = 0xED83D2f20cF2d218Adbe0a239C0F8AbDca8Fc499;
            // transfer to SAFT for later reissue
            newToken.pausedTransfer(SAFTSafe, totalBalance);
        } else if(_oldLockup == 0x35FDFe53b3817dde163dA82deF4F586450EDf893 || _oldLockup == 0x4923438A972Fe8bDf1994B276525d89F5DE654c9) {
            // 18mm or 2mm investor lockup
            require(ILockupContract(_newLockup).beneficiary() == beneficiary, 'lockup mismatch');
            // transfer to new OZ lockup
            newToken.pausedTransfer(_newLockup, totalBalance);
        } else {
            revert();
        }
        emit Migrated(_oldLockup, totalBalance);
        ecox.pause();
    }

    function _migrationBurn(address account) private returns (uint256){
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
        return totalBalance;
    }

    /**
     * @notice Sweeps any remaining tokens to the policy treasury
     * @dev Can only be called by the policy treasury
     */
    function sweep(address policy) external onlyRole(MIGRATOR_ROLE) {
        uint256 balance = newToken.balanceOf(address(this));
        if (balance > 0) {
            if (newToken.paused()) {
                newToken.pausedTransfer(address(policy), balance);
            } else {
                newToken.transfer(address(policy), balance);
            }
        }
    }
}
