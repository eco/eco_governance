pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ECOx} from "currency-1.5/currency/ECOx.sol";
import {Policy} from "currency-1.5/policy/Policy.sol";
import {ECOxZero} from "src/migration/upgrades/ECOxZero.sol";
import {ECOxCleanupProposal} from "src/migration/ECOxCleanupProposal.sol";
import {ECOxBurner} from "src/migration/ECOxBurner.sol";

contract ECOxCleanupProposalTest is Test {
    uint256 mainnetFork;
    string mainnetRpcUrl = vm.envString("MAINNET_RPC_URL");

    // Mainnet addresses (update as needed)
    address constant ECOX_MAINNET = 0xcccD1Ba9f7acD6117834E0D28F25645dECb1736a;
    address constant POLICY = 0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68;
    address constant SECURITY_COUNCIL = 0xCF2A6B4bc14A1FEf0862c9583b61B1beeDE980C2;
    address constant TEST_HOLDER = 0xcccD1Ba9f7acD6117834E0D28F25645dECb1736a; // ECOx contract, but has ECOx balance for some reason

    ECOxBurner burner;
    ECOxCleanupProposal proposal;
    ECOxZero ecoxZeroImpl;
    ECOx ecox;


    address public deployedProposal = 0x66e69b3af8058561335B88d3a56F099af8dBdd3f;
    address public deployedECOxBurner = 0x430d367389E9e032391B52278dd82afD2FF90F1E;

    function setUp() public {
        mainnetFork = vm.createSelectFork(mainnetRpcUrl, 22997414); // Use a recent block
        ecox = ECOx(ECOX_MAINNET);
        
        // Deploy ECOxZero implementation
        ecoxZeroImpl = new ECOxZero(Policy(0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68), address(0));
        
        // Deploy burner with SECURITY_COUNCIL as owner
        burner = new ECOxBurner(address(ecox), SECURITY_COUNCIL);
        
        // Deploy proposal with ECOxZero implementation
        proposal = new ECOxCleanupProposal(address(ecox), address(burner), address(ecoxZeroImpl));
    }

    function test_enactment_upgrade_and_burn_deploy() public {
        // Check initial balance
        uint256 initialBalance = ecox.balanceOf(TEST_HOLDER);
        console.log("Initial ECOx balance of test holder:", initialBalance);
        assertGt(initialBalance, 0, "Test holder should have ECOx");

        // Check initial total supply
        uint256 initialTotalSupply = ecox.totalSupply();
        console.log("Initial total supply:", initialTotalSupply);

        // Check initial name and symbol
        string memory initialName = ecox.name();
        string memory initialSymbol = ecox.symbol();
        console.log("Initial name:", initialName);
        console.log("Initial symbol:", initialSymbol);

        // Impersonate security council to approve the proposal
        vm.startPrank(SECURITY_COUNCIL);
        Policy(POLICY).enact(address(proposal));
        vm.stopPrank();

        // Check that name and symbol changed to "0xgone"
        string memory newName = ecox.name();
        string memory newSymbol = ecox.symbol();
        console.log("New name:", newName);
        console.log("New symbol:", newSymbol);
        assertEq(newName, "0xgone", "Name should be 0xgone");
        assertEq(newSymbol, "0xgone", "Symbol should be 0xgone");

        // Impersonate SECURITY_COUNCIL to burn the test holder's balance
        vm.startPrank(SECURITY_COUNCIL);
        burner.burnBalance(TEST_HOLDER);
        vm.stopPrank();

        // Check balance is zero
        uint256 finalBalance = ecox.balanceOf(TEST_HOLDER);
        console.log("Final ECOx balance of test holder:", finalBalance);
        assertEq(finalBalance, 0, "Balance should be zero after burning");

        // Check total supply decreased
        uint256 finalTotalSupply = ecox.totalSupply();
        console.log("Final total supply:", finalTotalSupply);
        assertEq(finalTotalSupply, initialTotalSupply - initialBalance, "Total supply should decrease by burned amount");

        // Check that token is still paused after upgrade
        bool isPaused = ecox.paused();
        console.log("Token paused state after upgrade:", isPaused);
        assertTrue(isPaused, "Token should remain paused after upgrade");
    }

    function test_enactment_upgrade_and_burn_live() public {
        // Read holder addresses from CSV
        address[] memory holderAddresses = readHolderAddressesFromCSV();
        console.log("Number of holders to burn:", holderAddresses.length);

        // Check initial balances
        uint256 totalInitialBalance = 0;
        for (uint256 i = 0; i < holderAddresses.length; i++) {
            uint256 balance = ecox.balanceOf(holderAddresses[i]);
            totalInitialBalance += balance;
            if (balance > 0) {
                console.log("Holder", holderAddresses[i], "has balance:", balance);
            }
        }
        console.log("Total initial ECOx balance across all holders:", totalInitialBalance);
        assertGt(totalInitialBalance, 0, "Should have total ECOx balance to burn");

        // Check initial total supply
        uint256 initialTotalSupply = ecox.totalSupply();
        console.log("Initial total supply:", initialTotalSupply);

        // Check initial name and symbol
        string memory initialName = ecox.name();
        string memory initialSymbol = ecox.symbol();
        console.log("Initial name:", initialName);
        console.log("Initial symbol:", initialSymbol);

        // Impersonate security council to approve the proposal
        vm.startPrank(SECURITY_COUNCIL);
        Policy(POLICY).enact(deployedProposal);
        vm.stopPrank();

        // Check that name and symbol changed to "0xgone"
        string memory newName = ecox.name();
        string memory newSymbol = ecox.symbol();
        console.log("New name:", newName);
        console.log("New symbol:", newSymbol);
        assertEq(newName, "0xgone", "Name should be 0xgone");
        assertEq(newSymbol, "0xgone", "Symbol should be 0xgone");

        // Impersonate SECURITY_COUNCIL to burn all holder balances
        vm.startPrank(SECURITY_COUNCIL);
        ECOxBurner(deployedECOxBurner).burnBalances(holderAddresses);
        vm.stopPrank();

        // Check all balances are zero
        uint256 totalFinalBalance = 0;
        for (uint256 i = 0; i < holderAddresses.length; i++) {
            uint256 balance = ecox.balanceOf(holderAddresses[i]);
            totalFinalBalance += balance;
            if (balance > 0) {
                console.log("WARNING: Holder", holderAddresses[i], "still has balance:", balance);
            }
        }
        console.log("Total final ECOx balance across all holders:", totalFinalBalance);
        assertEq(totalFinalBalance, 0, "All balances should be zero after burning");

        // Check total supply decreased
        uint256 finalTotalSupply = ecox.totalSupply();
        console.log("Final total supply:", finalTotalSupply);
        assertEq(finalTotalSupply, 0, "Total supply should be zero after burning all balances");

        // Check that token is still paused after upgrade
        bool isPaused = ecox.paused();
        console.log("Token paused state after upgrade:", isPaused);
        assertTrue(isPaused, "Token should remain paused after upgrade");
    }

    function readHolderAddressesFromCSV() internal view returns (address[] memory) {
        string memory csvContent = vm.readFile("data/ecox_token_holders.csv");
        
        // Count lines first
        uint256 lineCount = 0;
        uint256 pos = 0;
        while (pos < bytes(csvContent).length) {
            uint256 newlinePos = findNewline(csvContent, pos);
            if (newlinePos == bytes(csvContent).length) break;
            lineCount++;
            pos = newlinePos + 1;
        }
        
        // Skip header, so valid addresses = lineCount - 1
        address[] memory addresses = new address[](lineCount - 1);
        uint256 addressIndex = 0;
        
        // Parse each line
        pos = 0;
        bool firstLine = true;
        while (pos < bytes(csvContent).length && addressIndex < addresses.length) {
            uint256 newlinePos = findNewline(csvContent, pos);
            if (newlinePos == bytes(csvContent).length) break;
            
            if (!firstLine) {
                string memory line = substring(csvContent, pos, newlinePos);
                string memory addressStr = extractAddressFromCSVLine(line);
                addresses[addressIndex] = vm.parseAddress(addressStr);
                addressIndex++;
            }
            
            firstLine = false;
            pos = newlinePos + 1;
        }
        
        return addresses;
    }
    
    function findNewline(string memory str, uint256 start) internal pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        for (uint256 i = start; i < strBytes.length; i++) {
            if (strBytes[i] == "\n") {
                return i;
            }
        }
        return strBytes.length;
    }
    
    function substring(string memory str, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }
        return string(result);
    }
    
    function extractAddressFromCSVLine(string memory line) internal pure returns (string memory) {
        // Find the first comma
        bytes memory lineBytes = bytes(line);
        uint256 commaPos = 0;
        for (uint256 i = 0; i < lineBytes.length; i++) {
            if (lineBytes[i] == ",") {
                commaPos = i;
                break;
            }
        }
        
        // Extract the first field (address)
        string memory firstField = substring(line, 0, commaPos);
        
        // Remove quotes if present
        bytes memory fieldBytes = bytes(firstField);
        if (fieldBytes.length >= 2 && fieldBytes[0] == '"' && fieldBytes[fieldBytes.length - 1] == '"') {
            return substring(firstField, 1, fieldBytes.length - 1);
        }
        
        return firstField;
    }
} 