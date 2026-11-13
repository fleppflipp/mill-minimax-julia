using Gtk, Cairo
include(joinpath(@__DIR__, "..", "src", "minimax_alpha_beta.jl"))

const SCALE = 100.0
const MARGIN = 0.9
const POINT_SIZE = 1.0
const CLICK_RECORD_SIZE = 5.0
const MAX_DEPTH = 8
const WAIT_PERIOD = 0.0
const index_transform = Dict(
    1 => 0,
    2 => 9,
    3 => 21,
    4 => 1,
    5 => 22,
    6 => 2,
    7 => 14,
    8 => 23,
    9 => 3,
    10 => 10,
    11 => 18,
    12 => 4,
    13 => 19,
    14 => 5,
    15 => 13,
    16 => 20,
    17 => 6,
    18 => 11,
    19 => 15,
    20 => 7,
    21 => 16,
    22 => 8,
    23 => 12,
    24 => 17
)

global is_mill::Bool = false
global move_piece = UInt32(25)

global board = Board(UInt32(0), UInt32(0), UInt8(0), UInt8(0), Int8(0))

# Reading in all the elemenets from the Glade file
builder = GtkBuilder(filename=joinpath(@__DIR__, "Mill.glade"))
window = builder["window"]

event_container = builder["canvas_event_container"]
container = builder["canvas_container"]

global canvas = GtkCanvas()

# Telling the canvas to expand the container dynamically
set_gtk_property!(canvas, :hexpand, true)
set_gtk_property!(canvas, :vexpand, true)

push!(container, canvas)

function generate_board_points()
    pts = []
    POS_OFFSET = 15
    start_pos = 0
    end_pos = SCALE

    for _ in 0:2
        step_size = (end_pos - start_pos) / 2
        for col in start_pos:step_size:end_pos
            for row in start_pos:step_size:end_pos
                if col == start_pos + step_size && row == start_pos + step_size
                    continue
                end
                push!(pts, (col, row))
            end
        end
        start_pos += POS_OFFSET
        end_pos -= POS_OFFSET
    end
    return pts
end

const points = generate_board_points()

function draw_board(widget)
    global points
    ctx = getgc(widget)

    save(ctx)

    set_source_rgb(ctx, 0.96, 0.96, 0.96)
    paint(ctx)

    w = width(widget)
    h = height(widget)

    board_size = min(w, h) * MARGIN
    offset_x = (w - board_size) / 2
    offset_y = (h - board_size) / 2

    translate(ctx, offset_x, offset_y)
    scale_factor = board_size / SCALE
    scale(ctx, scale_factor, scale_factor)

    set_line_width(ctx, 3.0 / scale_factor)
    set_source_rgb(ctx, 0.0, 0.0, 0.0)

    POS_OFFSET = 15
    start_pos = 0
    end_pos = SCALE

    for nr_of_square in 0:2
        step_size = (end_pos - start_pos) / 2
        for col in start_pos:step_size:end_pos
            for row in start_pos:step_size:end_pos
                if col == start_pos + step_size && row == start_pos + step_size
                    continue
                end

                # Draw vertical lines within the square
                if row > start_pos && col != start_pos + step_size
                    draw_line(ctx, col, row, col, row - step_size)
                end
            end

            # Draw horizontal lines within the square
            if col != start_pos
                draw_line(ctx, col, start_pos, col - step_size, start_pos)
                draw_line(ctx, col, end_pos, col - step_size, end_pos)
            end

            # Draw cross lines connecting the squares
            if nr_of_square >= 1
                if col != start_pos + step_size
                    col == start_pos ? x_coord = col - POS_OFFSET : x_coord = col + POS_OFFSET
                    y_coord = start_pos + step_size
                    draw_line(ctx, col, y_coord, x_coord, y_coord)
                else
                    y_top_start = start_pos
                    y_top_end = start_pos - POS_OFFSET
                    draw_line(ctx, col, y_top_start, col, y_top_end)

                    y_bot_start = end_pos
                    y_bot_end = end_pos + POS_OFFSET
                    draw_line(ctx, col, y_bot_start, col, y_bot_end)
                end
            end
        end
        start_pos += POS_OFFSET
        end_pos -= POS_OFFSET
    end

    # Draw the black board points
    for (x, y) in points
        arc(ctx, x, y, POINT_SIZE, 0, 2*pi)
        fill(ctx)
    end

    # Draw the player pieces
    draw_pieces(ctx)

    restore(ctx)
end

function draw_pieces(ctx)
    global board
    global points

    for (i, (x, y)) in enumerate(points)
        if i > 24
            break
        end

        bit_index = index_transform[i]

        if (board.player_one_positions & (UInt32(1) << bit_index)) != 0
            # White piece for Player 1
            set_source_rgb(ctx, 1.0, 1.0, 1.0)
            arc(ctx, x, y, POINT_SIZE * 4, 0, 2*pi)
            fill(ctx)

            set_source_rgb(ctx, 0.0, 0.0, 0.0)
            set_line_width(ctx, 0.5)
            arc(ctx, x, y, POINT_SIZE * 4, 0, 2*pi)
            stroke(ctx)

        elseif (board.player_two_positions & (UInt32(1) << bit_index)) != 0
            # Black piece for Player 2
            set_source_rgb(ctx, 0.0, 0.0, 0.0)
            arc(ctx, x, y, POINT_SIZE * 4, 0, 2*pi)
            fill(ctx)
        end
    end
end

function draw_point(ctx, x, y)
    # Point at (x, y), 4 units
    arc(ctx, x, y, POINT_SIZE, 0, 2*pi)
    fill(ctx)
end

function draw_line(ctx, x1, y1, x2, y2)
    move_to(ctx, x1, y1)
    line_to(ctx, x2, y2)
    stroke(ctx)
end

# @Guarded needs a function to work
@guarded draw(canvas) do widget
    draw_board(widget)
end

showall(window)

function handle_click(widget, event)
    global board
    global canvas
    global is_mill
    global move_piece

    w = width(canvas)
    h = height(canvas)

    # Resizing the coordinates to the default factor
    board_size = min(w, h) * MARGIN
    offset_x = (w - board_size) / 2
    offset_y = (h - board_size) / 2
    scale_factor = board_size / SCALE

    transformed_x = (event.x - offset_x) / scale_factor
    transformed_y = (event.y - offset_y) / scale_factor

    # Searching for the nearest point clicked
    piece_index = UInt32(25)
    for (index, (point_x, point_y)) in enumerate(points)
        distance = hypot(transformed_x - point_x, transformed_y - point_y)

        if distance <= CLICK_RECORD_SIZE
            piece_index = UInt32(index_transform[index])
            break
        end
    end

    # If no point was clicked then we do nothing
    if piece_index == 25
        return true
    end

    # Removing phase
    if is_mill

        # If no piece was clicked then we return
        if board.player_two_positions & (UInt32(1) << piece_index) == 0
            return true
        end

        array_index = piece_index + 1

        # Can't take down a piece from a formed mill
        is_part_of_mill = any(MILLS_BY_POSITION_BIT_MASK[array_index]) do mill_mask
            (mill_mask & board.player_two_positions) == mill_mask
        end

        if is_part_of_mill
            return true
        end

        # Clearing the piece from the board
        global board = Board(board.player_one_positions, board.player_two_positions & ~(UInt32(1) << piece_index),
            board.player_one_pieces, UInt8(board.player_two_pieces - 1), board.total_placed)

        global is_mill = false

        draw(canvas)
        reveal(window, true)

        sleep(WAIT_PERIOD)

        if board.total_placed < 18
            global board = mini_max_first_phase(board, true, UInt8(MAX_DEPTH), typemin(Int), typemax(Int)).board
        else
            global board = mini_max_second_phase(board, true, UInt8(MAX_DEPTH), typemin(Int), typemax(Int)).board
        end

        draw(canvas)
        reveal(window, true)

        # End of the game
        if board.total_placed == 18 && (board.player_one_pieces < 3 || board.player_two_pieces < 3)
            sleep(WAIT_PERIOD)
            exit()
        end

        # Normal phase
    else
        if board.total_placed < 18
            first_phase(board, piece_index)
        else
            if board.player_one_positions & (UInt32(1) << piece_index) != 0
                global move_piece = piece_index
                println(move_piece, " was selected")
                return true
            else
                second_phase(board, piece_index)
            end
        end
    end

    if board.total_placed == 18 && (get_available_move_count(board, true) == 0 || get_available_move_count(board, false) == 0)
        exit()
    end

    return true
end

function first_phase(board, piece_index)
    if (!is_valid_placement(board, piece_index))
        return true
    end

    new_board = Board(board.player_one_positions | (UInt32(1) << piece_index), board.player_two_positions,
        UInt8(board.player_one_pieces + 1), board.player_two_pieces, Int8(board.total_placed + 1))

    # Checking mill for the future move
    if is_mill_after_move(new_board, piece_index, false)
        global is_mill = true
    end

    global board = new_board

    draw(canvas)
    reveal(window, true)

    if is_mill
        return true
    end

    sleep(WAIT_PERIOD)

    global board = mini_max_first_phase(board, true, UInt8(MAX_DEPTH), typemin(Int), typemax(Int)).board

    draw(canvas)
    reveal(window, true)

    return true
end

function second_phase(board, piece_index)
    global move_piece

    if !is_valid_move(board, move_piece, piece_index, false)
        return true
    end

    player_one_new_pos = board.player_one_positions & ~(UInt32(1) << move_piece)
    player_one_new_pos |= (UInt32(1) << piece_index)

    new_board = Board(player_one_new_pos, board.player_two_positions, board.player_one_pieces, board.player_two_pieces, board.total_placed)

    # Checking mill for the future move
    if is_mill_after_move(new_board, piece_index, false)
        global is_mill = true
    end

    global board = new_board

    draw(canvas)
    reveal(window, true)

    if is_mill
        return true
    end

    sleep(WAIT_PERIOD)

    global board = mini_max_second_phase(board, true, UInt8(MAX_DEPTH), typemin(Int), typemax(Int)).board

    draw(canvas)
    reveal(window, true)

    global move_piece = UInt32(25)

    return true
end

signal_connect(handle_click, event_container, "button-press-event")

# Branch so it doesn't automaticaly closes
if !isinteractive()
    c = Condition()
    signal_connect(window, :destroy) do widget
        notify(c)
    end
    wait(c)
end