# Mill Minimax Julia

A Nine Men's Morris (mill) implementation in Julia using minimax with alpha-beta pruning. The board uses a bitboard representation, with game logic and position evaluation built around bitwise operations. It runs reliably at search depths up to 8 on consumer hardware.

Hungarian-language statistics and charts prepared for a university presentation are available in [docs](docs/presentation_images.md).

## Run

Install Julia (the environment was generated with Julia 1.13.0), then run from the project root:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. ui/game.jl
```

Click an empty position to place a piece. To move, click your piece and then its destination. After forming a mill, click an opponent's piece to capture it.
