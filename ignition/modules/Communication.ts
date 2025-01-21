// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition
//WARNING!!!! the addresses corresponding to chaiID 17000 are random, 
//they need to be changed after the contracts are deployed and the addresses are known

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";
import hre, {network } from "hardhat";
const CURRENT_CHAIN_ID = (hre.network.config.chainId?? 0).toString();
// 31339 - Localhost 1
// 31338 - Localhost 2
// 1  - Ethereum Mainnet logo
// 56 - BNB Smart Chain Mainnet
// 11155111 - Sepolia Testnet
// 421614 - Arbitrum sepolia Testnet
const CHAIN_IDS:{ [key: string]: bigint[] } = {
  31339: [31338n], 
  31338: [31339n] , 
  17000: [17000n]
};
 // Outgoing communication contracts from other chains, in the order of CHAIN_IDS
const OUT_CHAIN_ADDRESSES:{ [key: string]: string[] } = {
  31339:["0x4B5f648644865DB820490B3DEee14de9DF7fFF39"], 
  31338:["0x364C7188028348566E38D762f6095741c49f492B"], 
  17000:["0x364C7188028348566E38D762f6095741c49f492B"], 
};
// Incoming communication contracts from other chains, in the order of CHAIN_IDS
const IN_CHAIN_ADDRESSES:{ [key: string]: string[] } = { 
  31339:["0x8F28B6fF628D11A1f39c550A63D8BF73aD95d1d0"], 
  31338:["0xF62eEc897fa5ef36a957702AA4a45B58fE8Fe312"], 
  17000:["0xF62eEc897fa5ef36a957702AA4a45B58fE8Fe312"], 
};
// Verification contract from the same chain
const VERIFICATION_ADDRESSES:{ [key: string]: string } = { 
  31339:"0xF2cb3cfA36Bfb95E0FD855C1b41Ab19c517FcDB9", 
  31338:"0x8e590b19CcD16282333c6AF32e77bCb65e98F3c9", 
  17000:"0x8e590b19CcD16282333c6AF32e77bCb65e98F3c9", 
};
// All communication contracts from the other chains, in the order of CHAIN_IDS
const CHAIN_ALL_ADDRESSES: { [key: string]: string[][] } = { 
  31339:[
    ["0x4B5f648644865DB820490B3DEee14de9DF7fFF39", 
     "0x8F28B6fF628D11A1f39c550A63D8BF73aD95d1d0"]
   ],
   31338:[
    ["0x364C7188028348566E38D762f6095741c49f492B", 
     "0xF62eEc897fa5ef36a957702AA4a45B58fE8Fe312"]
  ],
  17000:[
    ["0x364C7188028348566E38D762f6095741c49f492B", 
     "0xF62eEc897fa5ef36a957702AA4a45B58fE8Fe312"]
  ],
};
// Game contracts from all other chains
const GAME_ADDRESSES:{ [key: string]: string[] } = { 
  31339:["0x6F422FcbfF104822D27DC5BFacC5C6FA7c32af77"], 
  31338:["0x5147c5C1Cb5b5D3f56186C37a4bcFBb3Cd0bD5A7"],
  17000:["0x5147c5C1Cb5b5D3f56186C37a4bcFBb3Cd0bD5A7"],
};
// Outgoing communication contract from the same chain
const OUTGOING_COMMUNICATION_ADDRESS:{ [key: string]: string } = {
  31339:"0x364C7188028348566E38D762f6095741c49f492B", 
  31338:"0x4B5f648644865DB820490B3DEee14de9DF7fFF39", 
  17000:"0x4B5f648644865DB820490B3DEee14de9DF7fFF39", 
};
// incoming communication contract from the same chain
const INCOMING_COMMUNICATION_ADDRESS:{ [key: string]: string } = {
  31339:"0xF62eEc897fa5ef36a957702AA4a45B58fE8Fe312", 
  31338:"0x8F28B6fF628D11A1f39c550A63D8BF73aD95d1d0", 
  17000:"0xF62eEc897fa5ef36a957702AA4a45B58fE8Fe312", 
};
const CHAIN_BLOCKNUMBERS:{ [key: string]: bigint[] } = {
  31339: [44551689n], 
  31338: [21322555n], 
  17000: [21322555n],
};

const Communication = buildModule("Communication", (m) => {
  const chainIds = m.getParameter("chainIds", CHAIN_IDS[CURRENT_CHAIN_ID]);
  const inChainAddresses = m.getParameter("chainAddresses", IN_CHAIN_ADDRESSES[CURRENT_CHAIN_ID]);
  const outChainAddrseses = m.getParameter("chainAddresses", OUT_CHAIN_ADDRESSES[CURRENT_CHAIN_ID]);
  const verificationAddress = m.getParameter("verificationAddress", VERIFICATION_ADDRESSES[CURRENT_CHAIN_ID]);
  const chainBlockNumbers = m.getParameter("chainBlockNumbers", CHAIN_BLOCKNUMBERS[CURRENT_CHAIN_ID]);
  const allChainAddresses = m.getParameter("allChainAddresses", CHAIN_ALL_ADDRESSES[CURRENT_CHAIN_ID]);
  const gameAddress = m.getParameter("gameAddress", GAME_ADDRESSES[CURRENT_CHAIN_ID]);
  const outgoingCommunicationAddress = m.getParameter("outgoingCommunicationAddress", OUTGOING_COMMUNICATION_ADDRESS[CURRENT_CHAIN_ID]);
  const incomingCommunicationAddress = m.getParameter("incomingCommunicationAddress", INCOMING_COMMUNICATION_ADDRESS[CURRENT_CHAIN_ID]);

  const verification = m.contract("Verification", 
    [chainIds, chainBlockNumbers, allChainAddresses],
  );

  const incomingCommunication = m.contract("IncomingCommunication", 
    [chainIds, outChainAddrseses, verificationAddress],
  );

  const outgoingCommunication = m.contract("OutgoingCommunication", 
    [chainIds, inChainAddresses, verificationAddress], 
  );

  const RockPaperScissorsGame = m.contract("RockPaperScissorsGame", 
    [outgoingCommunicationAddress, incomingCommunicationAddress, gameAddress, chainIds], 
  );

  return { verification, incomingCommunication, outgoingCommunication, RockPaperScissorsGame };
});

export default Communication;