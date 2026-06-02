using Plots
using BenchmarkTools
include("mill_board.jl")
include("min_max_apha_beta.jl")

function collect_performance_data(max_d::Int)
    times_ab = Float64[]

    board = Board(UInt32(0), UInt32(0), Int8(0), Int8(0), Int8(0))

    mini_max_first_phase(board, true, UInt8(1), typemin(Int), typemax(Int))

    for d in 1:max_d
        t = @belapsed mini_max_first_phase($board, true, UInt8($d), typemin(Int), typemax(Int)) samples = 20 evals = 1

        push!(times_ab, t)
        println("\t-> Eltelt idő: $(round(t, digits=4)) másodperc")
    end
    return times_ab
end

TEST_DEPTH = 8
depths = 1:TEST_DEPTH
const PLOT_DIR = "plots/"

times_data = collect_performance_data(TEST_DEPTH)

max_time = maximum(times_data)
p2 = bar(depths, times_data, title="Lépés kiszámításának ideje", xlabel="Keresési mélység (Depth)",
    ylabel="Eltelt idő (Másodperc)", legend=false, color=:blue, alpha=0.8,
    ylims=(0, max_time * 1.15))

savefig(p2, joinpath(PLOT_DIR, "execution_time.png"))