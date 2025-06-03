// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IL2ECOxFreeze {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed _account, uint256 _amount);
    event EIP712DomainChanged();
    event Initialized(uint8 version);
    event Mint(address indexed _account, uint256 _amount);
    event Paused(address account);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Unpaused(address account);

    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function burn(address _from, uint256 _amount) external;
    function burners(address) external view returns (bool);
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function initialize(address _l1Token, address _OPl2Bridge, address _ECOl2Bridge) external;
    function l1Token() external view returns (address);
    function mint(address _to, uint256 _amount) external;
    function minters(address) external view returns (bool);
    function name() external view returns (string memory);
    function pause() external;
    function paused() external view returns (bool);
    function pausers(address) external view returns (bool);
    function reinitializeV2() external;
    function supportsInterface(bytes4 _interfaceId) external pure returns (bool);
    function symbol() external view returns (string memory);
    function tokenRoleAdmin() external view returns (address);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function unpause() external;
    function updateBurners(address _key, bool _value) external;
    function updateMinters(address _key, bool _value) external;
    function updatePausers(address _key, bool _value) external;
    function updateTokenRoleAdmin(address _newAdmin) external;
}
