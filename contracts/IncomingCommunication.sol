// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// For debugging -- Comment for deployment
import "hardhat/console.sol";

contract IncomingCommunication is Ownable {
    /**
     * @notice Status for incoming messaages
     */
    enum IncomingMsgStatus {
        Undefined,
        Delivered,
        Cancelled
    }

    /**
     * @notice Indicates that a new message is received from outside the blockchain
     * @dev
     * @param relayer address to pay relayer on source blockchainr
     * @param sourceBC Id of the source blockchain
     * @param messageNumber Number of message, unique per destintation blockchain
     */
    event InboundMessage(
        address relayer,
        uint256 sourceBC,
        uint256 messageNumber
    );

    /**
     * @notice Tracks processed incoming message status per source blockchain.
     */
    mapping(uint256 => mapping(uint256 => IncomingMsgStatus))
        public inMsgStatusPerChainIdAndMsgNumber;

    /**
     * @notice Tracks receipt trie root per source blockchain and blocknumber
     */
    mapping(uint256 => mapping(uint256 => bytes32))
        public recTrieRootPerChainIdAndBlocknumber;

    /**
     * @notice Tracks log data per source blockchhain and message number
     */
    mapping(uint256 => mapping(uint256 => bytes))
        public logDataPerChainIdAndMsgNumber;

    /**
     * @notice Tracks blocknumber data per source blockchhain
     */
    mapping(uint256 => uint256) public blocknumberPerChainId;

    // TODO: Add mapping for allowed oracle addresses and functions to update list

    constructor(uint[] memory _blockChainIds) payable Ownable(msg.sender) {
        for (uint i = 0; i < _blockChainIds.length; i++) {
            blocknumberPerChainId[_blockChainIds[i]] = 1;
        }
    }

    /**
     * @notice Receive a message from outside chain.
     * @param _proof inclusion proof for receipt trie
     * @param _relayer address to pay relayer on source blockchain
     * @param _sourceBC Id of the source blockchain
     * @param _messageNumber message number
     */
    function inboundsMessage(
        bytes32[] calldata _proof,
        address _relayer,
        uint256 _sourceBC,
        uint256 _messageNumber
    ) external payable {
        require(
            inMsgStatusPerChainIdAndMsgNumber[_sourceBC][_messageNumber] ==
                IncomingMsgStatus.Undefined,
            "Message already delivered"
        );
        require(
            blocknumberPerChainId[_sourceBC] > 0,
            "Not supporte blockchain"
        );
        // Check finality
        //require(
        //    logDataPerChainIdAndMsgNumber[_sourceBC][_messageNumber]
        //        .blocknumber +
        //        logDataPerChainIdAndMsgNumber[_sourceBC][_messageNumber]
        //            .data
        //            .finalityNBlocks <=
        //        blocknumberPerChainId[_sourceBC],
        //    "Finality not reached for message"
        //);

        // Verify the Merkle proof before forwarding
        //require(
        //    verifyMessage(
        //        _sourceBC,
        //        _messageNumber,
        //        _proof,
        //        recTrieRootPerChainIdAndBlocknumber[_sourceBC][_messageNumber]
        //    ),
        //    "Invalid Merkle proof"
        //);

        emit InboundMessage(_relayer, _sourceBC, _messageNumber);
        inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
            _messageNumber
        ] = IncomingMsgStatus.Delivered;
        // TODO: Forward message
        // Call the target contract's function to handle the message
        //(bool success, ) = _receiver.call(
        //    abi.encodeWithSignature("handleMessage(bytes)", _data)
        //);
        //require(success, "In chain message forwarding failed");
        //emit MessageSent(msg.sender, _data);
    }
}
