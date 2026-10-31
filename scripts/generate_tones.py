#!/usr/bin/env python3
"""Synthesizes the app's cue tones as 16-bit mono WAV files using only the standard library.

Run from the repo root:  python3 scripts/generate_tones.py
Re-running overwrites the files in IntervalTimer/Sounds.
"""

import math
import struct
import sys
import wave
from pathlib import Path

RATE = 44100
OUT_DIR = Path(__file__).resolve().parent.parent / "IntervalTimer" / "Sounds"


def envelope(t, duration, attack, decay_rate):
	"""Short linear attack, exponential decay, and a fade over the last 10 ms to avoid clicks."""
	if t < attack:
		amp = t / attack
	else:
		amp = math.exp(-decay_rate * (t - attack))
	tail = duration - t
	if tail < 0.01:
		amp *= max(tail, 0) / 0.01
	return amp


def tone(freq, duration, partials=((1.0, 1.0),), attack=0.005, decay_rate=4.0, gain=0.5):
	"""A single note built from (frequency ratio, amplitude) partials."""
	samples = []
	total = sum(a for _, a in partials)
	for i in range(int(RATE * duration)):
		t = i / RATE
		value = sum(a * math.sin(2 * math.pi * freq * r * t) for r, a in partials) / total
		samples.append(value * envelope(t, duration, attack, decay_rate) * gain)
	return samples


def mix(length, *placed):
	"""Overlays (start_seconds, samples) tracks into one buffer of `length` seconds."""
	out = [0.0] * int(RATE * length)
	for start, samples in placed:
		offset = int(RATE * start)
		for i, s in enumerate(samples):
			if offset + i < len(out):
				out[offset + i] += s
	peak = max(abs(s) for s in out) or 1.0
	# Normalize only if the overlay clips.
	return [s / peak * 0.9 for s in out] if peak > 0.9 else out


def write(name, samples):
	path = OUT_DIR / f"{name}.wav"
	with wave.open(str(path), "wb") as f:
		f.setnchannels(1)
		f.setsampwidth(2)
		f.setframerate(RATE)
		f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
	print(f"wrote {path.relative_to(OUT_DIR.parent.parent)}")


BELL = ((1.0, 1.0), (2.0, 0.5), (3.0, 0.25), (4.2, 0.1))
GLASS = ((1.0, 1.0), (2.76, 0.4), (5.4, 0.15))
SOFT = ((1.0, 1.0), (2.0, 0.15))

C5, E5, G5, C6, E6, G6 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0


def main():
	OUT_DIR.mkdir(parents=True, exist_ok=True)

	# Countdown beeps: short and quiet so they don't compete with the bing.
	write("beep-soft", tone(880, 0.16, SOFT, attack=0.01, decay_rate=12, gain=0.35))
	write("beep-tick", tone(1400, 0.07, SOFT, attack=0.002, decay_rate=30, gain=0.35))
	write("beep-low", tone(587.33, 0.2, SOFT, attack=0.01, decay_rate=10, gain=0.4))

	# Interval start/end.
	write("bing-bell", tone(C6, 1.2, BELL, decay_rate=3.5, gain=0.6))
	write("bing-glass", tone(G6, 1.0, GLASS, decay_rate=4.5, gain=0.55))
	write("bing-chime", mix(1.3, (0, tone(G5, 0.8, BELL, decay_rate=4, gain=0.5)),
		(0.14, tone(C6 * 1.122, 1.1, BELL, decay_rate=3.5, gain=0.5))))
	write("bing-low", tone(C5, 1.4, BELL, decay_rate=2.8, gain=0.65))

	# Finish.
	write("tada-fanfare", mix(2.0,
		(0.00, tone(C5, 0.25, BELL, decay_rate=6, gain=0.45)),
		(0.12, tone(E5, 0.25, BELL, decay_rate=6, gain=0.45)),
		(0.24, tone(G5, 0.25, BELL, decay_rate=6, gain=0.45)),
		(0.40, tone(C5, 1.6, BELL, decay_rate=1.8, gain=0.35)),
		(0.40, tone(E5, 1.6, BELL, decay_rate=1.8, gain=0.35)),
		(0.40, tone(G5, 1.6, BELL, decay_rate=1.8, gain=0.35)),
		(0.40, tone(C6, 1.6, BELL, decay_rate=1.8, gain=0.35))))
	write("tada-sparkle", mix(2.0, *[
		(i * 0.07, tone(f, 1.4 - i * 0.07, GLASS, decay_rate=3, gain=0.4))
		for i, f in enumerate((C5, E5, G5, C6, E6, G6))]))

	# Silent loop that keeps the audio session (and the timer) alive while the screen is locked.
	write("silence", [0.0] * RATE)


if __name__ == "__main__":
	sys.exit(main())
