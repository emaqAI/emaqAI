#ifndef TETRIS_INPUT_H
#define TETRIS_INPUT_H

#include <stdint.h>

#define IN_LEFT     (1 << 0)
#define IN_RIGHT    (1 << 1)
#define IN_UP       (1 << 2)  /* hard drop */
#define IN_DOWN     (1 << 3)  /* soft drop */
#define IN_CROSS    (1 << 4)  /* rotate CW */
#define IN_CIRCLE   (1 << 5)  /* rotate CCW */
#define IN_TRIANGLE (1 << 6)  /* hold */
#define IN_START    (1 << 7)
#define IN_SELECT   (1 << 8)

void input_init(void);

/* Polls the PSX pad. Must be called once per frame before reading state. */
void input_poll(void);

uint32_t input_pressed(void);  /* just pressed this frame */
uint32_t input_held(void);     /* currently held down */

#endif
