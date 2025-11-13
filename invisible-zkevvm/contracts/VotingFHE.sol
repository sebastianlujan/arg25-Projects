// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FHE, euint32, ebool, externalEuint32} from "@fhevm/solidity/lib/FHE.sol";
import {EthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";

/// @title Encrypted Voting Contract using Zama FHEVM
/// @notice Allows creating proposals and casting encrypted votes
/// @dev All vote tallies are encrypted using FHE
contract VotingFHE is EthereumConfig {
    struct Proposal {
        string question;
        string[] options;
        bool exists;
        // Encrypted tally per option
        mapping(uint256 => euint32) tally;
    }

    mapping(bytes32 => Proposal) private _proposals;
    mapping(bytes32 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(bytes32 id, string question);
    event EncryptedVote(bytes32 id, address voter);

    /// @notice Creates a new voting proposal
    /// @param id Unique identifier for the proposal
    /// @param question The question to be voted on
    /// @param options Array of voting options
    function createProposal(bytes32 id, string calldata question, string[] calldata options) external {
        require(!_proposals[id].exists, "exists");
        Proposal storage p = _proposals[id];
        p.question = question;
        p.exists = true;

        // Copy options array from calldata to storage
        uint256 optionsLength = options.length;
        p.options = new string[](optionsLength);
        for (uint256 i = 0; i < optionsLength; i++) {
            p.options[i] = options[i];
        }

        // Initialize tallies to encrypted 0
        for (uint256 i = 0; i < optionsLength; i++) {
            p.tally[i] = FHE.asEuint32(0);
        }
        emit ProposalCreated(id, question);
    }

    /// @notice Casts an encrypted vote for a proposal
    /// @param id The proposal identifier
    /// @param inputEuint32 The encrypted choice (option index as uint32)
    /// @param inputProof The input proof for the encrypted value
    /// @dev The vote is encrypted and added to the corresponding option's tally
    function castEncryptedVote(
        bytes32 id,
        externalEuint32 inputEuint32,
        bytes calldata inputProof
    ) external {
        Proposal storage p = _proposals[id];
        require(p.exists, "no-proposal");
        require(!hasVoted[id][msg.sender], "already");

        // Convert external encrypted input to internal euint32
        euint32 choice = FHE.fromExternal(inputEuint32, inputProof);

        // Increment tally[choice] += 1 (all encrypted)
        // Use encrypted demux: build encrypted selectors and add 1 where appropriate
        uint256 n = p.options.length;
        euint32 one = FHE.asEuint32(1);
        
        for (uint256 i = 0; i < n; i++) {
            // Selector: (choice == i) ? 1 : 0 (all encrypted)
            // FHE.eq returns ebool, use FHE.select to convert to euint32
            ebool isEqual = FHE.eq(choice, FHE.asEuint32(uint32(i)));
            euint32 isIdx = FHE.select(isEqual, FHE.asEuint32(1), FHE.asEuint32(0));
            euint32 incr = FHE.mul(isIdx, one);
            p.tally[i] = FHE.add(p.tally[i], incr);
            
            // Allow the contract and voter to decrypt the updated tally
            FHE.allowThis(p.tally[i]);
            FHE.allow(p.tally[i], msg.sender);
        }

        hasVoted[id][msg.sender] = true;
        emit EncryptedVote(id, msg.sender);
    }

    /// @notice Gets the encrypted tally for a specific option
    /// @param id The proposal identifier
    /// @param optionIndex The index of the option
    /// @return The encrypted tally count for that option
    function getTally(bytes32 id, uint256 optionIndex) external view returns (euint32) {
        Proposal storage p = _proposals[id];
        require(p.exists, "no-proposal");
        require(optionIndex < p.options.length, "invalid-option");
        return p.tally[optionIndex];
    }

    /// @notice Gets proposal information
    /// @param id The proposal identifier
    /// @return question The proposal question
    /// @return options Array of voting options
    /// @return exists Whether the proposal exists
    function getProposal(bytes32 id) external view returns (
        string memory question,
        string[] memory options,
        bool exists
    ) {
        Proposal storage p = _proposals[id];
        return (p.question, p.options, p.exists);
    }

    /// @notice Returns encrypted results for all options
    /// @param id The proposal identifier
    /// @return tallies Array of encrypted tallies for each option
    /// @return options Array of option strings
    /// @dev The tallies are encrypted and can be decrypted by authorized parties
    function getEncryptedResults(bytes32 id) external view returns (
        euint32[] memory tallies,
        string[] memory options
    ) {
        Proposal storage p = _proposals[id];
        require(p.exists, "no-proposal");

        uint256 n = p.options.length;
        tallies = new euint32[](n);
        
        for (uint256 i = 0; i < n; i++) {
            tallies[i] = p.tally[i];
        }
        
        return (tallies, p.options);
    }
}
