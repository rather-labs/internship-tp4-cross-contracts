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

    mapping(uint256 => Game) public games; // Track games by ID
    uint256 public gameCounter;

    address public communicationContract;

    event GameCreated(uint256 gameId, address player1, address player2);
    event MoveMade(uint256 gameId, address player, Move move);
    event GameResult(uint256 gameId, Result result);

    constructor(address _communicationContract) {
        communicationContract = _communicationContract;
    }

    // Function to create a new game
    function _createGame(address player1, address player2) external returns (uint256) {
        gameCounter++;
        games[gameCounter] = Game({
            player1: player1,
            player2: player2,
            player1Move: Move.None,
            player2Move: Move.None,
            result: Result.Pending
        });
        emit GameCreated(gameCounter, player1, player2);
        return gameCounter;
    }

    // Function to receive a move from a player
    function submitMove(uint256 gameId, address player, Move move) external {
        Game storage game = games[gameId];
        require(game.result == Result.Pending, "Game already completed");
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

        if (game.player1Move != Move.None && game.player2Move != Move.None) {
            determineWinner(gameId);
        }
    }

    // Internal function to determine the winner
    function determineWinner(uint256 gameId) internal {
        Game storage game = games[gameId];
        require(game.player1Move != Move.None && game.player2Move != Move.None, "Game not finished");

        if (game.player1Move == game.player2Move) {
            game.result = Result.Draw;
        } else if (
            (game.player1Move == Move.Rock && game.player2Move == Move.Scissors) ||
            (game.player1Move == Move.Paper && game.player2Move == Move.Rock) ||
            (game.player1Move == Move.Scissors && game.player2Move == Move.Paper)
        ) {
            game.result = Result.Player1Wins;
        } else {
            game.result = Result.Player2Wins;
        }

        emit GameResult(gameId, game.result);

        // Send the result back to the communication contract
        _sendMessageToCommunicationContract(gameId, game.result);
    }

    // Function to handle incoming messages from the communication contract
    // Need to receive the data from the communication contract, maybe we need an extra function to unravel the data for the params
    function _receiveMessage(uint256 gameId, address player, uint8 move) external {
        submitMove(gameId, player, Move(move));
    }

    // Function to send messages to the communication contract
    function _sendMessageToCommunicationContract(uint256 gameId, Result result) internal {
        // Logic for sending messages to the communication contract
        // Implement this according to the cross-chain communication protocol
    }
}
