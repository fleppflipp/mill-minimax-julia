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
        
        if(p1_count_in_mill == 3)
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

function mini_max_first_phase(board::Board, player::UInt8, depth::UInt8, alpha::Int32, beta::Int32)::Node
    if (depth == 0)
        return Node(evaluate_first_phase(board), board)
    end

    best_board = board

    # the minimizer player
    if player == 1
        ret = typemax(Int)
        for i in 0:23
            pos = UInt32(i)
            if (is_valid_placement(board, pos))
                new_p2_pos = board.player_two_positions | (UInt32(1) << pos)
                new_p2_piece_count = board.player_two_pieces + 1

                new_board = Board(board.player_one_positions, new_p2_pos, board.player_one_pieces, new_p2_piece_count)

                if (is_mill_after_move(new_board, pos, UInt8(1)))
                    can_capture_mask = get_capurable_bit_mask(new_board, UInt8(0))

                    for j in 0:23
                        capture_piece_bit = UInt32(1) << j

                        if (can_capture_mask & capture_piece_bit) != 0
                            new_p1_position = new_board.player_one_positions & (~capture_piece_bit)
                            new_p1_piece_count = new_board.player_one_pieces - 1

                            final_board = Board(new_p1_position, new_p2_pos, new_p1_piece_count, new_p2_piece_count)

                            evaluated = mini_max_first_phase(final_board, UInt8(0), UInt8(depth - 1), alpha, beta).mini_max_estimate

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

                    evaluated = mini_max_first_phase(new_board, UInt8(0), UInt8(depth - 1), alpha, beta).mini_max_estimate

                    if evaluated < ret
                        ret = evaluated
                        best_board = new_board
                    end

                    beta = min(beta, evaluated)

                    if beta <= alpha
                        break
                    end
                end
            end
        end
    else
        ret = typemin(Int)
        for i in 0:23
            pos = UInt32(i)
            if (is_valid_placement(board, pos))
                new_p1_pos = board.player_one_positions | (UInt32(1) << pos)
                new_p1_piece_count = board.player_one_pieces + 1

                new_board = Board(new_p1_pos, board.player_two_positions, new_p1_piece_count, board.player_two_pieces)

                if (is_mill_after_move(new_board, pos, UInt8(0)))
                    can_capture_mask = get_capurable_bit_mask(new_board, UInt8(1))

                    for j in 0:23
                        capture_piece_bit = UInt32(1) << j

                        if (can_capture_mask & capture_piece_bit) != 0
                            new_p2_position = new_board.player_two_positions & (~capture_piece_bit)
                            new_p2_piece_count = new_board.player_two_pieces - 1

                            final_board = Board(new_p1_pos, new_p2_position, new_p1_piece_count, new_p2_piece_count)

                            evaluated = mini_max_first_phase(final_board, UInt8(1), UInt8(depth - 1), alpha, beta).mini_max_estimate

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

                    evaluated = mini_max_first_phase(new_board, UInt8(1), UInt8(depth - 1), alpha, beta).mini_max_estimate

                    if evaluated > ret
                        ret = evaluated
                        best_board = new_board
                    end

                    alpha = max(alpha, evaluated)

                    if beta <= alpha
                        break
                    end
                end
            end
        end
    end

    @label alpha_beta_cut
    return Node(ret, best_board)
end