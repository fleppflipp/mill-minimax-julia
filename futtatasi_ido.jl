using Plots
include("mill_board.jl")
include("min_max_apha_beta.jl")

function collect_performance_data(max_d::Int)
    times_ab = Float64[]

    board = Board(UInt32(0), UInt32(0), Int8(0), Int8(0), Int8(0))

    mini_max_first_phase(board, true, UInt8(1), typemin(Int), typemax(Int))

    for d in 1:max_d
        t = @elapsed begin
            mini_max_first_phase(board, true, UInt8(d), typemin(Int), typemax(Int))
        end

        push!(times_ab, t)
    end
    return times_ab
end

TEST_DEPTH = 8
depths = 1:TEST_DEPTH
const PLOT_DIR = "good_plots"

times_data = collect_performance_data(TEST_DEPTH)

max_time = maximum(times_data)
p2 = bar(depths, times_data, title="Lépés kiszámításának ideje", xlabel="Keresési mélység (Depth)",
    ylabel="Eltelt idő (Másodperc)", legend=false, color=:teal, alpha=0.8,
    ylims=(0, max_time * 1.15))

savefig(p2, joinpath(PLOT_DIR, "execution_time.png"))
