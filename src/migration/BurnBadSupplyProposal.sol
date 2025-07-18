pragma solidity ^0.8.0;

import {Proposal} from "currency-1.5/governance/community/proposals/Proposal.sol";
import {Token} from "src/Token.sol";

contract BurnBadSupplyProposal is Proposal {
    address public immutable newToken;
    address public immutable migrationContract;

    constructor(address _newToken, address _migrationContract) {
        newToken = _newToken;
        migrationContract = _migrationContract;
    }

    function name() public pure override returns (string memory) {
        return "Burn Bad Supply";
    }

    function description() public pure override returns (string memory) {
        return "Burn the full supply of the new token to rectify bad mint";
    }

    function url() public pure override returns (string memory) {
        return "_";
    }

    function enacted(address _self) public override {
        Token(newToken).burn(migrationContract, Token(newToken).balanceOf(migrationContract));
    }
}