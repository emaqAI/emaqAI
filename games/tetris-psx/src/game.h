#ifndef TETRIS_GAME_H
#define TETRIS_GAME_H

#include <stdint.h>
#include "tetromino.h"
#include "state.h"

#define BOARD_WIDTH  10
#define BOARD_HEIGHT 20
#define LINES_PER_LEVEL 10
#define MAX_LEVEL 20

typedef struct {
	/* 0 = empty, otherwise 1 + PieceType of the block occupying the cell */
	uint8_t cells[BOARD_HEIGHT][BOARD_WIDTH];

	Piece current;
	Piece next;
	PieceType hold;
	int has_hold;
	int hold_used_this_turn;

	uint32_t score;
	uint16_t lines_cleared;
	uint16_t level;

	uint32_t gravity_timer;
	uint32_t gravity_interval; /* frames per row-drop, based on level */
	uint32_t lock_timer;
	int lock_delay_active;

	uint32_t rng_state;

	GameState state;
	int lines_to_flash[4];
	int lines_to_flash_count;
	int flash_timer;
} Game;

void game_init(Game *g);
void game_reset(Game *g);

/* Called once per frame while STATE_PLAYING. `input` bitmask uses the
 * PSTETRIS_IN_* flags from input.h. Returns 1 if the game just ended
 * (transitioned to STATE_GAME_OVER) this frame. */
int game_update(Game *g, uint32_t input_pressed, uint32_t input_held);

int game_is_cell_filled(const Game *g, int x, int y);

#endif
