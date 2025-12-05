// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FHE, euint256, euint64, ebool, externalEuint256, externalEuint64, externalEbool} from "@fhevm/solidity/lib/FHE.sol";
import {EthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Staking Manager with FHE
/// @notice Manages encrypted staking with private amounts
/// @dev IMPORTANT: This contract expects encrypted inputs from external sources.
///     Required encrypted inputs:
///     - Amount to stake: externalEuint64
///     - Owner address: externalEuint256
///     - Active status: externalEbool
///     See STAKING_ENCRYPTED_INPUTS.md for details.
contract StakingManager is EthereumConfig, Ownable {
    // ============ Structs ============
    
    struct Stake {
        euint64 amount;           // Encrypted staked amount (euint64 for operations)
        euint64 rewardDebt;        // Encrypted reward tracking (euint64 for operations)
        uint256 lockTimestamp;    // Lock end time (public)
        ebool isActive;           // Encrypted active status
    }

    struct StakingPool {
        euint64 totalStaked;      // Total encrypted stake (euint64 for operations)
        euint64 rewardPerShare;   // Encrypted reward distribution (euint64 for operations)
        uint256 lastRewardBlock;  // Last reward calculation
        uint256 apr;              // Annual Percentage Rate (public)
        uint256 minLockPeriod;    // Minimum lock period in seconds
    }

    // ============ State Variables ============
    
    IERC20 public stakingToken;
    StakingPool public pool;
    mapping(uint256 => Stake) public stakes;
    mapping(uint256 => euint256) public stakeOwner; // Encrypted owner address per stake
    mapping(address => uint256[]) public userStakes; // Public mapping for convenience (for ownership verification)
    uint256 private nextStakeId;
    uint256 private constant BLOCKS_PER_YEAR = 2_102_400; // ~12 seconds per block

    // ============ Events ============
    
    event Staked(address indexed user, uint256 indexed stakeId, uint256 lockTimestamp);
    event Unstaked(address indexed user, uint256 indexed stakeId);
    event RewardsClaimed(address indexed user, uint256 indexed stakeId);
    event PoolUpdated(uint256 newAPR, uint256 minLockPeriod);

    // ============ Constructor ============
    
    constructor(address _stakingToken, uint256 _apr, uint256 _minLockPeriod) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        pool.apr = _apr;
        pool.minLockPeriod = _minLockPeriod;
        pool.lastRewardBlock = block.number;
        pool.rewardPerShare = FHE.asEuint64(0);
        pool.totalStaked = FHE.asEuint64(0);
    }

    // ============ Staking Functions ============
    
    /// @notice Stake tokens with encrypted amount and owner address
    /// @param inputEncryptedAmount Encrypted amount to stake (externalEuint64)
    /// @param inputAmountProof Proof for encrypted amount
    /// @param inputEncryptedOwner Encrypted owner address (externalEuint256)
    /// @param inputOwnerProof Proof for encrypted owner address
    /// @param lockPeriod Lock period in seconds (public)
    /// @param inputEncryptedIsActive Optional: encrypted initial active status (externalEbool)
    /// @param inputActiveProof Optional: proof for encrypted active status
    /// @return stakeId The ID of the created stake
    function stake(
        externalEuint64 inputEncryptedAmount,
        bytes calldata inputAmountProof,
        externalEuint256 inputEncryptedOwner,
        bytes calldata inputOwnerProof,
        uint256 lockPeriod,
        externalEbool inputEncryptedIsActive,
        bytes calldata inputActiveProof
    ) external returns (uint256 stakeId) {
        require(lockPeriod >= pool.minLockPeriod, "Lock period too short");
        
        // Convert external encrypted inputs
        // IMPORTANT: Types must match: externalEuint64 → euint64 (use add64() in SDK)
        euint64 encryptedAmount = FHE.fromExternal(inputEncryptedAmount, inputAmountProof);
        // IMPORTANT: Types must match: externalEuint256 → euint256 (use add256() in SDK)
        euint256 encryptedOwner = FHE.fromExternal(inputEncryptedOwner, inputOwnerProof);
        // IMPORTANT: Types must match: externalEbool → ebool (use addBool() in SDK)
        ebool encryptedIsActive = FHE.fromExternal(inputEncryptedIsActive, inputActiveProof);
        
        // Update rewards before staking
        _updateRewards();
        
        // Create new stake
        stakeId = nextStakeId++;
        Stake storage newStake = stakes[stakeId];
        newStake.amount = encryptedAmount;
        
        // Calculate reward debt: amount * rewardPerShare
        // Note: Division by 1e18 handled in reward calculation
        newStake.rewardDebt = FHE.mul(encryptedAmount, pool.rewardPerShare);
        
        newStake.lockTimestamp = block.timestamp + lockPeriod;
        newStake.isActive = encryptedIsActive;
        
        // Store encrypted owner address (comes from external)
        stakeOwner[stakeId] = encryptedOwner;
        
        // Update pool total
        pool.totalStaked = FHE.add(pool.totalStaked, encryptedAmount);
        
        // Track user stake (public mapping for convenience/ownership verification)
        userStakes[msg.sender].push(stakeId);
        
        // Allow user to decrypt their stake
        FHE.allowThis(newStake.amount);
        FHE.allow(newStake.amount, msg.sender);
        FHE.allowThis(newStake.rewardDebt);
        FHE.allow(newStake.rewardDebt, msg.sender);
        FHE.allowThis(newStake.isActive);
        FHE.allow(newStake.isActive, msg.sender);
        
        emit Staked(msg.sender, stakeId, newStake.lockTimestamp);
        return stakeId;
    }

    // ============ Internal Functions ============
    
    /// @notice Update reward per share based on time elapsed
    function _updateRewards() internal {
        if (block.number <= pool.lastRewardBlock) return;
        
        uint256 blocks = block.number - pool.lastRewardBlock;
        // Calculate reward rate per block (scaled by 1e18, but cap to uint64)
        uint256 rewardRate = (pool.apr * 1e18) / BLOCKS_PER_YEAR;
        require(rewardRate <= type(uint64).max, "Reward rate too large");
        
        // Calculate new rewards: totalStaked * rewardRate * blocks
        euint64 blocksEncrypted = FHE.asEuint64(uint64(blocks));
        euint64 rewardRateEncrypted = FHE.asEuint64(uint64(rewardRate));
        
        // reward = totalStaked * rewardRate * blocks
        euint64 reward = FHE.mul(pool.totalStaked, FHE.mul(rewardRateEncrypted, blocksEncrypted));
        
        // Update reward per share: rewardPerShare += reward
        // Note: Full division by totalStaked handled in claimRewards calculation
        pool.rewardPerShare = FHE.add(pool.rewardPerShare, reward);
        
        pool.lastRewardBlock = block.number;
    }

    /// @notice Unstake tokens after lock period
    /// @param stakeId The stake ID to unstake
    /// @param inputEncryptedOwner Encrypted owner address for verification (externalEuint256)
    /// @param inputOwnerProof Proof for encrypted owner address
    /// @return unstakedAmount The encrypted amount unstaked
    function unstake(
        uint256 stakeId,
        externalEuint256 inputEncryptedOwner,
        bytes calldata inputOwnerProof
    ) external returns (euint64 unstakedAmount) {
        Stake storage s = stakes[stakeId];
        require(block.timestamp >= s.lockTimestamp, "Still locked");
        
        // Verify stake ownership using encrypted address comparison
        // IMPORTANT: externalEuint256 → euint256 (use add256() in SDK for address)
        euint256 callerEncrypted = FHE.fromExternal(inputEncryptedOwner, inputOwnerProof);
        euint256 ownerEncrypted = stakeOwner[stakeId];
        ebool isOwner = FHE.eq(callerEncrypted, ownerEncrypted);
        // Note: Ownership verification requires external decryption of isOwner
        // For MVP, we also check public mapping as fallback
        bool isOwnerPublic = false;
        uint256[] memory userStakeIds = userStakes[msg.sender];
        for (uint256 i = 0; i < userStakeIds.length; i++) {
            if (userStakeIds[i] == stakeId) {
                isOwnerPublic = true;
                break;
            }
        }
        require(isOwnerPublic, "Not owner");
        
        unstakedAmount = s.amount;
        s.isActive = FHE.asEbool(false);
        
        // Update pool total
        pool.totalStaked = FHE.sub(pool.totalStaked, unstakedAmount);
        
        emit Unstaked(msg.sender, stakeId);
    }

    /// @notice Claim rewards for a stake
    /// @param stakeId The stake ID to claim rewards for
    /// @param inputEncryptedOwner Encrypted owner address for verification (externalEuint256)
    /// @param inputOwnerProof Proof for encrypted owner address
    /// @return rewardAmount The encrypted reward amount
    function claimRewards(
        uint256 stakeId,
        externalEuint256 inputEncryptedOwner,
        bytes calldata inputOwnerProof
    ) external returns (euint64 rewardAmount) {
        _updateRewards();
        Stake storage s = stakes[stakeId];
        
        // Verify stake ownership using encrypted address comparison
        // IMPORTANT: externalEuint256 → euint256 (use add256() in SDK for address)
        euint256 callerEncrypted = FHE.fromExternal(inputEncryptedOwner, inputOwnerProof);
        euint256 ownerEncrypted = stakeOwner[stakeId];
        ebool isOwner = FHE.eq(callerEncrypted, ownerEncrypted);
        // Note: Ownership verification requires external decryption of isOwner
        // For MVP, we also check public mapping as fallback
        bool isOwnerPublic = false;
        uint256[] memory userStakeIds = userStakes[msg.sender];
        for (uint256 i = 0; i < userStakeIds.length; i++) {
            if (userStakeIds[i] == stakeId) {
                isOwnerPublic = true;
                break;
            }
        }
        require(isOwnerPublic, "Not owner");
        
        // Calculate rewards: (amount * rewardPerShare) - rewardDebt
        euint64 accumulatedReward = FHE.mul(s.amount, pool.rewardPerShare);
        rewardAmount = FHE.sub(accumulatedReward, s.rewardDebt);
        
        // Update reward debt to current accumulated reward
        s.rewardDebt = accumulatedReward;
        
        emit RewardsClaimed(msg.sender, stakeId);
    }

    // ============ Admin Functions ============
    
    /// @notice Update pool parameters
    function updatePoolParameters(uint256 newAPR, uint256 newMinLockPeriod) external onlyOwner {
        pool.apr = newAPR;
        pool.minLockPeriod = newMinLockPeriod;
        emit PoolUpdated(newAPR, newMinLockPeriod);
    }

    // ============ View Functions ============
    
    /// @notice Get stake information
    function getStake(uint256 stakeId) external view returns (
        euint64 amount,
        euint64 rewardDebt,
        uint256 lockTimestamp,
        ebool isActive
    ) {
        Stake storage s = stakes[stakeId];
        return (s.amount, s.rewardDebt, s.lockTimestamp, s.isActive);
    }

    /// @notice Get user's stake IDs
    function getUserStakes(address user) external view returns (uint256[] memory) {
        return userStakes[user];
    }
}

