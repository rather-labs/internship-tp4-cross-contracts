// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";
import hre from "hardhat";
const CURRENT_CHAIN_ID = (hre.network.config.chainId?? 0).toString();
// 31337 - Localhost 1
// 31338 - Localhost 2
// 1  - Ethereum Mainnet logo
// 56 - BNB Smart Chain Mainnet
// 11155111 - Sepolia Testnet
// 421614 - Arbitrum sepolia Testnet
const CHAIN_IDS:{ [key: string]: bigint[] } = {
  31337: [31338n], 
  31338: [31337n] , 
};
const OUT_CHAIN_ADDRESSES:{ [key: string]: string[] } = { // Outgoing communication contracts
  31337:["0x4B5f648644865DB820490B3DEee14de9DF7fFF39"], 
  31338:["0x364C7188028348566E38D762f6095741c49f492B"], 
};
const IN_CHAIN_ADDRESSES:{ [key: string]: string[] } = { // Incoming communication contracts
  31337:["0x8F28B6fF628D11A1f39c550A63D8BF73aD95d1d0"], 
  31338:["0xF62eEc897fa5ef36a957702AA4a45B58fE8Fe312"], 
};
const VERIFICATION_ADDRESSES:{ [key: string]: string } = { // Verification contracts
  31337:"0x5147c5c1cb5b5d3f56186c37a4bcfbb3cd0bd5a7", 
  31338:"0x6f422fcbff104822d27dc5bfacc5c6fa7c32af77", 
};
const CHAIN_ALL_ADDRESSES: { [key: string]: string[][] } = { // All communication contracts
  31337:[
    ["0x8F28B6fF628D11A1f39c550A63D8BF73aD95d1d0", 
     "0x4B5f648644865DB820490B3DEee14de9DF7fFF39"]
   ],
   31338:[
    ["0xF62eEc897fa5ef36a957702AA4a45B58fE8Fe312", 
     "0x364C7188028348566E38D762f6095741c49f492B"]
  ],
};
const CHAIN_BLOCKNUMBERS:{ [key: string]: bigint[] } = {
  31337: [44551689n], 
  31338: [21322555n], 
};
const ONE_GWEI: bigint = parseEther("1");

const Communication = buildModule("Communication", (m) => {
  const chainIds = m.getParameter("chainIds", CHAIN_IDS[CURRENT_CHAIN_ID]);
  const inChainAddresses = m.getParameter("chainAddresses", IN_CHAIN_ADDRESSES[CURRENT_CHAIN_ID]);
  const outChainAddrseses = m.getParameter("chainAddresses", OUT_CHAIN_ADDRESSES[CURRENT_CHAIN_ID]);
  const verificationAddress = m.getParameter("verificationAddress", VERIFICATION_ADDRESSES[CURRENT_CHAIN_ID]);
  const initialAmount = m.getParameter("initialAmount", ONE_GWEI);
  const chainBlockNumbers = m.getParameter("chainBlockNumbers", CHAIN_BLOCKNUMBERS[CURRENT_CHAIN_ID]);
  const allChainAddresses = m.getParameter("allChainAddresses", CHAIN_ALL_ADDRESSES[CURRENT_CHAIN_ID]);


  const verification = m.contract("Verification", 
    [chainIds, chainBlockNumbers, allChainAddresses], 
  );

  const incomingCommunication = m.contract("IncomingCommunication", 
    [chainIds, outChainAddrseses, verificationAddress], 
    { value: initialAmount}
  );

  const outgoingCommunication = m.contract("OutgoingCommunication", 
    [chainIds, inChainAddresses, verificationAddress], 
    { value: initialAmount }
  );

  return { verification, incomingCommunication, outgoingCommunication };
});

export default Communication;
