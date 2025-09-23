pragma solidity ^0.8.0;

import {Proposal} from "currency-1.5/governance/community/proposals/Proposal.sol";
import {Token} from "src/Token.sol";

contract GrantPauseExemptProposal is Proposal {
    Token public immutable token;
    address public immutable pauseExemptAddress1;
    address public immutable pauseExemptAddress2;
    address public immutable pauseExemptAddress3;

    constructor(Token _token, address _addr1, address _addr2, address _addr3) {
        token = _token;
        pauseExemptAddress1 = _addr1;
        pauseExemptAddress2 = _addr2;
        pauseExemptAddress3 = _addr3;
    }

    function name() public pure override returns (string memory) {
        return "Grant Pause Exempt Role";
    }

    function description() public pure override returns (string memory) {
        return "Grants PAUSE_EXEMPT_ROLE to specified addresses allowing them to transfer tokens while paused";
    }

    function url() public pure override returns (string memory) {
        return "_";
    }

    function enacted(address _self) public override {
        bytes32 pauseExemptRole = token.PAUSE_EXEMPT_ROLE();

        token.grantRole(pauseExemptRole, pauseExemptAddress1);
        token.grantRole(pauseExemptRole, pauseExemptAddress2);
        token.grantRole(pauseExemptRole, pauseExemptAddress3);
    }
}