"""Gera a música do HELL TIME da MEL-CHAN (assets/music/hell_time.wav).

    python -I tools/hell_time_music.py

150 BPM (batida de 0,4 s). 2 compassos de subida + 32 compassos + cauda. Os tempos têm que bater
com HELL_BEAT, HELL_PRE e HELL_BARS em scripts/game.gd: os golpes da boss saem em cima da batida.

Seções (8 compassos cada), iguais às da luta:
  A  Pulso   — bumbo, baixo e chimbal
  B  Pólen   — entra caixa e arpejo
  C  Marés   — meio tempo, melodia
  D  Tudo    — tudo junto, uma oitava acima, virada no fim
"""
import os
import wave

import numpy as np

SR = 32000
BPM = 150.0
BEAT = 60.0 / BPM            # 0,4 s
BAR = BEAT * 4.0
PRE_BARS = 2
BARS = 32
TAIL = 1.6
TOTAL = (PRE_BARS + BARS) * BAR + TAIL

rng = np.random.default_rng(7)
n_total = int(TOTAL * SR)
drums = np.zeros(n_total)
music = np.zeros(n_total)
duck = np.ones(n_total)


def t_of(bar, beat=0.0):
    """Instante (s) de um compasso/tempo. bar 0 = primeiro compasso da luta (depois da subida)."""
    return (PRE_BARS + bar) * BAR + beat * BEAT


def put(buf, at, sig, gain=1.0):
    i = int(at * SR)
    if i >= n_total or i < 0:
        return
    sig = sig[: n_total - i]
    buf[i:i + len(sig)] += sig * gain


def env(n, attack=0.002, decay=6.0):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / attack) * np.exp(-t * decay)


def hz(semi):
    """Semitons a partir do Mi1 (41,2 Hz)."""
    return 41.2 * 2.0 ** (semi / 12.0)


def kick():
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    f = 44.0 + 120.0 * np.exp(-t * 28.0)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11.0)
    click = rng.standard_normal(n) * np.exp(-t * 320.0) * 0.25
    return body + click


def snare():
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = noise - np.concatenate(([0.0], noise[:-1])) * 0.6   # tira o grave
    return noise * np.exp(-t * 22.0) * 0.55 + np.sin(2 * np.pi * 185.0 * t) * np.exp(-t * 30.0) * 0.5


