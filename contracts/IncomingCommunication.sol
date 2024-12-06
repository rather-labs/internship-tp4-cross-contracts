// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./Verification.sol";

// For debugging -- Comment for deployment
import "hardhat/console.sol";

contract IncomingCommunication is Ownable {
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

    /** ADD TAXI/BUS, define struct with 
     * @notice Indicates that a new message is received from outside the blockchain
     * @dev
     * @param messageNumber message nonce
     * @param sourceBC source blockchain
     */ 
    event MessageSent(
        uint256 messageNumber,
        uint256 sourceBC,
    );

    /**
     * @notice Indicates that oracle addresses have been added
     * @dev
     * @param addedOracles List of added oracle addresses
     */
    event OracleAddressesAdded(
        address[] addedOracles
    );

    /**
     * @notice Indicates that oracle addresses have been removed
     * @dev
     * @param removedOracles List of removed oracle addresses
     */
    event OracleAddressesRemoved(
        address[] removedOracles
    );

    // DYNAMIC CONFIG
    /**
     * @notice Set of allowed oracle addresses.
     */
    mapping(address => bool) private s_oracleAddresses;

    /**
     * @notice Tracks processed incoming message status per source blockchain.
     */
    mapping(uint256 => mapping(uint256 => IncomingMsgStatus)) //first  uint256 is message number
        public inMsgStatusPerChainIdAndMsgNumber;

    /**
     * @notice Tracks receipt trie root per source blockchain and blocknumber
     */
    mapping(uint256 => mapping(uint256 => bytes32))
        public recTrieRootPerChainIdAndBlocknumber;

    /**
     * @notice Tracks log data per source blockchain and message number. Used for finality determination.
     */
    mapping(uint256 => mapping(uint256 => bytes))
        public logDataPerChainIdAndMsgNumber;

    /**
     * @notice Tracks blocknumber data per source blockchhain
     */
    mapping(uint256 => uint256) public blocknumberPerChainId;


    constructor(uint[] memory _blockChainIds, address[] memory _oracleAddresses) payable Ownable(msg.sender) {
        for (uint i = 0; i < _blockChainIds.length; i++) {
            blocknumberPerChainId[_blockChainIds[i]] = 1;
        }

        _addOracles(_oracleAddresses);
    }

    // ================================================================
    // │                           Oracles                             │
    // ================================================================

    /**
     * @notice Add oracle addresses to the allowed list.
     * @param _oracleAddresses List of oracle addresses to add.
     */
    function addOracles(address[] calldata _oracleAddresses) external onlyOwner {
        _addOracles(_oracleAddresses);
    }

    /**
     * @notice Remove oracle addresses from the allowed list.
     * @param _oracleAddresses List of oracle addresses to remove.
     */
    function removeOracles(address[] calldata _oracleAddresses) external onlyOwner {
        address[] memory removedOracles = new address[](_oracleAddresses.length);

        for (uint i = 0; i < _oracleAddresses.length; i++) {
            if (s_oracleAddresses[_oracleAddresses[i]]) {
                s_oracleAddresses[_oracleAddresses[i]] = false;
                removedOracles[i] = _oracleAddresses[i];
            }
        }
        emit OracleAddressesRemoved(removedOracles);
    }

    /**
     * @notice Check if an address is an allowed oracle.
     * @param _oracleAddress Address to check.
     * @return True if the address is allowed, false otherwise.
     */
    function isAllowedOracle(address _oracleAddress) external view returns (bool) {
        return s_oracleAddresses[_oracleAddress];
    }

    /**
     * @dev Internal function to add oracle addresses to the allowed list.
     * @param _oracleAddresses List of oracle addresses to add.
     */
    function _addOracles(address[] memory _oracleAddresses) internal {
        address[] memory addedOracles = new address[](_oracleAddresses.length);

        for (uint i = 0; i < _oracleAddresses.length; i++) {
            if (!s_oracleAddresses[_oracleAddresses[i]]) {
                s_oracleAddresses[_oracleAddresses[i]] = true;
                addedOracles[i] = _oracleAddresses[i];
            }
        }
        emit OracleAddressesAdded(addedOracles);
    }

    // ================================================================
    // │                           Messaging                          │
    // ================================================================

    /**   CAMBIAR NOMBRE A receiveMessage?
     * @notice Receive a message from outside chain.
     * @param _proof inclusion proof for receipt trie
     * @param _relayer address to pay relayer on source blockchain
     * @param _sourceBC Id of the source blockchain
     * @param _messageNumber message number
     */
    function inboundMessage(
        //bytes32[] calldata _proof,
        address _relayer,
        uint256 _sourceBC,
        uint256 _messageNumber,
        bytes32 _data, //                    )
        uint256 _destinationBC, //           }     no falta esto??? 
        address _destinationAddress //     )

    ) external payable {
        require(
            inMsgStatusPerChainIdAndMsgNumber[_sourceBC][_messageNumber] ==
                IncomingMsgStatus.Undefined,
            "Message already received"
        );
        require(
            blocknumberPerChainId[_sourceBC] > 0,
            "Not supporte blockchain"
        );
        require(
            s_oracleAddresses[msg.sender],
            "Caller is not an allowed oracle"
        );
        // Check finality
/*         require(
           logDataPerChainIdAndMsgNumber[_sourceBC][_messageNumber]
               .blocknumber +
               logDataPerChainIdAndMsgNumber[_sourceBC][_messageNumber]
                   .data
                   .finalityNBlocks <=
               blocknumberPerChainId[_sourceBC],
           "Finality not reached for message"
        ); */

        // Verify the Merkle proof before forwarding
        require(
            verifyMessage(
                _sourceBC,
                _messageNumber,
                _proof,
                recTrieRootPerChainIdAndBlocknumber[_sourceBC][_messageNumber]
            ),
            "Invalid Merkle proof"
        );

        // This event is listened to by relayers to earn their fees
        emit InboundMessage(_relayer, _sourceBC, _destinationBC, _messageNumber);

        // Execute msg
        // Change msg status to delivered first to avoid re entry
        inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
            _messageNumber
        ] = IncomingMsgStatus.Delivered;

        // Call the target contract's function to handle the message
        (bool success, ) = _destinationAddress.call(
           abi.encodeWithSignature("handleMessage(bytes)", _data)
        );

        if (!success) {
            // Change msg status to failed
            inMsgStatusPerChainIdAndMsgNumber[_sourceBC][
                _messageNumber
            ] = IncomingMsgStatus.Failed;
        }

        require(success, "On-chain message execution failed");
        emit MessageSent(msg.sender, _data, _messageNumber, _destinationAddress);
    }

    /**
     * @notice Verifies a Merkle proof for an incoming message from an external source.
     * @param proof The Merkle proof.
     * @param root The Merkle root.
     */
    function verifyMessage(
        uint256 _sourceBC,
        uint256 _messageNumber,
        bytes32[] calldata proof,
        bytes32 root
    ) private view returns (bool) {
        bytes32 messageHash = keccak256(
            logDataPerChainIdAndMsgNumber[_sourceBC][_messageNumber]
        );
        return MerkleProof.verify(proof, root, messageHash);
    }


    /**
     * @notice Sets message log per blockchain id and message number.
     * @param _blockchain Blockchain identification.
     * @param _messageNumber Message number.
     * @param _logData Log data for the msg emission event.
     */
    function setMsgLog(
        uint256 _blockchain,
        uint256 _messageNumber,
        bytes memory _logData
    ) public onlyOwner {
        logDataPerChainIdAndMsgNumber[_blockchain][_messageNumber] = _logData;
    }

    /**
     * @notice Sets receipt trie root per blockchain and blocknumber.
     * @param _blockchain Blockchain identification.
     * @param _blocknumber Message number.
     * @param _recTrieRoot Log data for the msg emission event.
     */
    function setRecTrieRoot(
        uint256 _blockchain,
        uint256 _blocknumber,
        bytes32 _recTrieRoot
    ) public onlyOwner {
        recTrieRootPerChainIdAndBlocknumber[_blockchain][
            _blocknumber
        ] = _recTrieRoot;
    }

    /**
     * @notice Sets last confirmed block of the blockchain.
     * @param _blockchain blockchain identification.
     * @param _blocknumber blockchain number.
     */
    function setLastBlock(
        uint256 _blockchain,
        uint256 _blocknumber
    ) public onlyOwner {
        console.log(_blockchain, _blocknumber);
        blocknumberPerChainId[_blockchain] = _blocknumber;
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
