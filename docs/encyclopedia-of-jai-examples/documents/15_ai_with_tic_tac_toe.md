# Minimax with Alpha Beta Pruning

This is a Tic Tac Toe console application that lets a human player compete against an AI using the Minimax algorithm with Alpha-Beta pruning.

Alpha-Beta pruning works by passing two running bounds — `alpha` and `beta` — into each recursive call. When `beta <= alpha`, the current branch cannot possibly affect the final result, so the search stops early and prunes that subtree. This reduces the worst-case search from `O(b^d)` to roughly `O(b^(d/2))`, a dramatic speedup.

## Imports

The application imports `Basic` for `print` and `String_Builder` to build and manipulate strings. For reading console input, it imports `Windows` and `ReadConsoleA` on Windows, and `POSIX` on Linux and macOS.

```jai
#import "Basic";   // print, read_entire_file, etc.

#if OS == .WINDOWS {
    #import "Windows";
    kernel32 :: #system_library "kernel32";
    ReadConsoleA  :: (hConsoleHandle: HANDLE, buff : *u8, 
                      chars_to_read : s32,  chars_read : *s32,
                      lpInputControl := *void ) -> bool #foreign kernel32;
} else {
    #import "POSIX";
}
```

## Constants

`PLAYER_X` is `1` and `PLAYER_O` is `-1`. This signed encoding makes it easy to switch the current player with a single multiplication: `current_player *= -1`. An empty cell is represented by `EMPTY`, which equals zero.

```jai
BOARD_SIZE  :: 9;   // 3x3 = 9 cells
EMPTY       :: 0;
PLAYER_X    :: 1;   // Human
PLAYER_O    :: -1;  // AI

// Win conditions: every possible winning line (row, col, diagonal)
WIN_LINES :: int.[
    0, 1, 2,   // top row
    3, 4, 5,   // middle row
    6, 7, 8,   // bottom row
    0, 3, 6,   // left column
    1, 4, 7,   // middle column
    2, 5, 8,   // right column
    0, 4, 8,   // diagonal top-left -> bottom-right
    2, 4, 6,   // diagonal top-right -> bottom-left
];
```

## Data Structures

`Board` is a plain struct containing a static `[9] int` array. It is zero-initialized by default, meaning all cells start as `EMPTY`.

```jai
// In Jai, structs are plain data containers — no member functions, no
// constructors. Everything is a plain procedural function operating on data.
Board :: struct {
    cells: [BOARD_SIZE] int;  // Static array of 9 ints, all zero-initialised
}
```

## Board Utilities

The board utilities handle printing the board state, checking for a winner, reading and parsing console input, checking whether the board is full, and making or undoing a move. These functions provide all the core behavior needed to run the Tic Tac Toe game.

```jai
print_board :: (board: Board) {
    print("\n");
    for row: 0..2 {
        for col: 0..2 {
            idx   := row * 3 + col;
            cell  := board.cells[idx];

            // ifx is Jai's ternary operator:  ifx condition then_val else else_val
            symbol: string;
            if cell == PLAYER_X then {
                symbol = "X";
            } else if cell == PLAYER_O then {
                symbol = "O";
            } else {
                symbol = tprint("%", idx + 1);
            }

            print(" %", symbol);

            // Print column separators
            if col < 2  print(" |");
        }
        print("\n");
        if row < 2  print("---+---+---\n");
    }
    print("\n");
}

// Check if a particular player has won.
// Returns true if any winning line belongs entirely to 'player'.
check_winner :: (board: Board, player: int) -> bool {
    // Iterate over every group of 3 indices that form a winning line.
    // WIN_LINES has 8 lines × 3 cells = 24 entries.
    for i: 0..7 {
        a := WIN_LINES[i * 3 + 0];
        b := WIN_LINES[i * 3 + 1];
        c := WIN_LINES[i * 3 + 2];

        if board.cells[a] == player &&
           board.cells[b] == player &&
           board.cells[c] == player {
            return true;
        }
    }
    return false;
}

// Returns true when no empty cell remains.
is_board_full :: (board: Board) -> bool {
    for cell: board.cells {
        if cell == EMPTY  return false;
    }
    return true;
}

// Apply a move. In Jai, *Board means "pointer to Board" — we pass by pointer
// so we can mutate the caller's data directly.
make_move :: (board: *Board, index: int, player: int) {
    board.cells[index] = player;
}

// Undo a move (used inside the recursive AI search).
undo_move :: (board: *Board, index: int) {
    board.cells[index] = EMPTY;
}

// Read a single line from stdin and strip the trailing newline.
// Jai strings are NOT null-terminated; they carry an explicit length.
read_line :: () -> string {
    builder: String_Builder;
    init_string_builder(*builder);
    defer free_buffers(*builder);   // 'defer' runs at scope close, like Go

    while true {
        ch: u8;
        bytes_read := read_from_standard_input(*ch, 1);
        if bytes_read <= 0       break;
        if ch == #char "\n"      break;
        if ch == #char "\r"      continue;
        append(*builder, ch);
    }
    return builder_to_string(*builder);
}

read_from_standard_input :: (ch: *u8, n: u64) -> int {
    #if OS == .WINDOWS { 
        stdin := GetStdHandle( STD_INPUT_HANDLE );
        bytes_read: s32 = 0;
        ReadConsoleA(stdin, ch, cast(s32)n, *bytes_read);
        return bytes_read;
    } else {
        bytes_read := read(STDIN_FILENO, ch, n);
        return bytes_read;
    }
}

// Parse a string as an integer. Returns (value, ok).
// Multiple return values are a first-class Jai feature.
parse_int :: (s: string) -> (int, bool) {
    if s.count == 0  return 0, false;

    result   := 0;
    negative := false;
    start    := 0;

    if s[0] == #char "-" {
        negative = true;
        start    = 1;
    }

    for i: start..s.count - 1 {
        ch := s[i];
        if ch < #char "0" || ch > #char "9"  return 0, false;
        result = result * 10 + (cast(int)(ch - #char "0"));
    }

    if negative  result = -result;
    return result, true;
}
```

