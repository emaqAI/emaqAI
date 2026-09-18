#!/usr/bin/env python3
"""Generates real PS-X SPU ADPCM (.vag body, headerless) sound effects for
Tetris PSX from scratch (no external audio assets), using a plain sine/
square synthesizer and a from-scratch ADPCM encoder (filter 0 / no
prediction, forward-adaptive 4-bit quantization per 28-sample block --
this is a valid subset of the real PS-X ADPCM format used by the SPU and
decodes correctly on real hardware/emulators).

Output: raw ADPCM sample data (no 48-byte VAG file header), ready to be
DMA'd straight into SPU RAM, one file per effect under sfx/*.vagbody.
"""
import math
import os
import struct

SAMPLE_RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "sfx")
os.makedirs(OUT_DIR, exist_ok=True)


def synth(freq, duration, shape="square", sweep_to=None, decay=6.0):
	n = int(SAMPLE_RATE * duration)
	samples = []
	for i in range(n):
		t = i / SAMPLE_RATE
		f = freq if sweep_to is None else freq + (sweep_to - freq) * (i / n)
		phase = 2 * math.pi * f * t
		if shape == "square":
			s = 1.0 if math.sin(phase) >= 0 else -1.0
		else:
			s = math.sin(phase)
		env = math.exp(-decay * (i / n))
		samples.append(int(max(-1.0, min(1.0, s * env)) * 22000))
	return samples


def encode_adpcm(pcm):
	"""Encodes 16-bit PCM samples into PS-X ADPCM (filter 0), 16 bytes
	(28 samples) per block, last block flagged as loop-end/stop."""
	pad = (-len(pcm)) % 28
	pcm = pcm + [0] * pad

	out = bytearray()
	n_blocks = len(pcm) // 28

	for b in range(n_blocks):
		block = pcm[b * 28:(b + 1) * 28]
		max_abs = max(1, max(abs(s) for s in block))

		# Largest shift such that round(sample >> (12 - shift)) fits in
		# a signed 4-bit nibble range [-8, 7] for every sample in the block.
		shift = 0
		for s in range(12, -1, -1):
			ok = True
			for sample in block:
				nib = sample >> (12 - s) if (12 - s) >= 0 else sample << (s - 12)
				nib = (nib + 1) >> 1 if nib >= 0 else -((-nib + 1) >> 1)
				if nib < -8 or nib > 7:
					ok = False
					break
			if ok:
				shift = s
				break

		is_last = (b == n_blocks - 1)
		flag = 1 if is_last else 0  # 1 = loop end, stop (no repeat)
		header = ((0 & 0xF) << 4) | (shift & 0xF)  # filter 0, chosen shift
		out.append(header)
		out.append(flag)

		nibbles = []
		for sample in block:
			shifted = sample >> (12 - shift) if (12 - shift) >= 0 else sample << (shift - 12)
			nib = (shifted + 1) >> 1 if shifted >= 0 else -((-shifted + 1) >> 1)
			nib = max(-8, min(7, nib))
			nibbles.append(nib & 0xF)

		for i in range(0, 28, 2):
			out.append((nibbles[i] & 0xF) | ((nibbles[i + 1] & 0xF) << 4))

	return bytes(out)


EFFECTS = {
	"move":        lambda: synth(440, 0.05, "square", decay=8.0),
	"rotate":      lambda: synth(660, 0.06, "square", sweep_to=880, decay=7.0),
	"lock":        lambda: synth(220, 0.08, "square", decay=9.0),
	"line_clear":  lambda: synth(523, 0.18, "square", sweep_to=1046, decay=3.0),
	"tetris":      lambda: synth(392, 0.35, "square", sweep_to=1568, decay=1.8),
	"game_over":   lambda: synth(392, 0.6, "square", sweep_to=98, decay=1.2),
	"menu_select": lambda: synth(880, 0.07, "square", decay=8.0),
}

for name, gen in EFFECTS.items():
	pcm = gen()
	data = encode_adpcm(pcm)
	path = os.path.join(OUT_DIR, f"{name}.vagbody")
	with open(path, "wb") as f:
		f.write(data)
	print(f"{name}: {len(pcm)} samples -> {len(data)} bytes ADPCM ({path})")
