// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RockPaperScissorsGame {
    enum Move { None, Rock, Paper, Scissors }
    enum Result { Pending, Player1Wins, Player2Wins, Draw }

    struct Game {
        address player1;
        address player2;
        Move player1Move;
        Move player2Move;
        Result result; 
    }

    struct GameId {
        uint256 rivalChainID;
        uint256 gameNumber;
    }

    uint256 public chainID;
    mapping(uint256 => uint256) public gameCounter; //gameCounter for each chainID
    mapping(GameId => Game) public games; // Track games by ID

    address public communicationContract;

    event GameCreated(GameId gameId, address player1, address player2);
    event MoveMade(GameId gameId, address player, Move move);
    event GameResult(Game finishedGame);

    constructor(address _communicationContract, uint256 _chainID) {
        communicationContract = _communicationContract;
        chainID = _chainID;
    }

    // Function to create a new game
    function _createGame(address player1, address player2, uint256 rivalChainID, Move move) external returns (uint256) {
        gameCounter[rivalChainID]++; //update the game counter for the source chain
        GameId memory gameId = GameId({
            rivalChainID: rivalChainID,
            gameNumber: gameCounter[rivalChainID]
        });
        require(games[gameId]==0, "Game already exists");
        
        games[gameId] = Game({
            player1: player1,
            player2: player2,
            player1Move: Move.None,
            player2Move: Move.None,
            result: Result.Pending,
        });
        emit GameCreated(gameId, player1, player2);

        return gameId;
    }

    function submitMove(GameId gameId, address player, Move move) external {
        require(games[gameId] != 0, "Game not found");
        Game storage game = games[gameId];
        require(game.result == Result.Pending, "Game already completed"); //add chainID require
        require(move != Move.None, "Invalid move");

        if (player == game.player1) {
            require(game.player1Move == Move.None, "Player 1 has already made a move");
            game.player1Move = move;
        } else if (player == game.player2) {
            require(game.player2Move == Move.None, "Player 2 has already made a move");
            game.player2Move = move;
        } else {
            revert("Player not part of this game");
        }

        emit MoveMade(gameId, player, move);
    }

    function determineWinner(GameId gameId) internal {
        Game storage game = games[gameId];
        require(game.player1Move != Move.None && game.player2Move != Move.None, "Game not finished");

        if (game.player1Move == game.player2Move) {
            game.result = Result.Draw;
            emit GameResult(game);
        } else if (
            (game.player1Move == Move.Rock && game.player2Move == Move.Scissors) ||
            (game.player1Move == Move.Paper && game.player2Move == Move.Rock) ||
            (game.player1Move == Move.Scissors && game.player2Move == Move.Paper)
        ) {
            game.result = Result.Player1Wins;
            emit GameResult(game);
        } else {
            game.result = Result.Player2Wins;
            emit GameResult(game);
        }
    }

    // Function to handle incoming messages from the communication contract
    // Need to receive the data from the communication contract, maybe we need an extra function to unravel the data for the params
    function _receiveMessage(bytes calldata data) external {
        (GameId gameId, address player1, address player2, Move move) = abi.decode(data, (GameId, address, address, Move));

        if(games[gameId]==0) {
            //create the game
            _createGame(player1, player2, gameId.rivalChainID, move);
        }
        submitMove(gameId, player2, move);
    }

    function takeTurn(GameId gameId, address player, Move move) external {
        require(games[gameId] != 0, "Game not found");
        submitMove(gameId, player, move);
        if (games[gameId].player1Move != Move.None && games[gameId].player2Move != Move.None) {
            determineWinner(gameId);
        }
        _sendMoveToCommunicationContract(gameId.rivalChainID, gameId.gameNumber, move);
    }

    // Function to send messages to the communication contract
    function _sendMoveToCommunicationContract(uint256 destinationChainId, uint256 gameNumber, Move move) internal {
        //encode the data
        uint256 sourceChainId = chainID;
        bytes memory data = abi.encode(sourceChainId, destinationChainId, gameNumber, move);

        // Logic for sending messages to the communication contract
        // Implement this according to the cross-chain communication protocol
    }
}