## Minimax with Alpha-Beta Pruning

The AI plays as `PLAYER_O`, so lower scores are better for it. Alpha-Beta pruning tracks two bounds throughout the search:

* `alpha` — the best score the maximizing player `(X)` is guaranteed so far
* `beta` — the best score the minimizing player `(O)` is guaranteed so far

When `beta <= alpha`, we can stop searching the current branch — the opponent will never allow it to be reached.

```jai
minimax :: (board: *Board, depth: int, is_maximising: bool, alpha: int, beta: int) -> int {
    // Terminal state checks — these are the base cases of the recursion.
    if check_winner(board.*, PLAYER_X)  return  10 - depth;   // X wins
    if check_winner(board.*, PLAYER_O)  return -10 + depth;   // O wins (AI)
    if is_board_full(board.*)           return  0;             // Draw

    // Use mutable copies of alpha/beta for this stack frame.
    a := alpha;
    b := beta;

    if is_maximising {
        best := -1000;
        for i: 0..BOARD_SIZE - 1 {
            if board.cells[i] != EMPTY  continue;

            make_move(board, i, PLAYER_X);
            score := minimax(board, depth + 1, false, a, b);
            undo_move(board, i);

            if score > best  best = score;
            if best > a      a    = best;
            if b <= a        break;   // Alpha-Beta cutoff
        }
        return best;
    } else {
        best := 1000;
        for i: 0..BOARD_SIZE - 1 {
            if board.cells[i] != EMPTY  continue;

            make_move(board, i, PLAYER_O);
            score := minimax(board, depth + 1, true, a, b);
            undo_move(board, i);

            if score < best  best = score;
            if best < b      b    = best;
            if b <= a        break;   // Alpha-Beta cutoff
        }
        return best;
    }
}

// Find the single best move for PLAYER_O and return its board index.
find_best_move :: (board: *Board) -> int {
    best_score := 1000;
    best_move  := -1;

    for i: 0..BOARD_SIZE - 1 {
        if board.cells[i] != EMPTY  continue;

        make_move(board, i, PLAYER_O);
        // Minimax starts at depth 0; human (maximiser) moves next.
        score := minimax(board, 0, true, -1000, 1000);
        undo_move(board, i);

        if score < best_score {
            best_score = score;
            best_move  = i;
        }
    }
    return best_move;
}
```

## Main Game Loop

The main game loop initializes the Tic Tac Toe board, reads input from the console, and alternates turns between the human player and the AI. When the game ends, the loop breaks and the program exits.

