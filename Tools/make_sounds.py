"""Synthesize MSXPET's bundled cute sounds (stdlib only — no deps).
Writes 44.1kHz mono 16-bit WAVs to Sources/MSXPET/Resources/sounds/.
Usage: python3 Tools/make_sounds.py
"""
import math
import os
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "Sources", "MSXPET",
                   "Resources", "sounds")


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.5 / peak
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767))
            for s in samples))
    print(f"{name}.wav  {len(samples) / SR:.2f}s")


def secs(s):
    return int(s * SR)


def sweep(f0, f1, dur, attack=0.01, curve=2.0):
    """Sine sweep with attack + exponential decay (no clicks)."""
    n = secs(dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / SR
        env = min(1.0, i / max(1, secs(attack))) * math.exp(-curve * t)
        out.append(math.sin(phase) * env)
    return out


def tone(freq, dur, attack=0.01, decay=3.0, harm=(1.0, 0.25, 0.08)):
    n = secs(dur)
    out = []
    for i in range(n):
        t = i / n
        env = min(1.0, i / max(1, secs(attack))) * math.exp(-decay * t)
        s = (math.sin(2 * math.pi * freq * i / SR) * harm[0]
             + math.sin(2 * math.pi * freq * 2 * i / SR) * harm[1]
             + math.sin(2 * math.pi * freq * 3 * i / SR) * harm[2])
        out.append(s * env / sum(harm))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, s in enumerate(p):
            out[i] += s
    return out


def seq(notes, note_dur=0.09, gap=0.01):
    """Little arpeggio from (freq, dur_scale) notes."""
    out = []
    for freq, scale in notes:
        out += tone(freq, note_dur * scale, decay=4.0)
        out += [0.0] * secs(gap)
    return out


def purr(dur=1.2):
    """Seamless loopable purr: 25Hz-gated rumble + soft harmonics.
    1.2s holds exactly 30/60/90 cycles -> no loop click."""
    n = secs(dur)
    out = []
    for i in range(n):
        t = i / SR
        gate = max(0.0, math.sin(2 * math.pi * 25 * t)) ** 1.5
        s = (gate * 0.6
             + math.sin(2 * math.pi * 50 * t) * 0.15
             + math.sin(2 * math.pi * 75 * t) * 0.08)
        # gentle 0.4Hz breathing swell, also loop-aligned (0.48 cycles? no:
        # use exactly 1 swell per loop -> seamless)
        swell = 0.75 + 0.25 * math.sin(2 * math.pi * t / dur)
        out.append(s * swell)
    return out


if __name__ == "__main__":
    save("grab", sweep(300, 650, 0.12))
    save("happy", sweep(880, 1320, 0.09, curve=1.2) + sweep(1320, 990, 0.10))
    save("land", sweep(130, 55, 0.22, attack=0.004, curve=4.0))
    save("pounce", tone(1250, 0.08, decay=6.0))
    save("laserOn", seq([(880, 1), (1174, 1), (1568, 1.4)]))
    save("laserOff", seq([(1568, 1), (1174, 1), (880, 1.4)]))
    save("wake", sweep(520, 390, 0.35, attack=0.08, curve=1.0))
    save("purr", purr())
    print("done ->", os.path.abspath(OUT))
