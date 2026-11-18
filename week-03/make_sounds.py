"""Make COCO's two drum sounds from math (run once).

Run:  python make_sounds.py
Makes art/sounds/drum_low.wav and art/sounds/drum_high.wav
"""

import math
import os
import random
import struct
import wave

RATE = 44100      # samples per second
LENGTH = 0.35     # seconds
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art", "sounds")


def drum(start_hz, end_hz, noise=0.25, decay=11.0):
    """A drum hit: a tone that slides down in pitch, plus a little noise for the 'thwack'."""
    rnd = random.Random(7)  # same sound every time
    samples = []
    phase = 0.0
    for i in range(int(RATE * LENGTH)):
        t = i / RATE
        hz = end_hz + (start_hz - end_hz) * math.exp(-t * 30)  # pitch drops fast
        phase += 2 * math.pi * hz / RATE
        body = math.sin(phase) * math.exp(-t * decay)
        hit = rnd.uniform(-1, 1) * noise * math.exp(-t * 60)  # short noise at the start
        attack = min(1.0, i / 40)                              # no click at the very start
        samples.append(attack * (body + hit))
    peak = max(abs(s) for s in samples)
    return [s / peak * 0.8 for s in samples]


def save(name, samples):
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)  # 16-bit
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))
    print("saved", path)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    save("drum_low.wav", drum(180, 90))
    save("drum_high.wav", drum(420, 260, noise=0.35, decay=14.0))
