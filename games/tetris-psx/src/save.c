#include "save.h"
#include <psxcard.h>
#include <string.h>
#include <stdio.h>

#define SAVE_SLOT      0
#define SAVE_FILE_NAME "BXTETRIS-TETRISPSX"

typedef struct {
	char magic[4];  /* "TTR1" */
	uint32_t high_score;
	uint8_t  padding[128 - 4 - 4];
} SaveBlock;

static uint32_t cached_high_score = 0;
static int card_ready = 0;

void save_init(void)
{
	CdInit();
	card_ready = (CardInit(SAVE_SLOT) == 0);
	cached_high_score = save_load_high_score();
}

uint32_t save_load_high_score(void)
{
	SaveBlock block;
	memset(&block, 0, sizeof(block));

	int fd = CardOpen(SAVE_SLOT, SAVE_FILE_NAME, "r");
	if (fd < 0)
		return 0;

	CardRead(fd, (uint8_t *)&block, sizeof(block));
	CardClose(fd);

	if (memcmp(block.magic, "TTR1", 4) != 0)
		return 0;

	return block.high_score;
}

int save_store_high_score(uint32_t score)
{
	if (score <= cached_high_score)
		return 0;

	SaveBlock block;
	memset(&block, 0, sizeof(block));
	memcpy(block.magic, "TTR1", 4);
	block.high_score = score;

	int fd = CardOpen(SAVE_SLOT, SAVE_FILE_NAME, "w");
	if (fd < 0)
		return 0;

	int written = CardWrite(fd, (uint8_t *)&block, sizeof(block));
	CardClose(fd);

	if (written == sizeof(block)) {
		cached_high_score = score;
		return 1;
	}
	return 0;
}
