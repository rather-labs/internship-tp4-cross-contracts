// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "hardhat/console.sol";

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
        bytes cumulativeGasUsed;
        bytes logsBloom;
        Log[] logs;
        bytes txType;
        bytes rlpEncTxIndex;
    }

    // Function to convert a bytes array to uint8 array
    function bytesToUint8Array(
        bytes memory _bytes
    ) internal pure returns (uint8[] memory) {
        uint8[] memory result = new uint8[](_bytes.length);
        for (uint i = 0; i < _bytes.length; i++) {
            result[i] = uint8(_bytes[i]); // Convert each byte to uint8
        }
        return result;
    }

    function bytesToHex(
        bytes memory _bytes
    ) internal pure returns (string memory) {
        bytes memory hexBytes = new bytes(_bytes.length * 2);
        bytes16 hexSymbols = "0123456789abcdef";

        for (uint i = 0; i < _bytes.length; i++) {
            hexBytes[i * 2] = hexSymbols[uint8(_bytes[i] >> 4)]; // Get the higher nibble (first 4 bits)
            hexBytes[i * 2 + 1] = hexSymbols[uint8(_bytes[i] & 0x0f)]; // Get the lower nibble (last 4 bits)
        }

        return string(hexBytes);
    }

    ///**
    // * @dev Encode the first byte, followed by the `len` in binary form if `length` is more than 55.
    // * @param len The length of the string or the payload.
    // * @param offset 128 if item is string, 192 if item is list.
    // * @return RLP encoded bytes.
    // */
    function encodeLength(
        uint len,
        uint offset
    ) internal pure returns (bytes memory) {
        bytes memory encoded;
        if (len < 56) {
            encoded = new bytes(1);
            encoded[0] = bytes32(len + offset)[31];
        } else {
            uint lenLen;
            uint i = 1;
            while (len / i != 0) {
                lenLen++;
                i *= 256;
            }

            encoded = new bytes(lenLen + 1);
            encoded[0] = bytes32(lenLen + offset + 55)[31];
            for (i = 1; i <= lenLen; i++) {
                encoded[i] = bytes32((len / (256 ** (lenLen - i))) % 256)[31];
            }
        }
        return encoded;
    }

    /**
     * @dev RLP encodes a byte string.
     * @param byteString The byte string to encode.
     * @return The RLP encoded string in bytes.
     */
    function encodeBytes(
        bytes memory byteString
    ) internal pure returns (bytes memory) {
        bytes memory encoded;
        if (byteString.length == 1 && uint8(byteString[0]) < 128) {
            encoded = byteString;
        } else {
            encoded = abi.encodePacked(
                encodeLength(byteString.length, 128),
                byteString
            );
        }
        return encoded;
    }

    /**
     * @dev RLP encodes a list of RLP encoded byte byte strings.
     * @param list The list of RLP encoded byte strings.
     * @return The RLP encoded list of items in bytes.
     */
    function encodeList(
        bytes[] memory list
    ) internal pure returns (bytes memory) {
        bytes memory encoded;
        for (uint i = 0; i < list.length; i++) {
            encoded = abi.encodePacked(encoded, encodeBytes(list[i]));
        }
        return abi.encodePacked(encodeLength(encoded.length, 192), encoded);
    }

    function encodeReceipt(
        Receipt memory _receipt
    ) internal pure returns (bytes memory) {
        bytes memory _encodedLogs;
        bytes[] memory _encodedLog = new bytes[](3);
        for (uint i = 0; i < _receipt.logs.length; i++) {
            _encodedLog[0] = encodeBytes(
                abi.encodePacked(_receipt.logs[i].txAddress)
            );
            _encodedLog[1] = encodeList(_receipt.logs[i].topics);
            _encodedLog[2] = encodeBytes(_receipt.logs[i].data);
            _encodedLogs = abi.encodePacked(
                _encodedLogs,
                encodeLength(
                    _encodedLog[0].length +
                        _encodedLog[1].length +
                        _encodedLog[2].length,
                    192
                ),
                _encodedLog[0],
                _encodedLog[1],
                _encodedLog[2]
            );
        }

        bytes[] memory _receiptData = new bytes[](4);
        _receiptData[0] = encodeBytes(_receipt.status);
        _receiptData[1] = encodeBytes(_receipt.cumulativeGasUsed);
        _receiptData[2] = encodeBytes(_receipt.logsBloom);
        _receiptData[3] = abi.encodePacked(
            encodeLength(_encodedLogs.length, 192),
            _encodedLogs
        );
        bytes memory encodedReceipt = abi.encodePacked(
            encodeLength(
                _receiptData[0].length +
                    _receiptData[1].length +
                    _receiptData[2].length +
                    _receiptData[3].length,
                192
            ),
            _receiptData[0],
            _receiptData[1],
            _receiptData[2],
            _receiptData[3]
        );

        if (keccak256(_receipt.txType) != keccak256(hex"00")) {
            return abi.encodePacked(_receipt.txType, encodedReceipt);
        }
        return encodedReceipt;
    }
}
