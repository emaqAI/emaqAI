#ifndef TETRIS_SAVE_H
#define TETRIS_SAVE_H

#include <stdint.h>

void save_init(void);

/* Reads the high score from memory card slot 1. Returns 0 if no save file
 * exists (fresh card / no card inserted). */
uint32_t save_load_high_score(void);

/* Writes `score` as the new high score if it beats the stored one.
 * Returns 1 on success, 0 on failure (no card / write error). */
int save_store_high_score(uint32_t score);

#endif
