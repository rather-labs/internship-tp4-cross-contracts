// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

// For debugging -- Comment for deployment
import "hardhat/console.sol";

interface IVerification {
    /**
     * @notice message delivered
     */
    struct MessagesDelivered {
        address relayer;
        uint256 sourceBC;
        uint256[] messageNumbers;
    }

    function checkAllowedRelayers(address _sender) external view returns (bool);

    function verifyFinality(
        uint256 _blockchain,
        uint256 _finalityBlock
    ) external view returns (bool);

    function verifyMessageDelivery(
        MessagesDelivered calldata _messageDelivery,
        address _msgAddress,
        uint256 _destinationBC,
        uint256 _destinationBlockNumber
    ) external view returns (bool);
}

contract OutgoingCommunication is Ownable {
    address verificationContractAddress;

    /**
     * @notice Status for outgoing messaages
     */
    enum OutgoingMsgStatus {
        Undefined,
        Emitted,
        Payed,
        Cancelled
    }

    /**
     * @notice Indicates that a new message is sent outside the blockchain
     * @param data message to be sent
     * @param sender address of the message sender
     * @param receiver address of the receiver in the destination blockchain
     * @param destinationBC Id of the blockchain to relay the message to
     * @param finalityNBlocks Number of blocks for the message to reach finality
     * @param messageNumber Number of message, unique per destintation blockchain
     * @param taxi Indicates whether bus or taxi is used for reception confirmation event
     * @param fee fee to pay gas fees and the incentive for the relayer
     */
    event OutboundMessage(
        bytes data,
        address sender,
        address receiver,
        uint256 destinationBC,
        uint16 finalityNBlocks,
        uint256 messageNumber,
        bool taxi,
        uint256 fee
    );

    /**
     * @notice Indicates which message fees have already been paid
     * @param destinationBC Id of the destination blockchain for messages
     * @param messageNumbers Number of messages
     */
    event MessageDeliveryPaid(uint256 destinationBC, uint256[] messageNumbers);

    /**
     * @notice Indicates that the fees associated to a previously emmited msg are updated
     * @param destinationBC Id of the blockchain to relay the message to
     * @param fee fee to pay gas fees and the incentive for the relayer
     * @param messageNumber Number of message, unique per destination blockchain
     */
    event UpdateMessageFee(
        uint256 destinationBC,
        uint256 fee,
        uint256 messageNumber
    );

    /**
     * @notice Tracks processed outgoing message status per destination blockchain.
     */
    mapping(uint256 => mapping(uint256 => OutgoingMsgStatus))
        public outMsgStatusPerChainIdAndMsgNumber;

    /**
     * @notice Tracks outgoing message numbers.
     */
    mapping(uint256 => uint256) public outgoingMsgNumberPerDestChain;

    /**
     * @notice Tracks message fees per destintation blockchain.
     */
    mapping(uint256 => mapping(uint256 => uint256))
        public msgFeePerDestChainIdAndNumber;

    /**
     * @notice Communication contract addreses per destination blockchain.
     */
    mapping(uint256 => address) public destAddresesPerChainId;

    constructor(
        uint256[] memory _blockChainIds,
        address[] memory _blockChainAddresses,
        address _verificationAdress
    ) payable Ownable(msg.sender) {
        for (uint i = 0; i < _blockChainIds.length; i++) {
            destAddresesPerChainId[_blockChainIds[i]] = _blockChainAddresses[i];
        }
        verificationContractAddress = _verificationAdress;
    }

    /* BRIDGE FUNCTIONS */

    /**
     * @notice Updates the message fee for an already emitted message.
     * @dev
     * @param _destinationBC Destintation blockchain for message.
     * @param _messageNumber Number of message to be updated.
     */
    function updateMessageFee(
        uint256 _destinationBC,
        uint256 _messageNumber
    ) external payable {
        if (
            outMsgStatusPerChainIdAndMsgNumber[_destinationBC][
                _messageNumber
            ] == OutgoingMsgStatus.Undefined
        ) {
            revert("Trying to update the fee for an undefined message");
        }
        if (
            outMsgStatusPerChainIdAndMsgNumber[_destinationBC][
                _messageNumber
            ] == OutgoingMsgStatus.Payed
        ) {
            revert(
                "Trying to update the fee for an already delivered and paid message"
            );
        }
        if (
            outMsgStatusPerChainIdAndMsgNumber[_destinationBC][
                _messageNumber
            ] == OutgoingMsgStatus.Cancelled
        ) {
            revert("Trying to update the fee for a cancelled message");
        }
        msgFeePerDestChainIdAndNumber[_destinationBC][_messageNumber] += msg
            .value;
        emit UpdateMessageFee(
            _destinationBC,
            msgFeePerDestChainIdAndNumber[_destinationBC][_messageNumber],
            _messageNumber
        );
    }

    /**
     * @notice send a message from other contracts within the chain and forward it outside the chain.
     * @dev
     * @param _message The message to process.
     * @param _receiver Address of receiver in destintation BC.
     * @param _destinationBC Destination BC.
     * @param _finalityNBlocks Number of blocks to reach finality.
     * @param _taxi Whether delivery event is emmited as soon as possible with the
     * associated extra cost or it waits to pool suficient ammount of msg deliveries.
     */
    function sendMessage(
        bytes calldata _messageData,
        address _receiver,
        uint256 _destinationBC,
        uint16 _finalityNBlocks,
        bool _taxi
    ) external payable {
        require(
            destAddresesPerChainId[_destinationBC] != address(0),
            "Destination blockchain not supported"
        );

        outgoingMsgNumberPerDestChain[_destinationBC]++;

        emit OutboundMessage(
            _messageData,
            msg.sender,
            _receiver,
            _destinationBC,
            _finalityNBlocks,
            outgoingMsgNumberPerDestChain[_destinationBC],
            _taxi,
            msg.value
        );
    }

    /**
     * @notice Transfer fees to the relayer that forwarded the message.
     * @param _messagesDelivered Information of delivery event.
     * @param _destinationBC Destination blockchain.
     * @param _destinationBlockNumber Destination blockchain.
     * @param _destinationEndpoint Destination endpoint address.
     */
    function payRelayer(
        IVerification.MessagesDelivered calldata _messagesDelivered,
        uint256 _destinationBC,
        uint256 _destinationBlockNumber,
        address _destinationEndpoint
    ) external payable {
        // Calls verification contract
        IVerification _verification = IVerification(
            verificationContractAddress
        );
        require(
            _verification.checkAllowedRelayers(msg.sender),
            "Relayer not authorized"
        );
        require(
            _verification.verifyFinality(
                _destinationBC,
                _destinationBlockNumber + 32 // TODO: Implement per chain finality condition
            ),
            "Finality not reached for message delivery"
        );

        // Verify proof before accepting delivery
        require(
            _verification.verifyMessageDelivery(
                _messagesDelivered,
                _destinationEndpoint,
                _destinationBC,
                _destinationBlockNumber
            ),
            "Invalid message delivery data"
        );
        uint256 _feeToPay = 0;
        //uint256[] memory _messageNumbers = [];
        for (uint256 i = 0; i < _messagesDelivered.messageNumbers.length; i++) {
            // Sends the fee asociated with the message and the relayer address
            _feeToPay = msgFeePerDestChainIdAndNumber[_destinationBC][
                _messagesDelivered.messageNumbers[i]
            ];
            msgFeePerDestChainIdAndNumber[_destinationBC][
                _messagesDelivered.messageNumbers[i]
            ] = 0;
            (bool success, ) = _messagesDelivered.relayer.call{
                value: _feeToPay
            }("");
            if (!success) {
                msgFeePerDestChainIdAndNumber[_destinationBC][
                    _messagesDelivered.messageNumbers[i]
                ] = _feeToPay;
                revert("Call failed");
            }
        }
        //emit MessageDeliveryPaid(uint256 destin_destinationBCationBC, _messageNumbers)
    }

    /* ENDPOINT MAINTAINANCE FUNCTIONS */

    // TODO: Function to add new supported BCs (require contract owner)
    // TODO: Function to deposit/withdraw funds from contract (require contract owner)
    // TODO: Function to change destination blockchain addresses (require contract owner)
    // TODO: Add proof verification to test message reception events

    /**
     * @notice Sets belance from address.
     */
    function getBalance() public view returns (uint256) {
        console.log(address(this).balance);
        return address(this).balance;
    }
}
