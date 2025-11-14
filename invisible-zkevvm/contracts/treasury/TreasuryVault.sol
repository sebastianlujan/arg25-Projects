// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {FHE, euint64, ebool, InEuint64} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Treasury Vault with FHE
/// @notice Manages encrypted treasury balances with private amounts using Fhenix CoFHE
/// @dev IMPORTANT: This contract expects encrypted inputs from external sources.
///     Required encrypted inputs:
///     - Deposit amount: InEuint64
///     - Withdrawal amount: InEuint64
///     - Allocation amount: InEuint64
///     See TREASURY_GUIDE.md for details.
/// @dev Follows CoFHE best practices: encrypted constants, proper access control
contract TreasuryVault is Ownable {
    using SafeERC20 for IERC20;

    // ============ Structs ============
    
    struct TreasuryBalance {
        euint64 totalBalance;       // Total encrypted balance (euint64 for operations)
        euint64 reservedFunds;      // Reserved for operations (euint64 for operations)
        euint64 availableFunds;      // Available for distribution (euint64 for operations)
    }

    struct WithdrawalRequest {
        euint64 amount;             // Encrypted withdrawal amount (euint64 for operations)
        address recipient;          // Recipient address
        uint256 timestamp;          // Request timestamp
        ebool isApproved;           // Encrypted approval status
        uint256 executionTime;      // Timelock execution time
    }

    // ============ State Variables ============
    
    address public evvmCore;        // EVVM Core contract address
    mapping(address => TreasuryBalance) public balances; // Token -> Balance
    mapping(address => mapping(bytes32 => euint64)) public allocations; // Token -> Purpose -> Amount
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
    mapping(address => bool) public governors; // Governance addresses
    uint256 private nextRequestId;
    uint256 public constant TIMELOCK_DURATION = 2 days;

    // Encrypted constants for gas optimization (CoFHE best practice)
    euint64 private EUINT64_ZERO;
    ebool private EBOOL_TRUE;

    // ============ Events ============
    
    event Deposited(address indexed token, address indexed from);
    event WithdrawalRequested(
        uint256 indexed requestId,
        address indexed recipient,
        uint256 executionTime
    );
    event WithdrawalExecuted(uint256 indexed requestId);
    event FundsAllocated(address indexed token, bytes32 indexed purpose);
    event EmergencyWithdrawal(address indexed token, address indexed recipient);

    // ============ Modifiers ============
    
    modifier onlyGovernance() {
        require(governors[msg.sender], "Not governor");
        _;
    }

    // ============ Constructor ============
    
    constructor(address _evvmCore) Ownable(msg.sender) {
        evvmCore = _evvmCore;
        governors[msg.sender] = true; // Owner is initial governor
        
        // Initialize encrypted constants once in constructor to save gas (CoFHE best practice)
        EUINT64_ZERO = FHE.asEuint64(0);
        EBOOL_TRUE = FHE.asEbool(true);
    }

    // ============ Deposit Functions ============
    
    /// @notice Deposit funds to treasury with encrypted amount
    /// @param token Token address (address(0) for ETH)
    /// @param inputEncryptedAmount Encrypted deposit amount (InEuint64)
    /// @dev CoFHE handles proof verification internally
    function deposit(
        address token,
        InEuint64 memory inputEncryptedAmount
    ) external payable {
        // Convert encrypted input (CoFHE handles proof verification internally)
        euint64 encryptedAmount = FHE.asEuint64(inputEncryptedAmount);
        
        if (token == address(0)) {
            // ETH deposit
            require(msg.value > 0, "Amount must be > 0");
            // Note: For MVP, we trust msg.value matches encrypted amount
            // In production, verify encrypted amount matches msg.value externally
        } else {
            // ERC20 deposit
            require(msg.value == 0, "No ETH for ERC20");
            // Note: For MVP, amount must be provided via approve + transferFrom
            // In production, verify encrypted amount matches transferred amount
        }
        
        // Update treasury balance
        TreasuryBalance storage balance = balances[token];
        balance.totalBalance = FHE.add(balance.totalBalance, encryptedAmount);
        balance.availableFunds = FHE.add(balance.availableFunds, encryptedAmount);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(balance.totalBalance);
        FHE.allowThis(balance.availableFunds);
        
        // Handle ERC20 transfer (must be approved beforehand)
        if (token != address(0)) {
            // For MVP: assume transferFrom was called separately
            // In production: integrate with encrypted amount verification
        }
        
        emit Deposited(token, msg.sender);
    }

    // ============ Withdrawal Functions ============
    
    /// @notice Request withdrawal with governance approval
    /// @param token Token address
    /// @param inputEncryptedAmount Encrypted withdrawal amount (InEuint64)
    /// @param recipient Recipient address
    /// @dev CoFHE handles proof verification internally
    /// @return requestId The withdrawal request ID
    function requestWithdrawal(
        address token,
        InEuint64 memory inputEncryptedAmount,
        address recipient
    ) external onlyGovernance returns (uint256 requestId) {
        // Convert encrypted input (CoFHE handles proof verification internally)
        euint64 encryptedAmount = FHE.asEuint64(inputEncryptedAmount);
        
        // Check available funds (simplified for MVP)
        TreasuryBalance storage balance = balances[token];
        // Note: Full balance check requires external decryption
        
        // Create withdrawal request
        requestId = nextRequestId++;
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        request.amount = encryptedAmount;
        request.recipient = recipient;
        request.timestamp = block.timestamp;
        request.isApproved = EBOOL_TRUE; // Auto-approved for governance (using pre-encrypted constant)
        request.executionTime = block.timestamp + TIMELOCK_DURATION;
        
        // Reserve funds
        balance.reservedFunds = FHE.add(balance.reservedFunds, encryptedAmount);
        balance.availableFunds = FHE.sub(balance.availableFunds, encryptedAmount);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(balance.reservedFunds);
        FHE.allowThis(balance.availableFunds);
        FHE.allowThis(request.amount);
        FHE.allowThis(request.isApproved);
        
        emit WithdrawalRequested(requestId, recipient, request.executionTime);
        return requestId;
    }

    /// @notice Execute approved withdrawal after timelock
    /// @param requestId The withdrawal request ID
    /// @param token Token address to withdraw
    function executeWithdrawal(uint256 requestId, address token) external {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        require(block.timestamp >= request.executionTime, "Timelock not expired");
        require(request.recipient != address(0), "Invalid request");
        // Note: Approval verification requires external decryption
        
        // Update balances
        TreasuryBalance storage balance = balances[token];
        balance.reservedFunds = FHE.sub(balance.reservedFunds, request.amount);
        balance.totalBalance = FHE.sub(balance.totalBalance, request.amount);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(balance.reservedFunds);
        FHE.allowThis(balance.totalBalance);
        
        // Note: Actual token transfer requires decryption of amount
        // For MVP, this is handled externally after decryption
        
        emit WithdrawalExecuted(requestId);
    }

    // ============ Allocation Functions ============
    
    /// @notice Allocate funds to specific purpose
    /// @param token Token address
    /// @param inputEncryptedAmount Encrypted allocation amount (InEuint64)
    /// @param purpose Purpose identifier (bytes32)
    /// @dev CoFHE handles proof verification internally
    function allocateFunds(
        address token,
        InEuint64 memory inputEncryptedAmount,
        bytes32 purpose
    ) external onlyGovernance {
        // Convert encrypted input (CoFHE handles proof verification internally)
        euint64 encryptedAmount = FHE.asEuint64(inputEncryptedAmount);
        
        TreasuryBalance storage balance = balances[token];
        
        // Update allocations
        allocations[token][purpose] = FHE.add(allocations[token][purpose], encryptedAmount);
        balance.availableFunds = FHE.sub(balance.availableFunds, encryptedAmount);
        balance.reservedFunds = FHE.add(balance.reservedFunds, encryptedAmount);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(allocations[token][purpose]);
        FHE.allowThis(balance.availableFunds);
        FHE.allowThis(balance.reservedFunds);
        
        emit FundsAllocated(token, purpose);
    }

    // ============ Admin Functions ============
    
    /// @notice Add governance address
    function addGovernor(address governor) external onlyOwner {
        governors[governor] = true;
    }

    /// @notice Remove governance address
    function removeGovernor(address governor) external onlyOwner {
        governors[governor] = false;
    }

    // ============ View Functions ============
    
    /// @notice Get treasury balance for a token
    /// @param token Token address
    /// @return totalBalance Encrypted total balance
    /// @return reservedFunds Encrypted reserved funds
    /// @return availableFunds Encrypted available funds
    function getTreasuryBalance(address token) external view returns (
        euint64 totalBalance,
        euint64 reservedFunds,
        euint64 availableFunds
    ) {
        TreasuryBalance storage balance = balances[token];
        return (balance.totalBalance, balance.reservedFunds, balance.availableFunds);
    }

    /// @notice Get allocation for a token and purpose
    /// @param token Token address
    /// @param purpose Purpose identifier
    /// @return Encrypted allocation amount
    function getAllocation(address token, bytes32 purpose) external view returns (euint64) {
        return allocations[token][purpose];
    }

    /// @notice Get withdrawal request
    /// @param requestId Request ID
    /// @return amount Encrypted amount
    /// @return recipient Recipient address
    /// @return timestamp Request timestamp
    /// @return isApproved Encrypted approval status
    /// @return executionTime Execution time
    function getWithdrawalRequest(uint256 requestId) external view returns (
        euint64 amount,
        address recipient,
        uint256 timestamp,
        ebool isApproved,
        uint256 executionTime
    ) {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        return (
            request.amount,
            request.recipient,
            request.timestamp,
            request.isApproved,
            request.executionTime
        );
    }
}

