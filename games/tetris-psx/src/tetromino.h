#ifndef TETRIS_TETROMINO_H
#define TETRIS_TETROMINO_H

#include <stdint.h>

#define PIECE_COUNT   7
#define PIECE_CELLS   4
#define ROTATION_COUNT 4

typedef enum {
	PIECE_I = 0,
	PIECE_O,
	PIECE_T,
	PIECE_S,
	PIECE_Z,
	PIECE_J,
	PIECE_L
} PieceType;

typedef struct {
	int8_t x, y;
} Cell;

typedef struct {
	PieceType type;
	int rotation;   /* 0..3, SRS convention */
	int x, y;       /* top-left of the piece's 4x4 bounding box on the board */
} Piece;

/* Returns the 4 occupied cells (relative to the piece's 4x4 box) for the
 * given piece type and rotation, using the Super Rotation System (SRS)
 * layout used by modern Tetris guideline games. */
void tetromino_get_cells(PieceType type, int rotation, Cell out[PIECE_CELLS]);

/* Color index (0..7) used by render.c to pick the block sprite/palette. */
int tetromino_color_index(PieceType type);

/* SRS wall-kick offsets to try, in order, when rotating `type` from
 * `from_rotation` to `to_rotation`. Writes up to 5 (dx, dy) pairs into
 * `out` and returns how many were written. */
int tetromino_get_kicks(PieceType type, int from_rotation, int to_rotation, Cell out[5]);

#endif
