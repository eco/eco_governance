// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";

/// @title ProportionalChunkedClawbackVault
/// @notice A vesting wallet with an admin-controlled clawback mechanism for unvested tokens.
/// @dev Inherits from OpenZeppelin's VestingWallet. The admin can claw back unvested tokens at any time.
contract ProportionalChunkedClawbackVault is VestingWallet {

    struct VestingChunk {
        uint64 timestamp;
        uint64 totalPercentVested;
    }

    /// @notice Emitted when the admin claws back unvested tokens.
    /// @param token The address of the ERC20 token being clawed back.
    /// @param amount The amount of tokens clawed back.
    event Clawback(address indexed token, uint256 amount);

    error UnauthorizedClawback();
    error NothingToClawback();

    /// @notice The address with permission to claw back unvested tokens.
    address public immutable admin;

    VestingChunk[] public chunks;

    bool public clawedBack;

    /// @notice Creates a new ProportionalChunkedClawbackVault.
    /// @param _admin The address with clawback privileges.
    /// @param _beneficiary The address that will receive vested tokens.
    /// @param _chunks The array of vesting chunks, each specifying a timestamp and cumulative percent vested.
    constructor(address _admin, address _beneficiary, uint64 startTimestamp, uint64 durationSeconds, VestingChunk[] memory _chunks) 
        VestingWallet(_beneficiary, startTimestamp, durationSeconds)
    {
        admin = _admin;
        
        require(_chunks.length > 0, "Must have at least one chunk");
        require(_chunks[_chunks.length - 1].totalPercentVested == 100, "Last chunk must be 100% vested");
        
        uint256 prevTimestamp = 0;
        uint256 prevPercentVested = 0;
        
        for (uint256 i = 0; i < _chunks.length; i++) {
            require(_chunks[i].timestamp > prevTimestamp, "Chunks must be in ascending order");
            require(_chunks[i].totalPercentVested >= prevPercentVested, "Percent vested must be non-decreasing");
            require(_chunks[i].totalPercentVested <= 100, "Percent vested cannot exceed 100");
            
            chunks.push(_chunks[i]);
            prevTimestamp = _chunks[i].timestamp;
            prevPercentVested = _chunks[i].totalPercentVested;
        }
    }

    /// @notice Returns the beneficiary of the vault.
    /// @dev This is the same as the owner of the vesting wallet.
    function beneficiary() external view returns (address) {
        return owner();
    }

    /// @notice Returns the number of vesting chunks.
    function getChunksLength() external view returns (uint256) {
        return chunks.length;
    }

    /// @notice Returns a specific vesting chunk by index.
    /// @param index The index of the chunk to retrieve.
    /// @return timestamp The timestamp of the chunk.
    /// @return totalPercentVested The total percent vested at this chunk.
    function getChunk(uint256 index) external view returns (uint64 timestamp, uint64 totalPercentVested) {
        require(index < chunks.length, "Index out of bounds");
        VestingChunk memory chunk = chunks[index];
        return (chunk.timestamp, chunk.totalPercentVested);
    }

    /// @notice Allows the admin to claw back unvested tokens from the vault.
    /// @dev Only callable by the admin. Calculates the unvested amount and transfers it to the admin.
    /// @param token The address of the ERC20 token to claw back.
    function clawback(address token) external {
        if (msg.sender != admin) revert UnauthorizedClawback();
        
        uint256 totalAllocation = IERC20(token).balanceOf(address(this)) + released(token);
        uint256 vested = vestedAmount(token, uint64(block.timestamp));
        uint256 unvested = totalAllocation > vested ? totalAllocation - vested : 0;
        
        if (unvested == 0) revert NothingToClawback();
        
        IERC20(token).transfer(admin, unvested);
        clawedBack = true;
        emit Clawback(token, unvested);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view override returns (uint256) {
        if (timestamp < start()) {
            return 0;
        }
        
        if (clawedBack || timestamp >= start() + duration()) {
            return totalAllocation;
        }
        
        // Find the appropriate chunk for the given timestamp
        for (uint256 i = chunks.length; i > 0; i--) {
            if (timestamp >= chunks[i-1].timestamp) {
                return (totalAllocation * chunks[i-1].totalPercentVested) / 100;
            }
        }
        
        return 0;
    }
}