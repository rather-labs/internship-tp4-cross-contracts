// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Rlp.sol";
import "./ProofVerficitation.sol";

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
        address relayer;
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
     * @notice Tracks receipt trie root per source blockchain and block number
     */
    mapping(uint256 => mapping(uint256 => bytes32))
        public recTrieRootPerChainIdAndBlockNumber;

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

    modifier onlyOracles(address _sender) {
        require(allowedOracles[_sender], "Oracle not authorized");
        _;
    }

    modifier recTrieRootReceived(bytes32 recTrieRoot) {
        require(
            recTrieRoot != bytes32(0),
            "Block receipt trie root not yet recieved"
        );
        _;
    }

    modifier authEndpoint(uint256 _blockchain, address _address) {
        require(
            addressesPerChainId[_blockchain][_address],
            "Event from an unauthorized endpoint"
        );
        _;
    }

    function checkAllowedRelayers(
        address _sender
    ) external view returns (bool) {
        return (allowedRelayers[_sender]);
    }

    /* BRIDGE FUNCTIONS */

    function verifyFinality(
        uint256 _blockchain,
        uint256 _finalityBlock
    ) external view returns (bool) {
        return (blocknumberPerChainId[_blockchain] >= _finalityBlock);
    }

    /**
     * @notice Verifies a message emition.
     * @param _receipt Receipt that has to be verified.
     * @param _proof Proof of inclusion for the receipt.
     * @param _msgAddress Endpoint that emits the message
     * @param _sourceBC Source block for the receipt trie root.
     * @param _sourceBlockNumber BlockNumber for the receipt trie root.
     */
    function verifyReceipt(
        RlpEncoding.Receipt calldata _receipt,
        bytes[] memory _proof,
        address _msgAddress,
        uint256 _sourceBC,
        uint256 _sourceBlockNumber
    )
        external
        view
        authEndpoint(_sourceBC, _msgAddress)
        recTrieRootReceived(
            recTrieRootPerChainIdAndBlockNumber[_sourceBC][_sourceBlockNumber]
        )
        returns (bool)
    {
        return
            ProofVerification.verifyTrieProof(
                recTrieRootPerChainIdAndBlockNumber[_sourceBC][
                    _sourceBlockNumber
                ],
                _proof,
                RlpEncoding.encodeReceipt(_receipt),
                _receipt.rlpEncTxIndex
            );
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
        allowedRelayers[_relayerAddress] = _isAllowed;
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
     * @param _blockNumber Block number.
     * @param _reciptTrieRoot Receipt trie root.
     */
    function setRecTrieRoot(
        uint256 _sourceBC,
        uint256 _blockNumber,
        bytes32 _reciptTrieRoot
    ) public onlyOracles(msg.sender) {
        recTrieRootPerChainIdAndBlockNumber[_sourceBC][
            _blockNumber
        ] = _reciptTrieRoot;
    }

    /**
     * @notice Sets last confirmed block of the blockchain.
     * @param _blockchain blockchain identification.
     * @param _blocknumber blockchain number.
     */
    function setLastBlock(
        uint256 _blockchain,
        uint256 _blocknumber
    ) public onlyOracles(msg.sender) {
        blocknumberPerChainId[_blockchain] = _blocknumber;
    }
}
