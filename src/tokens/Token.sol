// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract Token is ERC20PermitUpgradeable, PausableUpgradeable, AccessControlUpgradeable {
    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant PAUSE_EXEMPT_ROLE = keccak256("PAUSE_EXEMPT_ROLE");

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("TOKEN", "TKN");
        __ERC20Permit_init("TOKEN");
        __Pausable_init();
        __AccessControl_init();

        //TODO: decide to hardcode this or deploy with hardhat proxy toolkit
        address admin = 0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68; // ROOT POLICY ADDRESS
        address pauser = 0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68; // ROOT POLICY ADDRESS

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(PAUSER_ROLE, pauser);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function transfer(address to, uint256 amount) public override(ERC20Upgradeable) whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override(ERC20Upgradeable)
        whenNotPaused
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    function pausedTransfer(address to, uint256 amount) public onlyRole(PAUSE_EXEMPT_ROLE) whenPaused returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    uint256[50] private __gap; 
    // no need to include increaseAllowance, decreaseAllowance -- see https://github.com/OpenZeppelin/openzeppelin-contracts/issues/4583
}
