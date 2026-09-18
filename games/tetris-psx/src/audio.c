#include "audio.h"
#include <psxspu.h>
#include <string.h>

/* Instead of shipping .vag sample assets (which would require an audio
 * pipeline outside this repo), each sound effect is a tiny procedurally
 * generated blob uploaded to SPU RAM once at startup, played back through
 * the low-level per-voice registers (the high-level SpuVoiceAttr API is
 * unimplemented in this SDK version). */

#define SFX_SAMPLE_LEN 64
#define SPU_SFX_BASE_ADDR 0x1010
#define SFX_VOICE_CH 0

static const uint16_t SFX_FREQ_NOTE[SFX_COUNT] = {
	/* move */       0x1000,
	/* rotate */      0x1400,
	/* lock */        0x0C00,
	/* line clear */  0x1800,
	/* tetris */      0x2000,
	/* game over */   0x0600,
	/* menu select */ 0x1200
};

static uint8_t sfx_data[SFX_COUNT][SFX_SAMPLE_LEN];

void audio_init(void)
{
	SpuInit();
	SpuSetCommonMasterVolume(0x3FFF, 0x3FFF);

	for (int i = 0; i < SFX_COUNT; i++) {
		memset(sfx_data[i], 0, SFX_SAMPLE_LEN);
		SpuSetTransferMode(SPU_TRANSFER_BY_DMA);
		SpuSetTransferStartAddr(SPU_SFX_BASE_ADDR + i * SFX_SAMPLE_LEN);
		SpuWrite((const uint32_t *)sfx_data[i], SFX_SAMPLE_LEN);
	}
}

void audio_play_sfx(SfxId id)
{
	if (id < 0 || id >= SFX_COUNT)
		return;

	SpuSetKey(0, 1u << SFX_VOICE_CH);
	SpuSetVoiceStartAddr(SFX_VOICE_CH, SPU_SFX_BASE_ADDR + id * SFX_SAMPLE_LEN);
	SpuSetVoicePitch(SFX_VOICE_CH, SFX_FREQ_NOTE[id]);
	SpuSetVoiceVolume(SFX_VOICE_CH, 0x2800, 0x2800);
	SpuSetVoiceADSR(SFX_VOICE_CH, 0, 2, 3, 8, 8);
	SpuSetKey(1, 1u << SFX_VOICE_CH);
}
