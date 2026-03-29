using Gtk, Cairo

SCALE = 100.0
LINE_WIDTH = 3.0
MARGIN = 0.9
POINT_SIZE = 1.0

const POINTS = []

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

# Reading in all the elemenets from the Glade file
builder = GtkBuilder(filename="Mill.glade")
window = builder["window"]

event_container = builder["canvas_event_container"]
container = builder["canvas_container"]

canvas = GtkCanvas()

# Telling the canvas to expand the container dynamically
set_gtk_property!(canvas, :hexpand, true)
set_gtk_property!(canvas, :vexpand, true)

push!(container, canvas)

function draw_board(widget)
    # Cairo's graphic context
    ctx = getgc(widget)

    w = width(widget)
    h = height(widget)

    # Leaving a bit of a margin
    board_size = min(w, h) * MARGIN

    offset_x = (w - board_size) / 2
    offset_y = (h - board_size) / 2

    # Moving the starting (0,0) point
    translate(ctx, offset_x, offset_y)

    scale_factor = board_size / SCALE
    scale(ctx, scale_factor, scale_factor)

    set_line_width(ctx, LINE_WIDTH / scale_factor)
    set_source_rgb(ctx, 0.0, 0.0, 0.0)

    POS_OFFSET = 15
    start_pos = 0
    end_pos = SCALE

    # Three set of squares make up the board
    for nr_of_square in range(0, 2)

        step_size = (end_pos - start_pos) / 2

        for col in start_pos:step_size:end_pos
            for row in start_pos:step_size:end_pos

                # We skip over the middle point
                if col == start_pos + step_size && row == start_pos + step_size
                    continue
                end

                push!(POINTS, (col, row))

                draw_point(ctx, col, row)

                # If we reach the second point in the col we start drawing the lines
                if row > start_pos && col != start_pos + step_size
                    draw_line(ctx, col, row, col, row - step_size)
                end
            end

            # Connecting the first row and last row points
            if col != start_pos
                draw_line(ctx, col, start_pos, col - step_size, start_pos)
                draw_line(ctx, col, end_pos, col - step_size, end_pos)
            end

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

signal_connect(event_container, "button-press-event") do widget, event
    # Recalculating the board size
    w = width(canvas)
    h = height(canvas)

    board_size = min(w, h) * MARGIN
    offset_x = (w - board_size) / 2
    offset_y = (h - board_size) / 2
    scale_factor = board_size / SCALE

    # Transforming the raw (x, y) coordinates for the board's (x, y) coordinates
    transformed_x = (event.x - offset_x) / scale_factor
    transformed_y = (event.y - offset_y) / scale_factor

    for(index, (point_x, point_y)) in enumerate(POINTS)
        distance = hypot(transformed_x - point_x, transformed_y - point_y)

        if distance <= POINT_SIZE
            println("Clicked button ", index_transform[index])
            return true
        end

    end

    println("Nothing was clicked!")
    return true
end

# Branch so it doesnt automaticaly closes
if !isinteractive()
    c = Condition()
    signal_connect(window, :destroy) do widget
        notify(c)
    end
    wait(c)
end