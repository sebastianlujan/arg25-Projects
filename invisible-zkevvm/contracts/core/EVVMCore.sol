// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {FHE, euint8, euint64, euint256, ebool, InEuint64, InEuint256} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEVVMStylus.sol";
import "../library/SignatureUtils.sol";

/// @title EVVM Core - Virtual Blockchain with FHE
/// @notice Main contract for the Ethereum Virtual Virtual Machine
/// @dev Implements a virtual blockchain with encrypted blocks and transactions using Fhenix CoFHE
/// @dev Follows CoFHE best practices: encrypted constants, proper access control, constant-time computation
contract EVVMCore is Ownable {
    // ============ Structs ============
    
    /// @notice EVVM metadata structure
    struct EvvmMetadata {
        string evvmName;
        uint256 evvmID;
        string principalTokenName;
        string principalTokenSymbol;
        address principalTokenAddress;
        euint64 totalSupply;      // Encrypted total supply (euint64 for operations)
        euint64 eraTokens;        // Encrypted era tokens threshold (euint64 for operations)
        euint64 reward;           // Encrypted reward amount (euint64 for operations)
    }
    
    /// @notice Address proposal with time delay
    struct AddressTypeProposal {
        address current;
        address proposal;
        uint256 timeToAccept;
    }
    
    /// @notice Disperse payment metadata
    struct DispersePayMetadata {
        uint256 amount;
        address to_address;
        string to_identity;
    }
    
    /// @notice Payment parameters structure to reduce stack depth
    struct PaymentParams {
        address from;
        address to;
        string toIdentity;
        address token;
        uint256 amountPlaintext;
        InEuint64 inputEncryptedAmount;
        uint256 priorityFeePlaintext;
        InEuint64 inputEncryptedPriorityFee;
        uint256 nonce;
        bool priorityFlag;
        address executor;
        bytes signature;
    }
    
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
    
    // EVVM metadata
    uint256 public evvmID;
    uint256 public windowTimeToChangeEvvmID;
    
    // Balance management (encrypted)
    mapping(address => mapping(address => euint64)) public balances; // user -> token -> encrypted balance (euint64 for operations)
    
    // Nonce management
    mapping(address => uint256) public nextSyncUsedNonce;
    mapping(address => mapping(uint256 => bool)) public asyncUsedNonce;
    
    // Staker management
    mapping(address => bool) public stakerList;
    bytes1 private constant FLAG_IS_STAKER = 0x01;
    
    // Token whitelist management
    mapping(address => bool) public tokenWhitelist;
    bool public whitelistEnabled;
    
    // Signature verification settings
    bool public signatureVerificationRequired;
    
    // Proxy pattern
    address public currentImplementation;
    address public proposalImplementation;
    uint256 public timeToAcceptImplementation;
    
    // Treasury and Staking integration
    address public treasuryAddress;
    address public stakingContractAddress;
    
    // EVVM metadata
    EvvmMetadata public evvmMetadata;
    AddressTypeProposal public admin;
    
    // Encrypted constants for gas optimization (CoFHE best practice)
    euint64 private EUINT64_ZERO;
    euint64 private EUINT64_ONE;
    euint256 private EUINT256_ZERO;
    ebool private EBOOL_FALSE;
    ebool private EBOOL_TRUE;
    
    // ============ Events ============
    
    event VirtualChainInitialized(string chainName, uint256 timestamp, uint256 initialGasLimit);
    event VirtualBlockCreated(uint64 indexed blockNumber, address indexed validator, bytes32 blockHash);
    event TransactionSubmitted(uint256 indexed txId, address indexed from, address indexed to);
    event BlockFinalized(uint64 indexed blockNumber, uint256 finalizationTimestamp);
    event ValidatorAdded(address indexed validator, address indexed by);
    event ValidatorRemoved(address indexed validator, address indexed by);
    event StylusEngineSet(address indexed engine);
    event PaymentProcessed(address indexed from, address indexed to, address indexed token);
    event EvvmIDUpdated(uint256 newEvvmID);
    event AmountAddedToUser(address indexed user, address indexed token);
    event AmountRemovedFromUser(address indexed user, address indexed token);
    event RewardGiven(address indexed user); // Amount is encrypted in balance
    event ImplementationProposed(address indexed newImpl, uint256 timeToAccept);
    event AdminProposed(address indexed newAdmin, uint256 timeToAccept);
    event TokenAddedToWhitelist(address indexed token);
    event TokenRemovedFromWhitelist(address indexed token);
    event WhitelistEnabled(bool enabled);
    event SignatureVerificationRequired(bool required);

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
        // Initialize encrypted constants once in constructor to save gas (CoFHE best practice)
        EUINT64_ZERO = FHE.asEuint64(0);
        EUINT64_ONE = FHE.asEuint64(1);
        EUINT256_ZERO = FHE.asEuint256(0);
        EBOOL_FALSE = FHE.asEbool(false);
        EBOOL_TRUE = FHE.asEbool(true);
        
        windowTimeToChangeEvvmID = block.timestamp + 1 days;
        admin.current = msg.sender; // Initialize admin
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
    /// @param inputGasLimit Encrypted gas limit for the block (InEuint256)
    /// @param _validators Array of validators for this block
    /// @return blockNumber The number of the created block
    function createVirtualBlock(
        InEuint256 memory inputGasLimit,
        address[] calldata _validators
    ) external onlyValidator onlyInitialized returns (uint64 blockNumber) {
        // Validate validators
        for (uint256 i = 0; i < _validators.length; i++) {
            require(validators[_validators[i]], "Invalid validator");
        }
        
        // Convert encrypted input to internal euint256
        euint256 encryptedGasLimit = FHE.asEuint256(inputGasLimit);
        
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
        virtualBlock.isFinalized = EBOOL_FALSE;
        virtualBlock.blockHash = blockHash;
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
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
    /// @param inputEncryptedValue Encrypted value to send (InEuint256)
    /// @param data Data payload (can be encrypted off-chain before submission)
    /// @return txId The transaction ID
    function submitTransaction(
        address to,
        InEuint256 memory inputEncryptedValue,
        bytes calldata data
    ) external onlyInitialized returns (uint256 txId) {
        require(to != address(0), "Invalid recipient");
        
        // Convert encrypted input to internal type
        euint256 encryptedValue = FHE.asEuint256(inputEncryptedValue);
        
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
        transaction.gasUsed = EUINT256_ZERO; // Will be updated when included in block
        transaction.isIncluded = EBOOL_FALSE;
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(transaction.txId);
        FHE.allowThis(transaction.value);
        FHE.allowSender(transaction.txId);
        FHE.allowSender(transaction.value);
        FHE.allow(transaction.value, to);
        
        emit TransactionSubmitted(txId, msg.sender, to);
        
        return txId;
    }
    
    /// @notice Include a transaction in a block
    /// @param txId Transaction ID to include
    /// @param blockNumber Block number to include transaction in
    /// @param inputGasUsed Encrypted gas used for the transaction (InEuint256)
    function includeTransactionInBlock(
        uint256 txId,
        uint64 blockNumber,
        InEuint256 memory inputGasUsed
    ) external onlyValidator onlyInitialized {
        require(txId > 0 && txId < nextTxId, "Invalid transaction");
        require(blockNumber > 0 && blockNumber < nextBlockNumber, "Invalid block");
        
        VirtualTransaction storage transaction = virtualTransactions[txId];
        
        // Convert and set gas used
        euint256 encryptedGasUsed = FHE.asEuint256(inputGasUsed);
        transaction.gasUsed = encryptedGasUsed;
        transaction.blockNumber = FHE.asEuint64(blockNumber);
        transaction.isIncluded = EBOOL_TRUE;
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(transaction.gasUsed);
        FHE.allowThis(transaction.isIncluded);
        FHE.allowSender(transaction.gasUsed);
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
    
    /// @notice Get EVVM metadata
    /// @return Complete metadata structure
    function getEvvmMetadata() external view returns (EvvmMetadata memory) {
        return evvmMetadata;
    }
    
    /// @notice Get balance (encrypted)
    /// @param user User address
    /// @param token Token address
    /// @return Encrypted balance (euint64)
    function getBalance(address user, address token) external view returns (euint64) {
        return balances[user][token];
    }
    
    /// @notice Check if address is staker
    /// @param user User address
    /// @return True if staker
    function isAddressStaker(address user) external view returns (bool) {
        return stakerList[user];
    }
    
    /// @notice Get next sync nonce
    /// @param user User address
    /// @return Next sync nonce
    function getNextCurrentSyncNonce(address user) external view returns (uint256) {
        return nextSyncUsedNonce[user];
    }
    
    /// @notice Check if async nonce is used
    /// @param user User address
    /// @param nonce Nonce to check
    /// @return True if used
    function getIfUsedAsyncNonce(address user, uint256 nonce) external view returns (bool) {
        return asyncUsedNonce[user][nonce];
    }
    
    /// @notice Get reward amount (encrypted)
    /// @return Encrypted reward amount (euint64) - decrypt with SDK
    function getRewardAmount() external view returns (euint64) {
        return evvmMetadata.reward;
    }
    
    /// @notice Get era tokens threshold (encrypted)
    /// @return Encrypted era tokens threshold (euint64) - decrypt with SDK
    function getEraPrincipalToken() external view returns (euint64) {
        return evvmMetadata.eraTokens;
    }
    
    /// @notice Get principal token total supply (encrypted)
    /// @return Encrypted total supply (euint64) - decrypt with SDK
    function getPrincipalTokenTotalSupply() external view returns (euint64) {
        return evvmMetadata.totalSupply;
    }
    
    /// @notice Get staking contract address
    /// @return Staking contract address
    function getStakingContractAddress() external view returns (address) {
        return stakingContractAddress;
    }
    
    /// @notice Get treasury address
    /// @return Treasury address
    function getTreasuryAddress() external view returns (address) {
        return treasuryAddress;
    }
    
    /// @notice Get current admin
    /// @return Current admin address
    function getCurrentAdmin() external view returns (address) {
        return admin.current;
    }
    
    /// @notice Get proposed admin
    /// @return Proposed admin address
    function getProposalAdmin() external view returns (address) {
        return admin.proposal;
    }
    
    /// @notice Get time to accept admin
    /// @return Timestamp when admin can be accepted
    function getTimeToAcceptAdmin() external view returns (uint256) {
        return admin.timeToAccept;
    }
    
    /// @notice Get proposed implementation
    /// @return Proposed implementation address
    function getProposalImplementation() external view returns (address) {
        return proposalImplementation;
    }
    
    /// @notice Get time to accept implementation
    /// @return Timestamp when implementation can be accepted
    function getTimeToAcceptImplementation() external view returns (uint256) {
        return timeToAcceptImplementation;
    }

    // ============ Stylus Integration ============
    
    /// @notice Set the Stylus engine address for high-performance computations
    /// @param _stylusEngine Address of the Stylus contract
    function setStylusEngine(address _stylusEngine) external onlyOwner {
        require(_stylusEngine != address(0), "Invalid address");
        stylusEngine = IEVVMStylus(_stylusEngine);
        emit StylusEngineSet(_stylusEngine);
    }
    
    /// @notice Set treasury address
    /// @param _treasuryAddress Treasury contract address
    function setTreasuryAddress(address _treasuryAddress) external onlyOwner {
        treasuryAddress = _treasuryAddress;
    }
    
    /// @notice Set staking contract address
    /// @param _stakingContractAddress Staking contract address
    function setStakingContractAddress(address _stakingContractAddress) external onlyOwner {
        stakingContractAddress = _stakingContractAddress;
    }
    
    /// @notice Set EVVM metadata
    /// @param _evvmMetadata Metadata structure (with encrypted fields)
    function setEvvmMetadata(EvvmMetadata memory _evvmMetadata) external onlyOwner {
        evvmMetadata = _evvmMetadata;
    }
    
    /// @notice Initialize encrypted metadata fields
    /// @param _totalSupply Encrypted total supply (InEuint64)
    /// @param _eraTokens Encrypted era tokens (InEuint64)
    /// @param _reward Encrypted reward amount (InEuint64)
    /// @dev CoFHE handles proof verification internally
    function initializeEncryptedMetadata(
        InEuint64 memory _totalSupply,
        InEuint64 memory _eraTokens,
        InEuint64 memory _reward
    ) external onlyOwner {
        evvmMetadata.totalSupply = FHE.asEuint64(_totalSupply);
        evvmMetadata.eraTokens = FHE.asEuint64(_eraTokens);
        evvmMetadata.reward = FHE.asEuint64(_reward);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(evvmMetadata.totalSupply);
        FHE.allowThis(evvmMetadata.eraTokens);
        FHE.allowThis(evvmMetadata.reward);
    }

    // ============ EVVM ID Management ============
    
    /// @notice Updates the EVVM ID with a new value (time-limited)
    /// @param newEvvmID New EVVM ID value
    function setEvvmID(uint256 newEvvmID) external onlyOwner {
        if (newEvvmID == 0) {
            require(block.timestamp <= windowTimeToChangeEvvmID, "Window expired");
        }
        
        evvmID = newEvvmID;
        windowTimeToChangeEvvmID = block.timestamp + 1 days;
        
        emit EvvmIDUpdated(newEvvmID);
    }

    // ============ Payment Functions ============
    
    /// @notice Process a payment with encrypted amount and optional signature verification
    /// @param params Payment parameters struct containing all payment data
    /// @dev WARNING: If signatureVerificationRequired is true, amountPlaintext and priorityFeePlaintext
    ///      will be visible in transaction calldata, breaking privacy. Consider using payWithCommitment()
    ///      for private payments when signature verification is required.
    function pay(PaymentParams memory params) external onlyInitialized {
        require(params.from != address(0), "Invalid sender");
        require(params.to != address(0) || bytes(params.toIdentity).length > 0, "Invalid recipient");
        
        // Verify token whitelist if enabled
        if (whitelistEnabled) {
            require(tokenWhitelist[params.token], "Token not whitelisted");
        }
        
        // Verify signature if required
        if (signatureVerificationRequired) {
            require(params.signature.length > 0, "Signature required");
            uint256 nonceForSignature = params.priorityFlag ? params.nonce : nextSyncUsedNonce[params.from];
            require(
                SignatureUtils.verifyMessageSignedForPay(
                    evvmID,
                    params.from,
                    params.to,
                    params.toIdentity,
                    params.token,
                    params.amountPlaintext,
                    params.priorityFeePlaintext,
                    nonceForSignature,
                    params.priorityFlag,
                    params.executor,
                    params.signature
                ),
                "Invalid signature"
            );
        }
        
        // Verify executor if specified
        if (params.executor != address(0)) {
            require(msg.sender == params.executor, "Not the executor");
        }
        
        // Convert encrypted inputs (CoFHE handles proof verification internally)
        euint64 encryptedAmount = FHE.asEuint64(params.inputEncryptedAmount);
        euint64 encryptedPriorityFee = FHE.asEuint64(params.inputEncryptedPriorityFee);
        
        // Verify nonce
        if (params.priorityFlag) {
            require(!asyncUsedNonce[params.from][params.nonce], "Nonce already used");
            asyncUsedNonce[params.from][params.nonce] = true;
        } else {
            require(params.nonce == nextSyncUsedNonce[params.from], "Invalid nonce");
            nextSyncUsedNonce[params.from]++;
        }
        
        // Update balances (encrypted operations)
        balances[params.from][params.token] = FHE.sub(balances[params.from][params.token], encryptedAmount);
        balances[params.to][params.token] = FHE.add(balances[params.to][params.token], encryptedAmount);
        
        // Handle priority fee if staker
        if (stakerList[msg.sender]) {
            balances[params.from][params.token] = FHE.sub(balances[params.from][params.token], encryptedPriorityFee);
            balances[msg.sender][params.token] = FHE.add(balances[msg.sender][params.token], encryptedPriorityFee);
            _giveReward(msg.sender, 1);
        }
        
        // Allow parties to decrypt their balances
        FHE.allowThis(balances[params.from][params.token]);
        FHE.allow(balances[params.from][params.token], params.from);
        FHE.allowThis(balances[params.to][params.token]);
        FHE.allow(balances[params.to][params.token], params.to);
        
        emit PaymentProcessed(params.from, params.to, params.token);
    }

    // ============ Treasury Exclusive Functions ============
    
    /// @notice Adds encrypted tokens to a user's balance (Treasury only)
    /// @param user User address
    /// @param token Token address
    /// @param inputEncryptedAmount Encrypted amount to add (InEuint64)
    /// @dev CoFHE handles proof verification internally
    function addAmountToUser(
        address user,
        address token,
        InEuint64 memory inputEncryptedAmount
    ) external {
        require(msg.sender == treasuryAddress, "Not treasury");
        
        euint64 encryptedAmount = FHE.asEuint64(inputEncryptedAmount);
        balances[user][token] = FHE.add(balances[user][token], encryptedAmount);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(balances[user][token]);
        FHE.allow(balances[user][token], user);
        
        emit AmountAddedToUser(user, token);
    }
    
    /// @notice Removes encrypted tokens from a user's balance (Treasury only)
    /// @param user User address
    /// @param token Token address
    /// @param inputEncryptedAmount Encrypted amount to remove (InEuint64)
    /// @dev CoFHE handles proof verification internally
    function removeAmountFromUser(
        address user,
        address token,
        InEuint64 memory inputEncryptedAmount
    ) external {
        require(msg.sender == treasuryAddress, "Not treasury");
        
        euint64 encryptedAmount = FHE.asEuint64(inputEncryptedAmount);
        balances[user][token] = FHE.sub(balances[user][token], encryptedAmount);
        
        // Always update permissions after modifying encrypted values (CoFHE best practice)
        FHE.allowThis(balances[user][token]);
        FHE.allow(balances[user][token], user);
        
        emit AmountRemovedFromUser(user, token);
    }

    // ============ Internal Functions ============
    
    /// @notice Internal function to update balances (encrypted)
    /// @param from Sender address
    /// @param to Recipient address
    /// @param token Token address
    /// @param encryptedValue Encrypted amount (euint64)
    /// @return success True if successful
    function _updateBalance(
        address from,
        address to,
        address token,
        euint64 encryptedValue
    ) internal returns (bool) {
        // Note: Balance validation requires external decryption
        balances[from][token] = FHE.sub(balances[from][token], encryptedValue);
        balances[to][token] = FHE.add(balances[to][token], encryptedValue);
        
        FHE.allowThis(balances[from][token]);
        FHE.allow(balances[from][token], from);
        FHE.allowThis(balances[to][token]);
        FHE.allow(balances[to][token], to);
        
        return true;
    }
    
    /// @notice Internal function to give rewards (encrypted)
    /// @param user Staker address
    /// @param amount Number of transactions (encrypted)
    /// @return success True if successful
    function _giveReward(address user, uint256 amount) internal returns (bool) {
        require(evvmMetadata.principalTokenAddress != address(0), "No principal token");
        
        // Calculate reward using encrypted reward amount
        // reward * amount (both encrypted operations)
        euint64 encryptedAmount = FHE.asEuint64(uint64(amount));
        euint64 encryptedReward = FHE.mul(evvmMetadata.reward, encryptedAmount);
        
        // Add encrypted reward to balance
        balances[user][evvmMetadata.principalTokenAddress] = 
            FHE.add(balances[user][evvmMetadata.principalTokenAddress], encryptedReward);
        
        FHE.allowThis(balances[user][evvmMetadata.principalTokenAddress]);
        FHE.allow(balances[user][evvmMetadata.principalTokenAddress], user);
        
        // Event without exposing amount (can be decrypted from balance)
        emit RewardGiven(user);
        return true;
    }

    // ============ Proxy Management Functions ============
    
    /// @notice Proposes a new implementation (30-day delay)
    /// @param _newImpl New implementation address
    function proposeImplementation(address _newImpl) external onlyOwner {
        proposalImplementation = _newImpl;
        timeToAcceptImplementation = block.timestamp + 30 days;
        emit ImplementationProposed(_newImpl, timeToAcceptImplementation);
    }
    
    /// @notice Rejects pending implementation proposal
    function rejectUpgrade() external onlyOwner {
        proposalImplementation = address(0);
        timeToAcceptImplementation = 0;
    }
    
    /// @notice Accepts implementation after time delay
    function acceptImplementation() external onlyOwner {
        require(block.timestamp >= timeToAcceptImplementation, "Time not elapsed");
        require(proposalImplementation != address(0), "No proposal");
        
        currentImplementation = proposalImplementation;
        proposalImplementation = address(0);
        timeToAcceptImplementation = 0;
    }

    // ============ Admin Management Functions ============
    
    /// @notice Proposes new admin (1-day delay)
    /// @param _newOwner New admin address
    function proposeAdmin(address _newOwner) external onlyOwner {
        require(_newOwner != address(0) && _newOwner != admin.current, "Invalid admin");
        
        admin.proposal = _newOwner;
        admin.timeToAccept = block.timestamp + 1 days;
        emit AdminProposed(_newOwner, admin.timeToAccept);
    }
    
    /// @notice Rejects pending admin proposal
    function rejectProposalAdmin() external onlyOwner {
        admin.proposal = address(0);
        admin.timeToAccept = 0;
    }
    
    /// @notice Accepts admin proposal (called by proposed admin)
    function acceptAdmin() external {
        require(block.timestamp >= admin.timeToAccept, "Time not elapsed");
        require(msg.sender == admin.proposal, "Not proposed admin");
        
        admin.current = admin.proposal;
        admin.proposal = address(0);
        admin.timeToAccept = 0;
    }

    // ============ Reward System Functions ============
    
    /// @notice Recalculates reward and triggers era transition
    /// @dev Note: Era transition comparison requires external decryption.
    ///      For MVP, we maintain encrypted storage but use public verification.
    ///      The encrypted values are updated after public calculation.
    function recalculateReward() external {
        // Note: For era transition, we need to compare encrypted values.
        // Since FHE comparison results are encrypted (ebool), we need external decryption.
        // For MVP: Store a public flag or require external verification.
        // Here we'll use a simplified approach: store encrypted but verify externally.
        
        // Give random bonus to caller (1-5083x reward) - encrypted
        uint256 randomMultiplier = getRandom(1, 5083);
        euint64 encryptedMultiplier = FHE.asEuint64(uint64(randomMultiplier));
        euint64 encryptedBonus = FHE.mul(evvmMetadata.reward, encryptedMultiplier);
        
        balances[msg.sender][evvmMetadata.principalTokenAddress] = 
            FHE.add(balances[msg.sender][evvmMetadata.principalTokenAddress], encryptedBonus);
        
        FHE.allowThis(balances[msg.sender][evvmMetadata.principalTokenAddress]);
        FHE.allow(balances[msg.sender][evvmMetadata.principalTokenAddress], msg.sender);
        
        // Note: Era transition and reward halving require encrypted division.
        // Since FHE.div is not available for euint64, we'll handle this externally
        // or use a hybrid approach where calculation is public but storage is encrypted.
        // For now, these operations are handled via setEvvmMetadata by admin after external calculation.
    }
    
    /// @notice Generates pseudo-random number
    /// @param min Minimum value
    /// @param max Maximum value
    /// @return Random number
    function getRandom(uint256 min, uint256 max) internal view returns (uint256) {
        return min + (uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % (max - min + 1));
    }

    // ============ Staking Integration Functions ============
    
    /// @notice Updates staker status (Staking contract only)
    /// @param user User address
    /// @param answer Staker flag
    function pointStaker(address user, bytes1 answer) external {
        require(msg.sender == stakingContractAddress, "Not staking contract");
        stakerList[user] = (answer == FLAG_IS_STAKER);
    }

    // ============ Token Whitelist Management ============
    
    /// @notice Add a token to the whitelist
    /// @param token Token address to add (address(0) for ETH is allowed)
    function addTokenToWhitelist(address token) external onlyOwner {
        require(!tokenWhitelist[token], "Token already whitelisted");
        
        tokenWhitelist[token] = true;
        emit TokenAddedToWhitelist(token);
    }
    
    /// @notice Remove a token from the whitelist
    /// @param token Token address to remove
    function removeTokenFromWhitelist(address token) external onlyOwner {
        require(tokenWhitelist[token], "Token not whitelisted");
        
        tokenWhitelist[token] = false;
        emit TokenRemovedFromWhitelist(token);
    }
    
    /// @notice Enable or disable the token whitelist
    /// @param enabled True to enable whitelist, false to disable
    function setWhitelistEnabled(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
        emit WhitelistEnabled(enabled);
    }
    
    /// @notice Check if a token is whitelisted
    /// @param token Token address to check
    /// @return True if token is whitelisted or whitelist is disabled
    function isTokenWhitelisted(address token) external view returns (bool) {
        return !whitelistEnabled || tokenWhitelist[token];
    }
    
    /// @notice Enable or disable signature verification requirement
    /// @param required True to require signatures, false to make them optional
    /// @dev WARNING: When signature verification is required, amountPlaintext and priorityFeePlaintext
    ///      must be provided in calldata, which breaks privacy. For maximum privacy, set this to false
    ///      and rely on encrypted amounts only.
    function setSignatureVerificationRequired(bool required) external onlyOwner {
        signatureVerificationRequired = required;
        emit SignatureVerificationRequired(required);
    }

    // ============ Proxy Pattern ============
    
    /// @notice Fallback function for proxy pattern
    fallback() external {
        if (currentImplementation == address(0)) revert("No implementation");
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            
            let result := delegatecall(
                gas(),
                sload(currentImplementation.slot),
                0,
                calldatasize(),
                0,
                0
            )
            
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
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

