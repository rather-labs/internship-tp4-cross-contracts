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
  contractSizer: {
    alphaSort: true, // Sort contracts alphabetically
    runOnCompile: true, // Automatically measure size after compilation
    disambiguatePaths: false, // Show file paths for contracts with the same name
  },
  networks: {
    hardhat:{ 
      chainId: 31338,
      forking: { 
        url:"https://bnb-mainnet.g.alchemy.com/v2/"+ALCHEMY_PROJECT_ID,
        blockNumber: 44551689,
      },
      mining: {
        auto: true,
        interval: 15_000
      },
    },
    localhost: {
      url: "http://localhost:8546",
      chainId: 31338, // Default Hardhat network chain ID  (couldn't make it work with different chain id)
    },
},
};

export default config;
