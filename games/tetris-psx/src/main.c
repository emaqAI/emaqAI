#include "game.h"
#include "render.h"
#include "input.h"
#include "audio.h"
#include "save.h"
#include "state.h"

typedef enum {
	MENU_START = 0,
	MENU_HIGH_SCORE,
	MENU_CONTROLS,
	MENU_ITEM_COUNT
} MenuItem;

int main(void)
{
	Game game;
	GameState app_state = STATE_MENU;
	int menu_selected = MENU_START;
	uint32_t high_score;
	int reported_new_high = 0;

	render_init();
	input_init();
	audio_init();
	save_init();

	high_score = save_load_high_score();

	for (;;) {
		input_poll();
		uint32_t pressed = input_pressed();
		uint32_t held = input_held();

		switch (app_state) {
		case STATE_MENU:
			if (pressed & IN_UP)
				menu_selected = (menu_selected + MENU_ITEM_COUNT - 1) % MENU_ITEM_COUNT;
			if (pressed & IN_DOWN)
				menu_selected = (menu_selected + 1) % MENU_ITEM_COUNT;
			if (pressed & IN_CROSS || pressed & IN_START) {
				audio_play_sfx(SFX_MENU_SELECT);
				if (menu_selected == MENU_START) {
					game_init(&game);
					app_state = STATE_PLAYING;
					reported_new_high = 0;
				}
			}
			break;

		case STATE_PLAYING:
			if (pressed & IN_START) {
				app_state = STATE_PAUSED;
				break;
			}
			if (game_update(&game, pressed, held)) {
				app_state = STATE_GAME_OVER;
				if (save_store_high_score(game.score)) {
					reported_new_high = 1;
					high_score = game.score;
				} else {
					reported_new_high = 0;
				}
			}
			break;

		case STATE_PAUSED:
			if (pressed & IN_START)
				app_state = STATE_PLAYING;
			if (pressed & IN_SELECT) {
				app_state = STATE_MENU;
				menu_selected = MENU_START;
			}
			break;

		case STATE_GAME_OVER:
			if (pressed & (IN_CROSS | IN_START)) {
				app_state = STATE_MENU;
				menu_selected = MENU_START;
			}
			break;
		}

		render_frame_begin();
		switch (app_state) {
		case STATE_MENU:
			render_menu(menu_selected, high_score);
			break;
		case STATE_PLAYING:
			render_game(&game);
			break;
		case STATE_PAUSED:
			render_game(&game);
			render_pause();
			break;
		case STATE_GAME_OVER:
			render_game(&game);
			render_game_over(&game, high_score, reported_new_high);
			break;
		}
		render_frame_end();
	}

	return 0;
}
