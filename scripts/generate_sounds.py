#!/usr/bin/env python3
"""
Procedural alarm-sound generator for RHOIDS.

Synthesizes 12 natural, calm notification tones and writes them as mono
16-bit .caf files into Sources/RHOIDS/Resources/Sounds/.

Design goals (per user feedback "the dings are too fast / not natural"):
  * Real instrument physics: inharmonic partials for bells, exponential
    decay where higher partials fade faster, soft (click-free) attacks.
  * A trailing silence "gap" baked into every file so that when the alarm
    loops (AVAudioPlayer.numberOfLoops = -1) the tone breathes instead of
    machine-gunning back-to-back.
  * Light synthetic reverb for a spacious, "supernatural" feel.

Requires: numpy, and macOS `afconvert` (WAV -> CAF).
Run:      python3 scripts/generate_sounds.py
"""

import os
import shutil
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Sources", "RHOIDS", "Resources", "Sounds",
)

# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------


def silence(dur):
    return np.zeros(int(SR * dur))


def soft_attack(sig, ms=5.0):
    """Linear fade-in to remove the click at sample 0."""
    n = int(SR * ms / 1000.0)
    if 0 < n < len(sig):
        env = np.ones(len(sig))
        env[:n] = np.linspace(0.0, 1.0, n)
        sig = sig * env
    return sig


def soft_release(sig, ms=40.0):
    """Linear fade-out so the tail never cuts abruptly."""
    n = int(SR * ms / 1000.0)
    if 0 < n < len(sig):
        env = np.ones(len(sig))
        env[-n:] = np.linspace(1.0, 0.0, n)
        sig = sig * env
    return sig


