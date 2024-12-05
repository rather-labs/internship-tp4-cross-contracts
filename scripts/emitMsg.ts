import hre from "hardhat";
import { ContractTypesMap } from "hardhat/types/artifacts";
import { decodeEventLog, hexToString, parseEther, toBytes, toHex } from "viem";
import { keccak256 } from 'ethereum-cryptography/keccak';

async function main() {
    const [firstWalletClient, secondWalletClient] = await hre.viem.getWalletClients();
    const publicClient = await hre.viem.getPublicClient();
    const contract: ContractTypesMap["OutgoingCommunication"] = await hre.viem.getContractAt(
      "OutgoingCommunication",
      "0x364C7188028348566E38D762f6095741c49f492B",
    );
    // emits message
    const transactionHash = await contract.write.sendMessage(
      [toHex("Mensaje de Prueba"),
       firstWalletClient.account.address,
       31338n,
       12,
       true
      ],
      {
        value: parseEther("0.1"),
        account: firstWalletClient.account
      } );
    
    const eventSignature = "OutboundMessage(bytes,address,address,uint256,uint256,uint16,uint256,bool)"
    const contractABI = [
      {
        type: 'event',
        name: 'OutboundMessage',
        inputs: [
          { name: 'data', type: 'bytes', indexed: false },
          { name: 'sender', type: 'address', indexed: false },
          { name: 'receiver', type: 'address', indexed: false },
          { name: 'destinationBC', type: 'uint256', indexed: false },
          { name: 'finalityNBlocks', type: 'uint16', indexed: false },
          { name: 'messageNumber', type: 'uint256', indexed: false },
          { name: 'taxi', type: 'bool', indexed: false },
          { name: 'fee', type: 'uint256', indexed: false },
        ],
      },
    ];
    const receipt = await publicClient.waitForTransactionReceipt({ hash: transactionHash });
    console.log("Transaction mined:", receipt);
    console.log("Encoded event signature:", toHex(keccak256(toBytes(eventSignature))));
    console.log("Transaction topics:");
    receipt.logs.forEach((log) => {
      console.log(log.topics)
      const decodedLog = decodeEventLog({
        abi: contractABI,
        data: log.data,
        topics: log.topics,
      });
      console.log("Decoded", decodedLog)
      console.log("Data:", hexToString(decodedLog.args?.data))
    })

    
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });