module MillGame

include("min_max_apha_beta.jl") # Győződj meg róla, hogy ez a fájlnév megegyezik a sajátoddal!

# ==========================================
# === TESZTKÖRNYEZET BEÁLLÍTÁSOK ===
# ==========================================
const AI_DEPTH = 6               # A minimax algoritmus mélysége
const SHOW_EVAL_COUNT = true     # Kiírja a kiértékelt csomópontok számát és a pontszámot
const PLAY_AS_PLAYER_ONE = true  # true = Te kezdesz (X), false = AI kezd (O)
# ==========================================

# Globális változó deklarálása a kiértékelések számolásához, hogy ne legyen hiba
total_evaluations = 0

# Segédfüggvény a tábla vizuális megjelenítéséhez
function print_board(board::Board)
    chars = fill(".", 24)
    for i in 0:23
        if (board.player_one_positions & (UInt32(1) << i)) != 0
            chars[i+1] = "X"
        elseif (board.player_two_positions & (UInt32(1) << i)) != 0
            chars[i+1] = "O"
        else
            chars[i+1] = lpad(string(i), 2, "0")
        end
    end

    println("\nJelenlegi állás (X = Játékos 1, O = Játékos 2):")
    println("$(chars[1])------------$(chars[2])------------$(chars[3])")
    println("|              |              |")
    println("|    $(chars[4])--------$(chars[5])--------$(chars[6])    |")
    println("|    |         |         |    |")
    println("|    |    $(chars[7])---$(chars[8])---$(chars[9])    |    |")
    println("|    |    |         |    |    |")
    println("$(chars[10])---$(chars[11])---$(chars[12])       $(chars[13])---$(chars[14])---$(chars[15])")
    println("|    |    |         |    |    |")
    println("|    |    $(chars[16])---$(chars[17])---$(chars[18])    |    |")
    println("|    |         |         |    |")
    println("|    $(chars[19])--------$(chars[20])--------$(chars[21])    |")
    println("|              |              |")
    println("$(chars[22])------------$(chars[23])------------$(chars[24])\n")
end

# Az emberi játékos lépését kezelő függvény (1. FÁZIS - Lerakás)
function human_turn_first_phase(board::Board, player_index::Bool)::Board
    new_board = board

    while true
        print(">> Hova szeretnél rakni? (Add meg az indexet 0-23): ")
        flush(stdout)

        input = readline()
        pos = tryparse(Int, input)

        if pos === nothing || !is_valid_placement(board, UInt32(pos))
            println("Érvénytelen mező! Próbáld újra.")
            continue
        end

        p1_pos = board.player_one_positions
        p2_pos = board.player_two_positions
        p1_c = board.player_one_pieces
        p2_c = board.player_two_pieces

        if player_index # Ha true, akkor Játékos 1 (X)
            p1_pos |= (UInt32(1) << pos)
            p1_c += 1
        else            # Ha false, akkor Játékos 2 (O)
            p2_pos |= (UInt32(1) << pos)
            p2_c += 1
        end

        new_board = Board(p1_pos, p2_pos, p1_c, p2_c)

        if is_mill_after_move(new_board, UInt32(pos), player_index)
            println("!!! MALOM !!!")
            enemy_index = !player_index # A másik játékos egyszerű negálással megkapható
            cap_mask = get_capturable_bit_mask(new_board, enemy_index)

            while true
                print(">> Melyik ellenséges bábut veszed le? (Index): ")
                flush(stdout)

                cap_input = readline()
                cap_pos = tryparse(Int, cap_input)

                if cap_pos !== nothing && (cap_mask & (UInt32(1) << cap_pos)) != 0
                    if enemy_index # Ha az ellenség Játékos 1
                        p1_pos &= ~(UInt32(1) << cap_pos)
                        p1_c -= 1
                    else           # Ha az ellenség Játékos 2
                        p2_pos &= ~(UInt32(1) << cap_pos)
                        p2_c -= 1
                    end
                    new_board = Board(p1_pos, p2_pos, p1_c, p2_c)
                    break
                else
                    println("Ezt a bábut nem veheted le (nincs ott bábu, vagy malomban van). Próbáld újra!")
                end
            end
        end

        return new_board
    end
end

# Az emberi játékos lépését kezelő függvény (2. FÁZIS - Mozgatás)
function human_turn_second_phase(board::Board, player_index::Bool)::Board
    new_board = board

    while true
        print(">> Melyik bábuddal szeretnél lépni? (Induló index): ")
        flush(stdout)
        start_input = readline()
        start_pos = tryparse(UInt32, start_input)

        if start_pos === nothing || start_pos > 23
            println("Érvénytelen mező!")
            continue
        end

        print(">> Hova szeretnél lépni? (Cél index): ")
        flush(stdout)
        end_input = readline()
        end_pos = tryparse(UInt32, end_input)

        if end_pos === nothing || !is_valid_move(board, start_pos, end_pos, player_index)
            println("Érvénytelen lépés! Ellenőrizd, hogy a mező üres-e és szomszédos-e.")
            continue
        end

        p1_pos = board.player_one_positions
        p2_pos = board.player_two_positions
        p1_c = board.player_one_pieces
        p2_c = board.player_two_pieces

        # Mozgás végrehajtása
        if player_index # Ha Játékos 1
            p1_pos &= ~(UInt32(1) << start_pos) # Levesszük a régi helyről
            p1_pos |= (UInt32(1) << end_pos)    # Rátesszük az újra
        else            # Ha Játékos 2
            p2_pos &= ~(UInt32(1) << start_pos)
            p2_pos |= (UInt32(1) << end_pos)
        end

        new_board = Board(p1_pos, p2_pos, p1_c, p2_c)

        if is_mill_after_move(new_board, end_pos, player_index)
            println("!!! MALOM !!!")
            enemy_index = !player_index
            cap_mask = get_capturable_bit_mask(new_board, enemy_index)

            while true
                print(">> Melyik ellenséges bábut veszed le? (Index): ")
                flush(stdout)

                cap_input = readline()
                cap_pos = tryparse(Int, cap_input)

                if cap_pos !== nothing && (cap_mask & (UInt32(1) << cap_pos)) != 0
                    if enemy_index
                        p1_pos &= ~(UInt32(1) << cap_pos)
                        p1_c -= 1
                    else
                        p2_pos &= ~(UInt32(1) << cap_pos)
                        p2_c -= 1
                    end
                    new_board = Board(p1_pos, p2_pos, p1_c, p2_c)
                    break
                else
                    println("Ezt a bábut nem veheted le. Próbáld újra!")
                end
            end
        end

        return new_board
    end
end

# A fő játékhurok az első fázishoz
function play_first_phase()::Board
    board = Board(UInt32(0), UInt32(0), Int8(0), Int8(0))

    human_player = PLAY_AS_PLAYER_ONE # a true/false alapán azonnal beállítva
    ai_player = !PLAY_AS_PLAYER_ONE

    for turn in 1:18
        # Ha a turn páratlan (1, 3, 5...), akkor az 1. Játékos jön (true)
        current_player = (turn % 2 != 0)

        print("\033c")
        println("=== MALOM AI TESZT (1. Fázis - Lerakás) ===")
        println("Kör: $turn / 18")
        print_board(board)

        if current_player == human_player
            println("=== TE JÖSSZ ===")
            board = human_turn_first_phase(board, human_player)
        else
            println("=== AI JÖN ===")
            println("Gondolkodik (mélység: $AI_DEPTH)...")

            global total_evaluations = 0

            old_board = board
            best_node = @time mini_max_first_phase(board, ai_player, UInt8(AI_DEPTH), typemin(Int), typemax(Int))
            board = best_node.board

            # Kiderítjük, hova rakott az AI
            ai_old_pos = ai_player ? old_board.player_one_positions : old_board.player_two_positions
            ai_new_pos = ai_player ? board.player_one_positions : board.player_two_positions
            placed_mask = ai_new_pos & ~ai_old_pos
            placed_pos = placed_mask != 0 ? trailing_zeros(placed_mask) : -1

            # Kiderítjük, vett-e le bábut
            hu_old_pos = human_player ? old_board.player_one_positions : old_board.player_two_positions
            hu_new_pos = human_player ? board.player_one_positions : board.player_two_positions
            cap_mask = hu_old_pos & ~hu_new_pos
            cap_pos = cap_mask != 0 ? trailing_zeros(cap_mask) : -1

            println("\n--------------------------------------------------")
            println("=== AI LÉPETT ===")
            println(">>> AI lerakott egy bábut ide: $placed_pos")
            if cap_pos != -1
                println("!!! AZ AI LEVETTE A BÁBUDAT INNEN: $cap_pos !!!")
            end

            print_board(board)

            if SHOW_EVAL_COUNT
                println("Értékelt állapotok: $total_evaluations")
                println("Becsült (heurisztikus) érték: $(best_node.mini_max_estimate)")
                print("\nNyomj Enter-t a folytatáshoz...")
                flush(stdout)
                readline()
            end
        end
    end

    print("\033c")
    println("--------------------------------------------------")
    println("Az 1. FÁZIS VÉGET ÉRT!")
    print_board(board)
    println("Játékos 1 (X) bábuk: $(board.player_one_pieces)")
    println("Játékos 2 (O) bábuk: $(board.player_two_pieces)")
    print("\nNyomj Enter-t a 2. fázis indításához...")
    readline()

    return board
end

# A fő játékhurok a második fázishoz
function play_second_phase(board::Board)
    human_player = PLAY_AS_PLAYER_ONE
    ai_player = !PLAY_AS_PLAYER_ONE

    turn = 19

    # Addig megy a játék, amíg mindkét játékosnak van legalább 3 bábuja
    while board.player_one_pieces >= 3 && board.player_two_pieces >= 3
        current_player = (turn % 2 != 0)

        print("\033c")
        println("=== MALOM AI TESZT (2. Fázis - Mozgatás) ===")
        println("Összesített Kör: $turn")

        # Bábuk számának kiírása
        my_pieces = PLAY_AS_PLAYER_ONE ? board.player_one_pieces : board.player_two_pieces
        ai_pieces = PLAY_AS_PLAYER_ONE ? board.player_two_pieces : board.player_one_pieces
        println(">> Jelenlegi bábuk -> TE: $my_pieces | AI: $ai_pieces")

        print_board(board)

        if current_player == human_player
            println("=== TE JÖSSZ ===")
            board = human_turn_second_phase(board, human_player)
        else
            println("=== AI JÖN ===")
            println("Gondolkodik (mélység: $AI_DEPTH)...")

            global total_evaluations = 0

            # Eltároljuk a régi táblát, hogy össze tudjuk hasonlítani az újjal
            old_board = board

            best_node = @time mini_max_second_phase(board, ai_player, UInt8(AI_DEPTH), typemin(Int), typemax(Int))
            board = best_node.board

            # Kiszámoljuk a változásokat a bitmaszkokból
            if ai_player # Ha az AI az 1. játékos (true)
                ai_old_pos = old_board.player_one_positions
                ai_new_pos = board.player_one_positions
                hu_old_pos = old_board.player_two_positions
                hu_new_pos = board.player_two_positions
            else         # Ha az AI a 2. játékos (false)
                ai_old_pos = old_board.player_two_positions
                ai_new_pos = board.player_two_positions
                hu_old_pos = old_board.player_one_positions
                hu_new_pos = board.player_one_positions
            end

            # Honnan lépett (Ami 1 volt, de 0 lett az AI tábláján)
            from_mask = ai_old_pos & ~ai_new_pos
            from_pos = from_mask != 0 ? trailing_zeros(from_mask) : -1

            # Hova lépett (Ami 0 volt, de 1 lett az AI tábláján)
            to_mask = ai_new_pos & ~ai_old_pos
            to_pos = to_mask != 0 ? trailing_zeros(to_mask) : -1

            # Mit vett le (Ami 1 volt, de 0 lett a Te tábládon)
            cap_mask = hu_old_pos & ~hu_new_pos
            cap_pos = cap_mask != 0 ? trailing_zeros(cap_mask) : -1

            println("\n--------------------------------------------------")
            println("=== AI LÉPETT ===")

            if from_pos != -1 && to_pos != -1
                println(">>> AI mozgása: $from_pos -> $to_pos")
            else
                println(">>> [Figyelem] Az AI nem talált érvényes lépést (lehet, hogy beszorult).")
            end

            if cap_pos != -1
                println("!!! AZ AI LEVETTE A BÁBUDAT INNEN: $cap_pos !!!")
            end

            # Bábuk számának frissítése kiíráshoz
            new_my_pieces = PLAY_AS_PLAYER_ONE ? board.player_one_pieces : board.player_two_pieces
            new_ai_pieces = PLAY_AS_PLAYER_ONE ? board.player_two_pieces : board.player_one_pieces
            println(">>> Frissített bábuk -> TE: $new_my_pieces | AI: $new_ai_pieces")

            print_board(board)

            if SHOW_EVAL_COUNT
                println("Értékelt állapotok: $total_evaluations")
                println("Becsült (heurisztikus) érték: $(best_node.mini_max_estimate)")
                print("\nNyomj Enter-t a folytatáshoz...")
                flush(stdout)
                readline()
            end
        end

        turn += 1
    end

    # Játék vége kiértékelés
    print("\033c")
    println("==================================")
    println("           JÁTÉK VÉGE!            ")
    println("==================================")
    print_board(board)

    if board.player_one_pieces < 3
        println("Játékos 2 (O) NYERT!")
    elseif board.player_two_pieces < 3
        println("Játékos 1 (X) NYERT!")
    else
        println("Valaki beszorult és nem tudott lépni!")
    end
end

# A játék indítása mindkét fázissal
function play_game()
    board = play_first_phase()
    play_second_phase(board)
end

end # MillGame modul vége

# ==========================================
# JÁTÉK INDÍTÁSA A MODULBÓL
# ==========================================
MillGame.play_game()