```jai
main :: () {
    board: Board;   // Zero-initialised by default — all cells are EMPTY.

    print("=== Tic-Tac-Toe ===\n");
    print("You are X. AI is O.\n");
    print("Enter a number 1-9 matching the board position:\n");
    print(" 1 | 2 | 3\n---+---+---\n 4 | 5 | 6\n---+---+---\n 7 | 8 | 9\n\n");

    current_player := PLAYER_X;   // Human goes first.

    while true {
        print_board(board);

        if current_player == PLAYER_X {
            // ----- Human turn -----
            move := -1;
            while true {
                print("Your move (1-9): ");
                input := read_line();
                defer free(input);   // Free heap-allocated string when done.

                value, ok := parse_int(input);
                if !ok || value < 1 || value > 9 {
                    print("Invalid input. Enter a number between 1 and 9.\n");
                    continue;
                }

                idx := value - 1;   // Convert 1-based UI to 0-based index.
                if board.cells[idx] != EMPTY {
                    print("That cell is already taken. Try again.\n");
                    continue;
                }

                move = idx;
                break;
            }
            make_move(*board, move, PLAYER_X);

        } else {
            // ----- AI turn -----
            print("AI is thinking...\n");
            ai_move := find_best_move(*board);
            make_move(*board, ai_move, PLAYER_O);
            print("AI played at position %\n", ai_move + 1);
        }

        // Check game end conditions.
        if check_winner(board, current_player) {
            print_board(board);
            if current_player == PLAYER_X
                print("You win! Congratulations!\n");
            else
                print("AI wins! Better luck next time.\n");
            break;
        }

        if is_board_full(board) {
            print_board(board);
            print("It's a draw!\n");
            break;
        }

        // Flip player: multiplying by -1 toggles between PLAYER_X (1) and
        // PLAYER_O (-1). A neat trick using the signed encoding.
        current_player *= -1;
    }
}
```

# Monte Carlo Tree Search

Monte Carlo Tree Search (MCTS) builds a search tree incrementally by running thousands of random game simulations. Each iteration has four phases:

* **Selection** — Starting from the root, walk down the tree by always picking the child with the highest UCB1 score. UCB1 = `wins/visits + C·√(ln(parent_visits)/visits)`. The constant `C=√2` balances exploration and exploitation, preventing the AI from committing too strongly to one branch before it has enough evidence.
* **Expansion** — When we reach a node that still has unexplored moves, pick one at random and create a new child node for it. The `unexplored` array uses a shrink-swap trick: swap the chosen entry to the end and decrement the count, avoiding any extra memory allocation.
* **Simulation** — From the new child node, play randomly until the game ends. No tree is built during this phase — it is a fast, cheap way to estimate whether a position is roughly good or bad.
* **Backpropagation** — Walk from the expanded node back up to the root, incrementing the visit count on every ancestor. Add `1.0` for a win, `0.5` for a draw, and `0.0` for a loss, always relative to the player who made the move leading to each node.

After all iterations, the root selects the most-visited child rather than the child with the highest win rate. Visit count is a more robust signal because the algorithm naturally spends more iterations on promising branches.

## Imports

The application imports `Basic` for `print` and `String_Builder`. It also imports `Random` for random number generation during simulations, and `Math` for `log` and `sqrt`, which are needed by the UCB1 formula. For console input, it imports `Windows` and `ReadConsoleA` on Windows, and `POSIX` on Linux and macOS.

```jai
#import "Basic";
#import "Random";
#import "Math";     // for log, sqrt
#if OS == .WINDOWS {
    #import "Windows";
    kernel32 :: #system_library "kernel32";
    ReadConsoleA  :: (hConsoleHandle: HANDLE, buff : *u8,
                      chars_to_read : s32,  chars_read : *s32,
                      lpInputControl := *void ) -> bool #foreign kernel32;
} else {
    #import "POSIX";
}
```

## Constants

`PLAYER_X` is `1` and `PLAYER_O` is `2`. `MCTS_ITERATIONS` controls how many simulation cycles the AI runs per move — more iterations produce stronger play but take longer. `UCB_C` is the exploration constant `√2` used in the UCB1 formula.

```jai
BOARD_SIZE    :: 9;
EMPTY         :: 0;
PLAYER_X      :: 1;   // Human
PLAYER_O      :: 2;   // AI (MCTS)

MCTS_ITERATIONS :: 10000;   // Higher = stronger AI, but slower response
UCB_C           :: 1.41421; // sqrt(2) exploration constant

// Win-line table: 8 lines × 3 cell indices each
WIN_LINES :: int.[
    0,1,2,  3,4,5,  6,7,8,  // rows
    0,3,6,  1,4,7,  2,5,8,  // cols
    0,4,8,  2,4,6,           // diagonals
];
```

## Board Utilities

The board utilities handle printing the board, checking for a winner, determining the game result, finding empty cells, and reading and parsing console input. These functions provide all the core behavior needed to run the game and support the MCTS search.

```jai
Board :: struct {
    cells : [BOARD_SIZE] int;   // 0=empty, 1=X, 2=O
}

// Check if 'player' has won. Returns true on the first matching line found.
check_winner :: (board: Board, player: int) -> bool {
    for i : 0..7 {
        a := WIN_LINES[i*3+0];
        b := WIN_LINES[i*3+1];
        c := WIN_LINES[i*3+2];
        if board.cells[a] == player &&
           board.cells[b] == player &&
           board.cells[c] == player   return true;
    }
    return false;
}

is_board_full :: (board: Board) -> bool {
    for cell : board.cells {
        if cell == EMPTY return false;
    }
    return true;
}

// Returns PLAYER_X, PLAYER_O, -1 for draw, or 0 if the game is still in progress.
game_result :: (board: Board) -> int {
    if check_winner(board, PLAYER_X) return PLAYER_X;
    if check_winner(board, PLAYER_O) return PLAYER_O;
    if is_board_full(board)          return -1;   // draw
    return 0;                                      // ongoing
}

// Fill 'out' with the indices of all empty cells.
// Returns the number of empty cells found.
get_empty_cells :: (board: Board, out: *[BOARD_SIZE] int) -> int {
    count := 0;
    for i : 0..BOARD_SIZE-1 {
        if board.cells[i] == EMPTY {
            out.*[count] = i;
            count += 1;
        }
    }
    return count;
}

print_board :: (board: Board) {
    print("\n");
    for row : 0..2 {
        for col : 0..2 {
            idx  := row * 3 + col;
            cell := board.cells[idx];
            // ifx is Jai's ternary operator
            sym  := ifx cell == PLAYER_X then "X"
                    else ifx cell == PLAYER_O then "O"
                    else cast(string)(tprint("%", idx + 1));
            print(" %", sym);
            if col < 2 print(" |");
        }
        print("\n");
        if row < 2 print("---+---+---\n");
    }
    print("\n");
}

read_from_standard_input :: (ch: *u8, n: u64) -> int {
    #if OS == .WINDOWS {
        stdin := GetStdHandle( STD_INPUT_HANDLE );
        bytes_read: s32 = 0;
        ReadConsoleA(stdin, ch, cast(s32)n, *bytes_read);
        return bytes_read;
    } else {
        bytes_read := read(STDIN_FILENO, ch, n);
        return bytes_read;
    }
}

read_line :: () -> string {
    builder: String_Builder;
    init_string_builder(*builder);
    defer free_buffers(*builder);

    while true {
        ch: u8;
        bytes_read := read_from_standard_input(*ch, 1);
        if bytes_read <= 0     break;
        if ch == #char "\n"    break;
        if ch == #char "\r"    continue;
        append(*builder, ch);
    }
    return builder_to_string(*builder);
}

// Returns (value, ok). Multiple return values are a first-class Jai feature.
parse_int :: (s: string) -> (int, bool) {
    if s.count == 0 return 0, false;
    result   := 0;
    negative := false;
    start    := 0;
    if s[0] == #char "-" { negative = true; start = 1; }
    for i : start..s.count-1 {
        ch := s[i];
        if ch < #char "0" || ch > #char "9" return 0, false;
        result = result * 10 + cast(int)(ch - #char "0");
    }
    if negative result = -result;
    return result, true;
}
```

## Monte Carlo Tree Search Implementation

MCTS is a decision-making algorithm that finds good moves by combining random simulation with incremental learning. Rather than evaluating every possible game state (which is computationally infeasible in complex games), MCTS:

* Runs many random playthroughs from the current position
* Learns which moves tend to lead to better outcomes
* Gradually builds a tree of promising decisions

The algorithm repeats the four phases — selection, expansion, simulation, and backpropagation — for many iterations. More iterations produce stronger, more reliable decisions.

