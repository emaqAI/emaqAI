#ifndef TETRIS_AUDIO_H
#define TETRIS_AUDIO_H

typedef enum {
	SFX_MOVE = 0,
	SFX_ROTATE,
	SFX_LOCK,
	SFX_LINE_CLEAR,
	SFX_TETRIS,
	SFX_GAME_OVER,
	SFX_MENU_SELECT,
	SFX_COUNT
} SfxId;

void audio_init(void);
void audio_play_sfx(SfxId id);

#endif
