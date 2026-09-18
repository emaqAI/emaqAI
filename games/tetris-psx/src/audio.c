#include "audio.h"
#include <psxspu.h>
#include <stdint.h>

/* Real SPU ADPCM sound effects, generated offline by assets/gen_sfx.py
 * (a from-scratch synthesizer + PS-X ADPCM encoder, no external audio
 * assets) and embedded into the executable via psn00bsdk_target_incbin.
 * The high-level SpuVoiceAttr API is unimplemented in this SDK version,
 * so playback uses the low-level per-voice register macros directly. */

#define SFX_VOICE_CH 0
#define SPU_SFX_BASE_ADDR 0x1010

extern const uint8_t sfx_move[];
extern const uint32_t sfx_move_size;
extern const uint8_t sfx_rotate[];
extern const uint32_t sfx_rotate_size;
extern const uint8_t sfx_lock[];
extern const uint32_t sfx_lock_size;
extern const uint8_t sfx_line_clear[];
extern const uint32_t sfx_line_clear_size;
extern const uint8_t sfx_tetris[];
extern const uint32_t sfx_tetris_size;
extern const uint8_t sfx_game_over[];
extern const uint32_t sfx_game_over_size;
extern const uint8_t sfx_menu_select[];
extern const uint32_t sfx_menu_select_size;

typedef struct {
	const uint8_t *data;
	const uint32_t *size;
	uint16_t note;
} SfxDef;

static const SfxDef SFX_DEFS[SFX_COUNT] = {
	{ sfx_move,        &sfx_move_size,        0x1000 },
	{ sfx_rotate,      &sfx_rotate_size,      0x1000 },
	{ sfx_lock,        &sfx_lock_size,        0x1000 },
	{ sfx_line_clear,  &sfx_line_clear_size,  0x1000 },
	{ sfx_tetris,      &sfx_tetris_size,      0x1000 },
	{ sfx_game_over,   &sfx_game_over_size,   0x1000 },
	{ sfx_menu_select, &sfx_menu_select_size, 0x1000 },
};

static uint32_t sfx_spu_addr[SFX_COUNT];

void audio_init(void)
{
	SpuInit();
	SpuSetCommonMasterVolume(0x3FFF, 0x3FFF);

	uint32_t addr = SPU_SFX_BASE_ADDR;
	SpuSetTransferMode(SPU_TRANSFER_BY_DMA);

	for (int i = 0; i < SFX_COUNT; i++) {
		sfx_spu_addr[i] = addr;
		SpuSetTransferStartAddr(addr);
		SpuWrite((const uint32_t *)SFX_DEFS[i].data, *SFX_DEFS[i].size);

		/* Keep each sample 16-byte (ADPCM block) aligned in SPU RAM. */
		addr += (*SFX_DEFS[i].size + 15) & ~15u;
	}
}

void audio_play_sfx(SfxId id)
{
	if (id < 0 || id >= SFX_COUNT)
		return;

	SpuSetKey(0, 1u << SFX_VOICE_CH);
	SpuSetVoiceStartAddr(SFX_VOICE_CH, sfx_spu_addr[id]);
	SpuSetVoicePitch(SFX_VOICE_CH, SFX_DEFS[id].note);
	SpuSetVoiceVolume(SFX_VOICE_CH, 0x3800, 0x3800);
	SpuSetVoiceADSR(SFX_VOICE_CH, 0, 0, 15, 8, 15);
	SpuSetKey(1, 1u << SFX_VOICE_CH);
}
