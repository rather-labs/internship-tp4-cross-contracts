// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// For debugging -- Comment for deployment
import "hardhat/console.sol";

contract Verification is Ownable {
    /**
     * @notice Log information required to verify proof
     */
    struct Log {
        address eventAddress;
        bytes data;
        bytes[] topic;
    }
    /**
     * @notice Receipt information required to validate proof
     */
    struct Receipt {
        string status;
        string txType;
        uint256 cumulativeGasUsed;
        bytes logsBloom;
        Log[] logs;
        uint256 recChainId;
        uint256 recBlockNumber;
        address recAddress;
    }

    /**
     * @notice Addresses allowed to act as Oracles
     */
    mapping(address => bool) public allowedOracles;

    /**
     * @notice Tracks receipt trie root per source blockchain and blocknumber
     */
    mapping(uint256 => mapping(uint256 => bytes32))
        public recTrieRootPerChainIdAndBlocknumber;

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
        require(allowedOracles[msg.sender], "Oracle not authorized");
        _;
    }

    /* BRIDGE FUNCTIONS */

    function verifyFinality(
        uint256 _blockchain,
        uint256 _finalityBlock
    ) public view returns (bool) {
        return (blocknumberPerChainId[_blockchain] >= _finalityBlock);
    }

    /**
     * @notice Verifies a Merkle proof for an incoming message from an external source.
     * @param _receipt Blocknumber of the receipt to be verified.
     * @param _proof The Merkle proof.
     */
    function verifyMessage(
        Receipt calldata _receipt,
        bytes32[] calldata _proof
    ) public view returns (bool) {
        // check that endpoint address is allowed
        require(
            addressesPerChainId[_receipt.recChainId][_receipt.recAddress],
            "Event from an unauthorized endpoint"
        );

        // TODO: Serialize and encode receipt
        bytes32 encodedReceipt;

        return
            MerkleProof.verify(
                _proof,
                recTrieRootPerChainIdAndBlocknumber[_receipt.recChainId][
                    _receipt.recBlockNumber
                ],
                encodedReceipt
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
     * @notice Sets receipt trie root per blockchain and blocknumber.
     * @param _blockchain Blockchain identification.
     * @param _blocknumber Message number.
     * @param _recTrieRoot Receipt trie root.
     */
    function setRecTrieRoot(
        uint256 _blockchain,
        uint256 _blocknumber,
        bytes32 _recTrieRoot
    ) public onlyOracles {
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
    ) public onlyOracles {
        console.log(_blockchain, _blocknumber);
        blocknumberPerChainId[_blockchain] = _blocknumber;
    }
}
