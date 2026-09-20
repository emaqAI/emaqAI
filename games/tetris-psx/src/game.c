#include "game.h"
#include "input.h"
#include "audio.h"
#include <string.h>

#define LOCK_DELAY_FRAMES 30 /* half a second at 60fps */
#define FLASH_DURATION_FRAMES 24 /* three white/blank blink cycles */

static uint32_t rng_next(Game *g)
{
	/* xorshift32 - deterministic, no libc rand() needed on PSX. */
	uint32_t x = g->rng_state;
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	g->rng_state = x;
	return x;
}

static PieceType random_piece(Game *g)
{
	return (PieceType)(rng_next(g) % PIECE_COUNT);
}

static void spawn_piece(Game *g, PieceType type)
{
	g->current.type = type;
	g->current.rotation = 0;
	g->current.x = (type == PIECE_O) ? 3 : 3;
	g->current.y = (type == PIECE_I) ? -1 : -2;
	g->hold_used_this_turn = 0;
	g->lock_delay_active = 0;
	g->lock_timer = 0;
}

static int piece_fits(const Game *g, PieceType type, int rotation, int px, int py)
{
	Cell cells[PIECE_CELLS];
	tetromino_get_cells(type, rotation, cells);

	for (int i = 0; i < PIECE_CELLS; i++) {
		int x = px + cells[i].x;
		int y = py + cells[i].y;

		if (x < 0 || x >= BOARD_WIDTH || y >= BOARD_HEIGHT)
			return 0;
		if (y >= 0 && g->cells[y][x])
			return 0;
	}
	return 1;
}

static uint32_t gravity_interval_for_level(int level)
{
	/* Frames per row, roughly matching classic guideline gravity curve at
	 * 60fps, clamped so it never becomes instant. */
	static const uint32_t table[MAX_LEVEL + 1] = {
		48,43,38,33,28,23,18,13,8,6,
		5,5,5,4,4,4,3,3,3,2
	};
	if (level > MAX_LEVEL)
		level = MAX_LEVEL;
	return table[level];
}

void game_init(Game *g)
{
	memset(g, 0, sizeof(*g));
	g->rng_state = 0xC0FFEEu ^ (uint32_t)(uintptr_t)g;
	if (g->rng_state == 0)
		g->rng_state = 1;
	game_reset(g);
}

void game_reset(Game *g)
{
	memset(g->cells, 0, sizeof(g->cells));
	g->score = 0;
	g->lines_cleared = 0;
	g->level = 0;
	g->gravity_timer = 0;
	g->gravity_interval = gravity_interval_for_level(0);
	g->has_hold = 0;
	g->hold_used_this_turn = 0;
	g->lock_delay_active = 0;
	g->lock_timer = 0;
	g->lines_to_flash_count = 0;
	g->flash_timer = 0;
	g->state = STATE_PLAYING;

	g->next.type = random_piece(g);
	spawn_piece(g, random_piece(g));
}

static void lock_piece(Game *g)
{
	Cell cells[PIECE_CELLS];
	tetromino_get_cells(g->current.type, g->current.rotation, cells);

	for (int i = 0; i < PIECE_CELLS; i++) {
		int x = g->current.x + cells[i].x;
		int y = g->current.y + cells[i].y;
		if (y >= 0 && y < BOARD_HEIGHT && x >= 0 && x < BOARD_WIDTH)
			g->cells[y][x] = (uint8_t)(1 + g->current.type);
	}

	audio_play_sfx(SFX_LOCK);
}

static int find_full_lines(Game *g, int *out_rows)
{
	int count = 0;
	for (int y = 0; y < BOARD_HEIGHT; y++) {
		int full = 1;
		for (int x = 0; x < BOARD_WIDTH; x++) {
			if (!g->cells[y][x]) {
				full = 0;
				break;
			}
		}
		if (full)
			out_rows[count++] = y;
	}
	return count;
}

static void clear_lines(Game *g, const int *rows, int count)
{
	for (int i = 0; i < count; i++) {
		int row = rows[i];
		for (int y = row; y > 0; y--)
			memcpy(g->cells[y], g->cells[y - 1], sizeof(g->cells[0]));
		memset(g->cells[0], 0, sizeof(g->cells[0]));
	}
}

static void apply_score_for_lines(Game *g, int count)
{
	static const uint32_t base_score[5] = {0, 100, 300, 500, 800};
	g->score += base_score[count] * (g->level + 1);
	g->lines_cleared += count;

	uint16_t new_level = g->lines_cleared / LINES_PER_LEVEL;
	if (new_level > g->level) {
		g->level = new_level;
		g->gravity_interval = gravity_interval_for_level(g->level);
	}

	audio_play_sfx(count == 4 ? SFX_TETRIS : SFX_LINE_CLEAR);
}

