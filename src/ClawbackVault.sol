// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {console} from "forge-std/console.sol";

contract ClawbackVault is VestingWallet {

    event Clawback(address indexed token, uint256 amount);

    error UnauthorizedClawback();

    error NothingToClawback();

    address public immutable admin;

    constructor(address _admin, address beneficiary, uint64 startTimestamp, uint64 durationSeconds) VestingWallet(beneficiary, startTimestamp, durationSeconds) {
        admin = _admin;
    }

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