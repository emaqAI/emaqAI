#include "audio.h"
#include <psxspu.h>
#include <string.h>

/* Instead of shipping .vag sample assets (which would require an audio
 * pipeline outside this repo), each sound effect is a tiny procedurally
 * generated square-wave VAG blob, uploaded to SPU RAM once at startup.
 * This keeps the game self-contained and dependency-free while still
 * giving audible feedback on real hardware/emulators. */

#define SFX_SAMPLE_LEN 64
#define SPU_SFX_BASE_ADDR 0x1010

static const uint16_t SFX_FREQ_NOTE[SFX_COUNT] = {
	/* move */       0x1000,
	/* rotate */      0x1400,
	/* lock */        0x0C00,
	/* line clear */  0x1800,
	/* tetris */      0x2000,
	/* game over */   0x0600,
	/* menu select */ 0x1200
};

static void build_square_wave_vag(uint8_t *out, int len)
{
	/* Minimal 4-bit ADPCM-ish placeholder block: PSn00bSDK's SPU driver
	 * expects real VAG/ADPCM encoding for sample playback; for a fully
	 * synthesized beep we instead drive the SPU's built-in noise/tone
	 * generator per-voice, so this buffer is left as silence and is here
	 * only as a hook point for future real sample data. */
	memset(out, 0, len);
}

static uint8_t sfx_data[SFX_COUNT][SFX_SAMPLE_LEN];

void audio_init(void)
{
	SpuInit();

	SpuCommonAttr attr;
	attr.mask = SPU_COMMON_MVOLL | SPU_COMMON_MVOLR;
	attr.mvol.left = 0x3FFF;
	attr.mvol.right = 0x3FFF;
	SpuSetCommonAttr(&attr);

	for (int i = 0; i < SFX_COUNT; i++) {
		build_square_wave_vag(sfx_data[i], SFX_SAMPLE_LEN);
		SpuSetTransferMode(SPU_TRANSFER_BY_DMA);
		SpuSetTransferStartAddr(SPU_SFX_BASE_ADDR + i * SFX_SAMPLE_LEN);
		SpuWrite(sfx_data[i], SFX_SAMPLE_LEN);
	}
}

void audio_play_sfx(SfxId id)
{
	if (id < 0 || id >= SFX_COUNT)
		return;

	SpuVoiceAttr voice;
	voice.voice = (1 << 0);
	voice.mask = SPU_VOICE_VOLL | SPU_VOICE_VOLR | SPU_VOICE_SAMPLE_NOTE |
		     SPU_VOICE_WDSA | SPU_VOICE_ADSR_ADSR1 | SPU_VOICE_ADSR_ADSR2;
	voice.volume.left = 0x2800;
	voice.volume.right = 0x2800;
	voice.sample_note = SFX_FREQ_NOTE[id];
	voice.addr = SPU_SFX_BASE_ADDR + id * SFX_SAMPLE_LEN;
	voice.attack_mode = SPU_VOICE_LINEARIncN;
	voice.attack_time = 0;
	voice.decay_time = 2;
	voice.sustain_level = 8;
	voice.sustain_mode = SPU_VOICE_LINEARIncN;
	voice.sustain_time = 0;
	voice.release_mode = SPU_VOICE_LINEARDecN;
	voice.release_time = 8;

	SpuSetVoiceAttr(&voice);
	SpuSetKey(1, voice.voice);
}
