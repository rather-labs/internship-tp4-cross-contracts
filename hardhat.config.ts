import { vars, type HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import 'hardhat-contract-sizer';
import dotenv from 'dotenv';
dotenv.config();

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
      chainId: 31_339,
      forking: { 
        url:"https://eth-mainnet.g.alchemy.com/v2/"+ALCHEMY_PROJECT_ID,
        blockNumber: 21322555,
      },
      mining: {
        auto: true,
        interval: 15_000
      }

    },
    localhost: {
        url: 'http://localhost:8547',
        chainId: 31_339, // Default Hardhat network chain ID
    },
    holesky: {
      url: "https://eth-holesky.g.alchemy.com/v2/" + ALCHEMY_PROJECT_ID,
      chainId: 17000,
      accounts: {
        mnemonic: process.env.MNEMONIC || "", // Ensure you have a valid mnemonic
      },
    },
  },
};

export default config;
