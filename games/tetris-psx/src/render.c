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

static uint32_t ot_ordering_table[2][1];
static uint8_t primitive_buffer[2][16384];
static uint8_t *next_primitive;

static int font_hud;    /* score / level / lines, bottom margin */
static int font_title;  /* state banner: menu title, PAUSED, GAME OVER */
static int font_menu;   /* menu item list */

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

	/* Debug font (built into PSn00bSDK) loaded once into an unused corner
	 * of VRAM; text streams are opened once here rather than per frame. */
	FntLoad(960, 0);
	font_hud   = FntOpen(4, 182, 312, 40, 0, 128);
	/* isbg=0: FntFlush() draws a background tile every frame regardless of
	 * whether any text was printed to the stream that frame, which would
	 * paint over the board during normal gameplay. The menu/pause/game-over
	 * screens already draw their own background rect before printing text. */
	font_title = FntOpen(56, 40, 208, 96, 0, 96);
	font_menu  = FntOpen(78, 76, 160, 72, 0, 96);
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

	/* FntFlush submits and draws its own primitives immediately (it does
	 * its own DrawSync/DrawOTag/DrawSync), so it must run after our own
	 * DrawOTag but before the display buffer flip below. */
	FntFlush(font_hud);
	FntFlush(font_title);
	FntFlush(font_menu);

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
	static const char *ITEMS[] = { "START", "HIGH SCORE", "CONTROLS" };

	draw_filled_rect(60, 60, 200, 100, 30, 30, 60);
	draw_filled_rect(70, 76 + selected_item * 16, 6, 6, 240, 240, 0);

	FntPrint(font_title, "TETRIS PSX");
	FntPrint(font_menu, "\n");
	for (int i = 0; i < 3; i++)
		FntPrint(font_menu, "  %s\n", ITEMS[i]);
	FntPrint(font_hud, "HIGH SCORE: %u", high_score);
}

void render_game(const Game *g)
{
	draw_board_frame();

	/* While a completed line is blinking, alternate every ~4 frames
	 * between a bright white flash and hiding the row entirely. */
	int flash_phase_visible = ((g->flash_timer / 4) & 1) == 0;

	for (int y = 0; y < BOARD_HEIGHT; y++) {
		int flashing = 0;
		if (g->flash_timer > 0) {
			for (int i = 0; i < g->lines_to_flash_count; i++) {
				if (g->lines_to_flash[i] == y) {
					flashing = 1;
					break;
				}
			}
		}

		if (flashing) {
			if (flash_phase_visible) {
				for (int x = 0; x < BOARD_WIDTH; x++)
					draw_filled_rect(BOARD_ORIGIN_X + x * CELL_SIZE + 1,
							  BOARD_ORIGIN_Y + y * CELL_SIZE + 1,
							  CELL_SIZE - 2, CELL_SIZE - 2, 255, 255, 255);
			}
			continue;
		}

		for (int x = 0; x < BOARD_WIDTH; x++) {
			uint8_t cell = g->cells[y][x];
			if (cell)
				draw_block(x, y, cell - 1);
		}
	}

	if (g->state == STATE_PLAYING && g->flash_timer == 0) {
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

	FntPrint(font_hud, "SCORE %06u  LEVEL %02u  LINES %03u",
		 g->score, g->level, g->lines_cleared);
}

void render_pause(void)
{
	draw_filled_rect(56, 40, 208, 96, 0, 0, 0);
	FntPrint(font_title, "PAUSED\n\nSTART: RESUME\nSELECT: QUIT TO MENU");
}

void render_game_over(const Game *g, uint32_t high_score, int is_new_high_score)
{
	draw_filled_rect(56, 40, 208, 96, 40, 0, 0);
	FntPrint(font_title, "GAME OVER\n\nSCORE: %u\n%s\n\nPRESS X/START",
		 g->score,
		 is_new_high_score ? "NEW HIGH SCORE!" : "");
	FntPrint(font_hud, "HIGH SCORE: %u", high_score);
}
