import { vars, type HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";

const ALCHEMY_PROJECT_ID = vars.get("ALCHEMY_PROJECT_ID");

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  networks: {
    hardhat:{ 
      chainId: 31338,
      forking: { 
        url:"https://bnb-mainnet.g.alchemy.com/v2/"+ALCHEMY_PROJECT_ID,
        blockNumber: 44551689,
      },
    },
    localhost: {
      url: "http://localhost:8546",
      chainId: 31338, // Default Hardhat network chain ID  (couldn't make it work with different chain id)
        //mining: {
        //  auto: false,
        //  interval: 10_000
        //},
    },
},
};

export default config;
