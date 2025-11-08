// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FHE, euint64, euint256, ebool, externalEuint256} from "@fhevm/solidity/lib/FHE.sol";
import {EthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEVVMStylus.sol";

/// @title EVVM Core - Virtual Blockchain with FHE
/// @notice Main contract for the Ethereum Virtual Virtual Machine
/// @dev Implements a virtual blockchain with encrypted blocks and transactions using Zama FHEVM
contract EVVMCore is EthereumConfig, Ownable {
    // ============ Structs ============
    
    /// @notice Virtual block structure with encrypted state
    struct VirtualBlock {
        euint64 blockNumber;      // Encrypted block number
        euint256 timestamp;       // Encrypted timestamp
        euint256 gasLimit;        // Encrypted gas limit
        address[] validators;      // Validator set (public for consensus)
        ebool isFinalized;        // Encrypted finalization status
        bytes32 blockHash;        // Block hash (public for verification)
    }

    /// @notice Virtual transaction structure with encrypted data
    struct VirtualTransaction {
        euint256 txId;            // Encrypted transaction ID
        address from;             // Sender (public for auditing)
        address to;               // Recipient (public)
        euint256 value;           // Encrypted value
        euint256 gasUsed;         // Encrypted gas used
        bytes data;               // Data payload (can be encrypted off-chain)
        bytes32 dataHash;         // Hash of data for verification
        euint64 blockNumber;      // Block where transaction is included
        ebool isIncluded;         // Encrypted inclusion status
    }

    // ============ State Variables ============
    
    string public chainName;
    uint256 public initialGasLimit;
    bool public initialized;
    
    // Block and transaction storage
    mapping(uint64 => VirtualBlock) public virtualBlocks;
    mapping(uint256 => VirtualTransaction) public virtualTransactions;
    
    // Block and transaction counters
    uint64 private nextBlockNumber;
    uint256 private nextTxId;
    
    // Validator management
    mapping(address => bool) public validators;
    address[] public validatorList;
    
    // Stylus integration
    IEVVMStylus public stylusEngine;
    
    // ============ Events ============
    
    event VirtualChainInitialized(string chainName, uint256 timestamp, uint256 initialGasLimit);
    event VirtualBlockCreated(uint64 indexed blockNumber, address indexed validator, bytes32 blockHash);
    event TransactionSubmitted(uint256 indexed txId, address indexed from, address indexed to);
    event BlockFinalized(uint64 indexed blockNumber, uint256 finalizationTimestamp);
    event ValidatorAdded(address indexed validator, address indexed by);
    event ValidatorRemoved(address indexed validator, address indexed by);
    event StylusEngineSet(address indexed engine);

    // ============ Modifiers ============
    
    modifier onlyValidator() {
        require(validators[msg.sender], "Not a validator");
        _;
    }
    
    modifier onlyInitialized() {
        require(initialized, "Not initialized");
        _;
    }

    // ============ Constructor ============
    
    constructor() Ownable(msg.sender) {
        // Constructor is empty - initialization happens via initializeVirtualChain
    }

    // ============ Initialization ============
    
    /// @notice Initialize the virtual blockchain
    /// @param _chainName Name of the virtual chain
    /// @param _initialGasLimit Initial gas limit for blocks
    function initializeVirtualChain(
        string memory _chainName,
        uint256 _initialGasLimit
    ) external onlyOwner {
        require(!initialized, "Already initialized");
        require(_initialGasLimit > 0, "Invalid gas limit");
        
        chainName = _chainName;
        initialGasLimit = _initialGasLimit;
        initialized = true;
        nextBlockNumber = 1;
        nextTxId = 1;
        
        emit VirtualChainInitialized(_chainName, block.timestamp, _initialGasLimit);
    }

    // ============ Validator Management ============
    
    /// @notice Add a validator to the validator set
    /// @param validator Address of the validator to add
    function addValidator(address validator) external onlyOwner {
        require(validator != address(0), "Invalid validator");
        require(!validators[validator], "Already a validator");
        
        validators[validator] = true;
        validatorList.push(validator);
        
        emit ValidatorAdded(validator, msg.sender);
    }
    
    /// @notice Remove a validator from the validator set
    /// @param validator Address of the validator to remove
    function removeValidator(address validator) external onlyOwner {
        require(validators[validator], "Not a validator");
        
        validators[validator] = false;
        
        // Remove from array (simplified - in production use more efficient method)
        for (uint256 i = 0; i < validatorList.length; i++) {
            if (validatorList[i] == validator) {
                validatorList[i] = validatorList[validatorList.length - 1];
                validatorList.pop();
                break;
            }
        }
        
        emit ValidatorRemoved(validator, msg.sender);
    }

    // ============ Block Operations ============
    
    /// @notice Create a new virtual block (FHE encrypted)
    /// @param inputGasLimit Encrypted gas limit for the block
    /// @param inputProof Proof for the encrypted gas limit
    /// @param _validators Array of validators for this block
    /// @return blockNumber The number of the created block
    function createVirtualBlock(
        externalEuint256 inputGasLimit,
        bytes calldata inputProof,
        address[] calldata _validators
    ) external onlyValidator onlyInitialized returns (uint64 blockNumber) {
        // Validate validators
        for (uint256 i = 0; i < _validators.length; i++) {
            require(validators[_validators[i]], "Invalid validator");
        }
        
        // Convert external encrypted input to internal euint256
        euint256 encryptedGasLimit = FHE.fromExternal(inputGasLimit, inputProof);
        
        // Create encrypted timestamp
        euint256 encryptedTimestamp = FHE.asEuint256(block.timestamp);
        
        // Create new block
        blockNumber = nextBlockNumber;
        nextBlockNumber++;
        
        // Compute block hash (using transaction hashes if available)
        bytes32 blockHash = computeBlockHash(blockNumber);
        
        VirtualBlock storage virtualBlock = virtualBlocks[blockNumber];
        virtualBlock.blockNumber = FHE.asEuint64(blockNumber);
        virtualBlock.timestamp = encryptedTimestamp;
        virtualBlock.gasLimit = encryptedGasLimit;
        virtualBlock.validators = _validators;
        virtualBlock.isFinalized = FHE.asEbool(false);
        virtualBlock.blockHash = blockHash;
        
        // Allow validators to decrypt block info
        FHE.allowThis(virtualBlock.blockNumber);
        FHE.allowThis(virtualBlock.timestamp);
        FHE.allowThis(virtualBlock.gasLimit);
        FHE.allowThis(virtualBlock.isFinalized);
        
        emit VirtualBlockCreated(blockNumber, msg.sender, blockHash);
        
        return blockNumber;
    }
    
    /// @notice Finalize a block (consensus)
    /// @param _blockNumber Block number to finalize
    function finalizeBlock(uint64 _blockNumber) external onlyValidator onlyInitialized {
        VirtualBlock storage virtualBlock = virtualBlocks[_blockNumber];
        
        // Verify block exists
        require(_blockNumber > 0 && _blockNumber < nextBlockNumber, "Invalid block");
        
        // Mark as finalized
        virtualBlock.isFinalized = FHE.asEbool(true);
        FHE.allowThis(virtualBlock.isFinalized);
        
        // Use Solidity block.timestamp for event (not encrypted timestamp)
        emit BlockFinalized(_blockNumber, block.timestamp);
    }
    
    /// @notice Finalize block with signature validation using Stylus
    /// @param _blockNumber Block number to finalize
    /// @param txHashes Array of transaction hashes in the block
    /// @param validatorSignatures Array of validator signatures
    function finalizeBlockWithValidation(
        uint64 _blockNumber,
        bytes32[] calldata txHashes,
        bytes[] calldata validatorSignatures
    ) external onlyValidator onlyInitialized {
        require(address(stylusEngine) != address(0), "Stylus engine not set");
        
        // Compute block hash using Stylus
        bytes32 computedHash = stylusEngine.computeBlockHash(txHashes);
        
        // Validate signatures using Stylus
        require(
            stylusEngine.validateSignatures(validatorSignatures, computedHash),
            "Invalid signatures"
        );
        
        // Update block hash
        VirtualBlock storage virtualBlock = virtualBlocks[_blockNumber];
        virtualBlock.blockHash = computedHash;
        
        // Mark as finalized
        virtualBlock.isFinalized = FHE.asEbool(true);
        FHE.allowThis(virtualBlock.isFinalized);
        
        // Use Solidity block.timestamp for event (not encrypted timestamp)
        emit BlockFinalized(_blockNumber, block.timestamp);
    }

    // ============ Transaction Operations ============
    
    /// @notice Submit an encrypted transaction
    /// @param to Recipient address
    /// @param inputEncryptedValue Encrypted value to send
    /// @param inputValueProof Proof for encrypted value
    /// @param data Data payload (can be encrypted off-chain before submission)
    /// @return txId The transaction ID
    function submitTransaction(
        address to,
        externalEuint256 inputEncryptedValue,
        bytes calldata inputValueProof,
        bytes calldata data
    ) external onlyInitialized returns (uint256 txId) {
        require(to != address(0), "Invalid recipient");
        
        // Convert external encrypted input to internal type
        euint256 encryptedValue = FHE.fromExternal(inputEncryptedValue, inputValueProof);
        
        // Create transaction
        txId = nextTxId;
        nextTxId++;
        
        VirtualTransaction storage transaction = virtualTransactions[txId];
        transaction.txId = FHE.asEuint256(txId);
        transaction.from = msg.sender;
        transaction.to = to;
        transaction.value = encryptedValue;
        transaction.data = data;
        transaction.dataHash = keccak256(data);
        transaction.gasUsed = FHE.asEuint256(0); // Will be updated when included in block
        transaction.isIncluded = FHE.asEbool(false);
        
        // Allow sender and recipient to decrypt transaction value
        FHE.allowThis(transaction.txId);
        FHE.allowThis(transaction.value);
        FHE.allow(transaction.txId, msg.sender);
        FHE.allow(transaction.value, msg.sender);
        FHE.allow(transaction.value, to);
        
        emit TransactionSubmitted(txId, msg.sender, to);
        
        return txId;
    }
    
    /// @notice Include a transaction in a block
    /// @param txId Transaction ID to include
    /// @param blockNumber Block number to include transaction in
    /// @param inputGasUsed Encrypted gas used for the transaction
    /// @param inputGasProof Proof for encrypted gas used
    function includeTransactionInBlock(
        uint256 txId,
        uint64 blockNumber,
        externalEuint256 inputGasUsed,
        bytes calldata inputGasProof
    ) external onlyValidator onlyInitialized {
        require(txId > 0 && txId < nextTxId, "Invalid transaction");
        require(blockNumber > 0 && blockNumber < nextBlockNumber, "Invalid block");
        
        VirtualTransaction storage transaction = virtualTransactions[txId];
        
        // Convert and set gas used
        euint256 encryptedGasUsed = FHE.fromExternal(inputGasUsed, inputGasProof);
        transaction.gasUsed = encryptedGasUsed;
        transaction.blockNumber = FHE.asEuint64(blockNumber);
        transaction.isIncluded = FHE.asEbool(true);
        
        // Allow access to gas used
        FHE.allowThis(transaction.gasUsed);
        FHE.allowThis(transaction.isIncluded);
        FHE.allow(transaction.gasUsed, transaction.from);
    }

    // ============ View Functions ============
    
    /// @notice Get block information (returns encrypted data)
    /// @param blockNumber Block number to query
    /// @return block The virtual block structure
    function getBlockInfo(
        uint64 blockNumber
    ) external view onlyInitialized returns (VirtualBlock memory) {
        require(blockNumber > 0 && blockNumber < nextBlockNumber, "Invalid block");
        return virtualBlocks[blockNumber];
    }
    
    /// @notice Get transaction information
    /// @param txId Transaction ID to query
    /// @return tx The virtual transaction structure
    function getTransaction(
        uint256 txId
    ) external view onlyInitialized returns (VirtualTransaction memory) {
        require(txId > 0 && txId < nextTxId, "Invalid transaction");
        return virtualTransactions[txId];
    }
    
    /// @notice Verify if a transaction is included in a block
    /// @param txId Transaction ID to verify
    /// @param blockNumber Block number to check
    /// @return isIncluded Encrypted boolean indicating inclusion status
    function verifyTransaction(
        uint256 txId,
        uint64 blockNumber
    ) external onlyInitialized returns (ebool isIncluded) {
        require(txId > 0 && txId < nextTxId, "Invalid transaction");
        require(blockNumber > 0 && blockNumber < nextBlockNumber, "Invalid block");
        
        VirtualTransaction storage transaction = virtualTransactions[txId];
        
        // Check if transaction is in the specified block
        // Compare encrypted block numbers directly
        euint64 targetBlockNum = FHE.asEuint64(blockNumber);
        ebool sameBlock = FHE.eq(transaction.blockNumber, targetBlockNum);
        isIncluded = FHE.and(sameBlock, transaction.isIncluded);
        
        // Allow caller to decrypt result
        FHE.allowThis(isIncluded);
        FHE.allow(isIncluded, msg.sender);
        
        return isIncluded;
    }
    
    /// @notice Get the current block number
    /// @return Current block number
    function getCurrentBlockNumber() external view returns (uint64) {
        return nextBlockNumber - 1;
    }
    
    /// @notice Get the next transaction ID
    /// @return Next transaction ID
    function getNextTxId() external view returns (uint256) {
        return nextTxId;
    }
    
    /// @notice Get all validators
    /// @return Array of validator addresses
    function getValidators() external view returns (address[] memory) {
        return validatorList;
    }

    // ============ Stylus Integration ============
    
    /// @notice Set the Stylus engine address for high-performance computations
    /// @param _stylusEngine Address of the Stylus contract
    function setStylusEngine(address _stylusEngine) external onlyOwner {
        require(_stylusEngine != address(0), "Invalid address");
        stylusEngine = IEVVMStylus(_stylusEngine);
        emit StylusEngineSet(_stylusEngine);
    }

    // ============ Internal Functions ============
    
    /// @notice Compute block hash (simplified version)
    /// @param blockNumber Block number
    /// @return blockHash Computed block hash
    function computeBlockHash(uint64 blockNumber) internal view returns (bytes32) {
        // Simplified hash computation
        // In production, this should use Merkle root of transactions
        return keccak256(abi.encodePacked(chainName, blockNumber, block.timestamp));
    }
}

