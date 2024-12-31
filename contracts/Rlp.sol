// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

//import "hardhat/console.sol";

library RlpEncoding {
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
        uint256 cumulativeGasUsed;
        bytes logsBloom;
        Log[] logs;
        bytes txType;
        bytes rlpEncTxIndex;
    }

    function uintToCompactBytes(
        uint256 value
    ) public pure returns (bytes memory) {
        // Count the number of non-zero bytes (start from the highest byte)
        uint256 temp = value;
        uint256 nonZeroLength = 0;

        while (temp != 0) {
            nonZeroLength++;
            temp >>= 8; // Shift right by one byte
        }

        // Create a bytes array of the required length
        bytes memory result = new bytes(nonZeroLength);
        for (uint256 i = 0; i < nonZeroLength; i++) {
            result[nonZeroLength - 1 - i] = bytes1(uint8(value)); // Extract the least significant byte
            value >>= 8; // Shift right by one byte
        }

        return result;
    }

    ///**
    // * @dev Encode the first byte, followed by the `len` in binary form if `length` is more than 55.
    // * @param len The length of the string or the payload.
    // * @param offset 128 if item is string, 192 if item is list.
    // * @return RLP encoded bytes.
    // */
    function encodeLength(
        uint256 length,
        uint256 offset
    ) internal pure returns (bytes memory) {
        if (length < 56) {
            // If length is less than 56, use a single byte.
            return abi.encodePacked(uint8(length + offset));
        } else {
            // If length is 56 or more, encode the length of the length.
            uint256 tempLength = length;
            uint256 lenLength = 0;
            while (tempLength != 0) {
                lenLength++;
                tempLength >>= 8;
            }

            bytes memory lengthBytes = new bytes(lenLength);
            for (uint256 i = 0; i < lenLength; i++) {
                lengthBytes[lenLength - 1 - i] = bytes1(
                    uint8(length >> (i * 8))
                );
            }

            return
                abi.encodePacked(uint8(lenLength + offset + 55), lengthBytes);
        }
    }

    /**
     * @dev RLP encodes a byte string.
     * @param byteString The byte string to encode.
     * @return The RLP encoded string in bytes.
     */
    function encodeBytes(
        bytes memory byteString
    ) internal pure returns (bytes memory) {
        if (byteString.length == 1 && uint8(byteString[0]) < 128) {
            return byteString;
        }
        return
            abi.encodePacked(encodeLength(byteString.length, 128), byteString);
    }

    /**
     * @dev RLP encodes a list of RLP encoded byte byte strings.
     * @param list The list of RLP encoded byte strings or pure items.
     * @param itemsRLPEncoded Whether the items are already RLP encoded.
     * @return The RLP encoded list of items in bytes.
     */
    function encodeList(
        bytes[] memory list,
        bool itemsRLPEncoded
    ) internal pure returns (bytes memory) {
        bytes memory encoded;
        if (itemsRLPEncoded) {
            for (uint i = 0; i < list.length; i++) {
                encoded = abi.encodePacked(encoded, list[i]);
            }
        } else {
            for (uint i = 0; i < list.length; i++) {
                encoded = abi.encodePacked(encoded, encodeBytes(list[i]));
            }
        }
        return abi.encodePacked(encodeLength(encoded.length, 192), encoded);
    }

    function encodeReceipt(
        Receipt memory _receipt
    ) internal pure returns (bytes memory) {
        bytes[] memory _encodedLogs = new bytes[](_receipt.logs.length);
        for (uint i = 0; i < _receipt.logs.length; i++) {
            bytes[] memory _encodedLog = new bytes[](3);
            _encodedLog[0] = encodeBytes(
                abi.encodePacked(_receipt.logs[i].txAddress)
            );
            _encodedLog[1] = encodeList(_receipt.logs[i].topics, false);
            _encodedLog[2] = encodeBytes(_receipt.logs[i].data);
            _encodedLogs[i] = encodeList(_encodedLog, true);
        }

        bytes[] memory _receiptData = new bytes[](4);
        _receiptData[0] = encodeBytes(_receipt.status);
        _receiptData[1] = encodeBytes(
            uintToCompactBytes(_receipt.cumulativeGasUsed)
        );
        _receiptData[2] = encodeBytes(_receipt.logsBloom);
        _receiptData[3] = encodeList(_encodedLogs, true);

        bytes memory encodedReceipt = encodeList(_receiptData, true);

        if (keccak256(_receipt.txType) != keccak256(hex"00")) {
            return abi.encodePacked(_receipt.txType, encodedReceipt);
        }
        return encodedReceipt;
    }
}
