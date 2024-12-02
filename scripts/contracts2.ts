import { createPublicClient, createWalletClient, http, parseAbi, getContract } from "viem";
import { localhost } from "viem/chains";

async function main() {
  // Replace with your deployed contract address
  const contractAddress = "0x5fbdb2315678afecb367f032d93f642f64180aa3";

  // ABI of the contract
  const abi = parseAbi([
    "function getBalance()",
    "function blocknumberPerChainId(uint256) returns (uint256)",
  ]);

  // Set up Viem client
  const client = createPublicClient({
    chain: localhost,
    transport: http(),
  });

  const walletClient = createWalletClient({
    chain: localhost,
    transport: http(),
  });

  // Attach the contract
  const contract = getContract({
    address: contractAddress,
    abi,
    client: walletClient,
  });

  // Call a read-only function
  const currentValue = await contract.read.getValue();
  console.log("Current Value:", currentValue);

  // Call a state-changing function
  const txHash = await contract.write.setValue([42]);
  console.log("Transaction hash:", txHash);

  // Confirm the new value
  const newValue = await contract.read.getValue();
  console.log("New Value:", newValue);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});