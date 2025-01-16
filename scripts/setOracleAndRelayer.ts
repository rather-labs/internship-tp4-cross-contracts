import hre from "hardhat";
import { ContractTypesMap } from "hardhat/types/artifacts";
import { hexToBytes, parseEther, toBytes, toHex } from "viem";


const CURRENT_CHAIN_ID = (hre.network.config.chainId?? 0).toString();

const VERIFICATION_ADDRESSES:{ [key: string]: string } = { // Verification contracts
  31339:"0xF2cb3cfA36Bfb95E0FD855C1b41Ab19c517FcDB9", 
  31338:"0x8e590b19CcD16282333c6AF32e77bCb65e98F3c9", 
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