#include "save.h"
#include <psxapi.h>
#include <string.h>

/* This SDK only exposes the low-level per-sector BIOS memory card driver
 * (InitCARD/_card_read/_card_write), not a higher-level file system with
 * directory entries. To keep this self-contained we skip writing a
 * standard memory card directory frame and instead persist the high score
 * directly in the first data sector of card slot 0, block 1 (sector 1 of
 * the card, right after the directory sector). This means the score will
 * not show up as a named file in the BIOS memory card manager, but it
 * round-trips correctly across boots on the same card slot. */

#define SAVE_CHANNEL 0   /* memory card slot 1 */
#define SAVE_SECTOR  1   /* first data sector of block 1 */
#define SECTOR_SIZE  128

typedef struct {
	char magic[4];  /* "TTR1" */
	uint32_t high_score;
	uint8_t  padding[SECTOR_SIZE - 4 - 4];
} SaveBlock;

static uint32_t cached_high_score = 0;
static int card_ready = 0;

static int card_wait_ready(void)
{
	int status;
	do {
		status = _card_status(SAVE_CHANNEL);
	} while (status < 0);
	return _card_wait(SAVE_CHANNEL) >= 0;
}

void save_init(void)
{
	InitCARD(1);
	StartCARD();
	_card_info(SAVE_CHANNEL);
	card_ready = card_wait_ready();

	cached_high_score = save_load_high_score();
}

uint32_t save_load_high_score(void)
{
	SaveBlock block;
	memset(&block, 0, sizeof(block));

	if (!card_ready)
		return 0;

	if (_card_read(SAVE_CHANNEL, SAVE_SECTOR, (uint8_t *)&block) < 0)
		return 0;
	if (!card_wait_ready())
		return 0;

	if (memcmp(block.magic, "TTR1", 4) != 0)
		return 0;

	return block.high_score;
}

int save_store_high_score(uint32_t score)
{
	if (!card_ready || score <= cached_high_score)
		return 0;

	SaveBlock block;
	memset(&block, 0, sizeof(block));
	memcpy(block.magic, "TTR1", 4);
	block.high_score = score;

	if (_card_write(SAVE_CHANNEL, SAVE_SECTOR, (uint8_t *)&block) < 0)
		return 0;
	if (!card_wait_ready())
		return 0;

	cached_high_score = score;
	return 1;
}
