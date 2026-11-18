"""Make COCO's two drum sounds from math (run once).

Run:  python make_sounds.py
Makes art/sounds/drum_low.wav, drum_high.wav, snore.wav and wake.wav
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


def snore(seconds=1.5, volume=0.35):
    """A soft snore: low, rumbly noise that swells up and fades away like one breath."""
    rnd = random.Random(11)
    samples = []
    smooth = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        smooth += 0.04 * (rnd.uniform(-1, 1) - smooth)        # soften the noise (low sounds only)
        rumble = 0.6 + 0.4 * math.sin(2 * math.pi * 38 * t)    # slow buzz of the throat
        breath = math.sin(math.pi * t / seconds) ** 2          # swell up, then fade out
        samples.append(smooth * rumble * breath)
    peak = max(abs(s) for s in samples)
    return [s / peak * volume for s in samples]


def wake(seconds=0.3, volume=0.6):
    """A short rising 'boing'."""
    samples = []
    phase = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        hz = 300 + 600 * (t / seconds) ** 0.7                  # slides up from 300 to 900 Hz
        phase += 2 * math.pi * hz / RATE
        wobble = 1 + 0.15 * math.sin(2 * math.pi * 18 * t)     # a little springy wobble
        fade = math.exp(-t * 6) * min(1.0, i / 200)             # soft start, fades out
        samples.append(math.sin(phase) * wobble * fade)
    peak = max(abs(s) for s in samples)
    return [s / peak * volume for s in samples]


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
    save("snore.wav", snore())
    save("wake.wav", wake())
