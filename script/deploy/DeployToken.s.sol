// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Token} from "../../src/Token.sol";
import {TokenProxy} from "../../src/TokenProxy.sol";

contract DeployTokenScript is Script {
    Token public tokenImplementation;
    TokenProxy public tokenProxy;
    Token public token; // This will be the proxy instance

    function setUp() public {}

    function run() public {
        // Get deployment parameters from environment or use defaults
        address admin = address(0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68);
        address pauser = address(0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68);
        string memory name = "New Eco";
        string memory symbol = "NEW";

        console.log("Deploying Token implementation...");
        console.log("Admin address:", admin);
        console.log("Pauser address:", pauser);
        console.log("Token name:", name);
        console.log("Token symbol:", symbol);

        vm.startBroadcast();

        // Deploy the implementation contract
        tokenImplementation = new Token();
        console.log("Token implementation deployed at:", address(tokenImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            Token.initialize.selector,
            admin,
            pauser,
            name,
            symbol
        );

        // Deploy the proxy contract
        tokenProxy = new TokenProxy(address(tokenImplementation), initData);
        console.log("TokenProxy deployed at:", address(tokenProxy));

        // Create a Token instance pointing to the proxy for easy interaction
        token = Token(address(tokenProxy));

        vm.stopBroadcast();

        console.log("Deployment complete!");
        console.log("Token implementation:", address(tokenImplementation));
        console.log("TokenProxy:", address(tokenProxy));
        console.log("Token (proxy instance):", address(token));
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Token decimals:", token.decimals());
        console.log("Token total supply:", token.totalSupply());
        
        // Verification on Etherscan
        console.log("\n=== ETHERSCAN VERIFICATION ===");
        console.log("To verify on Etherscan, run:");
        console.log("forge verify-contract", address(tokenImplementation), "src/Token.sol:Token --chain-id 1");
        console.log("forge verify-contract", address(tokenProxy), "src/TokenProxy.sol:TokenProxy --chain-id 1 --constructor-args", vm.toString(abi.encode(address(tokenImplementation), initData)));


        console.log("Token implementation deployed at:", address(tokenImplementation));
        console.log("TokenProxy deployed at:", address(tokenProxy));
    }
} 