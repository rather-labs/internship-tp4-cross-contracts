import hre from "hardhat";
import { ContractTypesMap } from "hardhat/types/artifacts";
import { decodeEventLog, hexToString, parseEther, toBytes, toHex } from "viem";
const CURRENT_CHAIN_ID = (hre.network.config.chainId?? 0).toString();
const GAME_CHAIN_ADDRESSES:{ [key: string]: string } = { // Game contracts
  31337:"0x5147c5C1Cb5b5D3f56186C37a4bcFBb3Cd0bD5A7", 
  31338:"0x6F422FcbfF104822D27DC5BFacC5C6FA7c32af77", 
};

const MetaMaskAddress = "0x17929f65DcF369f43B0EF06844c1a2A8C6C276C2";
async function main() {
    const [firstWalletClient] = await hre.viem.getWalletClients();
    const contract: ContractTypesMap["RockPaperScissorsGame"] = await hre.viem.getContractAt(
      "RockPaperScissorsGame",
      GAME_CHAIN_ADDRESSES[CURRENT_CHAIN_ID],
    );
    // emits message
    const transactionHash = await contract.write.startGame(
      [
        MetaMaskAddress,
       31338n,
       1,
       1
      ],
      {
        value: parseEther("100", "gwei"),
        account: firstWalletClient.account,
        maxFeePerGas: parseEther("10", "gwei")
      } 
    );
    
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });