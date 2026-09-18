#include "input.h"
#include <psxpad.h>
#include <psxetc.h>
#include <string.h>

static uint8_t pad_buf[2][34];
static uint32_t held = 0;
static uint32_t held_prev = 0;

void input_init(void)
{
	InitPAD((uint8_t *)pad_buf[0], 34, (uint8_t *)pad_buf[1], 34);
	StartPAD();
	ChangeClearPAD(0);
}

static uint32_t map_pad_bits(uint16_t sw)
{
	/* PSX pad switches are active-low. */
	uint32_t out = 0;
	if (!(sw & PAD_LEFT))     out |= IN_LEFT;
	if (!(sw & PAD_RIGHT))    out |= IN_RIGHT;
	if (!(sw & PAD_UP))       out |= IN_UP;
	if (!(sw & PAD_DOWN))     out |= IN_DOWN;
	if (!(sw & PAD_CROSS))    out |= IN_CROSS;
	if (!(sw & PAD_CIRCLE))   out |= IN_CIRCLE;
	if (!(sw & PAD_TRIANGLE)) out |= IN_TRIANGLE;
	if (!(sw & PAD_START))    out |= IN_START;
	if (!(sw & PAD_SELECT))   out |= IN_SELECT;
	return out;
}

void input_poll(void)
{
	held_prev = held;
	held = 0;

	PADTYPE *pad = (PADTYPE *)pad_buf[0];
	if (pad->stat == 0 &&
	    (pad->type == 0x4 || pad->type == 0x5 || pad->type == 0x7)) {
		held = map_pad_bits(pad->btn);
	}
}

uint32_t input_held(void)
{
	return held;
}

uint32_t input_pressed(void)
{
	return held & ~held_prev;
}
