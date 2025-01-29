import { createWalletClient, http } from 'viem';
import { mnemonicToAccount } from 'viem/accounts';
import { holesky } from 'viem/chains';
import dotenv from 'dotenv';

dotenv.config();

// Contract addresses on Holesky
const VERIFICATION_ADDRESS = "0x6A3413ca4099968Afb87b0EfB8AA399fd57378f4";
const INCOMING_COMM_ADDRESS = "0x6c3bF781F5853A46cb62e2503f9E89E559e36dfB";
const OUTGOING_COMM_ADDRESS = "0x6b3C11d20b1BB9556f86386ADfCB084f6F79Abad";
const GAME_ADDRESS = "0x3C57CAC009c14Fd018549821Ea585C7D0317e88d";

// BSC testnet addresses that Holesky needs to know about
const BSC_ADDRESSES = {
  outgoing: "0xeD55769F96C9BA7A14dFbCc0D8a13Cc73D42B095" as `0x${string}`,
  incoming: "0xD1313699Af6AC5F35619080583215057c5653E7F" as `0x${string}`,
  game: "0xa40f362263E81891293b7bD08DF6782Ff37E424b" as `0x${string}`,
};

async function main() {
  const account = mnemonicToAccount(process.env.MNEMONIC as string, {
    path: "m/44'/60'/0'/0/1",
  });
  
  const client = createWalletClient({
    account,
    chain: holesky,
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
    args: [97n, 21322555n],
    maxFeePerGas: 100000000000n,        // 100 gwei
    maxPriorityFeePerGas: 50000000000n  // 50 gwei
  });
  console.log('Holesky Verification updateBlockNumbers tx:', updateBlockNumbersTx);

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
    args: [97n, [BSC_ADDRESSES.outgoing, BSC_ADDRESSES.incoming], true],
    maxFeePerGas: 150000000000n,        // 150 gwei
    maxPriorityFeePerGas: 75000000000n  // 75 gwei
  });
  console.log('Holesky Verification updateAddresses tx:', updateVerificationTx);

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
    args: [97n, BSC_ADDRESSES.outgoing],
    maxFeePerGas: 200000000000n,        // 200 gwei
    maxPriorityFeePerGas: 100000000000n // 100 gwei
  });
  console.log('Holesky IncomingCommunication update tx:', updateIncomingTx);

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
    args: [VERIFICATION_ADDRESS],
    maxFeePerGas: 250000000000n,        // 250 gwei
    maxPriorityFeePerGas: 125000000000n // 125 gwei
  });
  console.log('Holesky IncomingCommunication updateVerification tx:', updateIncomingVerificationTx);

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
    args: [97n, BSC_ADDRESSES.incoming],
    maxFeePerGas: 300000000000n,        // 300 gwei
    maxPriorityFeePerGas: 150000000000n // 150 gwei
  });
  console.log('Holesky OutgoingCommunication update tx:', updateOutgoingTx);

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
    args: [VERIFICATION_ADDRESS],
    maxFeePerGas: 350000000000n,        // 350 gwei
    maxPriorityFeePerGas: 175000000000n // 175 gwei
  });
  console.log('Holesky OutgoingCommunication updateVerification tx:', updateOutgoingVerificationTx);

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
    args: [OUTGOING_COMM_ADDRESS],
    maxFeePerGas: 400000000000n,        // 400 gwei
    maxPriorityFeePerGas: 200000000000n // 200 gwei
  });
  console.log('Holesky Game updateOutgoing tx:', updateGameOutgoingTx);

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
    args: [INCOMING_COMM_ADDRESS],
    maxFeePerGas: 450000000000n,        // 450 gwei
    maxPriorityFeePerGas: 225000000000n // 225 gwei
  });
  console.log('Holesky Game updateIncoming tx:', updateGameIncomingTx);

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
    args: [97n, BSC_ADDRESSES.game],
    maxFeePerGas: 500000000000n,        // 500 gwei
    maxPriorityFeePerGas: 250000000000n // 250 gwei
  });
  console.log('Holesky Game updateAddress tx:', updateGameAddressTx);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
}); 