def partial(freq, dur, tau, amp=1.0, phase=0.0):
    """A single exponentially-decaying sine partial."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    return amp * np.exp(-t / tau) * np.sin(2.0 * np.pi * freq * t + phase)


def fft_convolve(a, b):
    """Fast linear convolution via FFT (avoids scipy)."""
    n = len(a) + len(b) - 1
    N = 1 << int(np.ceil(np.log2(n)))
    A = np.fft.rfft(a, N)
    B = np.fft.rfft(b, N)
    return np.fft.irfft(A * B, N)[:n]


def reverb(sig, ir_dur=1.1, decay=0.35, mix=0.18, seed=0):
    """Convolution reverb with a synthetic exponentially-decaying noise IR."""
    rng = np.random.default_rng(seed)
    n = int(SR * ir_dur)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * decay))
    ir[0] = 1.0  # keep the dry transient crisp
    wet = fft_convolve(sig, ir)
    wet = wet / (np.max(np.abs(wet)) + 1e-9)
    out = np.zeros(len(wet))
    out[: len(sig)] += (1.0 - mix) * sig
    out += mix * wet
    return out


def pluck(freq, dur, decay=0.996, amp=1.0, seed=0):
    """Karplus-Strong plucked string (harp / music-box bodies)."""
    n = int(SR * dur)
    N = max(2, int(SR / freq))
    rng = np.random.default_rng(seed)
    buf = rng.standard_normal(N)
    out = np.empty(n)
    idx = 0
    for i in range(n):
        out[i] = buf[idx]
        nxt = (idx + 1) % N
        buf[idx] = decay * 0.5 * (buf[idx] + buf[nxt])
        idx = nxt
    return amp * soft_attack(out, 2.0)


# Pentatonic-friendly note frequencies (equal temperament)
def note(name):
    table = {
        "C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.00, "A4": 440.00,
        "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.00,
        "C6": 1046.50, "D6": 1174.66, "E6": 1318.51, "G6": 1567.98,
    }
    return table[name]


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------


def make_bell():
    """Struck metal bell - classic inharmonic ratios, long natural decay."""
    f0 = note("C5")
    ratios = [0.56, 0.92, 1.19, 1.71, 2.00, 2.74, 3.00, 3.76, 4.07, 5.43]
    amps = [1.0, 0.55, 0.78, 0.45, 0.85, 0.35, 0.30, 0.22, 0.18, 0.12]
    taus = [3.2, 2.6, 2.3, 1.8, 2.7, 1.2, 1.0, 0.85, 0.65, 0.45]
    dur = 3.6
    sig = np.zeros(int(SR * dur))
    for r, a, tau in zip(ratios, amps, taus):
        sig += partial(f0 * r, dur, tau, a)
    sig = soft_attack(sig, 3.0)
    sig = reverb(sig, mix=0.16, seed=1)
    return np.concatenate([sig, silence(0.7)])


def make_chime():
    """Wind chimes - several tubular tones struck in soft succession."""
    notes = ["G5", "C6", "E6", "D6"]
    dur = 3.2
    total = int(SR * (dur + 0.6))
    sig = np.zeros(total)
    rng = np.random.default_rng(7)
    for i, nm in enumerate(notes):
        f0 = note(nm)
        seg = np.zeros(int(SR * dur))
        for r, a, tau in [(1.0, 1.0, 2.4), (2.76, 0.4, 1.4), (5.4, 0.2, 0.8)]:
            seg += partial(f0 * r, dur, tau, a)
        seg = soft_attack(seg, 3.0)
        start = int(SR * (0.18 * i + rng.uniform(0, 0.04)))
        sig[start:start + len(seg)] += seg[: total - start]
    sig = reverb(sig, mix=0.2, seed=2)
    return np.concatenate([sig, silence(0.6)])


def make_marimba():
    """Warm wooden mallet - fundamental + strong 4th-partial, quick decay."""
    f0 = note("C5")
    dur = 0.9

    def hit(freq, amp):
        seg = (
            partial(freq, dur, 0.35, amp)
            + partial(freq * 4.0, dur, 0.18, amp * 0.5)   # marimba 4th partial
            + partial(freq * 10.0, dur, 0.08, amp * 0.15)
        )
        return soft_attack(seg, 2.0)

    a = hit(f0, 1.0)
    b = hit(note("G5"), 0.8)
    total = int(SR * 1.4)
    sig = np.zeros(total)
    sig[: len(a)] += a[:total]
    s2 = int(SR * 0.16)
    sig[s2:s2 + len(b)] += b[: total - s2]
    sig = reverb(sig, mix=0.12, seed=3)
    return np.concatenate([sig, silence(0.6)])


def make_digital():
    """Soft electronic two-note rise - pleasant, not a harsh beep."""
    dur = 0.28

    def tone(freq):
        n = int(SR * dur)
        t = np.arange(n) / SR
        # sine + gentle 2nd harmonic, soft bell-ish decay
        s = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * 2 * freq * t)
        env = np.exp(-t / 0.18)
        s = soft_attack(s * env, 6.0)
        return soft_release(s, 30.0)

    a = tone(note("E5"))
    b = tone(note("A5"))
    gap = silence(0.06)
    sig = np.concatenate([a, gap, b])
    sig = reverb(sig, mix=0.1, seed=4)
    return np.concatenate([sig, silence(0.7)])


def make_bubbles():
    """Gentle water bubbles - short sines that rise in pitch (drop physics)."""
    rng = np.random.default_rng(11)
    total = int(SR * 1.8)
    sig = np.zeros(total)
    t0 = 0.0
    for _ in range(6):
        f_start = rng.uniform(420, 700)
        f_end = f_start * rng.uniform(1.4, 1.9)
        d = rng.uniform(0.07, 0.12)
        n = int(SR * d)
        t = np.arange(n) / SR
        freq = np.linspace(f_start, f_end, n)
        phase = 2 * np.pi * np.cumsum(freq) / SR
        env = np.sin(np.pi * np.linspace(0, 1, n)) ** 1.5  # soft pop
        seg = np.sin(phase) * env
        start = int(SR * t0)
        if start + n <= total:
            sig[start:start + n] += seg
        t0 += rng.uniform(0.18, 0.32)
    sig = reverb(sig, mix=0.14, seed=5)
    return np.concatenate([sig, silence(0.6)])


def make_singing_bowl():
    """Tibetan singing bowl - slow swell, shimmering beats, very long decay."""
    f0 = 312.0
    dur = 5.5
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    # inharmonic partials, each split into a beating pair for shimmer
    for r, a, tau in [(1.0, 1.0, 4.5), (2.74, 0.5, 3.2), (5.40, 0.28, 2.0),
                      (8.9, 0.14, 1.2)]:
        for det in (-1.0, 1.0):
            f = f0 * r + det * (0.7 * r)  # slight detune -> beating
            sig += a * np.exp(-t / tau) * np.sin(2 * np.pi * f * t)
    # slow swell-in (bowl is rubbed/struck softly)
    swell = np.clip(t / 0.25, 0, 1)
    sig *= swell
    sig = reverb(sig, ir_dur=1.8, decay=0.6, mix=0.28, seed=6)
    return np.concatenate([sig, silence(0.6)])


def make_gong():
    """Soft gong - low fundamental, dense partials, slow swell, spacious."""
    f0 = 138.0
    dur = 5.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    rng = np.random.default_rng(13)
    sig = np.zeros(n)
    for _ in range(14):
        r = rng.uniform(1.0, 7.5)
        a = rng.uniform(0.2, 1.0) / r
        tau = rng.uniform(1.5, 4.0)
        sig += a * np.exp(-t / tau) * np.sin(2 * np.pi * f0 * r * t + rng.uniform(0, 6.28))
    # shimmer wash from filtered noise that builds then fades
    noise = rng.standard_normal(n) * np.exp(-t / 2.5) * np.clip(t / 0.4, 0, 1) * 0.15
    sig += noise
    swell = np.clip(t / 0.3, 0, 1)
    sig *= swell
    sig = reverb(sig, ir_dur=2.0, decay=0.7, mix=0.26, seed=7)
    return np.concatenate([sig, silence(0.6)])


def make_harp():
    """Gentle ascending harp arpeggio (C major pentatonic)."""
    seq = ["C4", "E4", "G4", "C5", "E5", "G5"]
    step = 0.13
    dur = 1.6
    total = int(SR * (step * len(seq) + dur))
    sig = np.zeros(total)
    for i, nm in enumerate(seq):
        f = note(nm)
        seg = pluck(f, dur, decay=0.9965, amp=1.0 / (1 + 0.15 * i), seed=20 + i)
        seg = soft_release(seg, 60.0)
        start = int(SR * step * i)
        sig[start:start + len(seg)] += seg[: total - start]
    sig = reverb(sig, mix=0.2, seed=8)
    return np.concatenate([sig, silence(0.6)])


def make_music_box():
    """Delicate music-box melody - high metallic bell tones."""
    seq = ["G5", "E5", "C5", "E5", "G5", "C6"]
    step = 0.22
    dur = 1.2
    total = int(SR * (step * len(seq) + dur))
    sig = np.zeros(total)
    for i, nm in enumerate(seq):
        f0 = note(nm)
        seg = (
            partial(f0, dur, 0.9, 1.0)
            + partial(f0 * 2.01, dur, 0.6, 0.4)
            + partial(f0 * 3.0, dur, 0.35, 0.18)
            + partial(f0 * 5.4, dur, 0.2, 0.08)
        )
        seg = soft_attack(seg, 2.0)
        start = int(SR * step * i)
        sig[start:start + len(seg)] += seg[: total - start]
    sig = reverb(sig, mix=0.22, seed=9)
    return np.concatenate([sig, silence(0.6)])


def make_crystal():
    """Shimmering crystal / glass bells - pure high tones with beating."""
    notes = ["C6", "G5", "E6", "D6"]
    dur = 2.6
    total = int(SR * (dur + 0.5))
    sig = np.zeros(total)
    for i, nm in enumerate(notes):
        f0 = note(nm)
        seg = np.zeros(int(SR * dur))
        for det in (-1.0, 1.0):
            seg += partial(f0 + det * 1.2, dur, 1.8, 0.6)
            seg += partial(f0 * 2.76 + det * 1.5, dur, 1.0, 0.2)
        seg = soft_attack(seg, 3.0)
        start = int(SR * 0.14 * i)
        sig[start:start + len(seg)] += seg[: total - start]
    sig = reverb(sig, ir_dur=1.5, decay=0.5, mix=0.26, seed=10)
    return np.concatenate([sig, silence(0.6)])


def make_zen():
    """Zen woodblock - warm percussive knock, two soft hits."""
    def knock(f0, amp, seed):
        dur = 0.18
        n = int(SR * dur)
        t = np.arange(n) / SR
        rng = np.random.default_rng(seed)
        # resonant modes
        s = (
            partial(f0, dur, 0.05, amp)
            + partial(f0 * 1.6, dur, 0.035, amp * 0.5)
            + partial(f0 * 2.3, dur, 0.025, amp * 0.25)
        )
        # short noise transient for the "tok"
        s += rng.standard_normal(n) * np.exp(-t / 0.006) * amp * 0.4
        return soft_attack(s, 1.0)

    a = knock(880, 1.0, 30)
    b = knock(880, 0.7, 31)
    total = int(SR * 0.9)
    sig = np.zeros(total)
    sig[: len(a)] += a[:total]
    s2 = int(SR * 0.28)
    sig[s2:s2 + len(b)] += b[: total - s2]
    sig = reverb(sig, ir_dur=0.8, decay=0.3, mix=0.16, seed=11)
    return np.concatenate([sig, silence(0.7)])


def make_birdsong():
    """Soft morning birdsong - a few warbling chirps."""
    rng = np.random.default_rng(42)
    total = int(SR * 2.6)
    sig = np.zeros(total)

    def chirp(f0, f1, d, vib=0.0):
        n = int(SR * d)
        t = np.arange(n) / SR
        freq = np.linspace(f0, f1, n)
        if vib:
            freq = freq + vib * np.sin(2 * np.pi * 18 * t)
        phase = 2 * np.pi * np.cumsum(freq) / SR
        env = np.sin(np.pi * np.linspace(0, 1, n)) ** 0.8
        s = np.sin(phase) * env
        s += 0.2 * np.sin(2 * phase) * env  # a little brightness
        return s

    phrases = [
        (0.05, [(2600, 3300, 0.09), (3300, 2500, 0.08)]),
        (0.45, [(3000, 3600, 0.07), (3600, 3000, 0.07), (3000, 3500, 0.06)]),
        (1.05, [(2400, 2900, 0.10)]),
        (1.5, [(3200, 3900, 0.06), (3900, 3100, 0.08)]),
    ]
    for t0, notes in phrases:
        cursor = t0
        for f0, f1, d in notes:
            seg = chirp(f0, f1, d, vib=rng.uniform(20, 60))
            start = int(SR * cursor)
            if start + len(seg) <= total:
                sig[start:start + len(seg)] += seg
            cursor += d + rng.uniform(0.01, 0.04)
    sig = reverb(sig, ir_dur=1.2, decay=0.4, mix=0.22, seed=12)
    return np.concatenate([sig, silence(0.5)])


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

SOUNDS = {
    "bell": make_bell,
    "chime": make_chime,
    "marimba": make_marimba,
    "digital": make_digital,
    "bubbles": make_bubbles,
    "singing_bowl": make_singing_bowl,
    "gong": make_gong,
    "harp": make_harp,
    "music_box": make_music_box,
    "crystal": make_crystal,
    "zen": make_zen,
    "birdsong": make_birdsong,
}


def write_wav(path, sig, peak=0.89):
    sig = sig / (np.max(np.abs(sig)) + 1e-9) * peak
    pcm = (sig * 32767).astype("<i2")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    if shutil.which("afconvert") is None:
        raise SystemExit("afconvert not found (macOS required).")
    os.makedirs(OUT_DIR, exist_ok=True)
    tmp = tempfile.mkdtemp()
    print(f"Output: {OUT_DIR}\n")
    for name, fn in SOUNDS.items():
        sig = fn()
        dur = len(sig) / SR
        wav_path = os.path.join(tmp, f"{name}.wav")
        caf_path = os.path.join(OUT_DIR, f"{name}.caf")
        write_wav(wav_path, sig)
        subprocess.run(
            ["afconvert", "-f", "caff", "-d", "LEI16@44100", "-c", "1",
             wav_path, caf_path],
            check=True,
        )
        peak = np.max(np.abs(sig))
        rms = np.sqrt(np.mean(sig ** 2))
        print(f"  {name:14s} {dur:4.1f}s  peak={peak:5.3f}  rms={rms:5.3f}")
    print("\nDone.")


if __name__ == "__main__":
    main()
