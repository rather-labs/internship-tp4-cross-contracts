import { vars, type HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";

const ALCHEMY_PROJECT_ID = vars.get("ALCHEMY_PROJECT_ID");

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  networks: {
    hardhat:{ 
      chainId: 31337,
      forking: { 
        url:"https://eth-mainnet.g.alchemy.com/v2/"+ALCHEMY_PROJECT_ID,
        blockNumber: 21322555,
      },
    },
    localhost: {
        url: 'http://localhost:8545',
        chainId: 31337, // Default Hardhat network chain ID
        //mining: {
        //  auto: false,
        //  interval: 10_000
        //},
    }
},
};

export default config;
