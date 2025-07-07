pragma solidity ^0.8.20;
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title TokenProxy
/// @notice This contract is a simple extension of ERC1967Proxy, created solely to differentiate this proxy and give it a unique name.
/// @dev No additional logic is implemented; this contract exists for naming and identification purposes only.

contract TokenProxy is ERC1967Proxy {
    /// @notice Constructor that forwards the implementation and initialization data to the ERC1967Proxy constructor.
    /// @param implementation The address of the implementation contract.
    /// @param _data The initialization calldata for the implementation contract.
    constructor(address implementation, bytes memory _data) payable ERC1967Proxy(implementation, _data) {}
}