// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {FHE, euint64, InEuint64} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "../core/EVVMCore.sol";
import "../library/SignatureRecover.sol";

/// @title EVVM Cafhe - Coffee Shop with FHE
/// @notice Example contract demonstrating EVVM integration with encrypted payments using Fhenix CoFHE
/// @dev All payment amounts are encrypted using FHE for privacy
/// @dev Follows CoFHE best practices: proper access control, encrypted inputs
contract EVVMCafhe {

    /// @notice Thrown when a provided signature is invalid or verification fails
    error InvalidSignature();

    /// @notice Thrown when attempting to reuse a nonce that has already been consumed
    error NonceAlreadyUsed();

    /// @notice Thrown when an unauthorized action is attempted
    error Unauthorized();

    /// @notice Address of the EVVM virtual blockchain contract for payment processing
    EVVMCore public evvmCore;

    /// @notice Constant representing ETH in the EVVM virtual blockchain (address(0))
    address constant ETHER_ADDRESS = address(0);

    /// @notice Constant representing the principal token in EVVM virtual blockchain (address(1))
    address constant PRINCIPAL_TOKEN_ADDRESS = address(1);

    /// @notice Address of the coffee shop owner who can withdraw funds and rewards
    address public ownerOfShop;

    /// @notice Mapping to track used nonces per client address to prevent replay attacks
    /// @dev First key: client address, Second key: nonce, Value: whether nonce is used
    mapping(address => mapping(uint256 => bool)) public checkAsyncNonce;

    /// @notice Modifier to restrict function access to only the coffee shop owner
    modifier onlyOwner() {
        if (msg.sender != ownerOfShop) revert Unauthorized();
        _;
    }

    /**
     * @notice Initializes the coffee shop contract with EVVM integration
     * @param _evvmCoreAddress Address of the EVVM Core contract for payment processing
     * @param _ownerOfShop Address that will have administrative privileges over the shop
     */
    constructor(
        address _evvmCoreAddress,
        address _ownerOfShop
    ) {
        evvmCore = EVVMCore(_evvmCoreAddress);
        ownerOfShop = _ownerOfShop;
    }

    /**
     * @notice Processes a coffee order with encrypted payment through EVVM
     *
     * @param clientAddress Address of the customer placing the order
     * @param coffeeType Type/name of coffee being ordered (e.g., "Espresso", "Latte")
     * @param quantity Number of coffee units being ordered
     * @param totalPricePlaintext Total price in plaintext (for signature verification)
     * @param inputEncryptedTotalPrice Encrypted total price to be paid in ETH (InEuint64)
     * @param nonce Unique number to prevent replay attacks (must not be reused)
     * @param signature Client's signature authorizing the coffee order
     * @param inputEncryptedPriorityFee Encrypted priority fee for EVVM transaction (InEuint64)
     * @param nonce_EVVM Unique nonce for the EVVM payment transaction
     * @param priorityFlag_EVVM Boolean flag indicating the type of nonce we are using
     *                          (true for async nonce, false for sync nonce)
     *
     * @dev Signature format for client authorization:
     *      "<evvmID>,orderCoffee,<coffeeType>,<quantity>,<totalPrice>,<nonce>"
     *
     * @dev Reverts with InvalidSignature() if client signature verification fails
     * @dev Reverts with NonceAlreadyUsed() if nonce has been previously used
     * 
     * @dev Note: totalPricePlaintext is used for signature verification only.
     *      The actual payment uses inputEncryptedTotalPrice for privacy.
     * @dev CoFHE handles proof verification internally
     */
    function orderCoffee(
        address clientAddress,
        string memory coffeeType,
        uint256 quantity,
        uint256 totalPricePlaintext,
        InEuint64 memory inputEncryptedTotalPrice,
        uint256 nonce,
        bytes memory signature,
        uint256 priorityFeePlaintext,
        InEuint64 memory inputEncryptedPriorityFee,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM
    ) external {
        /**
         * Verify client's signature for ordering coffee
         * The signed message format is:
         * "<evvmID>,orderCoffee,<coffeeType>,<quantity>,<totalPrice>,<nonce>"
         * Where:
         * · <evvmID> ------ is obtained from evvmCore.evvmID()
         * · "orderCoffee" - is the name of the function being called
         * · <coffeeType> -- is the type of coffee ordered
         * · <quantity> ---- is the number of coffees ordered
         * · <totalPrice> -- is the total price to be paid in ETH (plaintext for signature)
         * · <nonce> ------- is a unique number to prevent replay attacks
         * 
         * Note: The totalPrice in the signature is the plaintext value that the client knows.
         * The actual payment uses the encrypted value (inputEncryptedTotalPrice) for privacy.
         */
        
        // Get EVVM ID for signature verification
        uint256 evvmID = evvmCore.evvmID();
        
        // Build the message for signature verification
        string memory inputs = string.concat(
            coffeeType,
            ",",
            Strings.toString(quantity),
            ",",
            Strings.toString(totalPricePlaintext),
            ",",
            Strings.toString(nonce)
        );

        if (
            !SignatureRecover.signatureVerification(
                Strings.toString(evvmID),
                "orderCoffee",
                inputs,
                signature,
                clientAddress
            )
        ) revert InvalidSignature();

        // Prevent replay attacks by checking if nonce has been used before
        if (checkAsyncNonce[clientAddress][nonce]) revert NonceAlreadyUsed();

        /**
         * Pay for the coffee using EVVM virtual blockchain's pay function
         * The parameters are as follows:
         * · from ----------- clientAddress
         * · to_address ----- address(this) (the EVVMCafe contract)
         * · token ---------- ETHER_ADDRESS (indicating payment in ETH)
         * · amount --------- inputEncryptedTotalPrice (encrypted total price of the coffee)
         * · priorityFee ---- inputEncryptedPriorityFee (encrypted fee for prioritizing the transaction)
         * · nonce ---------- nonce_EVVM (unique number for this payment)
         * · priorityFlag --- priorityFlag_EVVM (indicates if the payment is prioritized)
         *
         * If the payment fails due to
         * 1) Insufficient balance
         * 2) Invalid amount
         * 3) Invalid async nonce
         * the EVVM virtual blockchain will revert the transaction accordingly.
         *
         * If the contract has some stake in the EVVM virtual blockchain receives
         * · All the priority fees paid by the client for this transaction
         * · 1 reward according to the EVVM's reward mechanism
         */
        EVVMCore.PaymentParams memory paymentParams = EVVMCore.PaymentParams({
            from: clientAddress,
            to: address(this),
            toIdentity: "",
            token: ETHER_ADDRESS,
            amountPlaintext: totalPricePlaintext,
            inputEncryptedAmount: inputEncryptedTotalPrice,
            priorityFeePlaintext: priorityFeePlaintext,
            inputEncryptedPriorityFee: inputEncryptedPriorityFee,
            nonce: nonce_EVVM,
            priorityFlag: priorityFlag_EVVM,
            executor: address(0),
            signature: ""
        });
        evvmCore.pay(paymentParams);

        /**
         * FISHER INCENTIVE SYSTEM:
         * If this contract is registered as a staker in EVVM virtual blockchain, distribute rewards to the fisher.
         * This creates an economic incentive for fishers to process transactions.
         *
         * Rewards distributed:
         * 1. All priority fees paid by the client (inputEncryptedPriorityFee)
         * 2. Half of the reward earned from this transaction
         *
         * Note: You could optionally restrict this to only staker fishers by adding:
         * evvmCore.isAddressStaker(msg.sender) to the condition
         */
        if (evvmCore.isAddressStaker(address(this))) {
            // Transfer the priority fee to the fisher as immediate incentive
            // Note: In the new implementation, we use pay() to transfer from contract to fisher
            // The contract needs to have the encrypted balance to pay
            // For now, we'll use a simplified approach where the fisher gets the fee directly
            // through the EVVM's built-in mechanism (handled in pay function)
            
            // Note: The reward is already given to the staker (this contract) by EVVM's pay() function
            // To distribute rewards to fishers, we would need to:
            // 1. Get the encrypted reward amount (requires decryption off-chain)
            // 2. Calculate half of the reward (FHE.div is not available for euint64)
            // 3. Transfer it to the fisher using pay() with encrypted amounts
            // 
            // For MVP: This is a placeholder. The actual implementation would need to handle
            // encrypted transfers from contract balance to fisher, which requires:
            // - Off-chain decryption of the reward amount
            // - Off-chain calculation of half the reward
            // - Re-encryption and transfer via pay()
        }

        // Mark nonce as used to prevent future reuse
        checkAsyncNonce[clientAddress][nonce] = true;
    }

    /**
     * @notice Withdraws accumulated virtual blockchain reward tokens from the contract
     * @dev Only callable by the coffee shop owner
     *
     * @param to Address where the withdrawn reward tokens will be sent
     * @param inputEncryptedBalance Encrypted balance to withdraw (InEuint64)
     * @param nonce_EVVM Nonce for the EVVM payment transaction
     * @param priorityFlag_EVVM Boolean flag for nonce type
     * @param inputEncryptedPriorityFee Encrypted priority fee (InEuint64)
     * @dev CoFHE handles proof verification internally
     */
    function withdrawRewards(
        address to,
        InEuint64 memory inputEncryptedBalance,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        InEuint64 memory inputEncryptedPriorityFee
    ) external onlyOwner {
        // Transfer all accumulated reward tokens to the specified address
        // Using pay() function to transfer from contract to owner
        EVVMCore.PaymentParams memory paymentParams = EVVMCore.PaymentParams({
            from: address(this),
            to: to,
            toIdentity: "",
            token: PRINCIPAL_TOKEN_ADDRESS,
            amountPlaintext: 0,
            inputEncryptedAmount: inputEncryptedBalance,
            priorityFeePlaintext: 0,
            inputEncryptedPriorityFee: inputEncryptedPriorityFee,
            nonce: nonce_EVVM,
            priorityFlag: priorityFlag_EVVM,
            executor: address(0),
            signature: ""
        });
        evvmCore.pay(paymentParams);
    }

    /**
     * @notice Withdraws accumulated ETH funds from coffee sales
     * @dev Only callable by the coffee shop owner
     *
     * @param to Address where the withdrawn ETH will be sent
     * @param inputEncryptedBalance Encrypted balance to withdraw (InEuint64)
     * @param nonce_EVVM Nonce for the EVVM payment transaction
     * @param priorityFlag_EVVM Boolean flag for nonce type
     * @param inputEncryptedPriorityFee Encrypted priority fee (InEuint64)
     * @dev CoFHE handles proof verification internally
     */
    function withdrawFunds(
        address to,
        InEuint64 memory inputEncryptedBalance,
        uint256 nonce_EVVM,
        bool priorityFlag_EVVM,
        InEuint64 memory inputEncryptedPriorityFee
    ) external onlyOwner {
        // Transfer all accumulated ETH to the specified address
        // Using pay() function to transfer from contract to owner
        EVVMCore.PaymentParams memory paymentParams = EVVMCore.PaymentParams({
            from: address(this),
            to: to,
            toIdentity: "",
            token: ETHER_ADDRESS,
            amountPlaintext: 0,
            inputEncryptedAmount: inputEncryptedBalance,
            priorityFeePlaintext: 0,
            inputEncryptedPriorityFee: inputEncryptedPriorityFee,
            nonce: nonce_EVVM,
            priorityFlag: priorityFlag_EVVM,
            executor: address(0),
            signature: ""
        });
        evvmCore.pay(paymentParams);
    }

    function isThisNonceUsed(
        address clientAddress,
        uint256 nonce
    ) external view returns (bool) {
        return checkAsyncNonce[clientAddress][nonce];
    }

    function getPrincipalTokenAddress() external pure returns (address) {
        return PRINCIPAL_TOKEN_ADDRESS;
    }

    function getEtherAddress() external pure returns (address) {
        return ETHER_ADDRESS;
    }

    /**
     * @notice Get encrypted balance of principal tokens in the shop
     * @return Encrypted balance (euint64) - decrypt with SDK
     */
    function getAmountOfPrincipalTokenInShop() external view returns (euint64) {
        return evvmCore.getBalance(address(this), PRINCIPAL_TOKEN_ADDRESS);
    }

    /**
     * @notice Get encrypted balance of ETH in the shop
     * @return Encrypted balance (euint64) - decrypt with SDK
     */
    function getAmountOfEtherInShop() external view returns (euint64) {
        return evvmCore.getBalance(address(this), ETHER_ADDRESS);
    }

    /**
     * @notice Get the EVVM Core contract address
     * @return Address of the EVVM Core contract
     */
    function getEvvmAddress() external view returns (address) {
        return address(evvmCore);
    }
}

