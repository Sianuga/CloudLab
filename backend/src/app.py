from flask import Flask, jsonify, request, session
from flask_cors import CORS
from flask_session import Session
import os
from datetime import datetime, timedelta

app = Flask(__name__)

CORS(app, resources={r"/*": {"origins": "*"}})

app.secret_key = os.urandom(24)
app.config["SESSION_TYPE"] = "filesystem"
app.config["SESSION_FILE_DIR"] = "./.flask_session/"
Session(app)

board = [["" for _ in range(3)] for _ in range(3)]
players = {1: {"session_id": None, "last_heartbeat": None}, 2: {"session_id": None, "last_heartbeat": None}}
current_turn = 1

@app.route('/join', methods=['GET'])
def join_game():
    clean_inactive_players()
    for player_id in players:
        if players[player_id]["session_id"] is None:
            players[player_id]["session_id"] = session.sid
            players[player_id]["last_heartbeat"] = datetime.now()
            return jsonify({'player': player_id})
    return jsonify({'error': 'Game is full'}), 400

@app.route('/heartbeat', methods=['POST'])
def heartbeat():
    data = request.get_json()
    player_id = int(data['player'])

    if players.get(player_id) and players[player_id]["session_id"] == session.sid:
        players[player_id]["last_heartbeat"] = datetime.now()
        return jsonify({'status': 'ok'})
    else:
        return jsonify({'error': 'Heartbeat failed: invalid player or session'}), 400

def clean_inactive_players():
    for player_id, info in players.items():
        if info["session_id"] and (datetime.now() - info["last_heartbeat"]) > timedelta(seconds=30):
            # Reset player if inactive for more than 30 seconds
            players[player_id] = {"session_id": None, "last_heartbeat": None}

@app.route('/move', methods=['POST'])
def make_move():
    global current_turn
    session_id = session.sid
    data = request.get_json()
    x, y, player = data['x'], data['y'], data['player']

    if current_turn != player:
        return jsonify({'error': 'Not your turn'}), 400

    if board[x][y] != "":
        return jsonify({'error': 'Invalid move'}), 400

    board[x][y] = "X" if current_turn == 1 else "O"
    winner = check_winner()
    draw = is_draw()

    current_turn = 2 if current_turn == 1 else 1

    return jsonify({'board': board, 'winner': winner, 'draw': draw, 'current_turn': current_turn})

@app.route('/reset', methods=['POST'])
def reset_game():
    global board, current_turn, players
    board = [["" for _ in range(3)] for _ in range(3)]
    current_turn = 1
    players = {1: {"session_id": None, "last_heartbeat": None}, 2: {"session_id": None, "last_heartbeat": None}}
    return jsonify({'status': 'Game reset'}), 200





@app.route('/state', methods=['GET'])
def get_state():
    return jsonify({
        'board': board,
        'current_turn': current_turn,
        'winner': winner(),
        'draw': is_draw()
    })

@app.route('/current_turn', methods=['GET'])
def get_current_turn():
    return jsonify({'current_turn': current_turn})


def winner():
    win = check_winner()
    if win == "X":
        return "1"
    elif win == "O":
        return "2"
    return None


def check_winner():
    for i in range(3):
        if board[i][0] == board[i][1] == board[i][2] != "":
            return board[i][0]
        if board[0][i] == board[1][i] == board[2][i] != "":
            return board[0][i]
    if board[0][0] == board[1][1] == board[2][2] != "":
        return board[0][0]
    if board[0][2] == board[1][1] == board[2][0] != "":
        return board[1][1]
    return None

def is_draw():
    for row in board:
        if "" in row:
            return False
    return True

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)