// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

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
 * @title GetLockupBeneficiary
 * @notice Script to get the beneficiary address from a lockup contract
 */
contract GetLockupBeneficiary is Script {
    function run(address lockupAddress) external {
        console.log("Checking lockup contract at address:", lockupAddress);
        ILockupContract lockupContract = ILockupContract(lockupAddress);
        address beneficiary = lockupContract.beneficiary();
        console.log("Beneficiary address:", beneficiary);
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(beneficiary)
        }
    }
} 