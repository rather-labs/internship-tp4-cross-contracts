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

contract IncomingCommunication is Ownable {
    address verificationContractAddress =
        0xAB8Eb9F37bD460dF99b11767aa843a8F27FB7A6e;
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
     * @param inboundSuccessfull Wheter the Message was succesfully inbount
     * @param failureReasons Reason of failure per failure
     */
    event InboundMessages(
        address relayer,
        uint256 sourceBC,
        uint256[] inboundMessageNumbers,
        bool[] inboundSuccessfull,
        string[] failureReasons
    );

    /**
     * @notice Indicates that a new message is sent succesfully
     * @dev

    /**
     * @notice Tracks processed incoming message status per source blockchain.
     */
    mapping(uint256 => mapping(uint256 => IncomingMsgStatus)) //first  uint256 is message number
        public inMsgStatusPerChainIdAndMsgNumber;

    /**
     * @notice Communication contract addreses per destination blockchain.
     */
    mapping(uint256 => address) public destAddresesPerChainId;

    constructor(
        uint256[] memory _blockChainIds,
        address[] memory _blockChainAddresses
    ) payable Ownable(msg.sender) {
        for (uint i = 0; i < _blockChainIds.length; i++) {
            destAddresesPerChainId[_blockChainIds[i]] = _blockChainAddresses[i];
        }
    }

    // ================================================================
    // │                           Messaging                          │
    // ================================================================

    /**   CAMBIAR NOMBRE A receiveMessage?
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
    ) external payable {
        require(
            destAddresesPerChainId[_sourceBC] != address(0),
            "Source blockchain not supported"
        );

        // Calls verification contract
        IVerification _verification = IVerification(
            verificationContractAddress
        );
        uint256[] memory _inboundMessageNumbers = new uint256[](
            _messages.length
        );
        bool[] memory _inboundSuccessfull = new bool[](_messages.length);
        string[] memory _failureReasons = new string[](_messages.length);
        for (uint256 i = 0; i < _messages.length; i++) {
            _inboundMessageNumbers[i] = _messages[i].messageNumber;
            if (
                inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                    _messages[i].messageNumber
                ] == IncomingMsgStatus.Delivered
            ) {
                _inboundSuccessfull[i] = false;
                _failureReasons[i] = "Inbound: Message already delivered";
                continue;
            }
            if (
                inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                    _messages[i].messageNumber
                ] == IncomingMsgStatus.Cancelled
            ) {
                _inboundSuccessfull[i] = false;
                _failureReasons[i] = "Inbound: Message already canceled";
                continue;
            }
            if (
                !_verification.verifyFinality(
                    _sourceBC,
                    _sourceBlockNumbers[i] + _messages[i].finalityNBlocks
                )
            ) {
                _inboundSuccessfull[i] = false;
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
                _inboundSuccessfull[i] = false;
                _failureReasons[i] = "Inbound: Invalid Message hash";
                continue;
            }

            _inboundSuccessfull[i] = true;

            inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                _messages[i].messageNumber
            ] = IncomingMsgStatus.Delivered;

            // Call the target contract's function to handle the message
            (bool success, ) = _messages[i].receiver.call(
                abi.encodeWithSignature(
                    "handleMessage(bytes)",
                    _messages[i].data
                )
            );

            if (!success) {
                // Change msg status to failed
                inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                    _messages[i].messageNumber
                ] = IncomingMsgStatus.Failed;
                _failureReasons[i] = "On chain: message execution failed";
                continue;
            }
        }
        // This event is listened to by relayers to earn their fees
        emit InboundMessages(
            _relayer,
            _sourceBC,
            _inboundMessageNumbers,
            _inboundSuccessfull,
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
