#ifndef TETRIS_RENDER_H
#define TETRIS_RENDER_H

#include "game.h"
#include "state.h"

void render_init(void);
void render_frame_begin(void);
void render_frame_end(void);

void render_menu(int selected_item, uint32_t high_score);
void render_game(const Game *g);
void render_pause(void);
void render_game_over(const Game *g, uint32_t high_score, int is_new_high_score);

#endif
