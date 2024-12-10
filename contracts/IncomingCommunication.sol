// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Verification.sol";

// For debugging -- Comment for deployment
import "hardhat/console.sol";

interface IVerification {
    /**
     * @notice Message information
     */
    struct Message {
        bytes data;
        address sender;
        address receiver;
        uint256 destinationBC;
        uint16 finalityNBlocks;
        uint256 messageNumber;
        bool taxi;
        uint256 fee;
    }

    function checkAllowedRelayers(address _sender) external view returns (bool);

    function verifyFinality(
        uint256 _blockchain,
        uint256 _finalityBlock
    ) external view returns (bool);

    function verifyMessage(
        Message calldata _message,
        address _msgAddress,
        uint256 _sourceBC,
        uint256 _sourceBlockNumber
    ) external view returns (bool);
}

interface IReceiveMessage {
    function receiveMessage(
        bytes calldata _messageData,
        address sender,
        uint256 sourceBC
    ) external returns (bool);
}

contract IncomingCommunication is Ownable {
    address verificationContractAddress;
    /**
     * @notice Status for incoming messages
     */
    enum IncomingMsgStatus {
        Undefined,
        Delivered,
        Cancelled,
        Failed
    }

    /**
     * @notice Indicates that a new message is received from outside the blockchain
     * @dev A failure can occurr even if inboundSuccessfull is true due to an on-chain msg execution issue
     * @param relayer address to pay relayer on source blockchainr
     * @param sourceBC Id of the source blockchain
     * @param inboundMessageNumbers Numbers of message, unique per destintation blockchain
     * @param successfullInbound Wheter the Message was succesfully inbount
     * @param failureReasons Reason of failure per failure
     */
    event InboundMessagesRes(
        address relayer,
        uint256 sourceBC,
        uint256[] inboundMessageNumbers,
        bool[] successfullInbound,
        string[] failureReasons
    );

    /**
     * @notice Incoming message status per source blockchain and message number.
     */
    mapping(uint256 => mapping(uint256 => IncomingMsgStatus))
        public inMsgStatusPerChainIdAndMsgNumber;

    /**
     * @notice Communication contract addreses per source blockchain.
     */
    mapping(uint256 => address) public sourceAddresesPerChainId;

    constructor(
        uint256[] memory _blockChainIds,
        address[] memory _blockChainAddresses,
        address _verificationAdress
    ) payable Ownable(msg.sender) {
        for (uint i = 0; i < _blockChainIds.length; i++) {
            sourceAddresesPerChainId[_blockChainIds[i]] = _blockChainAddresses[
                i
            ];
        }
        verificationContractAddress = _verificationAdress;
    }

    // ================================================================
    // │                           Messaging                          │
    // ================================================================

    /*
     * @notice Receive a message from outside chain.
     * @param _messages Array of messages to be inbound
     * @param _relayer address to pay relayer on source blockchain
     * @param _sourceBC Id of the source blockchain
     * @param _sourceBlockNumbers Blocknumbers for each message emmission
     */
    function inboundMessages(
        IVerification.Message[] calldata _messages,
        address _relayer,
        address _sourceEndpoint,
        uint256 _sourceBC,
        uint256[] calldata _sourceBlockNumbers
    ) external {
        require(
            sourceAddresesPerChainId[_sourceBC] != address(0),
            "Source blockchain not supported"
        );

        // Calls verification contract
        IVerification _verification = IVerification(
            verificationContractAddress
        );
        require(
            _verification.checkAllowedRelayers(msg.sender),
            "Relayer not authorized"
        );
        uint256[] memory _inboundMessageNumbers = new uint256[](
            _messages.length
        );
        bool[] memory _successfullInbound = new bool[](_messages.length);
        string[] memory _failureReasons = new string[](_messages.length);
        for (uint i = 0; i < _messages.length; i++) {
            _inboundMessageNumbers[i] = _messages[i].messageNumber;
            if (
                inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                    _messages[i].messageNumber
                ] == IncomingMsgStatus.Delivered
            ) {
                _successfullInbound[i] = false;
                _failureReasons[i] = "Inbound: Message already delivered";
                continue;
            }
            if (
                inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                    _messages[i].messageNumber
                ] == IncomingMsgStatus.Cancelled
            ) {
                _successfullInbound[i] = false;
                _failureReasons[i] = "Inbound: Message already cancelled";
                continue;
            }
            if (
                !_verification.verifyFinality(
                    _sourceBC,
                    _sourceBlockNumbers[i] + _messages[i].finalityNBlocks
                )
            ) {
                _successfullInbound[i] = false;
                _failureReasons[
                    i
                ] = "Inbound: Finality not reached for message";
                continue;
            }
            if (
                !_verification.verifyMessage(
                    _messages[i],
                    _sourceEndpoint,
                    _sourceBC,
                    _sourceBlockNumbers[i]
                )
            ) {
                _successfullInbound[i] = false;
                _failureReasons[i] = "Inbound: Invalid Message hash";
                continue;
            }

            _successfullInbound[i] = true;

            inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                _messages[i].messageNumber
            ] = IncomingMsgStatus.Delivered;

            // Call the target contract's function to handle the message
            //(bool success, ) = _messages[i].receiver.call(
            //    abi.encodeWithSignature(
            //        "handleMessage(bytes)",
            //        _messages[i].data
            //    )
            //);

            //if (!success) {
            //    // Change msg status to failed
            //    inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
            //        _messages[i].messageNumber
            //    ] = IncomingMsgStatus.Failed;
            //    _failureReasons[i] = "On chain: message execution failed";
            //    continue;
            //}
        }
        // This event is listened to by relayers to earn their fees
        emit InboundMessagesRes(
            _relayer,
            _sourceBC,
            _inboundMessageNumbers,
            _successfullInbound,
            _failureReasons
        );
    }

    // ================================================================
    // │                           Utils                             │
    // ================================================================
    /**
     * @notice Gets balance from address.
     */
    function getBalance() public view returns (uint256) {
        console.log(address(this).balance);
        return address(this).balance;
    }
    // TODO: Function to add new supported BCs (require contract owner)
    // TODO: Function to deposit/withdraw funds from contract (require contract owner)
}
