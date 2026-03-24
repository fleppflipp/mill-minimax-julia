include("mill_board.jl")

struct Node
    mini_max_estimate::Int
    board::Board
end

function evaluate_first_phasr(board::Board)::Int
    
end

function mini_max_first_phase(board::Board, player::UInt8, depth::UInt8, alpha::Int32, beta::Int32)::Node
   if (depth == 0)
     return Node(evaluate_first_phasr(board), board)
   end

   best_board = board

   # the minimizer player
    if player == 1
        ret = typemax(Int)
        for i in 0:23
            pos = UInt32(i)
            if (is_valid_placement(board, pos))
                new_p2_pos = board.player_two_pieces | (UInt32(1) << pos)
                new_p2_piece_count = board.player_two_pieces + 1

                new_board = Board(board.player_one_positions, new_p2_pos, board.player_one_pieces, new_p2_piece_count)

                evaluated = mini_max_first_phase(new_board, 0, depth - 1, alpha, beta).mini_max_estimate

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
    else
        ret = typemin(Int)
        for i in 0:23 
            pos = UInt32(i)
            if(is_valid_placement(board, pos))
                new_p1_pos = board.player_one_positions | (UInt32(1) << pos)
                new_p1_pice_count = board.player_one_pieces + 1

                new_board = Board(new_p1_pos, board.player_two_positions, new_p1_pice_count, board.player_two_pieces)

                evaluated = mini_max_first_phase(new_board, 1, depth - 1, alpha, beta).mini_max_estimate

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
   return Node(ret, best_board)
end