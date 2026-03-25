include("mill_board.jl")

struct Node
    mini_max_estimate::Int
    board::Board
end

total_evaluations = 0


# multipliers for the heauristic evaluation of the score
const PIECE_DIFF_MULTIPLIER = 100
const END_PIECE_DIFF_MULTIPLIER = 10000
const MILLS_DIFF_MULTIPLIER = 40
const NEARLY_MILL_MULTIPLIER = 20
const INTERSECTION_MULTIPLIER = 5

function evaluate_first_phase(board::Board)::Int
    global total_evaluations += 1

    score = 0

    score += PIECE_DIFF_MULTIPLIER * (board.player_one_pieces - board.player_two_pieces)

    p1_mills = 0
    p1_nearly = 0

    p2_mills = 0
    p2_nearly = 0
    for mill_mask in ALL_MILLS_BIT_MASK

        p1_count_in_mill = count_ones(mill_mask & board.player_one_positions)
        p2_count_in_mill = count_ones(mill_mask & board.player_two_positions)

        if (p1_count_in_mill == 3)
            p1_mills += 1
        elseif p1_count_in_mill == 2 && p2_count_in_mill == 0
            p1_nearly += 1
        end

        if (p2_count_in_mill == 3)
            p2_mills += 1
        elseif p2_count_in_mill == 2 && p1_count_in_mill == 0
            p2_nearly += 1
        end
    end

    score += MILLS_DIFF_MULTIPLIER * (p1_mills - p2_mills)
    score += NEARLY_MILL_MULTIPLIER * (p1_nearly - p2_nearly)

    p1_intersection_count = count_ones(INTERSECTIONS_BIT_MASK & board.player_one_positions)
    p2_intersection_count = count_ones(INTERSECTIONS_BIT_MASK & board.player_two_positions)

    score += INTERSECTION_MULTIPLIER * (p1_intersection_count - p2_intersection_count)

    return score
end

function mini_max_first_phase(board::Board, player::Bool, depth::UInt8, alpha::Int, beta::Int)::Node
    if (depth == 0)
        return Node(evaluate_first_phase(board), board)
    end

    best_board = board

    player == false ? ret = typemin(Int) : ret = typemax(Int)

    empty_spots = get_empty_spots_mask(board)

    while (empty_spots != 0)
        pos = UInt32(trailing_zeros(empty_spots))
        if (is_valid_placement(board, pos))
            # Player 1 branch Maximizer
            if player == false
                player1_pos = board.player_one_positions | (UInt32(1) << pos)
                player1_piece_count = board.player_one_pieces + 1

                player2_pos = board.player_two_positions
                player2_piece_count = board.player_two_pieces
            
            # Player 2 branch Minimizer
            else
                player1_pos = board.player_one_positions
                player1_piece_count = board.player_one_pieces

                player2_pos = board.player_two_positions | (UInt32(1) << pos)
                player2_piece_count = board.player_two_pieces + 1
            end

            new_board = Board(player1_pos, player2_pos, player1_piece_count, player2_piece_count)

            child_node = process_move(new_board, pos, depth, alpha, beta, player)

            evaluated_score = child_node.mini_max_estimate
            evaluated_board = child_node.board

            if (player)
                if evaluated_score < ret
                    ret = evaluated_score
                    best_board = evaluated_board
                end
                beta = min(beta, evaluated_score)
            else
                if evaluated_score > ret
                    ret = evaluated_score
                    best_board = evaluated_board
                end
                alpha = max(alpha, evaluated_score)
            end
            
            if beta <= alpha
                return Node(ret, best_board)
            end

        end
        empty_spots &= ~(UInt32(1) << pos)
    end
               
    return Node(ret, best_board)
end

function process_move(board::Board, pos::UInt32, depth::UInt8,alpha::Int, beta::Int, player::Bool)::Node
    
    player == false ? ret = typemin(Int) : ret = typemax(Int)

    best_board = board

    if (is_mill_after_move(board, pos, player))
        can_capture_mask = get_capturable_bit_mask(board, !player)

        while (can_capture_mask > 0)
            capturable_piece = trailing_zeros(can_capture_mask)

            other_player_pos = player ? ( board.player_one_positions & (~(UInt32(1) << capturable_piece)) ) : ( board.player_two_positions & (~(UInt32(1) << capturable_piece)) )
            other_player_piece_count = player ? board.player_one_pieces - 1 : board.player_two_pieces - 1

            final_board = player ? Board(other_player_pos, board.player_two_positions, other_player_piece_count, board.player_two_pieces) : Board(board.player_one_positions, other_player_pos, board.player_one_pieces, other_player_piece_count)

            evaluated = mini_max_first_phase(final_board, !player, UInt8(depth - 1), alpha, beta).mini_max_estimate

            if (player)
                if evaluated < ret
                    ret = evaluated
                    best_board = final_board
                end
                beta = min(beta, evaluated)
            else
                if evaluated > ret
                    ret = evaluated
                    best_board = final_board
                end
                alpha = max(alpha, evaluated)
            end
            
            if beta <= alpha
                return Node(ret, best_board)
            end

            can_capture_mask &= ~(UInt32(1) << capturable_piece)
        end
    else
        evaluated = mini_max_first_phase(board, !player, UInt8(depth - 1), alpha, beta).mini_max_estimate

        if (player)
            if evaluated < ret
                ret = evaluated
                best_board = board
            end
            beta = min(beta, evaluated)
        else
            if evaluated > ret
                ret = evaluated
                best_board = board
            end
            alpha = max(alpha, evaluated)
        end
            
            if beta <= alpha
                return Node(ret, best_board)
            end
    end
    return Node(ret, best_board)
