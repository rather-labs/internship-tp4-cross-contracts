import { parseEther } from "ethers";
import hre from "hardhat";

async function main() {
    const walletAddres = "0x17929f65DcF369f43B0EF06844c1a2A8C6C276C2"
    const [firstWalletClient, secondWalletClient] = await hre.viem.getWalletClients();
    const txHash = await firstWalletClient.sendTransaction({
        to: walletAddres,
        value: parseEther("100", "gwei"),
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