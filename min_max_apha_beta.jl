include("mill_board.jl")

struct Node
    mini_max_estimate::Int
    board::Board
end

total_evaluations = 0


# multipliers for the heauristic evaluation of the score
const PIECE_DIFF_MULTIPLIER = 100
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

# this function does not abide by the DRY principles at all, and should be refactored as soon as possible,
# to make it readable at all xD
function mini_max_first_phase(board::Board, player::Bool, depth::UInt8, alpha::Int, beta::Int)::Node
    if (depth == 0)
        return Node(evaluate_first_phase(board), board)
    end

    best_board = board

    # the minimizer player
    if player
        ret = typemax(Int)
        for i in 0:23
            pos = UInt32(i)
            if (is_valid_placement(board, pos))
                child_node = first_phase_action(board, pos, depth, alpha, beta, player)

                evaluated_score = child_node.score
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
        end
    else
        ret = typemin(Int)
        for i in 0:23
            pos = UInt32(i)
            if (is_valid_placement(board, pos))
                child_node = first_phase_action(board, pos, depth, alpha, beta, player)

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
        end
    end

    return Node(ret, best_board)
end

function first_phase_action(board::Board, pos::UInt32, depth::UInt8,alpha::Int, beta::Int, player::Bool)::Node
    
    curr_player_pos = player ? board.player_two_positions | (UInt32(1) << pos) : board.player_one_positions | (UInt32(1) << pos)
    curr_player_piece_count = player ? board.player_two_pieces + 1 : board.player_one_pieces + 1

    new_board = Board(board.player_one_positions, curr_player_pos, board.player_one_pieces, curr_player_piece_count)

    player != 0 ? ret = typemax(Int) : ret = typemin(Int)

    best_board = new_board

    if (is_mill_after_move(board, pos, player))
        can_capture_mask = get_capturable_bit_mask(board, UInt8(1 - player))

        while (can_capture_mask)
            capturable_piece = trailing_zeros(can_capture_mask)

            other_player_pos = player ? ( board.player_one_positions & (~capturable_piece) ) : ( board.player_two_positions & (~capturable_piece) )
            other_player_piece_count = player ? board.player_one_pieces - 1 : board.player_two_pieces - 1

            final_board = Board(other_player_pos, curr_player_pos, other_player_piece_count, curr_player_piece_count)

            evaluated = mini_max_first_phase(final_board, false, UInt8(depth - 1), alpha, beta).mini_max_estimate

            if (player != 0)
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
        evaluated = mini_max_first_phase(new_board, false, UInt8(depth - 1), alpha, beta).mini_max_estimate

        if (player)
            if evaluated < ret
                ret = evaluated
                best_board = new_board
            end
        else
            if evaluated > ret
                ret = evaluated
                best_board = new_board
            end
        end

        player ? beta = min(beta, evaluated) : alpha = max(alpha, evaluated)

        if beta <= alpha
            return Node(ret, best_board)
        end
    end
    return Node(ret, best_board)
end
# this is just a copy of the first phase evalution for test purposes and should be extended with logic more fitting
# for the second phase of the game
function evaluate_second_phase(board::Board)::Int
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

