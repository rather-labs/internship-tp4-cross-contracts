import hre from "hardhat";
import { ContractTypesMap } from "hardhat/types/artifacts";
import { hexToBytes, parseEther, toBytes, toHex } from "viem";


const CURRENT_CHAIN_ID = (hre.network.config.chainId?? 0).toString();

const VERIFICATION_ADDRESSES:{ [key: string]: string } = { // Verification contracts
  31337:"0x5147c5C1Cb5b5D3f56186C37a4bcFBb3Cd0bD5A7", 
  31338:"0x6F422FcbfF104822D27DC5BFacC5C6FA7c32af77", 
};
async function main() {
    const [firstWalletClient, secondWalletClient] = await hre.viem.getWalletClients();
    const contract: ContractTypesMap["Verification"] = await hre.viem.getContractAt(
      "Verification",
      VERIFICATION_ADDRESSES[CURRENT_CHAIN_ID],
    );

    // set Oracle Address
    await contract.write.modifyOracleAddresses(
      [firstWalletClient.account.address,
       true
      ],
      {
        account: firstWalletClient.account
      } 
    );
      
    // set Relayer Address
    await contract.write.modifyRelayerAddresses(
      [firstWalletClient.account.address,
       true
      ],
      {
        account: firstWalletClient.account
      } 
    );
    // disable automining
    await hre.network.provider.send('evm_setAutomine', [false]);
        
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });