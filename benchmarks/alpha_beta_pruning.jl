include(joinpath(@__DIR__, "..", "src", "minimax_alpha_beta.jl"))
using Plots

function mini_max_first_phase_without_a_b(board::Board, player::Bool, depth::UInt8, alpha::Int, beta::Int)::Node
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

            new_board = Board(player1_pos, player2_pos, player1_piece_count, player2_piece_count, board.total_placed + 1)

            child_node = process_move_without_a_b(new_board, pos, depth, alpha, beta, player)

            evaluated_score = child_node.mini_max_estimate
            evaluated_board = child_node.board

            if player ? (evaluated_score < ret) : (evaluated_score > ret)
                ret = evaluated_score
                best_board = evaluated_board
            end
            player ? (beta = min(beta, evaluated_score)) : (alpha = max(alpha, evaluated_score))
        end
        empty_spots &= ~(UInt32(1) << pos)
    end

    return Node(ret, best_board)
end

function process_move_without_a_b(board::Board, pos::UInt32, depth::UInt8, alpha::Int, beta::Int, player::Bool)::Node
    player == false ? ret = typemin(Int) : ret = typemax(Int)
    best_board = board

    if (is_mill_after_move(board, pos, player))
        can_capture_mask = get_capturable_bit_mask(board, !player)

        while (can_capture_mask > 0)
            capturable_piece = trailing_zeros(can_capture_mask)

            other_player_pos = player ? (board.player_one_positions & (~(UInt32(1) << capturable_piece))) : (board.player_two_positions & (~(UInt32(1) << capturable_piece)))
            other_player_piece_count = player ? board.player_one_pieces - 1 : board.player_two_pieces - 1

            final_board = player ? Board(other_player_pos, board.player_two_positions, other_player_piece_count, board.player_two_pieces, board.total_placed) : Board(board.player_one_positions, other_player_pos, board.player_one_pieces, other_player_piece_count, board.total_placed)

            evaluated = mini_max_first_phase_without_a_b(final_board, !player, UInt8(depth - 1), alpha, beta).mini_max_estimate

            if (player)
                if evaluated < ret
                    ret = evaluated
                    best_board = final_board
                end
            else
                if evaluated > ret
                    ret = evaluated
                    best_board = final_board
                end
            end

            can_capture_mask &= ~(UInt32(1) << capturable_piece)
        end
    else
        evaluated = mini_max_first_phase_without_a_b(board, !player, UInt8(depth - 1), alpha, beta).mini_max_estimate

        if (player)
            if evaluated < ret
                ret = evaluated
                best_board = board
            end
        else
            if evaluated > ret
                ret = evaluated
                best_board = board
            end
        end
    end

    return Node(ret, best_board)
end

function empirical_test(max_depth=3)
    ab_evaluated = Float64[]
    total_tree_nodes = Float64[]

    initial_board = Board(UInt32(0), UInt32(0), Int8(0), Int8(0), Int8(0))
    for d in 1:max_depth
        println("A $d melyse szamitasa:")

        global total_evaluations = 0
        mini_max_first_phase(initial_board, true, UInt8(d), typemin(Int), typemax(Int))
        ab_nodes = total_evaluations
        push!(ab_evaluated, ab_nodes)

        global total_evaluations = 0
        mini_max_first_phase_without_a_b(initial_board, true, UInt8(d), typemin(Int), typemax(Int))
        std_nodes = total_evaluations
        push!(total_tree_nodes, std_nodes)

        println("kiértékelt: $ab_nodes, teljes fa: $std_nodes")
    end

    pruned_nodes = total_tree_nodes .- ab_evaluated
    pruned_percentages = (pruned_nodes ./ total_tree_nodes) .* 100

    depths = 1:max_depth
    pruned_nodes_plot = max.(1.0, pruned_nodes)

    p1 = plot(depths, pruned_nodes_plot,
        label="Levágott csomópontok",
        color=:green,
        lw=2,
        marker=:circle,
        yaxis=:log10,
        title="1. Alpha-Beta Vágás (Log skála)",
        ylabel="Csomópontok száma",
        legend=:topleft,
        grid=true)

    plot!(p1, depths, ab_evaluated,
        label="Kiértékelt csomópontok",
        color=:red,
        lw=2,
        marker=:circle)

    for i in 1:max_depth
        annotate!(p1, depths[i], pruned_nodes_plot[i] * 1.5, Plots.text(format_number(pruned_nodes[i]), 8, :green, :bottom))
        annotate!(p1, depths[i], ab_evaluated[i] * 0.65, Plots.text(format_number(ab_evaluated[i]), 8, :red, :top))
    end

    p2 = plot(depths, pruned_percentages,
        label=false,
        color=:blue,
        lw=2,
        marker=:circle,
        title="2. A Teljes Állapotfa Hány Százalékát Vágta Le Az Algoritmus?",
        ylabel="Levágott rész (%)",
        xlabel="Keresési mélység",
        ylims=(-5, 110),
        grid=true)

    for i in 1:max_depth
        annotate!(p1, depths[i], pruned_nodes_plot[i] * 1.5, Plots.text(format_number(pruned_nodes[i]), 8, :green, :bottom))
        annotate!(p1, depths[i], ab_evaluated[i] * 0.65, Plots.text(format_number(ab_evaluated[i]), 8, :red, :top))
    end

    display(plot(p1, p2, layout=(2, 1), size=(800, 800)))
end

function format_number(n)
    if n == 0
        return "0"
    elseif n < 1000
        return string(Int(n))
    elseif n < 1_000_000
        return string(round(n / 1000, digits=1), " E")
    elseif n < 1_000_000_000
        return string(round(n / 1_000_000, digits=1), " M")
    else
        return string(round(n / 1_000_000_000, digits=1), " Mrd")
    end
end