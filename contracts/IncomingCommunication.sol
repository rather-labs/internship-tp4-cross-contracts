// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

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

    /**
     * @notice Log information
     */
    struct Log {
        address txAddress;
        bytes[] topics;
        bytes data;
    }
    /**
     * @notice Receipt information
     */
    struct Receipt {
        bytes status;
        bytes cumulativeGasUsed;
        bytes logsBloom;
        Log[] logs;
        bytes txType;
        bytes rlpEncTxIndex;
    }

    function checkAllowedRelayers(address _sender) external view returns (bool);

    function verifyFinality(
        uint256 _blockchain,
        uint256 _finalityBlock
    ) external view returns (bool);

    function verifyReceipt(
        Receipt calldata _receipt,
        bytes[] memory _proof,
        address _msgAddress,
        uint256 _sourceBC,
        uint256 _sourceBlockNumber
    ) external view returns (bool);
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
        uint256 messageNumber
    );

    /** ADD TAXI/BUS, define struct with 
     * @notice Indicates that a new message is received from outside the blockchain
     * @dev
     * @param messageNumber message nonce
     * @param sourceBC source blockchain
     */ 
    event MessageSent(
        uint256 messageNumber,
        uint256 sourceBC
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

    function decodeMessage(
        bytes memory _data
    ) internal pure returns (IVerification.Message memory) {
        IVerification.Message memory _message;
        (
            bytes memory _dataMsg,
            address _sender,
            address _receiver,
            uint256 _destinationBC,
            uint16 _finalityNBlocks,
            uint256 _messageNumber,
            bool _taxi,
            uint256 _fee
        ) = abi.decode(
                _data,
                (
                    bytes,
                    address,
                    address,
                    uint256,
                    uint16,
                    uint256,
                    bool,
                    uint256
                )
            );
        _message.data = _dataMsg;
        _message.sender = _sender;
        _message.receiver = _receiver;
        _message.destinationBC = _destinationBC;
        _message.finalityNBlocks = _finalityNBlocks;
        _message.messageNumber = _messageNumber;
        _message.taxi = _taxi;
        _message.fee = _fee;
        return _message;
    }

    /*
     * @notice Receive a message from outside chain.
     * @param _relayer address to pay relayer on source blockchain
     * @param _sourceBC Id of the source blockchain
     * @param _sourceBlockNumbers Blocknumbers for each message emmission
     */
    function inboundMessages(
        IVerification.Receipt[] calldata _receipts,
        bytes[][] memory _proofs,
        address _relayer,
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
            _receipts.length
        );
        bool[] memory _successfullInbound = new bool[](_receipts.length);
        string[] memory _failureReasons = new string[](_receipts.length);

        // Proceed with decoding
        IVerification.Message memory _message;
        for (uint i = 0; i < _receipts.length; i++) {
            if (_receipts[i].logs.length == 0) {
                _inboundMessageNumbers[i] = 0;
                _successfullInbound[i] = false;
                _failureReasons[i] = "Inbound: Receipt with no events given";
                continue;
            }
            // Get message information
            // Check for event emmited by outgoing endpoint
            // The emit function transaction only emits one event
            for (uint j = 0; j < _receipts[i].logs.length; j++) {
                if (
                    (sourceAddresesPerChainId[_sourceBC] ==
                        _receipts[i].logs[j].txAddress)
                ) {
                    _message = decodeMessage(_receipts[i].logs[j].data);
                    break;
                }
            }
            _inboundMessageNumbers[i] = _message.messageNumber;
            if (
                inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                    _message.messageNumber
                ] == IncomingMsgStatus.Delivered
            ) {
                _successfullInbound[i] = false;
                _failureReasons[i] = "Inbound: Message already delivered";
                continue;
            }
            if (
                inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                    _message.messageNumber
                ] == IncomingMsgStatus.Cancelled
            ) {
                _successfullInbound[i] = false;
                _failureReasons[i] = "Inbound: Message already cancelled";
                continue;
            }
            if (
                !_verification.verifyFinality(
                    _sourceBC,
                    _sourceBlockNumbers[i] + _message.finalityNBlocks
                )
            ) {
                _successfullInbound[i] = false;
                _failureReasons[
                    i
                ] = "Inbound: Finality not reached for message";
                continue;
            }
            if (
                !_verification.verifyReceipt(
                    _receipts[i],
                    _proofs[i],
                    sourceAddresesPerChainId[_sourceBC],
                    _sourceBC,
                    _sourceBlockNumbers[i]
                )
            ) {
                _successfullInbound[i] = false;
                _failureReasons[i] = "Inbound: Invalid inclusion proof";
                continue;
            }

            _successfullInbound[i] = true;

            inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                _message.messageNumber
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
