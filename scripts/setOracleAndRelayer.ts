import hre from "hardhat";
import { ContractTypesMap } from "hardhat/types/artifacts";
import { hexToBytes, parseEther, toBytes, toHex } from "viem";
import { keccak256 } from 'ethereum-cryptography/keccak';
import { encodeAbiParameters } from "viem";

const CURRENT_CHAIN_ID = (hre.network.config.chainId?? 0).toString();

const VERIFICATION_ADDRESSES:{ [key: string]: string } = { // Verification contracts
  31337:"0x5147c5c1cb5b5d3f56186c37a4bcfbb3cd0bd5a7", 
  31338:"0x6f422fcbff104822d27dc5bfacc5c6fa7c32af77", 
};
async function main() {
    const [firstWalletClient, secondWalletClient] = await hre.viem.getWalletClients();
    const publicClient = await hre.viem.getPublicClient();
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
      } );
    // get Message Hash 
    
    const encodedData = encodeAbiParameters(
      [ { type: "bytes"},
        { type: "address"},
        { type: "address"},
        { type: "uint16"},
        { type: "uint256"},
        { type: "uint256"},
        { type: "uint256"}
       ],
      [
        toHex("Mensaje de Prueba"),
        firstWalletClient.account.address,
        firstWalletClient.account.address,
        1,
        1n,
        31337n,
        21322559n
     ]
     );
    const msgHash = keccak256(hexToBytes(encodedData));
    
    // set Message Hash 
    await contract.write.setMsgHash(
      [31337n, 1n, toHex(msgHash)],
      {
        account: firstWalletClient.account
      }
    );
    
    // set Message Hash 
    await contract.write.setMsgHash(
      [31337n, 1n, toHex(msgHash)],
      {
        account: firstWalletClient.account
      }
    );

    // set BlockNumber Address
    await contract.write.setLastBlock(
      [31337n,
       21322560n
      ],
      {
        account: firstWalletClient.account
      } );
        
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });