mutable struct Board
    player_one_positions::UInt32
    player_two_positions::UInt32

    player_one_pieces::UInt8
    player_two_pieces::UInt8
end
# stores all the possible combinations for a valid mill from a given positoin
const MILLS_BY_POSITION = [
    [[0, 1, 2], [0, 9, 21]],
    [[0, 1, 2], [1, 4, 7]],
    [[0, 1, 2], [2, 14, 23]],
    [[3, 4, 5], [3, 10, 18]],
    [[3, 4, 5], [1, 4, 7]],
    [[3, 4, 5], [5, 13, 20]],
    [[6, 7, 8], [6, 11, 15]],
    [[6, 7, 8], [1, 4, 7]],
    [[6, 7, 8], [8, 12, 17]],
    [[9, 10, 11], [0, 9, 21]],
    [[9, 10, 11], [3, 10, 18]],
    [[9, 10, 11], [6, 11, 15]],
    [[12, 13, 14], [8, 12, 17]],
    [[12, 13, 14], [5, 13, 20]],
    [[12, 13, 14], [2, 14, 23]],
    [[15, 16, 17], [6, 11, 15]],
    [[15, 16, 17], [16, 19, 22]],
    [[15, 16, 17], [8, 12, 17]],
    [[18, 19, 20], [3, 10, 18]],
    [[18, 19, 20], [16, 19, 22]],
    [[18, 19, 20], [5, 13, 20]],
    [[21, 22, 23], [0, 9, 21]],
    [[21, 22, 23], [16, 19, 22]],
    [[21, 22, 23], [2, 14, 23]]
]

# stores the neighboring positions for a valid move for each position
const ADJACENCY_LIST = [
    [1, 9],
    [0, 2, 4],
    [1, 14],
    [4, 10],
    [1, 3, 5, 7],
    [4, 13],
    [7, 11],
    [4, 6, 8],
    [7, 12],
    [0, 10, 21],
    [3, 9, 11, 18],
    [6, 10, 15],
    [8, 13, 17],
    [5, 12, 14, 20],
    [2, 13, 23],
    [11, 16],
    [15, 17, 19],
    [12, 16],
    [10, 19],
    [16, 18, 20, 22],
    [13, 19],
    [9, 22],
    [19, 21, 23],
    [14, 22]
]

function convert_list_to_bitmask(list::Vector{Int})::UInt32
    res = UInt32(0)
    for current in list
        res |= UInt32(1) << current
    end
    return res
end

# creating bitmasks from these for faster operations
const ADJACENCY_LIST_BIT_MASK = [convert_list_to_bitmask(neighbor) for neighbor in ADJACENCY_LIST]
const MILLS_BY_POSITION_BIT_MASK = [[convert_list_to_bitmask(neighbor) for neighbor in neighbors_list] for neighbors_list in MILLS_BY_POSITION]

# checks if a placement is valid in the first phase of the game
function is_valid_placement(board::Board, position::UInt32)::Bool

    if position > 23
        return false
    end

    if (board.player_one_positions | board.player_two_positions) & (UInt32(1) << position) != 0
        return false
    end

    return true
end

# checks if a move is valid in the second and third phases of the game
function is_valid_move(board::Board, start_pos::UInt32, end_pos::UInt32, player_index::UInt8)::Bool
    if (start_pos > 23) || (end_pos > 23)
        return false
    end

    player_board, enemy_board = player_index == 0 ? (board.player_one_positions, board.player_two_positions) : (board.player_two_positions, board.player_one_positions)

    if player_board & (UInt32(1) << start_pos) == 0
        return false
    end

    if (player_board | enemy_board) & (UInt32(1) << end_pos) != 0
        return false
    end

    # if in third phase, you can jump, no more checks needed
    if (player_index == 0 && board.player_one_pieces == 3) || (player_index == 1 && board.player_two_pieces == 3)
        return true
    end

    # checks if the start and end positions are neighbors
    if ADJACENCY_LIST_BIT_MASK[start_pos+1] & (UInt32(1) << end_pos) == 0
        return false
    end

    return true
end

# checks if a move or placement of a piece created a new mill
function is_mill_after_move(board::Board, position::UInt32, player_index::UInt8)::Bool
    player_board = player_index == 0 ? board.player_one_positions : board.player_two_positions

    for possible_mill in MILLS_BY_POSITION_BIT_MASK[position+1]
        if (player_board & possible_mill) == possible_mill
            return true
        end
    end

    return false
end