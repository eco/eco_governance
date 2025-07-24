// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ProportionalChunkedClawbackVault} from "../../src/ProportionalChunkedClawbackVault.sol";

contract DeployProportionalChunkedClawbackVaultScript is Script {
    ProportionalChunkedClawbackVault public vault;

    function setUp() public {}

    function run() public {
        // Get deployment parameters from environment or use defaults
        address admin = vm.envOr("ADMIN_ADDRESS", address(0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68));
        
        
        
        // Create vesting chunks from timestamps and proportions

        // 2M vault: 0x4923438A972Fe8bDf1994B276525d89F5DE654c9
        // uint64[7] memory timestamps = [uint64(1730131200), 1740762000, 1751126400, 1761667200, 1772298000, 1782662400, 1793203200];
        // uint64[7] memory proportions = [uint64(10), 25, 40, 55, 70, 85, 100];
        // address beneficiary = address(0x90a478BfF9b1e7f23e6b6c6d1eE6a0F574eEDB01);

        // // 18M vault: 0x35FDFe53b3817dde163dA82deF4F586450EDf893
        uint64[7] memory timestamps = [uint64(1730131200), 1740762000, 1751126400, 1761667200, 1772298000, 1782662400, 1793203200];
        uint64[7] memory proportions = [uint64(10), 25, 40, 55, 70, 85, 100];
        address beneficiary = address(0x17123d273B24615E2643fbBC273F613789a64d31);

        // Vesting schedule parameters
        uint64 startTimestamp = timestamps[0];
        uint64 durationSeconds = timestamps[timestamps.length - 1] - startTimestamp;
        
        // Create chunks from the arrays
        ProportionalChunkedClawbackVault.VestingChunk[] memory chunks = new ProportionalChunkedClawbackVault.VestingChunk[](timestamps.length);
        
        for (uint256 i = 0; i < timestamps.length; i++) {
            chunks[i] = ProportionalChunkedClawbackVault.VestingChunk({
                timestamp: timestamps[i],
                totalPercentVested: proportions[i]
            });
        }

        console.log("Deploying ProportionalChunkedClawbackVault...");
        console.log("Admin address:", admin);
        console.log("Beneficiary address:", beneficiary);
        console.log("Start timestamp:", startTimestamp);
        console.log("Duration (seconds):", durationSeconds);
        console.log("Number of vesting chunks:", chunks.length);
        
        // Log vesting schedule
        for (uint256 i = 0; i < chunks.length; i++) {
            console.log("Chunk", i);
            console.log("Timestamp:", chunks[i].timestamp);
            console.log("Percent Vested:", chunks[i].totalPercentVested, "%");
        }

        vm.startBroadcast();

        // Deploy the vault contract
        vault = new ProportionalChunkedClawbackVault(
            admin,
            beneficiary,
            startTimestamp,
            durationSeconds,
            chunks
        );

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("ProportionalChunkedClawbackVault deployed at:", address(vault));
        console.log("Admin:", vault.admin());
        console.log("Beneficiary:", vault.beneficiary());
        console.log("Start timestamp:", vault.start());
        console.log("Duration:", vault.duration());
        console.log("Clawed back:", vault.clawedBack());
        console.log("Number of chunks:", vault.getChunksLength());
        
        // Verify chunks were set correctly
        for (uint256 i = 0; i < vault.getChunksLength(); i++) {
            uint64 timestamp;
            uint64 percentVested;
            (timestamp, percentVested) = vault.getChunk(i);
            console.log("Verified Chunk", i);
            console.log("Timestamp:", timestamp);
            console.log("Percent Vested:", percentVested, "%");
        }
        
        // Verification on Etherscan
        console.log("\n=== ETHERSCAN VERIFICATION ===");
        console.log("To verify on Etherscan, run:");
        console.log("forge verify-contract", address(vault), "src/ProportionalChunkedClawbackVault.sol:ProportionalChunkedClawbackVault --chain-id 1 --constructor-args", vm.toString(abi.encode(admin, beneficiary, startTimestamp, durationSeconds, chunks)));
    }
} 