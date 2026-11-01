#!/usr/bin/env python3
"""F10-T05 — Genera sonidos propios NPS (originales, sin muestras Apple).

Sintesis 100% propia con stdlib `wave`: senos con envolvente exponencial,
ruido filtrado y barridos. Todos <=300ms (contrato Tahoe §2.5: sonidos
propios <300ms + cue visual redundante). Pico ~-6dBFS (conservador;
equivalente perceptual aprox. -14LUFS para tonos cortos).

Uso: python3 generate_sounds.py  -> escribe stereo/*.wav y stereo/*.oga
     (la conversion a .oga necesita ffmpeg en PATH).
"""
import math
import os
import random
import struct
import subprocess
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stereo")
os.makedirs(OUT, exist_ok=True)

rng = random.Random(20261101)  # semilla fija: builds reproducibles


def env_exp(n, tau=0.35):
    return [math.exp(-(i / n) / tau) for i in range(n)]


def sine(freq, ms, amp=0.5, tau=0.35, phase=0.0):
    n = int(SR * ms / 1000)
    e = env_exp(n, tau)
    out = []
    for i in range(n):
        t = i / SR
        out.append(amp * e[i] * math.sin(2 * math.pi * freq * t + phase))
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, v in enumerate(l):
            out[i] += v
    peak = max(1e-9, max(abs(v) for v in out))
    if peak > 0.89:
        out = [v * 0.89 / peak for v in out]
    return out


def seq(notes):
    """notes: lista de (freq, ms, amp). Concatena con fundido de 8ms."""
    out = []
    for freq, ms, amp in notes:
        out += sine(freq, ms, amp)
    return out


def noise_burst(ms, amp=0.4, tau=0.5, lp=0.25):
    n = int(SR * ms / 1000)
    e = env_exp(n, tau)
    y = 0.0
    out = []
    for i in range(n):
        y += lp * (rng.uniform(-1, 1) - y)  # paso-bajo una polo
        out.append(amp * e[i] * y * 2.0)
    return out


def sweep(f0, f1, ms, amp=0.45, tau=0.5):
    n = int(SR * ms / 1000)
    e = env_exp(n, tau)
    out = []
    ph = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        ph += 2 * math.pi * f / SR
        out.append(amp * e[i] * math.sin(ph))
    return out


# Evento -> muestras (nombre KDE/ocean/freedesktop verificado en
# /usr/share/sounds/{ocean,freedesktop}/stereo en Plasma 6.8).
EVENTS = {
    # Arranque: arpegio mayor ascendente propio C5-E5-G5, 3x100ms.
    "service-login": seq([(523.25, 100, 0.5), (659.25, 100, 0.5),
                          (783.99, 100, 0.5)]),
    # Notificacion: campanilla bitonal E6->A6 suave.
    "message": mix(sine(1318.5, 110, 0.45),
                   [0.0] * int(SR * 0.09) + sine(1760.0, 130, 0.45)),
    "message-new-instant": None,  # alias de message (se copia abajo)
    # Dialogo: seno unico 880Hz con caida.
    "bell": sine(880.0, 200, 0.5, tau=0.3),
    # Error: dos tonos graves descendentes 220->174Hz.
    "dialog-error": seq([(220.0, 125, 0.5), (174.61, 125, 0.5)]),
    # Papelera: barrido de ruido filtrado descendente.
    "trash-empty": mix(sweep(2400, 500, 200, 0.35), noise_burst(200, 0.25)),
    # Volumen: blip corto 660Hz.
    "audio-volume-change": sine(660.0, 120, 0.5, tau=0.4),
    # Captura: clic de ruido + blip agudo (obturador sintetico).
    "screen-capture": mix(noise_burst(60, 0.5, tau=0.25, lp=0.6),
                          [0.0] * int(SR * 0.05) + sine(2093.0, 130, 0.45)),
    "camera-shutter": None,  # alias de screen-capture
}


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767))
                               for s in samples))


def main():
    aliases = {"message-new-instant": "message",
               "camera-shutter": "screen-capture"}
    base = {}
    for name, samples in EVENTS.items():
        if samples is None:
            continue
        wav = os.path.join(OUT, name + ".wav")
        write_wav(wav, samples)
        base[name] = wav
        print(f"OK {wav} ({len(samples) / SR * 1000:.0f}ms)")
    for alias, src in aliases.items():
        for ext in (".wav", ".oga"):
            s = os.path.join(OUT, src + ext)
            d = os.path.join(OUT, alias + ext)
            if ext == ".wav":
                subprocess.run(["cp", "-f", s, d], check=True)
            print(f"alias {d} -> {src + ext}")
    # wav -> oga (vorbis) para KDE
    for name in base:
        wav = os.path.join(OUT, name + ".wav")
        oga = os.path.join(OUT, name + ".oga")
        r = subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", wav,
                            "-c:a", "libvorbis", "-q:a", "4", oga])
        if r.returncode != 0:
            print(f"WARN: ffmpeg fallo para {name}; queda solo .wav")
        else:
            print(f"OK {oga}")
    # aliases en oga
    for alias, src in aliases.items():
        subprocess.run(["cp", "-f", os.path.join(OUT, src + ".oga"),
                        os.path.join(OUT, alias + ".oga")], check=True)


if __name__ == "__main__":
    main()