# this function does not abide by the DRY principles at all, and should be refactored as soon as possible,
# to make it readable at all xD
function mini_max_second_phase(board::Board, player::Bool, depth::UInt8, alpha::Int, beta::Int)::Node

    # check if the game ended
    board_eval = evaluate_second_phase(board)
    if (board_eval == typemax(Int)) || (board_eval == typemin(Int)) || (depth == 0)
        return Node(board_eval, board)
    end

    best_board = board
    # getting the empty places, by combining both players pieces,negating, and cutting off the last unused ones, by and-ing with a full ones
    empty_spots = ~(board.player_one_positions | board.player_two_positions) & typemax(UInt32)

    # the minimizer player
    if (player)
        ret = typemax(Int)

        player_positions = board.player_two_positions

        while (player_positions != 0)
            # the place of first one, from the players pieces, is the starting position of our move
            from_move = trailing_zeros(player_positions)

            valid_moves_bit_mask = ADJACENCY_LIST_BIT_MASK[from_move+1] & empty_spots
            while (valid_moves_bit_mask != 0)
                to_move = trailing_zeros(valid_moves_bit_mask)

                new_p2_position = board.player_two_positions & ~(UInt32(1) << from_move) | (UInt32(1) << to_move)
                new_board = Board(board.player_one_positions, new_p2_position, board.player_one_pieces, board.player_two_pieces)

                if (is_mill_after_move(new_board, UInt32(to_move), UInt8(1)))
                    can_capture_mask = get_capturable_bit_mask(new_board, UInt8(0))

                    for j in 0:23
                        capture_piece_bit = UInt32(1) << j

                        if (can_capture_mask & capture_piece_bit) != 0
                            new_p1_position = new_board.player_one_positions & (~capture_piece_bit)
                            new_p1_piece_count = new_board.player_one_pieces - 1

                            final_board = Board(new_p1_position, new_p2_position, new_p1_piece_count, board.player_two_pieces)

                            evaluated = mini_max_second_phase(final_board, UInt8(0), UInt8(depth - 1), alpha, beta).mini_max_estimate

                            if evaluated < ret
                                ret = evaluated
                                best_board = final_board
                            end
                            beta = min(beta, evaluated)
                            if beta <= alpha
                                @goto alpha_beta_cut
                            end
                        end
                    end
                else
                    evaluated = mini_max_second_phase(new_board, UInt8(0), UInt8(depth - 1), alpha, beta).mini_max_estimate

                    if evaluated < ret
                        ret = evaluated
                        best_board = new_board
                    end

                    beta = min(beta, evaluated)

                    if beta <= alpha
                        @goto alpha_beta_cut
                    end
                end
                # we remove the last one, the place, where we moved our place
                valid_moves_bit_mask &= ~(UInt32(1) << to_move)
            end
            player_positions &= ~(UInt32(1) << from_move)
        end
    else
        
        ret = typemin(Int)

        player_positions = board.player_one_positions

        while (player_positions != 0)
            # the place of first one, from the players pices, is the starting position of our move
            from_move = trailing_zeros(player_positions)

            valid_moves_bit_mask = ADJACENCY_LIST_BIT_MASK[from_move+1] & empty_spots
            while (valid_moves_bit_mask != 0)
                to_move = trailing_zeros(valid_moves_bit_mask)

                new_p1_position = board.player_one_positions & ~(UInt32(1) << from_move) | (UInt32(1) << to_move)
                new_board = Board(new_p1_position, board.player_two_positions, board.player_one_pieces, board.player_two_pieces)

                if (is_mill_after_move(new_board, UInt32(to_move), UInt8(0)))
                    can_capture_mask = get_capturable_bit_mask(new_board, UInt8(1))

                    for j in 0:23
                        capture_piece_bit = UInt32(1) << j

                        if (can_capture_mask & capture_piece_bit) != 0
                            new_p2_position = new_board.player_two_positions & (~capture_piece_bit)
                            new_p2_piece_count = new_board.player_two_pieces - 1

                            final_board = Board(new_p1_position, new_p2_position, board.player_one_pieces, new_p2_piece_count)

                            evaluated = mini_max_second_phase(final_board, UInt8(1), UInt8(depth - 1), alpha, beta).mini_max_estimate

                            if evaluated > ret
                                ret = evaluated
                                best_board = final_board
                            end
                            alpha = max(alpha, evaluated)
                            if beta <= alpha
                                @goto alpha_beta_cut
                            end
                        end
                    end
                else
                    evaluated = mini_max_second_phase(new_board, UInt8(1), UInt8(depth - 1), alpha, beta).mini_max_estimate

                    if evaluated > ret
                        ret = evaluated
                        best_board = new_board
                    end

                    alpha = max(alpha, evaluated)

                    if beta <= alpha
                        @goto alpha_beta_cut
                    end
                end
                # we remove the last one, the place, where we moved our place
                valid_moves_bit_mask &= ~(UInt32(1) << to_move)
            end
            player_positions &= ~(UInt32(1) << from_move)
        end
    end

    @label alpha_beta_cut
    return Node(ret, best_board)
end