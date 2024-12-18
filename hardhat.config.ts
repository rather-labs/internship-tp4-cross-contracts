import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  networks: {
    hardhat:{ chainId: 31337},
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
