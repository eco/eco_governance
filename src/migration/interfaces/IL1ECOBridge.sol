// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IL1ERC20Bridge} from "@eth-optimism/contracts/L1/messaging/IL1ERC20Bridge.sol";

// I had to copy the interface from op-eco because of solidity version conflicts

/**
 * @title IL1ECOBridge
 * @dev Interface for the L1 ECO bridge contract, which handles token deposits and withdrawals between L1 and L2
 */
interface IL1ECOBridge is IL1ERC20Bridge {
    // Event for when the L2ECO token implementation is upgraded
    event UpgradeL2ECO(address _newEcoImpl);

    // Event for when the L2ECOx token implementation is upgraded
    event UpgradeL2ECOx(address _newEcoXImpl);

    // Event for when the L2ECOBridge token implementation is upgraded
    event UpgradeL2Bridge(address _newBridgeImpl);

    // Event for when this contract's token implementation is upgraded
    event UpgradeSelf(address _newBridgeImpl);

    // Event for when failed withdrawal needs to be u-turned
    event WithdrawalFailed(
        address indexed _l1Token,
        address indexed _l2Token,
        address indexed _from,
        address _to,
        uint256 _amount,
        bytes _data
    );

    /**
     * @param _l1messenger L1 Messenger address being used for cross-chain communications.
     * @param _l2TokenBridge L2 ECO bridge address.
     * @param _l1Eco address of L1 ECO contract.
     * @param _l2Eco address of L2 ECO contract.
     * @param _l1ProxyAdmin address of ProxyAdmin contract for the L1 Bridge.
     * @param _upgrader address that can perform upgrades.
     */
    function initialize(
        address _l1messenger,
        address _l2TokenBridge,
        address _l1Eco,
        address _l2Eco,
        address _l1ProxyAdmin,
        address _upgrader
    ) external;

    /**
     * @dev Upgrades the L2ECO token implementation address by sending
     *      a cross domain message to the L2 Bridge via the L1 Messenger
     * @param _impl L2 contract address.
     * @param _l2Gas The minimum gas limit required for an L2 address finalizing the transation
     */
    function upgradeECO(address _impl, uint32 _l2Gas) external;

    /**
     * @dev Upgrades the L2ECOx token implementation address by sending
     *      a cross domain message to the L2 Bridge via the L1 Messenger
     * @param _impl L2 contract address.
     * @param _l2Gas The minimum gas limit required for an L2 address finalizing the transation
     */
    function upgradeECOx(address _impl, uint32 _l2Gas) external;

    /**
     * @dev Upgrades the L2ECOBridge implementation address by sending
     *      a cross domain message to the L2 Bridge via the L1 Messenger
     * @param _impl L2 contract address.
     * @param _l2Gas The minimum gas limit required for an L2 address finalizing the transation
     */
    function upgradeL2Bridge(address _impl, uint32 _l2Gas) external;

    /**
     * @dev Upgrades this contract implementation by passing the new implementation address to the ProxyAdmin.
     * @param _newBridgeImpl The new L1ECOBridge implementation address.
     */
    function upgradeSelf(address _newBridgeImpl) external;

    /**
     * @dev initiates the propagation of a linear rebase from L1 to L2
     * @param _l2Gas The minimum gas limit required for an L2 address finalizing the transation
     */
    function rebase(uint32 _l2Gas) external;
}
