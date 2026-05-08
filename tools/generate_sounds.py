"""
Generate 20 notification sounds for Mirit Reminders app.
Output: assets/sounds/*.wav
"""
import wave
import struct
import math
import os

SAMPLE_RATE = 44100
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
os.makedirs(OUTPUT_DIR, exist_ok=True)


def write_wav(filename, samples, sample_rate=SAMPLE_RATE):
    path = os.path.join(OUTPUT_DIR, filename)
    with wave.open(path, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        for s in samples:
            clamped = max(-32767, min(32767, int(s)))
            f.writeframes(struct.pack('<h', clamped))
    print(f'  OK  {filename}')


def silence(duration):
    return [0] * int(SAMPLE_RATE * duration)


def tone(freq, duration, volume=0.7, attack=0.01, decay=0.08):
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # ADSR envelope
        if t < attack:
            env = t / attack
        elif t < attack + decay:
            env = 1.0 - 0.3 * ((t - attack) / decay)
        elif t < duration - 0.05:
            env = 0.7
        else:
            env = 0.7 * (duration - t) / 0.05
        env = max(0.0, env)
        samples.append(32767 * volume * env * math.sin(2 * math.pi * freq * t))
    return samples


def chord(freqs, duration, volume=0.5, attack=0.01):
    n = int(SAMPLE_RATE * duration)
    parts = [tone(f, duration, volume / len(freqs), attack) for f in freqs]
    return [sum(p[i] for p in parts) for i in range(n)]


def sweep(f_start, f_end, duration, volume=0.65):
    n = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        frac = t / duration
        freq = f_start + (f_end - f_start) * frac
        env = math.sin(math.pi * frac)          # rise-and-fall
        env = max(0.0, env)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        samples.append(32767 * volume * env * math.sin(phase))
    return samples


def vibrato(freq, duration, depth=8, rate=5, volume=0.65):
    n = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        f = freq + depth * math.sin(2 * math.pi * rate * t)
        phase += 2 * math.pi * f / SAMPLE_RATE
        frac = t / duration
        env = min(frac / 0.01, 1.0) * min((duration - t) / 0.06, 1.0)
        env = max(0.0, env)
        samples.append(32767 * volume * env * math.sin(phase))
    return samples


def harmonics(freq, duration, volume=0.55):
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        frac = t / duration
        env = min(frac / 0.01, 1.0) * min((duration - t) / 0.1, 1.0)
        env = max(0.0, env)
        s = (math.sin(2 * math.pi * freq * t)
             + 0.5 * math.sin(2 * math.pi * freq * 2 * t)
             + 0.25 * math.sin(2 * math.pi * freq * 3 * t))
        samples.append(32767 * volume * env * s / 1.75)
    return samples


# ─── 20 SOUNDS ────────────────────────────────────────────────────────────────
print('\nGenerating 20 notification sounds...\n', flush=True)

# 1. צלצול פשוט  — single clean ping at A5
write_wav('ping_simple.wav',
    tone(880, 0.5))

# 2. צלצול כפול  — two pings a fifth apart
write_wav('ping_double.wav',
    tone(880, 0.25) + silence(0.08) + tone(1320, 0.3))

# 3. צלצול משולש  — three ascending pings
write_wav('ping_triple.wav',
    tone(660, 0.2) + silence(0.06) +
    tone(880, 0.2) + silence(0.06) +
    tone(1100, 0.3))

# 4. פעמון עדין  — soft bell with harmonics
write_wav('chime_soft.wav',
    harmonics(523, 1.2, volume=0.45))

# 5. פעמון  — richer bell (C5 chord)
write_wav('chime_bell.wav',
    chord([523, 659, 784], 1.0, volume=0.5))

# 6. התראה נמוכה  — calm low alert
write_wav('alert_low.wav',
    tone(330, 0.4) + silence(0.05) + tone(330, 0.4))

# 7. התראה בינונית  — medium alert (two tones)
write_wav('alert_medium.wav',
    tone(523, 0.25) + silence(0.05) + tone(659, 0.35))

# 8. התראה גבוהה  — bright high alert
write_wav('alert_high.wav',
    tone(1047, 0.2) + silence(0.04) +
    tone(1047, 0.2) + silence(0.04) +
    tone(1047, 0.3))

# 9. טון עולה  — smooth frequency sweep up
write_wav('tone_rise.wav',
    sweep(440, 880, 0.7))

# 10. טון יורד  — smooth frequency sweep down
write_wav('tone_fall.wav',
    sweep(880, 440, 0.7))

# 11. גלי  — rise then fall (wavelike)
write_wav('tone_wave.wav',
    sweep(440, 880, 0.4) + sweep(880, 440, 0.4))

# 12. צפצוף מהיר  — quick short beep
write_wav('beep_quick.wav',
    tone(1200, 0.12))

# 13. צפצוף ארוך  — longer steady beep
write_wav('beep_long.wav',
    tone(800, 0.8))

# 14. מנגינה 1  — short 4-note melody (C-E-G-C)
write_wav('melody_1.wav',
    tone(523, 0.18) + silence(0.04) +
    tone(659, 0.18) + silence(0.04) +
    tone(784, 0.18) + silence(0.04) +
    tone(1047, 0.35))

# 15. מנגינה 2  — descending melody (C-B-A-G)
write_wav('melody_2.wav',
    tone(1047, 0.18) + silence(0.04) +
    tone(988, 0.18) + silence(0.04) +
    tone(880, 0.18) + silence(0.04) +
    tone(784, 0.35))

# 16. קסילופון  — xylophone-like staccato hits
write_wav('xylophone.wav',
    tone(1047, 0.12, attack=0.005) + silence(0.05) +
    tone(880,  0.12, attack=0.005) + silence(0.05) +
    tone(1047, 0.12, attack=0.005) + silence(0.05) +
    tone(1319, 0.18, attack=0.005))

# 17. פסנתר  — piano-like two note chord
write_wav('piano.wav',
    chord([392, 523, 659], 1.1, volume=0.45))

# 18. עדין  — very soft single tone (low volume, long release)
write_wav('gentle.wav',
    tone(622, 1.0, volume=0.35, decay=0.3))

# 19. בוקר  — cheerful morning arpeggio (C-E-G-E-C)
write_wav('morning.wav',
    tone(523, 0.15) + silence(0.03) +
    tone(659, 0.15) + silence(0.03) +
    tone(784, 0.15) + silence(0.03) +
    tone(659, 0.15) + silence(0.03) +
    tone(1047, 0.3))

# 20. דחוף  — urgent repeating pulse
write_wav('urgent.wav',
    tone(900, 0.1) + silence(0.04) +
    tone(900, 0.1) + silence(0.04) +
    tone(900, 0.1) + silence(0.04) +
    tone(1100, 0.1) + silence(0.04) +
    tone(1100, 0.1) + silence(0.04) +
    tone(1100, 0.18))

print('\nDone! 20 sounds generated in assets/sounds/\n')