static void try_spawn_next(Game *g)
{
	PieceType next = g->next.type;
	g->next.type = random_piece(g);

	/* Every piece's rotation-0 shape only occupies relative rows 0-1, so
	 * checking fit at the actual (off-board, negative-y) spawn position
	 * used for the smooth entry animation would always trivially succeed
	 * (those rows never touch the visible board, so there's never
	 * anything to collide with). Check at y=0 instead: the row the piece
	 * will actually descend into first. This is what determines whether
	 * there's genuinely room to place it, independent of the animation. */
	if (!piece_fits(g, next, 0, 3, 0)) {
		g->state = STATE_GAME_OVER;
		audio_play_sfx(SFX_GAME_OVER);
		return;
	}
	spawn_piece(g, next);
}

/* Locks the current piece, and if it completed any lines, starts the
 * blink-flash animation instead of clearing them immediately (clear_lines()
 * and the next spawn happen once the flash finishes, in game_update()).
 * Returns 1 if this ended the game (only possible when no lines were
 * completed, since spawning is deferred while flashing). */
static int finish_lock(Game *g)
{
	lock_piece(g);

	int rows[4];
	int count = find_full_lines(g, rows);
	if (count > 0) {
		memcpy(g->lines_to_flash, rows, sizeof(int) * count);
		g->lines_to_flash_count = count;
		g->flash_timer = FLASH_DURATION_FRAMES;
		apply_score_for_lines(g, count);
		return 0;
	}

	try_spawn_next(g);
	return g->state == STATE_GAME_OVER;
}

static void try_move(Game *g, int dx, int dy)
{
	if (piece_fits(g, g->current.type, g->current.rotation,
		       g->current.x + dx, g->current.y + dy)) {
		g->current.x += dx;
		g->current.y += dy;
		if (dx != 0)
			audio_play_sfx(SFX_MOVE);
		g->lock_delay_active = 0;
		g->lock_timer = 0;
	}
}

static void try_rotate(Game *g, int dir)
{
	int from = g->current.rotation;
	int to = (from + dir) & 3;

	Cell kicks[5];
	int n = tetromino_get_kicks(g->current.type, from, to, kicks);

	for (int i = 0; i < n; i++) {
		int nx = g->current.x + kicks[i].x;
		int ny = g->current.y + kicks[i].y;
		if (piece_fits(g, g->current.type, to, nx, ny)) {
			g->current.rotation = to;
			g->current.x = nx;
			g->current.y = ny;
			g->lock_delay_active = 0;
			g->lock_timer = 0;
			audio_play_sfx(SFX_ROTATE);
			return;
		}
	}
}

static int hard_drop(Game *g)
{
	int dropped = 0;
	while (piece_fits(g, g->current.type, g->current.rotation,
			   g->current.x, g->current.y + 1)) {
		g->current.y++;
		dropped++;
	}
	g->score += (uint32_t)dropped * 2;
	return finish_lock(g);
}

static void hold_piece(Game *g)
{
	if (g->hold_used_this_turn)
		return;

	PieceType current_type = g->current.type;
	if (!g->has_hold) {
		g->has_hold = 1;
		g->hold = current_type;
		try_spawn_next(g);
	} else {
		PieceType swapped = g->hold;
		g->hold = current_type;
		if (!piece_fits(g, swapped, 0, 3, 0))
			return;
		spawn_piece(g, swapped);
	}
	g->hold_used_this_turn = 1;
}

int game_update(Game *g, uint32_t pressed, uint32_t held_in)
{
	if (g->state == STATE_GAME_OVER)
		return 0;

	if (g->flash_timer > 0) {
		g->flash_timer--;
		if (g->flash_timer == 0) {
			clear_lines(g, g->lines_to_flash, g->lines_to_flash_count);
			g->lines_to_flash_count = 0;
			try_spawn_next(g);
			return g->state == STATE_GAME_OVER;
		}
		return 0;
	}

	if (pressed & IN_LEFT)
		try_move(g, -1, 0);
	if (pressed & IN_RIGHT)
		try_move(g, 1, 0);
	if (pressed & IN_CROSS)
		try_rotate(g, 1);
	if (pressed & IN_CIRCLE)
		try_rotate(g, -1);
	if (pressed & IN_TRIANGLE)
		hold_piece(g);
	if (pressed & IN_UP)
		return hard_drop(g);

	uint32_t interval = g->gravity_interval;
	if (held_in & IN_DOWN)
		interval = (interval > 2) ? 2 : interval;

	g->gravity_timer++;
	if (g->gravity_timer >= interval) {
		g->gravity_timer = 0;

		if (piece_fits(g, g->current.type, g->current.rotation,
			       g->current.x, g->current.y + 1)) {
			g->current.y++;
			if (held_in & IN_DOWN)
				g->score += 1;
			g->lock_delay_active = 0;
			g->lock_timer = 0;
		} else {
			g->lock_delay_active = 1;
		}
	}

	if (g->lock_delay_active) {
		g->lock_timer++;
		if (g->lock_timer >= LOCK_DELAY_FRAMES)
			return finish_lock(g);
	}

	return 0;
}

int game_is_cell_filled(const Game *g, int x, int y)
{
	if (x < 0 || x >= BOARD_WIDTH || y < 0 || y >= BOARD_HEIGHT)
		return 0;
	return g->cells[y][x] != 0;
}
