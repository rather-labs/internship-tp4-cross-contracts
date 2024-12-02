# Cross-chain communication protocol contracts

In this project we develop a cross blockchain communication protocol. In this repo we have the blockchain related files. Also, we have the contracts.

# CommunicationContracts

## Overview

The `CommunicationContracts` are two Solidity smart contracts designed to facilitate cross-chain and on-chain communication. they can handle:

- Receiving messages from other contracts on the same chain.
- Sending messages cross-chain to relayers or external chains.
- Verifying Merkle proofs for incoming messages from external sources.
- Forwarding messages to other contracts on the same chain.
- Tracking processed messages to avoid duplication.

This contract also supports configurable message fees, ensuring flexible and incentivized usage.
It also suuports fee updates of previously sent but undelivered messages.

## Features

- **Receive Messages:** Handles messages sent by other contracts within the same chain and emits an event for each received message.
- **Send Messages:** Emits an event to notify the intent to send a cross-chain message.
- **Merkle Proof Verification:** Verifies incoming messages using Merkle proof validation to ensure integrity and authenticity.
- **Forward Messages:** Allows forwarding messages to other on-chain contracts after verifying their authenticity.
- **Configurable Fees:** The owner can set and update message fees for sending and receiving operations.
- **Processed Message Tracking:** Maintains a record of processed messages to prevent reprocessing.
- **Delivered Message Tracking:** Maintains a record of delivered messages to allow pay to the correct relayer.
- **Allow for taxi/bus delivery confirmation:** To receive the confirmation of message delivery a taxi/bus
  option is defined per message with an associated differentiated fee. This allows for asap message
  delivery confirmation or to include it in a pool of confirmed messages for gas saving.

## Events

- **`InboundMessage(address relayer, uint256 sourceBC, uint256 messageNumber)`**
  - Emitted when a message is received from outside the blockchain.
- **`OutboundMessage(bytes data, address sender, address receiver, uint256 destinationBC, uint256 fee, uint16 finalityNBlocks, uint256 messageNumber, bool taxi)`**
  - Emitted when a message is sent to a cross-chain relayer or external chain.

## Functions

### Core Functions

- `receiveMessage(bytes calldata message)`

  - Receives a message from other contracts within the same chain.
  - Ensures the message hasn't been processed before.

- `sendMessage(bytes calldata message)`

  - Emits an event indicating the intent to send a cross-chain message.

- `verifyMessage(bytes calldata message, bytes32[] calldata proof, bytes32 root)`

  - Verifies a Merkle proof to authenticate a message.
  - Returns `true` if the proof is valid.

- `forwardMessage(address targetContract, bytes calldata message, bytes32[] calldata proof, bytes32 root)`
  - Forwards a message to another contract on the same chain after verifying its authenticity using `verifyMessage`.

### Administrative Functions

- `updateMessageFee(uint256 _newFee)`
  - Updates the fee for sending messages.
  - Can only be called by the owner.

## Usage

### Deployment

1. Install the required OpenZeppelin contracts:

   ```bash
   npm install @openzeppelin/contracts
   ```

2. Deploy the contract using a framework like Hardhat or Truffle. The constructor accepts the initial message fee:
   ```solidity
   uint256 initialFee = 1000000000000000; // Example fee in wei
   CommunicationContract contract = new CommunicationContract(initialFee);
   ```

### Interacting with the Contract

- **Receiving Messages:**

  ```solidity
  contract.receiveMessage{value: messageFee}(message);
  ```

- **Sending Messages:**

  ```solidity
  contract.sendMessage{value: messageFee}(message);
  ```

- **Forwarding Messages:**

  ```solidity
  contract.forwardMessage(targetContract, message, proof, root);
  ```

- **Verifying Messages:**
  ```solidity
  bool isValid = contract.verifyMessage(message, proof, root);
  ```

### Events

Listen to contract events using tools like Ethers.js or Web3.js to track activity:

```javascript
contract.on("MessageReceived", (sender, message, messageHash) => {
  console.log(`Message received from ${sender}:`, message);
});

contract.on("MessageSent", (receiver, message) => {
  console.log(`Message sent to ${receiver}:`, message);
});
```

## Development Notes

- **Solidity Version:** `^0.8.0`
- **Dependencies:** Uses OpenZeppelin's `Ownable` and `MerkleProof` libraries.
- **Gas Optimization:** Avoid sending large messages to reduce gas costs.
- **Security:** Ensure the Merkle root and proofs are securely generated and transmitted.

### Two chain setup to test communication bridge

```shell
npx hardhat node --port 8545
npx hardhat ignition deploy ./ignition/modules/Communication.ts --network localhost --reset
npx hardhat run .\scripts\emitMsg.ts --network localhost
npx hardhat run .\scripts\contracts.ts --network localhost
npx hardhat node --port 8546 --config ./hardhat2.config.ts
npx hardhat ignition deploy ./ignition/modules/Communication.ts  --network localhost --reset --config ./hardhat2.config.ts
npx hardhat run .\scripts\contracts.ts --network localhost --config ./hardhat2.config.ts
npx hardhat run .\scripts\emitMsg.ts --network localhost --config ./hardhat2.config.ts
```

## TODO

- Implement a FIFO queue for tracking messages to manage storage efficiently.
- Add a `payRelayer` function to incentivize relayers.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

```

```
