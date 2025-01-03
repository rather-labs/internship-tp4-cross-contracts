import { vars, type HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import 'hardhat-contract-sizer';

const ALCHEMY_PROJECT_ID = vars.get("ALCHEMY_PROJECT_ID");

const config: HardhatUserConfig = {
  solidity: {
    version:"0.8.27",
    //settings: {
    //  optimizer: {
    //    enabled: true,
    //    runs: 200,
    //  },
    //  viaIR: true,
    //},
  },
  networks: {
    hardhat:{ 
      chainId: 31337,
      forking: { 
        url:"https://eth-mainnet.g.alchemy.com/v2/"+ALCHEMY_PROJECT_ID,
        blockNumber: 21322555,
      },
      mining: {
        auto: true,
        interval: 15_000
      },
    },
    localhost: {
        url: 'http://localhost:8545',
        chainId: 31337, // Default Hardhat network chain ID
    },
  },
};

export default config;
