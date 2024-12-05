// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

// 31337 - Localhost 1
// 31338 - Localhost 2
// 1  - Ethereum Mainnet logo
// 56 - BNB Smart Chain Mainnet
// 11155111 - Sepolia Testnet
// 421614 - Arbitrum sepolia Testnet
const CHAIN_IDS: bigint[] = [
  31337n, 
  31338n, 
];
const CHAIN_ADDRESSES: string[] = [ // Incoming communication contracts
  "0xF62eEc897fa5ef36a957702AA4a45B58fE8Fe312", 
  "0x8F28B6fF628D11A1f39c550A63D8BF73aD95d1d0", 
];
const CHAIN_ALL_ADDRESSES: string[][] = [ // All communication contracts
  ["0xF62eEc897fa5ef36a957702AA4a45B58fE8Fe312", "0x364C7188028348566E38D762f6095741c49f492B"],
  ["0x8F28B6fF628D11A1f39c550A63D8BF73aD95d1d0", "0x4B5f648644865DB820490B3DEee14de9DF7fFF39"]
];
const CHAIN_BLOCKNUMBERS: bigint[] = [
  21322555n, 
  44551689n, 
];
const ONE_GWEI: bigint = parseEther("1");

const Communication = buildModule("Communication", (m) => {
  const chainIds = m.getParameter("chainIds", CHAIN_IDS);
  const chainAddresses = m.getParameter("chainAddresses", CHAIN_ADDRESSES);
  const initialAmount = m.getParameter("initialAmount", ONE_GWEI);

  const verification = m.contract("Verification", 
    [chainIds, CHAIN_BLOCKNUMBERS, CHAIN_ALL_ADDRESSES], 
  );

  const incomingCommunication = m.contract("IncomingCommunication", 
    [chainIds], 
    { value: initialAmount}
  );

  const outgoingCommunication = m.contract("OutgoingCommunication", 
    [chainIds, chainAddresses], 
    { value: initialAmount }
  );

  return { verification, incomingCommunication, outgoingCommunication };
});

export default Communication;
