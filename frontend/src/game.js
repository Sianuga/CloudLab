let currentPlayer = '';
const board = document.querySelector('#board');
const tiles = board.querySelectorAll('.tile');
const SERVER_URL = '${server_url}';
let playerID = '';

function joinGame() {
    fetch(`${SERVER_URL}/join`)
        .then(response => response.json())
        .then(data => {
            if(data.player) {
                currentPlayer = data.player;
                playerID = data.player;
                document.querySelector('#current-player').textContent = `You are: ${currentPlayer}`;
                pollGameStatus();
                setInterval(sendHeartbeat, 10000);
            } else if(data.error) {
                alert(data.error);
            }
        });
}



function sendHeartbeat() {
    if (playerID) {
        fetch(`${SERVER_URL}/heartbeat`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ player: playerID.toString() })
        })
            .then(response => {
                if (!response.ok) {
                    throw new Error('Heartbeat failed with status: ' + response.status);
                }
                return response.json();
            })
            .catch(error => console.error('Error sending heartbeat:', error));
    }
}


function makeMove(x, y) {
    fetch(`${SERVER_URL}/move`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ x, y, player: currentPlayer })
    })
        .then(response => response.json())
        .then(data => {
            if (data.error) {
                alert(data.error);
            } else {
                updateBoard(data.board);
                pollGameStatus();
            }
        });
}

function updateBoard(board) {
    board.forEach((row, x) => {
        row.forEach((value, y) => {
            const tile = tiles[x * 3 + y];
            tile.textContent = value;
        });
    });
}


function startGame() {
    const playerName = document.getElementById('player-name').value;
    if (playerName) {
        joinGame(playerName);

        document.getElementById('start-game').style.display = 'none';
    } else {
        alert("Please enter your name.");
    }
}

function pollGameStatus() {
    fetch(`${SERVER_URL}/state`)
        .then(response => response.json())
        .then(data => {
            updateBoard(data.board);

            if (data.winner) {
                document.querySelector('#game-over-text').textContent = `Winner is ${data.winner === '1' ? 'X' : 'O'}`;
                document.querySelector('#game-over-area').classList.remove('hidden');
            } else if (data.draw) {
                document.querySelector('#game-over-text').textContent = 'Draw!';
                document.querySelector('#game-over-area').classList.remove('hidden');
            } else {
                if (data.current_turn.toString() === playerID) {
                    document.querySelector('#current-player-info').textContent = 'Your turn';
                } else {
                    document.querySelector('#current-player-info').textContent = 'Waiting for opponent';
                    pollGameStatus();
                }
            }
        })
        .catch(error => console.error('Error polling game status:', error));

    setTimeout(pollGameStatus, 2000);
}

board.addEventListener('click', event => {
    if (event.target.classList.contains('tile')) {
        const index = Array.from(tiles).indexOf(event.target);
        const x = Math.floor(index / 3);
        const y = index % 3;
        makeMove(x, y);
    }
});

document.querySelector('#play-again').addEventListener('click', () => {
    fetch(`${SERVER_URL}/reset`, { method: 'POST' })
        .then(response => response.json())
        .then(data => {

            document.querySelector('#game-over-area').classList.add('hidden');
            tiles.forEach(tile => tile.textContent = '');
            joinGame();
        });
});



joinGame();
