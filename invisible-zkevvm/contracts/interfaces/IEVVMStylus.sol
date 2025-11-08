// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Interface for EVVM Stylus Contracts
/// @notice Defines the interface for high-performance Rust contracts in Stylus
/// @dev Used for offloading heavy computations from Solidity to Stylus
interface IEVVMStylus {
    /// @notice Compute Merkle root for block transactions
    /// @param txHashes Array of transaction hashes
    /// @return blockHash Computed block hash (Merkle root)
    function computeBlockHash(
        bytes32[] calldata txHashes
    ) external view returns (bytes32);
    
    /// @notice Validate multiple signatures in batch
    /// @param signatures Array of signatures to validate
    /// @param messageHash Hash of the message that was signed
    /// @return isValid True if all signatures are valid
    function validateSignatures(
        bytes[] calldata signatures,
        bytes32 messageHash
    ) external view returns (bool);
    
    /// @notice Verify Merkle proof for transaction inclusion
    /// @param leaf Transaction hash (leaf)
    /// @param proof Array of Merkle proof elements
    /// @param root Merkle root to verify against
    /// @param index Index of the leaf in the tree
    /// @return isValid True if proof is valid
    function verifyMerkleProof(
        bytes32 leaf,
        bytes32[] calldata proof,
        bytes32 root,
        uint256 index
    ) external view returns (bool);
}

