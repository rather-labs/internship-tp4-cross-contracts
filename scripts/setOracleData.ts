import hre from "hardhat";
import { ContractTypesMap } from "hardhat/types/artifacts";
import { parseEther, toBytes, toHex } from "viem";

async function main() {
    const [firstWalletClient, secondWalletClient] = await hre.viem.getWalletClients();
    const publicClient = await hre.viem.getPublicClient();
    const contract: ContractTypesMap["OutgoingCommunication"] = await hre.viem.getContractAt(
      "OutgoingCommunication",
      "0x364C7188028348566E38D762f6095741c49f492B",
    );

    const destBlockchain = new Map<bigint, bigint>();
    destBlockchain.set(31337n, 31338n);
    destBlockchain.set(31338n, 31337n);

    const chainId = BigInt(await publicClient.getChainId())

    let blockHeader = await publicClient.getBlock()
    console.log(blockHeader)
    let balance = await publicClient.getBalance({ 
      address: "0x364C7188028348566E38D762f6095741c49f492B"
     });
    console.log("Contract balance:", balance, "wei");

    
    let receiptMsgEmit = await publicClient.getTransactionReceipt(
      {
        hash:"0xf9cadaf75e62e4cbaa42dcd55790b968ec89ad09da3a413091af7884d3ee21c3"
      }
    )
    console.log("Receipt MsgEmit:", receiptMsgEmit)
    // set Oracle Address
    const transactionHash = await contract.write.modifyOracleAddresses(
      [firstWalletClient.account.address,
       true
      ],
      {
        account: firstWalletClient.account
      } );
    
    // setMsgHsh
    await contract.write.setMsgLog(
      [
        destBlockchain.get(chainId)?? 0n,
        1n,
        toHex(2)
      ],
      {
        account: firstWalletClient.account
      } 
    );

    
    // setMsgDeliveredHash

    
    // setRecTrieRoot    
    await contract.write.setRecTrieRoot(
      [
        destBlockchain.get(chainId)?? 0n,
        blockHeader.number,
        blockHeader.receiptsRoot
      ],
      {
        account: firstWalletClient.account
      } 
    );

    // setLastBlock
    await contract.write.setLastBlock(
      [
        destBlockchain.get(chainId)?? 0n,
        blockHeader.number
      ],
      {
        account: firstWalletClient.account
      } 
    );
  
    const receipt = await publicClient.waitForTransactionReceipt({ hash: transactionHash });
    console.log("Transaction mined:", receipt);

    balance = await publicClient.getBalance({ 
      address: "0x364c7188028348566e38d762f6095741c49f492b"
     });
     
    console.log("Block Number:", await publicClient.getBlockNumber());
    console.log("Contract balance:", balance, "wei");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });