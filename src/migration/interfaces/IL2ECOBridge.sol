// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IL2ERC20Bridge} from "@eth-optimism/contracts/L2/messaging/IL2ERC20Bridge.sol";

// I had to copy the interface from op-eco because of solidity version conflicts

/**
 * @title IL2ECOBridge
 */
interface IL2ECOBridge is IL2ERC20Bridge {
    // Event for when the inflation multiplier is set in the rebase function
    event RebaseInitiated(uint256 _inflationMultiplier);

    // Event for when the L2ECO token implementation is upgraded
    event UpgradeECOImplementation(address _newEcoImpl);

    // Event for when the L2ECOx token implementation is upgraded
    event UpgradeECOxImplementation(address _newEcoImpl);

    // Event for when the L2ECOBridge authority is transferred to a new bridge address
    event UpgradeSelf(address _newBridgeImpl);

    /**
     * @dev Initializer that sets the L2 messanger to use, L1 bridge address, the L2 token address, and the proxy admin address
     * @param _l2CrossDomainMessenger Cross-domain messenger used by this contract on L2
     * @param _l1TokenBridge Address of the L1 bridge deployed to L1 chain
     * @param _l1Eco Address of the L1 ECO token deployed to L1 chain
     * @param _l2Eco Address of the L2 ECO token deployed to L2 chain
     * @param _l2ProxyAdmin Address of the L2 proxy admin that manages the upgrade of the L2 token implementation
     */
    function initialize(
        address _l2CrossDomainMessenger,
        address _l1TokenBridge,
        address _l1Eco,
        address _l2Eco,
        address _l2ProxyAdmin
    ) external;

    /**
     * @dev Passes the inflation multiplier to the L2Eco token.
     * @param _inflationMultiplier The inflation multiplier to rebase the token with
     * @param _blockNumber The block number of the L1 call that initiated the rebase. Used to prevent replay attacks on failed rebase calls
     */
    function rebase(uint256 _inflationMultiplier, uint256 _blockNumber) external;

    /**
     * @dev Sets the L2ECO token proxy to a new implementation address for the L2ECO token.
     * @param _newEcoImpl The address of the new L2ECO token implementation
     * @param _blockNumber The block number of the L1 call that initiated the upgrade. Used to prevent replay attacks on failed upgrade calls
     */
    function upgradeECO(address _newEcoImpl, uint256 _blockNumber) external;

    /**
     * @dev Sets the L2ECO token proxy to a new implementation address for the L2ECO token.
     * @param _newEcoXImpl The address of the new L2ECOx token implementation
     * @param _blockNumber The block number of the L1 call that initiated the upgrade. Used to prevent replay attacks on failed upgrade calls
     */
    function upgradeECOx(address _newEcoXImpl, uint256 _blockNumber) external;

    /**
     * @dev Upgrades this contract implementation by passing the new implementation address to the ProxyAdmin.
     * @param _newBridgeImpl The new L2ECOBridge implementation address.
     * @param _blockNumber The block number of the L1 call that initiated the upgrade. Used to prevent replay attacks on failed upgrade calls
     */
    function upgradeSelf(address _newBridgeImpl, uint256 _blockNumber) external;
}
