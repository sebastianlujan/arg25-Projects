// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {FHE, euint8, euint32, ebool, InEuint8} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/// @title Encrypted Voting Contract using Fhenix CoFHE
/// @notice Allows creating proposals and casting encrypted votes
/// @dev All vote tallies are encrypted using FHE
/// @dev Follows CoFHE best practices: constant-time computation, encrypted constants, proper access control
contract VotingFHE {
    struct Proposal {
        string question;
        string[] options;
        bool exists;
        // Encrypted tally per option
        mapping(uint256 => euint32) tally;
    }

    mapping(bytes32 => Proposal) private _proposals;
    mapping(bytes32 => mapping(address => bool)) public hasVoted;

    // Encrypted constants for gas optimization (CoFHE best practice)
    euint32 private EUINT32_ZERO;
    euint32 private EUINT32_ONE;

    event ProposalCreated(bytes32 id, string question);
    event EncryptedVote(bytes32 id, address voter);

    constructor() {
        // Initialize encrypted constants once in constructor to save gas
        EUINT32_ZERO = FHE.asEuint32(0);
        EUINT32_ONE = FHE.asEuint32(1);
    }

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

        // Initialize tallies to encrypted 0 (using pre-encrypted constant)
        for (uint256 i = 0; i < optionsLength; i++) {
            p.tally[i] = EUINT32_ZERO;
        }
        emit ProposalCreated(id, question);
    }

    /// @notice Casts an encrypted vote for a proposal
    /// @param id The proposal identifier
    /// @param optionIndex The encrypted choice (option index as InEuint8)
    /// @dev The vote is encrypted and added to the corresponding option's tally
    /// @dev Uses constant-time computation to prevent information leakage
    function castEncryptedVote(
        bytes32 id,
        InEuint8 memory optionIndex
    ) external {
        Proposal storage p = _proposals[id];
        require(p.exists, "no-proposal");
        require(!hasVoted[id][msg.sender], "already");

        // Convert encrypted input to internal euint8
        euint8 choice = FHE.asEuint8(optionIndex);

        // Constant-time computation: update all tallies, but only increment the selected one
        // This prevents information leakage about which option was chosen
        uint256 n = p.options.length;
        
        for (uint256 i = 0; i < n; i++) {
            // Selector: (choice == i) ? 1 : 0 (all encrypted)
            // Use FHE.select instead of if/else (CoFHE best practice)
            ebool isEqual = FHE.eq(choice, FHE.asEuint8(uint8(i)));
            euint32 increment = FHE.select(isEqual, EUINT32_ONE, EUINT32_ZERO);
            
            // Add increment to tally (always executes, but increment is 0 or 1)
            p.tally[i] = FHE.add(p.tally[i], increment);
            
            // Always update permissions after modifying encrypted values (CoFHE best practice)
            FHE.allowThis(p.tally[i]);
        }

        // Allow sender to decrypt their choice (for event emission)
        FHE.allowSender(choice);
        
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

    /// @notice Finalizes voting by decrypting all tallies
    /// @param id The proposal identifier
    /// @dev Only authorized parties can decrypt. Use FHE.decrypt() to request decryption
    function finalizeVote(bytes32 id) external {
        Proposal storage p = _proposals[id];
        require(p.exists, "no-proposal");

        uint256 n = p.options.length;
        for (uint256 i = 0; i < n; i++) {
            // Request decryption for each tally
            FHE.decrypt(p.tally[i]);
        }
    }

    /// @notice Gets proposal with decrypted results
    /// @param id The proposal identifier
    /// @return question The proposal question
    /// @return options Array of voting options
    /// @return votes Array of decrypted vote counts (0 if not yet decrypted)
    /// @return finalized Whether all votes have been decrypted
    /// @dev Uses FHE.getDecryptResultSafe to safely check decryption status
    function getProposalWithResults(bytes32 id) external view returns (
        string memory question,
        string[] memory options,
        uint32[] memory votes,
        bool finalized
    ) {
        Proposal storage p = _proposals[id];
        require(p.exists, "no-proposal");

        question = p.question;
        uint256 n = p.options.length;
        options = new string[](n);
        votes = new uint32[](n);
        finalized = true;

        for (uint256 i = 0; i < n; i++) {
            options[i] = p.options[i];
            
            // Safely get decryption result
            (uint256 result, bool decrypted) = FHE.getDecryptResultSafe(p.tally[i]);
            votes[i] = decrypted ? uint32(result) : 0;
            if (!decrypted) finalized = false;
        }
    }
}
