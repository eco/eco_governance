// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {L2ECOx} from "lib/op-eco/contracts/token/L2ECOx.sol";
import {Initializable} from "@openzeppelin-op-eco/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin-op-eco/contracts-upgradeable/security/PausableUpgradeable.sol";

contract L2ECOxFreeze is L2ECOx, PausableUpgradeable {

    mapping(address => bool) public pausers;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// Re-init for V2
    function reinitializeV2() public reinitializer(2) {
        address newTokenRoleAdmin = 0xCF2A6B4bc14A1FEf0862c9583b61B1beeDE980C2; //security council for now
        pausers[newTokenRoleAdmin] = true;
        _pause();
    }


    modifier onlyPauser() {
        require(pausers[msg.sender], "L2ECOx: not pauser");
        _;
    }

    function updatePausers(address _key, bool _value) public onlyTokenRoleAdmin {
        pausers[_key] = _value;
    }

    function pause() external onlyPauser whenNotPaused {
        _pause();
    }

    function unpause() external onlyPauser whenPaused {
        _unpause();
    }

    function transfer(address to, uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }
}
