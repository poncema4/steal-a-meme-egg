"""The in-game sounds for Steal a Meme Egg, synthesised from scratch (no samples, so nothing to license).
Cheerful and punchy like the top egg games: a hatch pop with sparkle, a steal blip, a guardian roar, a sad-trombone catch,
a delivery fanfare, a coin ping, an event horn, a limited-egg chime, a UI click and a looping background tune.
Usage: python3 scripts/audio/make_game_sfx.py <out-dir>   (writes WAVs; convert to .ogg with ffmpeg for Roblox)"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from synth import RATE, add, env, lowpassed_noise, write_wav  # noqa: E402

random.seed(11)


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def tone(freq, seconds, shape="triangle", attack=0.004, decay=0.25, vibrato=0.0, glide=0.0):
    """One note. shape: sine, triangle, square or saw. glide multiplies the pitch over the note (e.g. 0.5 = falls an octave)."""
    out = []
    phase = 0.0
    n = int(seconds * RATE)
    for i in range(n):
        t = i / RATE
        f = freq * (1 + (glide - 1) * (t / seconds)) * (1 + vibrato * math.sin(2 * math.pi * 6 * t))
        phase += f / RATE
        p = phase % 1.0
        if shape == "sine":
            v = math.sin(2 * math.pi * p)
        elif shape == "triangle":
            v = 4 * abs(p - 0.5) - 1
        elif shape == "square":
            v = 1.0 if p < 0.5 else -1.0
            v *= 0.6
        else:  # saw
            v = 2 * p - 1
        out.append(v * env(t, attack, decay))
    return out


def mix(*parts):
    """Mix [(start_seconds, samples, gain)] into one buffer long enough for all of them."""
    length = max(int(s * RATE) + len(x) for s, x, _ in parts)
    buf = [0.0] * length
    for start, samples, gain in parts:
        add(buf, start, samples, gain)
    return buf


def fade_tail(buf, seconds=0.03):
    n = min(int(seconds * RATE), len(buf))
    for i in range(n):
        buf[len(buf) - 1 - i] *= i / n
    return buf


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def hatch():
    pop_noise = [v * env(i / RATE, 0.0005, 0.02) for i, v in enumerate(lowpassed_noise(0.12, 5000))]
    pop = tone(900, 0.12, "sine", 0.001, 0.05, glide=0.25)
    sparkle = [(0.09 + k * 0.075, tone(midi(n), 0.45, "triangle", 0.002, 0.16), 0.5) for k, n in enumerate((84, 88, 91, 96))]
    return fade_tail(mix((0, pop_noise, 0.9), (0, pop, 1.0), *sparkle))


def steal():
    whoosh = [v * env(i / RATE, 0.12, 0.2) for i, v in enumerate(lowpassed_noise(0.5, 3500))]
    blip = tone(midi(72), 0.1, "square", 0.002, 0.07) + tone(midi(79), 0.18, "square", 0.002, 0.1)
    return fade_tail(mix((0, whoosh, 0.5), (0.02, blip, 0.7)))


def roar():
    n = int(1.1 * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = 85 + 18 * math.sin(2 * math.pi * 4 * t) - 20 * t
        phase += f / RATE
        grit = 0.55 + 0.45 * math.sin(2 * math.pi * 26 * t)  # the growl: fast amplitude wobble
        v = (2 * (phase % 1.0) - 1) * grit + (random.random() * 2 - 1) * 0.25
        out.append(v * env(t, 0.05, 0.55))
    return fade_tail(out, 0.08)


def caught():
    bonk = tone(300, 0.15, "sine", 0.001, 0.06, glide=0.3)
    wah = [(0.18 + k * 0.28, tone(midi(n), 0.34 if k < 3 else 0.7, "saw", 0.02, 0.5, vibrato=0.02 if k == 3 else 0.0), 0.28) for k, n in enumerate((67, 66, 65, 64))]
    return fade_tail(mix((0, bonk, 1.0), *wah))


def deliver():
    notes = [(0.0, 72), (0.11, 76), (0.22, 79), (0.33, 84)]
    parts = [(s, tone(midi(n), 0.3, "square", 0.003, 0.15), 0.3) for s, n in notes]
    parts += [(0.33, tone(midi(n), 0.7, "triangle", 0.003, 0.4), 0.45) for n in (79, 84, 88)]
    return fade_tail(mix(*parts))


def coin():
    return fade_tail(mix((0, tone(midi(83), 0.2, "triangle", 0.001, 0.07), 0.8), (0.07, tone(midi(88), 0.3, "triangle", 0.001, 0.1), 0.8)))


def horn():
    n = int(1.7 * RATE)
    notes = (midi(57), midi(61), midi(64))
    out = []
    phases = [0.0, 0.0, 0.0]
    for i in range(n):
        t = i / RATE
        v = 0.0
        for k, f in enumerate(notes):
            phases[k] += f * (1 + 0.004 * math.sin(2 * math.pi * 5 * t)) / RATE
            v += (2 * (phases[k] % 1.0) - 1) * 0.3
        swell = min(1.0, t / 0.12) * (1.0 if t < 1.2 else math.exp(-(t - 1.2) / 0.18))
        out.append(v * swell)
    return fade_tail(out, 0.05)


def limited():
    glide = tone(midi(60), 0.9, "sine", 0.01, 0.6, glide=2.0)
    bells = [(0.25 + k * 0.1, tone(midi(n), 0.9, "triangle", 0.002, 0.35), 0.4) for k, n in enumerate((79, 84, 88, 91, 96))]
    return fade_tail(mix((0, glide, 0.5), *bells))


def click():
    return fade_tail(tone(1400, 0.06, "square", 0.001, 0.02), 0.01)


def music():
    """A 16-bar bouncy marimba loop (about 35 s) over C, Am, F, G. The tail wraps onto the start so it loops cleanly."""
    bpm = 110
    beat = 60.0 / bpm
    bars = 16
    length = int(bars * 4 * beat * RATE)
    buf = [0.0] * length
    chords = [(60, (60, 64, 67)), (57, (57, 60, 64)), (53, (53, 57, 60)), (55, (55, 59, 62))]  # bass note, chord tones
    melody_pool = [72, 74, 76, 79, 81, 84]  # C major pentatonic-ish
    rng = random.Random(5)
    for bar in range(bars):
        bass, chord = chords[bar % 4]
        t0 = bar * 4 * beat
        for q in range(4):  # bass on every beat, softly
            add(buf, t0 + q * beat, tone(midi(bass - 12), beat * 0.9, "sine", 0.004, 0.25), 0.55)
        for e in range(8):  # eighth-note arpeggio of the chord
            note = chord[e % 3] + (12 if (e // 3) % 2 else 0)
            add(buf, t0 + e * beat / 2, tone(midi(note + 12), 0.35, "sine", 0.002, 0.12), 0.3)
            add(buf, t0 + e * beat / 2, tone(midi(note + 24), 0.2, "sine", 0.002, 0.06), 0.08)
        if bar % 2 == 1:  # a little tune every other bar
            for k in range(4):
                note = rng.choice(melody_pool)
                add(buf, t0 + k * beat + (0.5 * beat if k % 2 else 0), tone(midi(note), 0.5, "triangle", 0.003, 0.2), 0.32)
        for tick in range(8):  # soft shaker on the off-beats
            add(buf, t0 + tick * beat / 2 + beat / 4, [v * env(i / RATE, 0.001, 0.02) for i, v in enumerate(lowpassed_noise(0.05, 9000))], 0.05)
    return buf


SOUNDS = {"hatch": hatch, "steal": steal, "roar": roar, "caught": caught, "deliver": deliver, "coin": coin, "horn": horn, "limited": limited, "click": click}


def main(out):
    os.makedirs(out, exist_ok=True)
    for name, fn in SOUNDS.items():
        buf = fn()
        peak = write_wav(os.path.join(out, f"{name}.wav"), buf, level=0.85, drive=1.0)
        print(f"{name:8s} {len(buf) / RATE:5.2f}s peak {peak:.2f}")
    buf = music()
    peak = write_wav(os.path.join(out, "music.wav"), buf, level=0.7, drive=1.0)
    print(f"music    {len(buf) / RATE:5.2f}s peak {peak:.2f}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "sfx-out")
