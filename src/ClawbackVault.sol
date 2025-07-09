// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";

/// @title ClawbackVault
/// @notice A vesting wallet with an admin-controlled clawback mechanism for unvested tokens.
/// @dev Inherits from OpenZeppelin's VestingWallet. The admin can claw back unvested tokens at any time.
contract ClawbackVault is VestingWallet {

    /// @notice Emitted when the admin claws back unvested tokens.
    /// @param token The address of the ERC20 token being clawed back.
    /// @param amount The amount of tokens clawed back.
    event Clawback(address indexed token, uint256 amount);

    error UnauthorizedClawback();

    error NothingToClawback();

    /// @notice The address with permission to claw back unvested tokens.
    address public immutable admin;

    /// @notice Creates a new ClawbackVault.
    /// @param _admin The address with clawback privileges.
    /// @param beneficiary The address that will receive vested tokens.
    /// @param startTimestamp The timestamp when vesting starts.
    /// @param durationSeconds The duration of the vesting period in seconds.
    constructor(address _admin, address beneficiary, uint64 startTimestamp, uint64 durationSeconds) VestingWallet(beneficiary, startTimestamp, durationSeconds) {
        admin = _admin;
    }

    /// @notice Allows the admin to claw back unvested tokens from the vault.
    /// @dev Only callable by the admin. Calculates the unvested amount and transfers it to the admin.
    /// @param token The address of the ERC20 token to claw back.
    function clawback(address token) external {
        require(msg.sender == admin, UnauthorizedClawback());
        uint256 totalAllocation = IERC20(token).balanceOf(address(this)) + released(token);
        uint256 vested = vestedAmount(token, uint64(block.timestamp));
        uint256 unvested = totalAllocation > vested ? totalAllocation - vested : 0;
        require(unvested > 0, NothingToClawback());
        IERC20(token).transfer(admin, unvested);
        emit Clawback(token, unvested);
    }
}