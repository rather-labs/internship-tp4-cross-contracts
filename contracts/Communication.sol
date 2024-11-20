// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract CommunicationContract is Ownable {
    event MessageReceived(address indexed sender, bytes message, bytes32 indexed messageHash);
    event MessageSent(address indexed receiver, bytes message);
    event OutboundMessage(address indexed targetContract, bytes message);

    mapping(bytes32 => bool) public processedMessages; // Tracks processed incoming messages
    uint256 public messageFee; // Fee for sending messages

    constructor(uint256 _messageFee) Ownable(msg.sender) {
        messageFee = _messageFee;
    }

    /**
     * @dev Updates the message fee.
     * @param _newFee The new fee for sending messages.
     */
    function updateMessageFee(uint256 _newFee) external onlyOwner {
        messageFee = _newFee;
    }

    /**
     * @dev Receives a message from other contracts within the chain.
     * @param message The message to process.
     */
    function receiveMessage(bytes calldata message) external payable {
        require(msg.value >= messageFee, "Insufficient fee");
        bytes32 messageHash = keccak256(message);
        require(!processedMessages[messageHash], "Message already processed");

        processedMessages[messageHash] = true;
        emit MessageReceived(msg.sender, message, messageHash);
    }

    /**
     * @dev Sends a message to an external chain or relayer.
     * @param message The message to send.
     */
    function sendMessage(bytes calldata message) external payable {
        require(msg.value >= messageFee, "Insufficient fee");
        emit MessageSent(msg.sender, message);
    }

    /**
     * @dev Verifies a Merkle proof for an incoming message from an external source.
     * @param message The original message.
     * @param proof The Merkle proof.
     * @param root The Merkle root.
     */
    function verifyMessage(
        bytes calldata message,
        bytes32[] calldata proof,
        bytes32 root
    ) external view returns (bool) {
        bytes32 messageHash = keccak256(message);
        return MerkleProof.verify(proof, root, messageHash);
    }

    /**
     * @dev Sends a message to another contract on the same chain.
     * @param targetContract The target contract's address.
     * @param message The message to send.
     */
    function forwardMessage(address targetContract, bytes calldata message) external {
        require(targetContract != address(0), "Invalid target address");

        // Call the target contract's function to handle the message
        (bool success, ) = targetContract.call(abi.encodeWithSignature("handleMessage(bytes)", message));
        require(success, "Message forwarding failed");

        emit OutboundMessage(targetContract, message);
    }
}
