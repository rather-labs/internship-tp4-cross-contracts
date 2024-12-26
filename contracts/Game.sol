// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    mapping(uint256 => mapping(uint256 => Game)) public games; // Track games by chainID and gameNumber

    address public communicationContract;

    event GameCreated(GameId gameId, address player1, address player2);
    event MoveMade(GameId gameId, address player, Move move);
    event GameResult(Game finishedGame);

    constructor(address _communicationContract, uint256 _chainID) {
        communicationContract = _communicationContract;
        chainID = _chainID;
    }

    function _determineWinner(GameId memory gameId) internal {
        Game storage game = games[gameId.rivalChainID][gameId.gameNumber];
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
    
    // Function to create a new game
    function _createGame(
        address player1,
        address player2,
        uint256 rivalChainID,
        Move move
    ) internal {
        gameCounter[rivalChainID]++; //update the game counter for the source chain
        GameId memory gameId = GameId({
            rivalChainID: rivalChainID,
            gameNumber: gameCounter[rivalChainID]
        });
        require(games[rivalChainID][gameId.gameNumber].player1 == address(0), "Game already exists");
        
        games[rivalChainID][gameId.gameNumber] = Game({
            player1: player1,
            player2: player2,
            player1Move: move, //player1 always makes the first move, assigned in the game creation
            player2Move: Move.None,
            result: Result.Pending
        });
        emit GameCreated(gameId, player1, player2);
    }

    
    // Function to send messages to the communication contract
    function _sendMoveToCommunicationContract(GameId memory gameId, address player1, address player2, Move move) internal {
        // First encode the receiveMove function call
        bytes memory functionCall = abi.encodeWithSignature(
            "receiveMove(GameId,address,address,Move)", 
            gameId,
            player1,
            player2,
            move
        );
        
        // Then encode the handleMessage call with the function call as parameter
        bytes memory messageData = abi.encodeWithSignature(
            "handleMessage(bytes)",
            functionCall
        );
        
        // Cast the communicationContract address to the interface
        IOutgoingCommunication outgoing = IOutgoingCommunication(communicationContract);
        
        // Send message to execute handleMessage on destination chain
        // Call sendMessage with the following parameters:
        // - messageData: encoded game result
        // - receiver: address of the game contract on the destination chain
        // - destinationBC: the destination blockchain ID (you'll need to specify this)
        // - finalityNBlocks: number of blocks for finality (e.g., 1)
        // - taxi: whether to use taxi mode (faster but more expensive)
        outgoing.sendMessage{value: 0}( // Add value if needed for fees
            messageData,
            address(this), // assuming the game contract has same address on other chain CHANGE
            gameId.rivalChainID,
            1, // Replace with actual finality blocks needed
            false // Replace with actual taxi preference
        );
    }

    function submitMove(GameId memory gameId, address player1, address player2, Move move) public {
        require(move != Move.None, "Invalid move");

        if(games[gameId.rivalChainID][gameId.gameNumber].player1 == address(0)) {
            //create the game and add the first move to the game
            _createGame(player1, player2, gameId.rivalChainID, move);
        } else {
            Game storage game = games[gameId.rivalChainID][gameId.gameNumber];

            require(game.result == Result.Pending && game.player2Move == Move.None, "Game already completed"); 
            
            //In this case, we submit the move to a game that already has a first move so, it's the player2 move
            game.player2Move = move;

            emit MoveMade(gameId, player2, move);

            _determineWinner(gameId);

            //In this case, the player is responding to a received game, and has to inform the player1 of this move.
            if (msg.sender == game.player2) {
                _sendMoveToCommunicationContract(gameId, player1, player2, move);
            }
        }
    }

    function startGame(GameId memory gameId, address player1, address player2, Move move) external {
        _createGame(player1, player2, gameId.rivalChainID, move);
        _sendMoveToCommunicationContract(gameId, player1, player2, move);
    }

    // Function to handle incoming messages from the communication contract
    // Need to receive the data from the communication contract, maybe we need an extra function to unravel the data for the params
    function receiveMove(bytes calldata data) external {
        (GameId memory gameId, address player1, address player2, Move move) = abi.decode(data, (GameId, address, address, Move));
        
        // Now we can directly use the memory struct
        submitMove(gameId, player1, player2, move);
    }

}
