// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

// For debugging -- Comment for deployment
import "hardhat/console.sol";

contract Verification is Ownable {
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
     * @notice message delivered
     */
    struct MessagesDelivered {
        address[] relayers;
        uint256 sourceBC;
        uint256[] messageNumbers;
    }

    /**
     * @notice Addresses allowed to act as Oracles
     */
    mapping(address => bool) public allowedOracles;

    /**
     * @notice Addresses allowed to act as relayers
     */
    mapping(address => bool) public allowedRelayers;

    /**
     * @notice Tracks message hash per source blockchain and message number
     */
    mapping(uint256 => mapping(uint256 => bytes32))
        public msgHashPerChainIdAndMsgNumber;

    /**
     * @notice Tracks message delivery hash per source blockchain and message number
     * @dev In bus mode, stores the first message of the array
     */
    mapping(uint256 => mapping(uint256 => bytes32))
        public msgDeliveryHashPerChainIdAndMsgNumber;

    /**
     * @notice Tracks blocknumber data per blockchhain
     */
    mapping(uint256 => uint256) public blocknumberPerChainId;

    /**
     * @notice Tracks endpoint addresses per blockchhain
     */
    mapping(uint256 => mapping(address => bool)) public addressesPerChainId;

    constructor(
        uint256[] memory _blockChainIds,
        uint256[] memory _blockChainNumber,
        address[][] memory _adddresses
    ) Ownable(msg.sender) {
        for (uint i = 0; i < _blockChainIds.length; i++) {
            blocknumberPerChainId[_blockChainIds[i]] = _blockChainNumber[i];
            for (uint j = 0; j < _adddresses[i].length; j++) {
                addressesPerChainId[_blockChainIds[i]][
                    _adddresses[i][j]
                ] = true;
            }
        }
    }

    modifier onlyOracles() {
        //require(allowedOracles[msg.sender], "Oracle not authorized");
        _;
    }

    modifier onlyRelayers() {
        require(allowedRelayers[msg.sender], "Relayer not authorized");
        _;
    }

    modifier onlyThisChain(uint256 chainId) {
        require(chainId == block.chainid, "Event not intended for this chain");
        _;
    }

    modifier hashReceived(bytes32 eventHash) {
        require(eventHash == bytes32(0), "Event hash not yet recieved");
        _;
    }

    modifier authEndpoint(uint256 _blockchain, address _address) {
        require(
            addressesPerChainId[_blockchain][_address],
            "Event from an unauthorized endpoint"
        );
        _;
    }

    /* BRIDGE FUNCTIONS */

    function verifyFinality(
        uint256 _blockchain,
        uint256 _finalityBlock
    ) public view onlyRelayers returns (bool) {
        return (blocknumberPerChainId[_blockchain] >= _finalityBlock);
    }

    /**
     * @notice Verifies a message emition.
     * @param _message Message that has to be verified.
     * @param _msgAddress Endpoint that emits the message
     */
    function verifyMessage(
        Message calldata _message,
        address _msgAddress,
        uint256 _sourceBC,
        uint256 _sourceBlockNumber
    )
        public
        view
        onlyRelayers
        onlyThisChain(_message.destinationBC)
        authEndpoint(_sourceBC, _msgAddress)
        hashReceived(
            msgHashPerChainIdAndMsgNumber[_sourceBC][_message.messageNumber]
        )
        returns (bool)
    {
        // Serialize and hash message receipt
        bytes32 hashedData = keccak256(
            abi.encode(
                _message.data,
                _message.sender,
                _message.receiver,
                _message.finalityNBlocks,
                _message.messageNumber,
                _sourceBC,
                _sourceBlockNumber
            )
        );

        return (hashedData ==
            msgHashPerChainIdAndMsgNumber[_sourceBC][_message.messageNumber]);
    }

    /**
     * @notice Verifies a message delivery event.
     * @param _messagesDelivered Message delivery event information.
     * @param _msgAddress Endpoint that emits the event
     * @param _destinationBC Endpoint that emits the event
     * @param _destinationBlockNumber Endpoint that emits the event
     */
    function verifyMessageDelivery(
        MessagesDelivered calldata _messagesDelivered,
        address _msgAddress,
        uint256 _destinationBC,
        uint256 _destinationBlockNumber
    )
        public
        view
        onlyRelayers
        onlyThisChain(_messagesDelivered.sourceBC)
        authEndpoint(_destinationBC, _msgAddress)
        hashReceived(
            msgDeliveryHashPerChainIdAndMsgNumber[_destinationBC][
                _messagesDelivered.messageNumbers[0]
            ]
        )
        returns (bool)
    {
        // Serialize and hash message receipt
        bytes32 hashedData = keccak256(
            abi.encode(
                _messagesDelivered.relayers,
                _messagesDelivered.sourceBC,
                _messagesDelivered.messageNumbers,
                _destinationBC,
                _destinationBlockNumber
            )
        );

        return (hashedData ==
            msgDeliveryHashPerChainIdAndMsgNumber[_destinationBC][
                _messagesDelivered.messageNumbers[0]
            ]);
    }

    /* ENDPOINT MAINTAINANCE FUNCTIONS */

    /**
     * @notice Modifies which addresses can act as Oracles.
     * @param _oracleAddress Oracle Address in the blockchain.
     * @param _isAllowed whether it's allowed or not.
     */
    function modifyOracleAddresses(
        address _oracleAddress,
        bool _isAllowed
    ) public onlyOwner {
        allowedOracles[_oracleAddress] = _isAllowed;
    }

    /**
     * @notice Modifies which addresses can act as Relayers.
     * @param _relayerAddress Oracle Address in the blockchain.
     * @param _isAllowed whether it's allowed or not.
     */
    function modifyRelayerAddresses(
        address _relayerAddress,
        bool _isAllowed
    ) public onlyOwner {
        allowedOracles[_relayerAddress] = _isAllowed;
    }

    /**
     * @notice Modifies which blockchains are supported.
     * @param _blockChainNumber Blockchain identification.
     * @param _blockNumber Current block number, 0 indicates that it's not supported.
     */
    function modifyAllowedChains(
        uint256 _blockChainNumber,
        uint256 _blockNumber
    ) public onlyOwner {
        blocknumberPerChainId[_blockChainNumber] = _blockNumber;
    }

    /**
     * @notice Modifies which endpoints are allowed.
     * @param _blockChainNumber Blockchain identification.
     * @param _address Current block number, 0 indicates that it's not supported.
     */
    function modifyEndPoints(
        uint256 _blockChainNumber,
        address _address,
        bool _isAllowed
    ) public onlyOwner {
        addressesPerChainId[_blockChainNumber][_address] = _isAllowed;
    }

    /* ORACLE FUNCTIONS */

    /**
     * @notice Sets message hash per blockchain and message number.
     * @param _sourceBC Blockchain identification that emits the event.
     * @param _messageNumber Message number.
     * @param _msgHash Hash of msg information.
     */
    function setMsgHash(
        uint256 _sourceBC,
        uint256 _messageNumber,
        bytes32 _msgHash
    ) public onlyOracles {
        msgHashPerChainIdAndMsgNumber[_sourceBC][_messageNumber] = _msgHash;
    }

    /**
     * @notice Sets message delivery hash per blockchain and message number.
     * @param _destinationBC Blockchain identification that emits the event.
     * @param _messageNumber Message number.
     * @param _msgDeliveryHash Hash of msg information.
     */
    function setMsgDeliveryHash(
        uint256 _destinationBC,
        uint256 _messageNumber,
        bytes32 _msgDeliveryHash
    ) public onlyOracles {
        msgDeliveryHashPerChainIdAndMsgNumber[_destinationBC][
            _messageNumber
        ] = _msgDeliveryHash;
    }

    /**
     * @notice Sets last confirmed block of the blockchain.
     * @param _blockchain blockchain identification.
     * @param _blocknumber blockchain number.
     */
    function setLastBlock(
        uint256 _blockchain,
        uint256 _blocknumber
    ) public onlyOracles {
        blocknumberPerChainId[_blockchain] = _blocknumber;
    }
}
