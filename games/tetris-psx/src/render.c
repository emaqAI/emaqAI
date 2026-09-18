#include "render.h"
#include <psxgpu.h>
#include <psxgte.h>
#include <stdio.h>

#define SCREEN_W 320
#define SCREEN_H 240
#define CELL_SIZE 8
#define BOARD_ORIGIN_X 96
#define BOARD_ORIGIN_Y 16

static DISPENV disp_env[2];
static DRAWENV draw_env[2];
static int active_buf = 0;

static uint8_t ot_ordering_table[2][1];
static uint8_t primitive_buffer[2][16384];
static uint8_t *next_primitive;

static const CVECTOR PIECE_COLORS[PIECE_COUNT] = {
	{0,   240, 240, 0}, /* I - cyan */
	{240, 240, 0,   0}, /* O - yellow */
	{160, 0,   200, 0}, /* T - purple */
	{0,   200, 0,   0}, /* S - green */
	{200, 0,   0,   0}, /* Z - red */
	{0,   0,   200, 0}, /* J - blue */
	{220, 120, 0,   0}  /* L - orange */
};

void render_init(void)
{
	ResetGraph(0);

	SetDefDispEnv(&disp_env[0], 0, 0, SCREEN_W, SCREEN_H);
	SetDefDispEnv(&disp_env[1], 0, SCREEN_H, SCREEN_W, SCREEN_H);
	SetDefDrawEnv(&draw_env[0], 0, SCREEN_H, SCREEN_W, SCREEN_H);
	SetDefDrawEnv(&draw_env[1], 0, 0, SCREEN_W, SCREEN_H);

	draw_env[0].isbg = 1;
	draw_env[1].isbg = 1;
	setRGB0(&draw_env[0], 10, 10, 20);
	setRGB0(&draw_env[1], 10, 10, 20);

	PutDispEnv(&disp_env[active_buf]);
	PutDrawEnv(&draw_env[active_buf]);

	SetDispMask(1);
}

void render_frame_begin(void)
{
	next_primitive = primitive_buffer[active_buf];
	ClearOTagR(ot_ordering_table[active_buf], 1);
}

void render_frame_end(void)
{
	DrawSync(0);
	VSync(0);

	PutDispEnv(&disp_env[active_buf]);
	PutDrawEnv(&draw_env[active_buf]);
	DrawOTag(ot_ordering_table[active_buf]);

	active_buf ^= 1;
}

static void draw_filled_rect(int x, int y, int w, int h, uint8_t r, uint8_t g, uint8_t b)
{
	TILE *tile = (TILE *)next_primitive;
	setTile(tile);
	setXY0(tile, x, y);
	setWH(tile, w, h);
	setRGB0(tile, r, g, b);
	addPrim(ot_ordering_table[active_buf], tile);
	next_primitive += sizeof(TILE);
}

static void draw_block(int col, int row, int color_index)
{
	if (color_index < 0 || color_index >= PIECE_COUNT)
		return;
	const CVECTOR *c = &PIECE_COLORS[color_index];
	int x = BOARD_ORIGIN_X + col * CELL_SIZE;
	int y = BOARD_ORIGIN_Y + row * CELL_SIZE;
	draw_filled_rect(x + 1, y + 1, CELL_SIZE - 2, CELL_SIZE - 2, c->r, c->g, c->b);
}

static void draw_board_frame(void)
{
	draw_filled_rect(BOARD_ORIGIN_X - 2, BOARD_ORIGIN_Y - 2,
			  BOARD_WIDTH * CELL_SIZE + 4, 2, 120, 120, 120);
	draw_filled_rect(BOARD_ORIGIN_X - 2, BOARD_ORIGIN_Y + BOARD_HEIGHT * CELL_SIZE,
			  BOARD_WIDTH * CELL_SIZE + 4, 2, 120, 120, 120);
	draw_filled_rect(BOARD_ORIGIN_X - 2, BOARD_ORIGIN_Y - 2,
			  2, BOARD_HEIGHT * CELL_SIZE + 4, 120, 120, 120);
	draw_filled_rect(BOARD_ORIGIN_X + BOARD_WIDTH * CELL_SIZE, BOARD_ORIGIN_Y - 2,
			  2, BOARD_HEIGHT * CELL_SIZE + 4, 120, 120, 120);
}

void render_menu(int selected_item, uint32_t high_score)
{
	draw_filled_rect(60, 60, 200, 100, 30, 30, 60);
	draw_filled_rect(70, 70 + selected_item * 20, 8, 8,
			  240, 240, 0);
	(void)high_score;
}

void render_game(const Game *g)
{
	draw_board_frame();

	for (int y = 0; y < BOARD_HEIGHT; y++) {
		for (int x = 0; x < BOARD_WIDTH; x++) {
			uint8_t cell = g->cells[y][x];
			if (cell)
				draw_block(x, y, cell - 1);
		}
	}

	if (g->state == STATE_PLAYING) {
		Cell cells[PIECE_CELLS];
		tetromino_get_cells(g->current.type, g->current.rotation, cells);
		for (int i = 0; i < PIECE_CELLS; i++) {
			int col = g->current.x + cells[i].x;
			int row = g->current.y + cells[i].y;
			if (row >= 0)
				draw_block(col, row, tetromino_color_index(g->current.type));
		}
	}

	/* Next-piece preview box */
	draw_filled_rect(BOARD_ORIGIN_X + BOARD_WIDTH * CELL_SIZE + 16, BOARD_ORIGIN_Y,
			  4 * CELL_SIZE, 4 * CELL_SIZE, 20, 20, 40);
	{
		Cell cells[PIECE_CELLS];
		tetromino_get_cells(g->next.type, 0, cells);
		for (int i = 0; i < PIECE_CELLS; i++) {
			int col = cells[i].x;
			int row = cells[i].y;
			const CVECTOR *c = &PIECE_COLORS[tetromino_color_index(g->next.type)];
			draw_filled_rect(
				BOARD_ORIGIN_X + BOARD_WIDTH * CELL_SIZE + 16 + col * CELL_SIZE + 1,
				BOARD_ORIGIN_Y + row * CELL_SIZE + 1,
				CELL_SIZE - 2, CELL_SIZE - 2, c->r, c->g, c->b);
		}
	}

	/* Hold box */
	draw_filled_rect(BOARD_ORIGIN_X - 16 - 4 * CELL_SIZE, BOARD_ORIGIN_Y,
			  4 * CELL_SIZE, 4 * CELL_SIZE, 20, 20, 40);
	if (g->has_hold) {
		Cell cells[PIECE_CELLS];
		tetromino_get_cells(g->hold, 0, cells);
		for (int i = 0; i < PIECE_CELLS; i++) {
			int col = cells[i].x;
			int row = cells[i].y;
			const CVECTOR *c = &PIECE_COLORS[tetromino_color_index(g->hold)];
			draw_filled_rect(
				BOARD_ORIGIN_X - 16 - 4 * CELL_SIZE + col * CELL_SIZE + 1,
				BOARD_ORIGIN_Y + row * CELL_SIZE + 1,
				CELL_SIZE - 2, CELL_SIZE - 2, c->r, c->g, c->b);
		}
	}
}

void render_pause(void)
{
	draw_filled_rect(110, 100, 100, 40, 0, 0, 0);
}

void render_game_over(const Game *g, uint32_t high_score, int is_new_high_score)
{
	(void)g;
	draw_filled_rect(70, 90, 180, 60, 40, 0, 0);
	(void)high_score;
	(void)is_new_high_score;
}
