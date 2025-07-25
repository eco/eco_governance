// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECOx} from "../../lib/currency-1.5/contracts/currency/ECOx.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ECOxBurner
 * @dev Burns ECOx tokens from specified addresses. Only the owner can call burn functions.
 */
contract ECOxBurner is Ownable {
    ECOx public immutable ecox;

    constructor(address _ecox, address _owner) Ownable(_owner) {
        require(_ecox != address(0), "ECOx address required");
        ecox = ECOx(_ecox);
    }

    /// @notice Burns the entire ECOx balance of a single address
    /// @param account The address whose balance will be burned
    function burnBalance(address account) public onlyOwner {
        uint256 bal = ecox.balanceOf(account);
        if (bal > 0) {
            ecox.burn(account, bal);
        }
    }

    /// @notice Burns the entire ECOx balance of each address in the input array
    /// @param accounts The array of addresses whose balances will be burned
    function burnBalances(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; ++i) {
            burnBalance(accounts[i]);
        }
    }
}
