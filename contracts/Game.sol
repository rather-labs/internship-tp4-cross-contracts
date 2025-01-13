// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// For debugging -- Comment for deployment
import "hardhat/console.sol";

interface IOutgoingCommunication {
    function sendMessage(
        bytes calldata _messageData,
        address _receiver,
        uint256 _destinationBC,
        uint16 _finalityNBlocks,
        bool _taxi
    ) external payable;
}

contract RockPaperScissorsGame {
    enum Move {
        None,
        Rock,
        Paper,
        Scissors
    }
    enum Result {
        Pending,
        Player1Wins,
        Player2Wins,
        Draw
    }

    struct Game {
        uint256 id;
        uint256 nMoves;
        address player1;
        uint256 player1ChainID;
        address player2;
        uint256 player2ChainID;
        Move player1Move;
        Move player2Move;
        Result result;
        uint16 blocksForFinality;
        uint256 player1Bet;
        uint256 player2Bet;
    }

    mapping(uint256 => uint256) public gameCounter; //gameCounter for each game source chainID
    mapping(uint256 => mapping(uint256 => Game)) public games; // Track games by Source chainID and gameNumber

    address public outgoingCommunicationContract;
    address public incomingCommunicationContract;
    mapping(uint256 => address) public gameContractAddresses; //gameContractAddress per chainID

    event MoveReceived(uint256 gameId, uint256 gameSourceChainId, Move move);
    event GameResult(Game finishedGame);

    constructor(
        address _outgoingCommunicationContract,
        address _incomingCommunicationContract,
        address[] memory _gameContractAddresses,
        uint256[] memory _chainIDs
    ) {
        outgoingCommunicationContract = _outgoingCommunicationContract;
        incomingCommunicationContract = _incomingCommunicationContract;
        for (uint256 i = 0; i < _gameContractAddresses.length; i++) {
            gameContractAddresses[_chainIDs[i]] = _gameContractAddresses[i];
        }
    }

    modifier onlyIncomingCommunicationContract() {
        require(
            msg.sender == incomingCommunicationContract,
            "Only incoming communication contract can call this function"
        );
        _;
    }

    modifier onlyValidGameContract(
        uint256 _chainID,
        address _gameContractAddress
    ) {
        require(
            gameContractAddresses[_chainID] == _gameContractAddress,
            "Invalid game contract address is sending a move"
        );
        _;
    }

    /**
     * @notice Resolves the final transaction for the game.
     * @param _gameSourceChainId The source chain ID of the game.
     * @param _gameId The ID of the game.
     */
    function _resolveGame(
        uint256 _gameSourceChainId,
        uint256 _gameId
    ) internal {
        require(
            games[_gameSourceChainId][_gameId].result != Result.Pending,
            "Game not already resolved"
        );
        if (
            block.chainid == _gameSourceChainId &&
            games[_gameSourceChainId][_gameId].result == Result.Player1Wins
        ) {
            uint256 bet = games[_gameSourceChainId][_gameId].player1Bet;
            games[_gameSourceChainId][_gameId].player1Bet = 0;
            (bool success, ) = payable(
                games[_gameSourceChainId][_gameId].player1
            ).call{value: bet}("");
            require(success, "Transfer failed");
        } else if (
            block.chainid != _gameSourceChainId &&
            games[_gameSourceChainId][_gameId].result == Result.Player2Wins
        ) {
            uint256 bet = games[_gameSourceChainId][_gameId].player2Bet;
            games[_gameSourceChainId][_gameId].player2Bet = 0;
            (bool success, ) = payable(
                games[_gameSourceChainId][_gameId].player2
            ).call{value: bet}("");
            require(success, "Transfer failed");
        } //else if (games[_gameSourceChainId][_gameId].result != Result.Draw) {
        //  address burnAddress = address(0);
        //  if (block.chainid == _gameSourceChainId) {
        //      uint256 bet = games[_gameSourceChainId][_gameId].player1Bet;
        //      games[_gameSourceChainId][_gameId].player1Bet = 0;
        //      (bool success, ) = payable(burnAddress).call{value: bet}("");
        //      require(success, "Transfer failed");
        //  } else {
        //      uint256 bet = games[_gameSourceChainId][_gameId].player2Bet;
        //      games[_gameSourceChainId][_gameId].player2Bet = 0;
        //      (bool success, ) = payable(burnAddress).call{value: bet}("");
        //      require(success, "Transfer failed");
        //  }
        //}
    }

    function _determineWinner(
        uint256 _gameSourceChainId,
        uint256 _gameId
    ) internal {
        require(
            games[_gameSourceChainId][_gameId].player1Move != Move.None &&
                games[_gameSourceChainId][_gameId].player2Move != Move.None,
            "Game not finished"
        );

        if (
            games[_gameSourceChainId][_gameId].player1Move ==
            games[_gameSourceChainId][_gameId].player2Move
        ) {
            games[_gameSourceChainId][_gameId].result = Result.Draw;
            emit GameResult(games[_gameSourceChainId][_gameId]);
        } else if (
            (games[_gameSourceChainId][_gameId].player1Move == Move.Rock &&
                games[_gameSourceChainId][_gameId].player2Move ==
                Move.Scissors) ||
            (games[_gameSourceChainId][_gameId].player1Move == Move.Paper &&
                games[_gameSourceChainId][_gameId].player2Move == Move.Rock) ||
            (games[_gameSourceChainId][_gameId].player1Move == Move.Scissors &&
                games[_gameSourceChainId][_gameId].player2Move == Move.Paper)
        ) {
            games[_gameSourceChainId][_gameId].result = Result.Player1Wins;
            emit GameResult(games[_gameSourceChainId][_gameId]);
        } else {
            games[_gameSourceChainId][_gameId].result = Result.Player2Wins;
            emit GameResult(games[_gameSourceChainId][_gameId]);
        }
    }

    // Function to send a new game to the communication contract
    function _sendGameToCommunicationContract(
        uint256 _gameId,
        uint256 _gameSourceChainId
    ) internal {
        // Encode data to be sent to the communication contract
        bytes memory messageData = abi.encode(
            games[_gameSourceChainId][_gameId]
        );

        // Cast the communicationContract address to the interface
        IOutgoingCommunication outgoing = IOutgoingCommunication(
            outgoingCommunicationContract
        );

        uint256 _rivalChainID;
        if (block.chainid == _gameSourceChainId) {
            _rivalChainID = games[_gameSourceChainId][_gameId].player2ChainID;
        } else {
            _rivalChainID = games[_gameSourceChainId][_gameId].player1ChainID;
        }

        // Send message to execute handleMessage on destination chain
        // Call sendMessage with the following parameters:
        // - messageData: encoded game result
        // - receiver: address of the game contract on the destination chain
        // - destinationBC: the destination blockchain ID (you'll need to specify this)
        // - finalityNBlocks: number of blocks for finality (e.g., 1)
        // - taxi: whether to use taxi mode (faster but more expensive)
        outgoing.sendMessage{value: 0}( // Add value if needed for fees
            messageData,
            gameContractAddresses[_rivalChainID],
            _rivalChainID,
            games[_gameSourceChainId][_gameId].blocksForFinality,
            false // TODO: Replace with actual taxi preference
        );
    }

    // Function to send an update to a game to the communication contract
    function _sendMoveToCommunicationContract(
        uint256 _gameId,
        uint256 _gameSourceChainId
    ) internal {
        Move _move;
        uint256 _rivalChainID;
        if (block.chainid == _gameSourceChainId) {
            _move = games[_gameSourceChainId][_gameId].player1Move;
            _rivalChainID = games[_gameSourceChainId][_gameId].player2ChainID;
        } else {
            _move = games[_gameSourceChainId][_gameId].player2Move;
            _rivalChainID = games[_gameSourceChainId][_gameId].player1ChainID;
        }
        // Encode data to be sent to the communication contract
        bytes memory messageData = abi.encode(
            _gameId,
            _gameSourceChainId,
            _move,
            games[_gameSourceChainId][_gameId].nMoves,
            games[_gameSourceChainId][_gameId].result
        );

        // Cast the communicationContract address to the interface
        IOutgoingCommunication outgoing = IOutgoingCommunication(
            outgoingCommunicationContract
        );

        // Send message to execute handleMessage on destination chain
        // Call sendMessage with the following parameters:
        // - messageData: encoded game result
        // - receiver: address of the game contract on the destination chain
        // - destinationBC: the destination blockchain ID (you'll need to specify this)
        // - finalityNBlocks: number of blocks for finality (e.g., 1)
        // - taxi: whether to use taxi mode (faster but more expensive)
        outgoing.sendMessage{value: 0}( // Add value if needed for fees
            messageData,
            gameContractAddresses[_rivalChainID],
            _rivalChainID,
            games[_gameSourceChainId][_gameId].blocksForFinality,
            false // TODO: Replace with actual taxi preference
        );
    }

    function submitMove(
        uint256 _gameId,
        uint256 _gameSourceChainId,
        Move _move
    ) public payable {
        require(_move != Move.None, "Invalid move");

        require(
            games[_gameSourceChainId][_gameId].result == Result.Pending,
            "Game already completed"
        );

        if (
            games[_gameSourceChainId][_gameId].nMoves == 1 &&
            games[_gameSourceChainId][_gameId].player1Bet > msg.value
        ) {
            revert(
                "The bet required to play the game is higher than the amount sent"
            );
        }

        //In this case, we submit the move to a game that already has a first move so, it's the player2 move
        if (
            msg.sender == games[_gameSourceChainId][_gameId].player1 &&
            block.chainid == games[_gameSourceChainId][_gameId].player1ChainID
        ) {
            games[_gameSourceChainId][_gameId].player1Move = _move;
            games[_gameSourceChainId][_gameId].player1Bet += msg.value;
        } else {
            games[_gameSourceChainId][_gameId].player2Move = _move;
            games[_gameSourceChainId][_gameId].player2Bet += msg.value;
        }
        games[_gameSourceChainId][_gameId].nMoves++;

        if (
            msg.sender == games[_gameSourceChainId][_gameId].player2 &&
            block.chainid == games[_gameSourceChainId][_gameId].player2ChainID
        ) {
            _determineWinner(_gameId, _gameSourceChainId);
            _resolveGame(_gameId, _gameSourceChainId);
        }

        _sendMoveToCommunicationContract(_gameId, _gameSourceChainId);
    }

    // Function to create a new game
    function _createGame(
        address _player1,
        uint256 _player1ChainID,
        address _player2,
        uint256 _player2ChainID,
        Move _move,
        uint16 _blocksForFinality
    ) internal {
        gameCounter[_player1ChainID]++; //update the game counter for the source chain

        games[block.chainid][gameCounter[block.chainid]] = Game({
            id: gameCounter[_player1ChainID],
            nMoves: 1,
            player1: _player1,
            player1ChainID: _player1ChainID,
            player2: _player2,
            player2ChainID: _player2ChainID,
            player1Move: _move, //player1 always makes the first move, assigned in the game creation
            player2Move: Move.None,
            result: Result.Pending,
            blocksForFinality: _blocksForFinality,
            player1Bet: msg.value,
            player2Bet: 0
        });
    }

    function startGame(
        address _player2,
        uint256 _player2ChainID,
        Move _move,
        uint16 _blocksForFinality
    ) external payable {
        _createGame(
            msg.sender,
            block.chainid,
            _player2,
            _player2ChainID,
            _move,
            _blocksForFinality
        );
        _sendGameToCommunicationContract(
            gameCounter[block.chainid],
            block.chainid
        );
    }

    // Function to handle incoming messages from the communication contract
    // Need to receive the data from the communication contract,
    // maybe we need an extra function to unravel the data for the params
    function receiveMsg(
        address _gameContractAddress,
        uint256 _chainID,
        bytes calldata data
    )
        external
        onlyIncomingCommunicationContract
        onlyValidGameContract(_chainID, _gameContractAddress)
    {
        if (data.length == 160) {
            // Attempt to decode as an update in a game
            (
                uint256 _gameId,
                uint256 _gameSourceChainId,
                Move _move,
                uint256 _nMoves,
                Result _result
            ) = abi.decode(data, (uint256, uint256, Move, uint256, Result));
            if (games[_gameSourceChainId][_gameId].player1 == address(0)) {
                revert("Game not created");
            }
            if (games[_gameSourceChainId][_gameId].nMoves + 1 != _nMoves) {
                revert("Non expected number of move");
            }
            // If the game is already created, we update the game with the new moves and the result
            // if it's a move to be received it will always be from player1
            if (block.chainid == _gameSourceChainId) {
                games[_gameSourceChainId][_gameId].player2Move = _move;
            } else {
                games[_gameSourceChainId][_gameId].player1Move = _move;
            }
            games[_gameSourceChainId][_gameId].result = _result;
            if (_result == Result.Pending) {
                emit MoveReceived(_gameId, _gameSourceChainId, _move);
            } else {
                _resolveGame(_gameId, _gameSourceChainId);
            }
            return;
        } else if (data.length == 384) {
            // Attempt to decode as a new game
            Game memory _game = abi.decode(data, (Game));
            if (games[_game.player1ChainID][_game.id].player1 != address(0)) {
                revert("Game already created");
            }
            games[_game.player1ChainID][_game.id] = _game;
            if (_chainID == _game.player1ChainID) {
                emit MoveReceived(
                    _game.id,
                    _game.player1ChainID,
                    _game.player1Move
                );
            }
            return;
        }
        console.log("Unknown Message of length: %s", data.length);
        revert("Unknown Message");
    }
}
