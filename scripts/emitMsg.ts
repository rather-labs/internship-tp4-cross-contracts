import hre from "hardhat";
import { ContractTypesMap } from "hardhat/types/artifacts";
import { decodeEventLog, hexToString, parseEther, toBytes, toHex } from "viem";
const CURRENT_CHAIN_ID = (hre.network.config.chainId?? 0).toString();
const OUT_CHAIN_ADDRESSES:{ [key: string]: string } = { // Outgoing communication contracts
  31337:"0x364C7188028348566E38D762f6095741c49f492B", 
  31338:"0x4B5f648644865DB820490B3DEee14de9DF7fFF39", 
};
async function main() {
    const [firstWalletClient, secondWalletClient] = await hre.viem.getWalletClients();
    const publicClient = await hre.viem.getPublicClient();
    const contract: ContractTypesMap["OutgoingCommunication"] = await hre.viem.getContractAt(
      "OutgoingCommunication",
      OUT_CHAIN_ADDRESSES[CURRENT_CHAIN_ID],
    );
    // emits message
    const transactionHash = await contract.write.sendMessage(
      [toHex("Mensaje de Prueba"),
       firstWalletClient.account.address,
       31338n,
       1,
       true
      ],
      {
        value: parseEther("100", "gwei"),
        account: firstWalletClient.account,
        maxFeePerGas: parseEther("10", "gwei")
      } 
    );
    
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