```jai
// -----------------------------------------------------------------------------
//  MCTS Node
//
//  In Jai, structs are plain data. Self-referential pointers (*MCTS_Node) are
//  fine; the struct is declared at file scope so the compiler knows its full
//  layout before any procedures reference it.
// -----------------------------------------------------------------------------

MCTS_Node :: struct {
    board         : Board;       // board state at this node
    move          : int;         // which cell index led to this state (-1 = root)
    player        : int;         // which player moves NEXT from this node
    parent        : *MCTS_Node;

    // Children are stored in a dynamic array [..] — grows on demand
    children      : [..] *MCTS_Node;

    // Unexplored moves for this node (filled at creation, shrinks as we expand)
    unexplored     : [BOARD_SIZE] int;
    unexplored_count : int;

    visits        : int;
    wins          : float;       // fractional: win=1, draw=0.5, loss=0
}

// Allocate and initialize a new node.
// 'New(T)' in Jai heap-allocates one T (like C's malloc + memset 0).
new_node :: (board: Board, move: int, player: int, parent: *MCTS_Node) -> *MCTS_Node {
    node := New(MCTS_Node);
    node.board   = board;
    node.move    = move;
    node.player  = player;
    node.parent  = parent;
    node.visits  = 0;
    node.wins    = 0.0;

    // Populate unexplored moves from the board's empty cells
    node.unexplored_count = get_empty_cells(board, *node.unexplored);
    return node;
}

// Recursively free the entire subtree rooted at 'node'.
// 'free(ptr)' is the Jai Basic-module equivalent of C's free().
free_tree :: (node: *MCTS_Node) {
    for child : node.children  free_tree(child);
    array_free(node.children);
    free(node);
}

// Returns true once every legal move from this node has a corresponding child.
is_fully_expanded :: (node: *MCTS_Node) -> bool {
    return node.unexplored_count == 0;
}

is_terminal :: (node: *MCTS_Node) -> bool {
    return game_result(node.board) != 0;
}

// -----------------------------------------------------------------------------
//  UCB1 — Upper Confidence Bound (exploration / exploitation trade-off)
// -----------------------------------------------------------------------------

ucb1_score :: (node: *MCTS_Node, parent_visits: int) -> float {
    if node.visits == 0 return 1.0e30;   // unvisited nodes get infinite priority

    exploitation := node.wins / cast(float) node.visits;
    exploration  := UCB_C * sqrt(log(cast(float) parent_visits) /
                                 cast(float) node.visits);
    return exploitation + exploration;
}

// Choose the child with the highest UCB1 value.
best_uct_child :: (node: *MCTS_Node) -> *MCTS_Node {
    best      : *MCTS_Node = null;
    best_score := -1.0e30;

    for child : node.children {
        score := ucb1_score(child, node.visits);
        if score > best_score {
            best_score = score;
            best       = child;
        }
    }
    return best;
}

// -----------------------------------------------------------------------------
//  PHASE 1 — Selection
//  Walk down the tree using UCB1 until we reach a node that is either
//  terminal or not yet fully expanded.
// -----------------------------------------------------------------------------

select_node :: (root: *MCTS_Node) -> *MCTS_Node {
    node := root;
    while !is_terminal(node) && is_fully_expanded(node) {
        node = best_uct_child(node);
    }
    return node;
}

// -----------------------------------------------------------------------------
//  PHASE 2 — Expansion
//  Pick one random unexplored move and create a new child node for it.
// -----------------------------------------------------------------------------

expand :: (node: *MCTS_Node) -> *MCTS_Node {
    if is_terminal(node) return node;  // can't expand a finished game

    // Pick a random unexplored move by swapping it to the end and shrinking
    // the unexplored slice — avoids the need for a separate visited-flag array.
    r   := cast(int)(random_get() % cast(u32) node.unexplored_count);
    move := node.unexplored[r];

    // Swap chosen move with the last unexplored entry, then shrink
    node.unexplored[r]                         = node.unexplored[node.unexplored_count - 1];
    node.unexplored_count -= 1;

    // Build the child board by applying the move
    new_board        := node.board;
    new_board.cells[move] = node.player;

    // Next player: toggle between PLAYER_X (1) and PLAYER_O (2)
    next_player := ifx node.player == PLAYER_X then PLAYER_O else PLAYER_X;

    child := new_node(new_board, move, next_player, node);
    array_add(*node.children, child);
    return child;
}

// -----------------------------------------------------------------------------
//  PHASE 3 — Simulation (Rollout)
//  Play randomly until the game ends. Returns the winner (PLAYER_X, PLAYER_O,
//  or -1 for a draw).
// -----------------------------------------------------------------------------

simulate :: (node: *MCTS_Node) -> int {
    board  := node.board;
    player := node.player;

    while true {
        result := game_result(board);
        if result != 0 return result;

        // Gather empty cells and pick one at random
        empties   : [BOARD_SIZE] int;
        emp_count := get_empty_cells(board, *empties);

        r    := cast(int)(random_get() % cast(u32) emp_count);
        move := empties[r];

        board.cells[move] = player;
        player = ifx player == PLAYER_X then PLAYER_O else PLAYER_X;
    }

    return -1;   // unreachable, but satisfies the compiler
}

// -----------------------------------------------------------------------------
//  PHASE 4 — Backpropagation
//  Walk from 'node' back to the root, updating visits and wins.
//  The score is always recorded from the perspective of the node's *parent*
//  (i.e. the player who just moved to reach this node).
// -----------------------------------------------------------------------------

backpropagate :: (node: *MCTS_Node, result: int, ai_player: int) {
    current := node;
    while current != null {
        current.visits += 1;

        // The player who made the move that led TO 'current' is the *parent's*
        // current player. We award the win to whoever owns this node's move.
        mover := ifx current.parent != null then current.parent.player else -99;

        if result == -1 {
            current.wins += 0.5;   // draw — both sides share half a point
        } else if result == mover {
            current.wins += 1.0;   // the player who moved here won
        }
        // else: opponent won — no points added for this node

        current = current.parent;
    }
}

// -----------------------------------------------------------------------------
//  Top-level MCTS search
//  Runs MCTS_ITERATIONS selection/expansion/simulation/backpropagation cycles,
//  then returns the index of the move with the most visits at the root.
// -----------------------------------------------------------------------------

mcts_best_move :: (board: Board, ai_player: int) -> int {
    // The root node represents the state *before* the AI moves.
    // 'ai_player' is the player whose turn it is at the root.
    root := new_node(board, -1, ai_player, null);
    defer free_tree(root);   // 'defer' runs when this scope closes — clean up

    for 0..MCTS_ITERATIONS-1 {
        // --- Selection ---
        selected := select_node(root);

        // --- Expansion ---
        expanded := ifx is_terminal(selected) then selected else expand(selected);

        // --- Simulation ---
        result := simulate(expanded);

        // --- Backpropagation ---
        backpropagate(expanded, result, ai_player);
    }

    // Pick the child with the most visits (most robust policy)
    best_move   := -1;
    best_visits := -1;
    for child : root.children {
        if child.visits > best_visits {
            best_visits = child.visits;
            best_move   = child.move;
        }
    }

    return best_move;
}

// Seed the RNG using the current wall-clock time so each run differs.
seed_rng :: () {
    t := cast(u32)(seconds_since_init() * 1_000_000.0);
    random_seed(t);
}

```

