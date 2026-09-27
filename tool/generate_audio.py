#!/usr/bin/env python3
"""Synthesizes the game's placeholder sound effects and music.

Everything is generated procedurally so the repo has no third-party audio
licensing to worry about. Re-run after tweaking:

    pip install numpy
    python3 tool/generate_audio.py

Writes 16-bit mono WAVs into assets/audio/.
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')

# C major pentatonic, so every merge pitch sounds pleasant together.
PENTA = [0, 2, 4, 7, 9]


def note_freq(semitones_from_c5):
    return 523.25 * 2 ** (semitones_from_c5 / 12)


def penta(step):
    octave, idx = divmod(step, len(PENTA))
    return note_freq(PENTA[idx] + 12 * octave)


def t_axis(duration):
    return np.arange(int(RATE * duration)) / RATE


def env(n, attack=0.005, decay=0.25):
    t = np.arange(n) / RATE
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def tone(freq, duration, decay=0.25, harmonics=(1.0, 0.35, 0.12), attack=0.004, bend=0.0):
    t = t_axis(duration)
    f = freq * (1 + bend * np.exp(-t * 30))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    sig = sum(a * np.sin(phase * (i + 1)) for i, a in enumerate(harmonics))
    return sig * env(len(t), attack, decay)


def pluck(freq, duration=0.35, decay=0.12):
    # Soft marimba-like pluck
    t = t_axis(duration)
    sig = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t * 40)
    return sig * env(len(t), 0.002, decay)


def noise(duration, decay=0.1, lowpass=0.2):
    n = int(RATE * duration)
    x = np.random.default_rng(7).uniform(-1, 1, n)
    y = np.zeros(n)
    for i in range(1, n):
        y[i] = y[i - 1] + lowpass * (x[i] - y[i - 1])
    return y * env(n, 0.002, decay)


def mix(*parts):
    """parts: (offset_seconds, signal)"""
    length = max(int(o * RATE) + len(s) for o, s in parts)
    out = np.zeros(length)
    for o, s in parts:
        i = int(o * RATE)
        out[i:i + len(s)] += s
    return out


def write(name, sig, gain=0.8):
    sig = np.asarray(sig, dtype=float)
    peak = np.max(np.abs(sig)) or 1
    sig = sig / peak * gain
    # Short fade-out to avoid clicks
    fade = min(len(sig), int(RATE * 0.01))
    sig[-fade:] *= np.linspace(1, 0, fade)
    data = (sig * 32767).astype('<i2').tobytes()
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def main():
    os.makedirs(OUT, exist_ok=True)

    # Merge: two-note "bloop" rising with item level.
    for level in range(1, 9):
        base = penta(level + 1)
        s = mix((0, pluck(base * 0.75, 0.25)), (0.06, pluck(base, 0.45, 0.18)),
                (0.06, 0.25 * tone(base * 2, 0.4, 0.15)))
        write(f'merge_{level}.wav', s, 0.75)

    write('bonus.wav', mix(*[(i * 0.06, pluck(penta(5 + i), 0.5, 0.2)) for i in range(5)]), 0.8)
    write('pop.wav', tone(620, 0.12, 0.04, (1.0, 0.2), bend=0.8), 0.6)
    write('tap.wav', tone(880, 0.06, 0.015, (1.0,)), 0.35)
    write('error.wav', mix((0, tone(220, 0.18, 0.08, (1.0, 0.5))), (0.1, tone(185, 0.2, 0.08, (1.0, 0.5)))), 0.5)
    write('coin.wav', mix((0, tone(1318, 0.12, 0.05, (1.0, 0.3))), (0.06, tone(1760, 0.3, 0.12, (1.0, 0.3)))), 0.55)
    write('collect.wav', mix(*[(i * 0.05, tone(1318 * 2 ** (i / 12 * 2), 0.25, 0.08, (1.0, 0.3))) for i in range(6)]), 0.6)
    write('order.wav', mix(*[(i * 0.08, pluck(penta(3 + i * 2), 0.5, 0.2)) for i in range(4)],
                           (0.32, 0.4 * tone(penta(11), 0.6, 0.3))), 0.8)
    write('levelup.wav', mix(*[(i * 0.1, tone(penta(i + 2), 0.6, 0.3, (1.0, 0.4, 0.2))) for i in range(6)],
                             (0.6, 0.6 * tone(penta(10), 1.0, 0.5, (1.0, 0.5, 0.25)))), 0.8)
    write('unlock.wav', mix((0, 0.7 * noise(0.35, 0.12, 0.08)), (0.05, pluck(penta(7), 0.4, 0.15))), 0.6)
    write('restore.wav', mix(*[(i * 0.07, pluck(penta(4 + i), 0.8, 0.35)) for i in range(5)],
                             (0.0, 0.3 * noise(0.5, 0.2, 0.03))), 0.75)
    # Hatch: crack + sparkly arpeggio + chirp
    chirp_t = t_axis(0.25)
    chirp = np.sin(2 * np.pi * np.cumsum(1400 + 900 * np.sin(chirp_t * 40)) / RATE) * env(len(chirp_t), 0.01, 0.1)
    write('hatch.wav', mix((0, noise(0.12, 0.03, 0.5)), (0.08, noise(0.1, 0.03, 0.5)),
                           *[(0.2 + i * 0.06, pluck(penta(6 + i), 0.5, 0.2)) for i in range(6)],
                           (0.62, 0.5 * chirp)), 0.8)

    # Music: calm pentatonic loop with a soft pad, 32 bars-ish at ~84 bpm.
    beat = 60 / 84
    bars = 8
    length = bars * 4 * beat
    music = np.zeros(int(RATE * length) + RATE)
    rng = np.random.default_rng(3)
    chords = [[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]]  # C Am F G (roots relative to C5)
    for bar in range(bars):
        chord = chords[bar % 4]
        start = bar * 4 * beat
        # Pad
        for semi in chord:
            f = note_freq(semi - 12)
            pad = tone(f, 4 * beat + 0.5, 1.6, (1.0, 0.15), attack=0.4) * 0.18
            i = int(start * RATE)
            music[i:i + len(pad)] += pad
        # Melody: gentle random walk on the pentatonic scale
        step = 5
        for b in range(8):
            if rng.random() < 0.3:
                continue
            step = int(np.clip(step + rng.integers(-2, 3), 2, 10))
            n = pluck(penta(step), 0.9, 0.35) * 0.32
            i = int((start + b * beat / 2) * RATE)
            music[i:i + len(n)] += n
    loop = music[:int(RATE * length)]
    # Cross-fade the tail into the head for a seamless loop
    tail = music[int(RATE * length):int(RATE * length) + RATE // 2]
    loop[:len(tail)] += tail
    write('music_meadow.wav', loop, 0.55)


if __name__ == '__main__':
    main()
