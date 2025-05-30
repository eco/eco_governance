// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECOxStaking} from "currency-1.5/governance/community/ECOxStaking.sol";
import {Policy} from "currency-1.5/policy/Policy.sol";
import {IERC20} from "@openzeppelin-currency/contracts/token/ERC20/IERC20.sol";


/**
 * @title ECOxStakingBurnable
 * @dev Extends ECOxStaking to allow authorized burners to burn staked ECOx tokens
 */

contract ECOxStakingBurnable is ECOxStaking {
    /// mapping of addresses authorized to burn tokens
    mapping(address => bool) public burners;
    
    /// error for unauthorized burn attempts
    error UnauthorizedBurner();
    
    /// error for trying to set zero address as burner
    error NoZeroBurner();

    /**
     * Event emitted when a burner is added or removed
     * @param burner The address of the burner
     * @param authorized Whether the burner is authorized or not
     */
    event BurnerUpdated(address indexed burner, bool authorized);

    /**
     * Event emitted when tokens are burned by an authorized burner
     * @param burner The address that performed the burn
     * @param account The account whose tokens were burned
     * @param amount The amount of tokens burned
     */
    event Burned(address indexed burner, address indexed account, uint256 amount);

    constructor(
        Policy _policy,
        IERC20 _ecoXAddr
    ) ECOxStaking(_policy, _ecoXAddr) {}

    /**
     * @dev Modifier to check if the caller is an authorized burner
     */
    modifier onlyBurner() {
        if (!burners[msg.sender]) {
            revert UnauthorizedBurner();
        }
        _;
    }

    /**
     * @dev Adds or removes a burner address
     * @param _burner The address to add or remove as a burner
     * @param _authorized Whether to authorize or deauthorize the burner
     */
    function setBurner(address _burner, bool _authorized) external onlyPolicy {
        if (_burner == address(0)) {
            revert NoZeroBurner();
        }
        
        burners[_burner] = _authorized;
        emit BurnerUpdated(_burner, _authorized);
    }

    /**
     * @dev Allows authorized burners to burn tokens from any account
     * @param _account The account to burn tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(address _account, uint256 _amount) external onlyBurner {
        _burn(_account, _amount);
        emit Burned(msg.sender, _account, _amount);
    }
}