// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "solidity-rlp/contracts/RLPReader.sol";

// For debugging -- Comment for deployment
//import "hardhat/console.sol";

library ProofVerification {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    /**
     * @notice Verifies a Merkle Patricia Trie proof for a receipt.
     * @param receiptsRoot The root hash of the receipts trie from the block header.
     * @param proofNodes The RLP-encoded proof nodes for the receipt.
     * @param encodedReceipt The RLP-encoded receipt being verified.
     * @param rlpEncodedIndex The transaction index in the block.
     * @return isValid True if the proof is valid, false otherwise.
     */
    function verifyTrieProof(
        bytes32 receiptsRoot,
        bytes[] memory proofNodes,
        bytes memory encodedReceipt,
        bytes memory rlpEncodedIndex
    )
        internal
        pure
        returns (
            //uint txIndex
            bool isValid
        )
    {
        // Start with the root hash
        bytes32 currentNodeHash = receiptsRoot;
        // Traverse the proof nodes
        for (uint256 i = 0; i < proofNodes.length; i++) {
            bytes memory currentNode = proofNodes[i];
            // Hash the current node and ensure it matches the expected hash
            if (currentNodeHash != keccak256(currentNode)) {
                return false; // Proof is invalid
            }
            // Decode the current node to determine the next node hash
            RLPReader.RLPItem[] memory nodeItems = currentNode
                .toRlpItem()
                .toList();
            if (nodeItems.length == 17) {
                uint256 nibbleIndex = i / 2;
                if (nibbleIndex >= rlpEncodedIndex.length) {
                    return false; // Invalid index length
                }
                // Branch node: Use the current nibble of the key to find the next node
                // Extract nibble based on current depth
                uint8 nibble = uint8(rlpEncodedIndex[nibbleIndex]);
                nibble = (i % 2 == 0) ? (nibble >> 4) : (nibble & 0x0F);
                if (nibble >= 16) {
                    return false; // Invalid nibble
                }
                RLPReader.RLPItem memory nextNode = nodeItems[nibble];
                if (nextNode.len == 0) {
                    return false; // Missing child node
                }
                currentNodeHash = bytes32(nextNode.toUint());
            } else if (nodeItems.length == 2) {
                // Leaf node: Verify the encoded receipt
                if (i == proofNodes.length - 1) {
                    return
                        keccak256(nodeItems[1].toBytes()) ==
                        keccak256(encodedReceipt);
                }

                currentNodeHash = bytes32(nodeItems[1].toUint());
            } else {
                return false; // Invalid node structure
            }
        }
        return false; // Proof traversal failed
    }
}