def hat(open_=False):
    n = int((0.16 if open_ else 0.045) * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = np.diff(noise, prepend=0.0)
    noise = np.diff(noise, prepend=0.0)
    return noise * np.exp(-t * (20.0 if open_ else 80.0)) * 0.16


def saw(freq, dur, harmonics=9):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(1, harmonics + 1):
        if freq * k > SR * 0.45:
            break
        out += np.sin(2 * np.pi * freq * k * t) / k
    return out * 0.6


def square(freq, dur, width=0.5, harmonics=13):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(1, harmonics + 1):
        if freq * k > SR * 0.45:
            break
        out += np.sin(np.pi * k * width) * np.cos(2 * np.pi * freq * k * t) / k
    return out * 0.8


def lead(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1.0, t / 0.15)
    phase = 2 * np.pi * np.cumsum(freq * vib) / SR
    sig = np.sin(phase) + 0.45 * np.sin(2 * phase) + 0.2 * np.sin(3 * phase)
    a = np.minimum(1.0, t / 0.01) * np.minimum(1.0, (dur - t) / 0.04).clip(0.0, 1.0)
    return sig * a * 0.5


def do_kick(at, gain=1.0):
    put(drums, at, kick(), gain)
    # o bumbo "abaixa" o resto por um instante (sidechain)
    n = int(0.22 * SR)
    i = int(at * SR)
    if i < n_total:
        shape = 1.0 - 0.55 * np.exp(-np.arange(n) / SR * 14.0)
        m = min(n, n_total - i)
        duck[i:i + m] = np.minimum(duck[i:i + m], shape[:m])


# Mi menor: Em | Em | C | C | D | D | Bm | Bm  (a tônica de cada compasso, em semitons do Mi1)
ROOTS = [0, 0, -4, -4, -2, -2, -5, -5]
THIRD = [3, 3, 4, 4, 4, 4, 3, 3]  # menor ou maior

# melodia das seções C e D: (tempo dentro de 2 compassos, duração em tempos, grau acima da tônica do Mi)
MOTIF = [
    [(0, 1.5, 12), (1.5, 0.5, 15), (2, 1, 19), (3, 1, 17), (4, 1.5, 15), (5.5, 0.5, 12), (6, 2, 14)],
    [(0, 1.5, 8), (1.5, 0.5, 12), (2, 1, 15), (3, 1, 12), (4, 1.5, 14), (5.5, 0.5, 10), (6, 2, 12)],
    [(0, 1.5, 10), (1.5, 0.5, 14), (2, 1, 17), (3, 1, 14), (4, 1, 19), (5, 1, 17), (6, 2, 14)],
    [(0, 1, 7), (1, 1, 11), (2, 1, 14), (3, 1, 11), (4, 0.5, 14), (4.5, 0.5, 15), (5, 1, 14), (6, 2, 11)],
]

# ---------------------------------------------------------------- subida (2 compassos antes da luta)
n_pre = int(PRE_BARS * BAR * SR)
tp = np.arange(n_pre) / SR
riser = rng.standard_normal(n_pre)
riser = np.diff(riser, prepend=0.0) * (tp / tp[-1]) ** 2 * 0.2
put(music, 0.0, riser)
sweep = np.sin(2 * np.pi * np.cumsum(110.0 * 2.0 ** (tp / tp[-1] * 2.0)) / SR) * (tp / tp[-1]) * 0.25
put(music, 0.0, sweep)
for b in range(4):
    do_kick(b * BEAT)
for e in range(8):           # segundo compasso: colcheias
    do_kick(BAR + e * BEAT * 0.5, 0.9)
for s in range(8):           # rufar da caixa na última metade
    put(drums, BAR + 2 * BEAT + s * BEAT * 0.25, snare(), 0.4 + s * 0.07)

# ---------------------------------------------------------------- os 32 compassos
for bar in range(BARS):
    sec = bar // 8           # 0=A 1=B 2=C 3=D
    root = ROOTS[bar % 8]
    third = THIRD[bar % 8]
    half_time = sec == 2
    # bumbo
    for b in range(4):
        if half_time and b in (1, 3):
            continue
        do_kick(t_of(bar, b))
    if sec == 3:
        do_kick(t_of(bar, 3.5), 0.7)
    # caixa
    if sec == 0 and bar >= 4 or sec in (1, 3):
        put(drums, t_of(bar, 1), snare())
        put(drums, t_of(bar, 3), snare())
    elif half_time:
        put(drums, t_of(bar, 2), snare(), 1.1)
    # chimbal nas colcheias fracas; semicolcheias na seção D
    for e in range(8 if sec != 3 else 16):
        step = 0.5 if sec != 3 else 0.25
        pos = e * step
        if sec != 3 and e % 2 == 0:
            continue
        put(drums, t_of(bar, pos), hat(open_=(sec >= 1 and abs(pos - 3.5) < 0.01)), 1.0 if e % 2 else 0.6)
    # baixo: colcheias pulsando na tônica, com a oitava nos tempos fracos
    for e in range(8):
        if half_time and e in (1, 3, 5):
            continue
        semi = root + 12 + (12 if (e % 4 == 3 and sec != 0) else 0)
        note = saw(hz(semi), BEAT * 0.5 * 0.9, harmonics=7 if sec == 0 else 10)
        put(music, t_of(bar, e * 0.5), note * env(len(note), 0.004, 5.0), 0.5)
    # arpejo em semicolcheias (B e D)
    if sec in (1, 3):
        chord = [0, third, 7, 12, 7, third]
        for s in range(16):
            semi = root + 24 + chord[s % len(chord)] + (12 if sec == 3 else 0)
            note = square(hz(semi), BEAT * 0.25 * 0.95, width=0.3 if sec == 1 else 0.5)
            put(music, t_of(bar, s * 0.25), note * env(len(note), 0.002, 14.0), 0.2 if sec == 1 else 0.17)
    # acorde de fundo (C): quintas longas
    if half_time:
        for semi in (root + 24, root + 24 + 7, root + 24 + third):
            pad = saw(hz(semi), BAR, harmonics=5)
            tt = np.arange(len(pad)) / SR
            pad *= np.minimum(1.0, tt / 0.3) * np.minimum(1.0, (BAR - tt) / 0.3).clip(0.0, 1.0)
            put(music, t_of(bar), pad, 0.1)
    # melodia (C e D), frases de 2 compassos
    if sec >= 2 and bar % 2 == 0:
        for (pos, dur, semi) in MOTIF[(bar // 2) % 4]:
            put(music, t_of(bar, pos), lead(hz(semi + 24 + (12 if sec == 3 else 0)), dur * BEAT * 0.95), 0.42 if sec == 2 else 0.34)

# virada no último compasso e o golpe final
for s in range(16):
    put(drums, t_of(31, s * 0.25), snare(), 0.35 + s * 0.045)
end = t_of(32)
do_kick(end, 1.3)
n_tail = int(TAIL * SR)
tt = np.arange(n_tail) / SR
crash = np.diff(rng.standard_normal(n_tail), prepend=0.0) * np.exp(-tt * 3.0) * 0.35
put(drums, end, crash)
for semi in (12, 19, 24, 27):
    put(music, end, saw(hz(semi), TAIL, harmonics=8) * np.exp(-tt * 2.5), 0.3)

mix = drums * 0.9 + music * duck
mix = np.tanh(mix * 1.1)
mix = mix / np.max(np.abs(mix)) * 0.82
# sem estalo no começo e no fim
fade = int(0.01 * SR)
mix[:fade] *= np.linspace(0.0, 1.0, fade)
mix[-fade:] *= np.linspace(1.0, 0.0, fade)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "music", "hell_time.wav")
os.makedirs(os.path.dirname(out), exist_ok=True)
with wave.open(out, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((mix * 32767.0).astype("<i2").tobytes())
print("ok %.1f s -> %s" % (TOTAL, os.path.normpath(out)))
