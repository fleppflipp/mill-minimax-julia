using Plots
include(joinpath(@__DIR__, "..", "src", "minimax_alpha_beta.jl"))

const PLOT_DIR = joinpath(@__DIR__, "..", "docs", "images")
mkpath(PLOT_DIR)

function play_full_game(depth_p1::Int, depth_p2::Int)
    board = Board(UInt32(0), UInt32(0), Int8(0), Int8(0), Int8(0))
    move_count = 0
    no_capture_counter = 0

    while true
        move_count += 1
        current_player = (move_count % 2 == 0)
        depth = (current_player == false) ? UInt8(depth_p1) : UInt8(depth_p2)

        prev_p1_pieces = board.player_one_pieces
        prev_p2_pieces = board.player_two_pieces

        if board.total_placed < 18
            node = mini_max_first_phase(board, current_player, depth, typemin(Int), typemax(Int))
        else
            node = mini_max_second_phase(board, current_player, depth, typemin(Int), typemax(Int))
        end

        board = node.board

        if board.player_one_pieces < prev_p1_pieces || board.player_two_pieces < prev_p2_pieces
            no_capture_counter = 0
        else
            no_capture_counter += 1
        end

        if board.total_placed >= 18
            p1_moves = get_available_move_count(board, false)
            p2_moves = get_available_move_count(board, true)

            if board.player_two_pieces < 3 || p2_moves == 0
                return move_count, 1
            elseif board.player_one_pieces < 3 || p1_moves == 0
                return move_count, 2
            end
        end

        if no_capture_counter >= 70
            return move_count, 0
        end

        if move_count > 300
            return move_count, 0
        end
    end
end

opponents = 1:7
moves_to_end = Int[]
results = Int[]

for opp_depth in opponents
    m_count, res = play_full_game(8, opp_depth)
    push!(moves_to_end, m_count)
    push!(results, res)
end

colors = [r == 1 ? :mediumseagreen : (r == 2 ? :crimson : :lightgray) for r in results]
labels = ["Depth $d" for d in opponents]

labels_mat = reshape(labels, 1, :)
moves_mat = reshape(moves_to_end, 1, :)
colors_mat = reshape(colors, 1, :)

max_m = isempty(moves_to_end) ? 100 : maximum(moves_to_end)

p_tour = bar(labels_mat, moves_mat, color=colors_mat, legend=false,
    title="Depth 8 Hatékonysága",
    ylabel="Lépések száma a meccs végéig",
    xlabel="Ellenfelek (Player 2)",
    linewidth=1, linecolor=:black, grid=true,
    ylims=(0, max_m * 1.15))

for (i, (m, r)) in enumerate(zip(moves_to_end, results))
    res_text = r == 1 ? "Győzelem" : (r == 2 ? "Vereség" : "Dönt.")

    annotate!(p_tour, [(labels[i], m + (max_m * 0.04), Plots.text(res_text, 9, :black, :bottom))])
end

filename = "plot_tournament_depth8.png"
savefig(p_tour, joinpath(PLOT_DIR, filename))