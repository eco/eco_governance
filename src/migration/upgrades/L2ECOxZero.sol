// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* Interface Imports */
import {IL2StandardERC20} from "@eth-optimism/contracts/standards/IL2StandardERC20.sol";

/* Contract Imports */
import {L2ECOxFreeze} from "./L2ECOxFreeze.sol";

/**
 * @title L2ECOxZero
 * @dev The L2 ECOxZero token is an upgraded version of L2ECOxFreeze designed for token migration.
 *
 * This contract maintains full storage compatibility with L2ECOxFreeze while adding:
 * - Name and symbol changed to "0xgone" to indicate the token is being phased out
 * - Ability to burn all balances from specified addresses during migration
 * - Self-burner and self-pauser permissions via reinitializeV3() to enable balance burning
 *
 * The contract inherits all functionality from L2ECOxFreeze including pause/unpause
 * capabilities and role management, while providing the additional migration features.
 *
 * @notice This token is dead, and all its balances have been moved to L1.
 */
contract L2ECOxZero is L2ECOxFreeze {
    // Maximum accounts allowed in a single batch to prevent out-of-gas errors
    uint256 public constant MAX_BATCH_SIZE = 200;

    /**
     * @dev Override name to return "0xgone" to indicate the token is being phased out
     */
    function name() public view virtual override returns (string memory) {
        return "0xgone";
    }

    /**
     * @dev Override symbol to return "0xgone" to indicate the token is being phased out
     */
    function symbol() public view virtual override returns (string memory) {
        return "0xgone";
    }

    /**
     * @dev Reinitializer for V3 - gives this contract burner and pauser permissions
     * This allows the contract to burn its own balances
     */
    function reinitializeV3() public reinitializer(3)[cite: 9] {
        // Give this contract burner and pauser permissions[cite: 9]
        burners[address(this)] = true;[cite: 9]
        pausers[address(this)] = true;[cite: 9]
    }

    /**
     * @dev Burns the entire ECOx balance of each address in the input array
     * @dev Restricted to pausers: the function toggles the pause state and destroys
     * arbitrary balances, so it must never be callable by an unprivileged account
     * @param accounts The array of addresses whose balances will be burned
     */
    function burnBalances(address[] calldata accounts) external onlyPauser {[cite: 9]
        // Enforce a maximum batch size to prevent unbounded gas consumption
        require(accounts.length <= MAX_BATCH_SIZE, "accounts array exceeds max batch size");

        // Unpause to allow transfers[cite: 9]
        _unpause();[cite: 9]

        for (uint256 i = 0; i < accounts.length; ++i) {[cite: 9]
            uint256 bal = balanceOf(accounts[i]);[cite: 9]
            if (bal > 0) {[cite: 9]
                _burn(accounts[i], bal);[cite: 9]
            }
        }

        // Repause after burning[cite: 9]
        _pause();[cite: 9]
    }
}
