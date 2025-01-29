import { parseEther } from "ethers";
import hre from "hardhat";

async function main() {
    const walletAddres = "0xD3B5a2d4bAb5F72e31465c2E459E6cDFe9620EC9"
    const [firstWalletClient, secondWalletClient] = await hre.viem.getWalletClients();
    const txHash = await firstWalletClient.sendTransaction({
        to: walletAddres,
        value: parseEther("0.1"),
        account: firstWalletClient.account,
    })
    console.log(txHash)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });