import { createWalletClient, http } from 'viem';
import { mnemonicToAccount } from 'viem/accounts';
import { bscTestnet } from 'viem/chains';
import dotenv from 'dotenv';

dotenv.config();

// Contract addresses on BSC testnet
const VERIFICATION_ADDRESS = "0x0857ffDCEDc623b5b5E21a39A5A854bAF34EEbA2";
const INCOMING_COMM_ADDRESS = "0xD1313699Af6AC5F35619080583215057c5653E7F";
const OUTGOING_COMM_ADDRESS = "0xeD55769F96C9BA7A14dFbCc0D8a13Cc73D42B095";
const GAME_ADDRESS = "0xa40f362263E81891293b7bD08DF6782Ff37E424b";

// Holesky addresses that BSC needs to know about
const HOLESKY_ADDRESSES = {
  outgoing: "0x6b3C11d20b1BB9556f86386ADfCB084f6F79Abad" as `0x${string}`,
  incoming: "0x6c3bF781F5853A46cb62e2503f9E89E559e36dfB" as `0x${string}`,
  game: "0x3C57CAC009c14Fd018549821Ea585C7D0317e88d" as `0x${string}`,
};

async function main() {
  const account = mnemonicToAccount(process.env.MNEMONIC as string, {
    path: "m/44'/60'/0'/0/1",
  });
  
  const client = createWalletClient({
    account,
    chain: bscTestnet,
    transport: http()
  });

  // 1. Update Verification contract
  // Update chain block numbers
  const updateBlockNumbersTx = await client.writeContract({
    address: VERIFICATION_ADDRESS,
    abi: [{
      name: 'updateChainBlockNumbers',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: '_chainId', type: 'uint256' },
        { name: '_blockNumber', type: 'uint256' }
      ],
      outputs: []
    }],
    functionName: 'updateChainBlockNumbers',
    args: [17000n, 21322555n] // Use appropriate block number
  });
  console.log('BSC Verification updateBlockNumbers tx:', updateBlockNumbersTx);

  // Update chain addresses
  const updateVerificationTx = await client.writeContract({
    address: VERIFICATION_ADDRESS,
    abi: [{
      name: 'updateChainAddresses',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: '_chainId', type: 'uint256' },
        { name: '_addresses', type: 'address[]' },
        { name: '_isAllowed', type: 'bool' }
      ],
      outputs: []
    }],
    functionName: 'updateChainAddresses',
    args: [17000n, [HOLESKY_ADDRESSES.outgoing, HOLESKY_ADDRESSES.incoming], true]
  });
  console.log('BSC Verification updateAddresses tx:', updateVerificationTx);

  // 2. Update IncomingCommunication contract
  // Update source addresses
  const updateIncomingTx = await client.writeContract({
    address: INCOMING_COMM_ADDRESS,
    abi: [{
      name: 'updateSourceAddresses',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: '_chainId', type: 'uint256' },
        { name: '_address', type: 'address' }
      ],
      outputs: []
    }],
    functionName: 'updateSourceAddresses',
    args: [17000n, HOLESKY_ADDRESSES.outgoing]
  });
  console.log('BSC IncomingCommunication update tx:', updateIncomingTx);

  // Update verification contract address
  const updateIncomingVerificationTx = await client.writeContract({
    address: INCOMING_COMM_ADDRESS,
    abi: [{
      name: 'updateVerificationContract',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: '_newAddress', type: 'address' }
      ],
      outputs: []
    }],
    functionName: 'updateVerificationContract',
    args: [VERIFICATION_ADDRESS]
  });
  console.log('BSC IncomingCommunication updateVerification tx:', updateIncomingVerificationTx);

  // 3. Update OutgoingCommunication contract
  // Update destination addresses
  const updateOutgoingTx = await client.writeContract({
    address: OUTGOING_COMM_ADDRESS,
    abi: [{
      name: 'updateDestinationAddresses',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: '_chainId', type: 'uint256' },
        { name: '_address', type: 'address' }
      ],
      outputs: []
    }],
    functionName: 'updateDestinationAddresses',
    args: [17000n, HOLESKY_ADDRESSES.incoming]
  });
  console.log('BSC OutgoingCommunication update tx:', updateOutgoingTx);

  // Update verification contract address
  const updateOutgoingVerificationTx = await client.writeContract({
    address: OUTGOING_COMM_ADDRESS,
    abi: [{
      name: 'updateVerificationContract',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: '_newAddress', type: 'address' }
      ],
      outputs: []
    }],
    functionName: 'updateVerificationContract',
    args: [VERIFICATION_ADDRESS]
  });
  console.log('BSC OutgoingCommunication updateVerification tx:', updateOutgoingVerificationTx);

  // 4. Update RockPaperScissorsGame contract
  // Update communication contracts
  const updateGameOutgoingTx = await client.writeContract({
    address: GAME_ADDRESS,
    abi: [{
      name: 'updateOutgoingCommunicationContract',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: '_newAddress', type: 'address' }
      ],
      outputs: []
    }],
    functionName: 'updateOutgoingCommunicationContract',
    args: [OUTGOING_COMM_ADDRESS]
  });
  console.log('BSC Game updateOutgoing tx:', updateGameOutgoingTx);

  const updateGameIncomingTx = await client.writeContract({
    address: GAME_ADDRESS,
    abi: [{
      name: 'updateIncomingCommunicationContract',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: '_newAddress', type: 'address' }
      ],
      outputs: []
    }],
    functionName: 'updateIncomingCommunicationContract',
    args: [INCOMING_COMM_ADDRESS]
  });
  console.log('BSC Game updateIncoming tx:', updateGameIncomingTx);

  // Update game contract address
  const updateGameAddressTx = await client.writeContract({
    address: GAME_ADDRESS,
    abi: [{
      name: 'updateGameContractAddress',
      type: 'function',
      stateMutability: 'nonpayable',
      inputs: [
        { name: '_chainId', type: 'uint256' },
        { name: '_address', type: 'address' }
      ],
      outputs: []
    }],
    functionName: 'updateGameContractAddress',
    args: [17000n, HOLESKY_ADDRESSES.game]
  });
  console.log('BSC Game updateAddress tx:', updateGameAddressTx);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
}); 