## Main Game Loop

The main game loop initializes the board, prints instructions, and alternates turns between the human player and the MCTS AI. When the game ends — by a win or a draw — the loop breaks and the program exits.

```jai
main :: () {
    seed_rng();

    board : Board;   // zero-initialised — all cells are EMPTY

    print("=== Tic-Tac-Toe (MCTS AI) ===\n");
    print("You are X. The AI is O.\n");
    print("Enter a number 1-9 matching the board position:\n");
    print(" 1 | 2 | 3\n---+---+---\n 4 | 5 | 6\n---+---+---\n 7 | 8 | 9\n");
    print("AI will run % simulations per move.\n\n", MCTS_ITERATIONS);

    current_player := PLAYER_X;   // Human goes first

    while true {
        print_board(board);

        if current_player == PLAYER_X {
            // ---- Human turn ----
            move := -1;
            while true {
                print("Your move (1-9): ");
                input := read_line();
                defer free(input);

                value, ok := parse_int(input);
                if !ok || value < 1 || value > 9 {
                    print("Invalid input. Please enter a number from 1 to 9.\n");
                    continue;
                }

                idx := value - 1;
                if board.cells[idx] != EMPTY {
                    print("Cell % is already taken. Try again.\n", value);
                    continue;
                }
                move = idx;
                break;
            }
            board.cells[move] = PLAYER_X;

        } else {
            // ---- AI turn (MCTS) ----
            print("AI is thinking (running % iterations)...\n", MCTS_ITERATIONS);

            t0       := seconds_since_init();
            ai_move  := mcts_best_move(board, PLAYER_O);
            elapsed  := seconds_since_init() - t0;

            board.cells[ai_move] = PLAYER_O;
            print("AI played position % (took %.3fs)\n", ai_move + 1, elapsed);
        }

        // Check end conditions
        result := game_result(board);
        if result != 0 {
            print_board(board);
            if result == PLAYER_X         print("You win! Congratulations!\n");
            else if result == PLAYER_O    print("AI wins! Better luck next time.\n");
            else                          print("It's a draw!\n");
            break;
        }

        // Toggle player
        current_player = ifx current_player == PLAYER_X then PLAYER_O else PLAYER_X;
    }
}
```