end

# this is just a copy of the first phase evalution for test purposes and should be extended with logic more fitting
# for the second phase of the game
const AVAILABLE_MOVES_MULTIPLIER = 20
function evaluate_second_phase(board::Board)::Int
    global total_evaluations += 1

    score = 0

    player_one_possible_move_count = get_available_move_count(board, false)
    player_two_possible_move_count = get_available_move_count(board, true)

    #   checking if the game ended
    if  board.player_two_pieces < 3 || player_two_possible_move_count == 0
        return typemax(Int)
    elseif board.player_one_pieces < 3 || player_one_possible_move_count == 0
        return typemin(Int) 
    end

    score += AVAILABLE_MOVES_MULTIPLIER * (player_one_possible_move_count * player_two_possible_move_count)


    current_piece_diff_multiplier = (board.player_one_pieces == 3 || board.player_two_pieces == 3) ? PIECE_DIFF_MULTIPLIER : END_PIECE_DIFF_MULTIPLIER
    score += current_piece_diff_multiplier * (board.player_one_pieces - board.player_two_pieces)

    p1_mills = 0
    p1_nearly = 0

    p2_mills = 0
    p2_nearly = 0
    for mill_mask in ALL_MILLS_BIT_MASK

        p1_count_in_mill = count_ones(mill_mask & board.player_one_positions)
        p2_count_in_mill = count_ones(mill_mask & board.player_two_positions)

        if (p1_count_in_mill == 3)
            p1_mills += 1
        elseif p1_count_in_mill == 2 && p2_count_in_mill == 0
            p1_nearly += 1
        end

        if (p2_count_in_mill == 3)
            p2_mills += 1
        elseif p2_count_in_mill == 2 && p1_count_in_mill == 0
            p2_nearly += 1
        end
    end

    score += MILLS_DIFF_MULTIPLIER * (p1_mills - p2_mills)
    score += NEARLY_MILL_MULTIPLIER * (p1_nearly - p2_nearly)

    p1_intersection_count = count_ones(INTERSECTIONS_BIT_MASK & board.player_one_positions)
    p2_intersection_count = count_ones(INTERSECTIONS_BIT_MASK & board.player_two_positions)
    score += INTERSECTION_MULTIPLIER * (p1_intersection_count - p2_intersection_count)

    return score
end


function mini_max_second_phase(board::Board, player::Bool, depth::UInt8, alpha::Int, beta::Int)::Node

    # check if the game ended
    board_eval = evaluate_second_phase(board)
    if (board_eval == typemax(Int)) || (board_eval == typemin(Int)) || (depth == 0)
        return Node(board_eval, board)
    end

    best_board = board
    empty_spots = get_empty_spots_mask(board)

    player == false ? ret = typemin(Int) : ret = typemax(Int)

    player == false ? player_positions = board.player_one_positions : player_positions = board.player_two_positions

    while (player_positions != 0)
            # the place of first one, from the players pieces, is the starting position of our move
            from_move = trailing_zeros(player_positions)

            valid_moves_bit_mask = ADJACENCY_LIST_BIT_MASK[from_move+1] & empty_spots
            while (valid_moves_bit_mask != 0)
                to_move = trailing_zeros(valid_moves_bit_mask)

                if (player == false)
                    new_p1_position = board.player_one_positions & ~(UInt32(1) << from_move) | (UInt32(1) << to_move)    
                    new_board = Board(new_p1_position, board.player_two_positions, board.player_one_pieces, board.player_two_pieces)
                else
                    new_p2_position = board.player_two_positions & ~(UInt32(1) << from_move) | (UInt32(1) << to_move)
                    new_board = Board(board.player_one_positions, new_p2_position, board.player_one_pieces, board.player_two_pieces)
                end

                child_node = process_move(new_board, to_move, depth, alpha, beta, player)
                
                evaluated_score = child_node.mini_max_estimate
                evaluated_board = child_node.board

                if (player)
                    if evaluated_score < ret
                        ret = evaluated_score
                        best_board = evaluated_board
                    end
                    beta = min(beta, evaluated_score)
                else
                    if evaluated_score > ret
                        ret = evaluated_score
                        best_board = evaluated_board
                    end
                    alpha = max(alpha, evaluated_score)
                end
            
                if beta <= alpha
                    return Node(ret, best_board)
                end

                # we remove the last one, the place, where we moved our place
                valid_moves_bit_mask &= ~(UInt32(1) << to_move)
            end
            player_positions &= ~(UInt32(1) << from_move)
        end

    return Node(ret, best_board)
end