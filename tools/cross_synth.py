#!/usr/bin/env python3
"""Cross-synthesis (a vocoder): make a carrier sound "say" a modulator sound.

Frame by frame (STFT), the carrier is whitened (its own spectral envelope
divided out, leaving its raw texture) and then given the modulator's spectral
envelope and loudness. With a zombie growl as carrier and a hadeda call as
modulator you get one voice: the growl crying the bird's call. `--keep` mixes a
little of the plain modulator back in so it stays recognisable.

    cross_synth.py modulator.wav carrier.wav out.wav [--keep 0.25] [--lifter 40]

Inputs are decoded with ffmpeg (any format); output is 44.1 kHz mono 16-bit WAV.
"""
import argparse
import subprocess

import numpy as np

RATE = 44100
N = 2048          # frame
HOP = 512         # 75% overlap


def load(path: str) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def save(path: str, x: np.ndarray) -> None:
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
         "-c:a", "pcm_s16le", path],
        input=x.astype(np.float32).tobytes(), check=True)


def stft(x: np.ndarray) -> np.ndarray:
    win = np.hanning(N)
    frames = 1 + max(0, (len(x) - N) // HOP)
    return np.stack([np.fft.rfft(win * x[i * HOP:i * HOP + N]) for i in range(frames)])


def istft(spec: np.ndarray, length: int) -> np.ndarray:
    win = np.hanning(N)
    out = np.zeros(length + N)
    norm = np.zeros(length + N)
    for i, frame in enumerate(spec):
        out[i * HOP:i * HOP + N] += win * np.fft.irfft(frame, N)
        norm[i * HOP:i * HOP + N] += win ** 2
    return (out / np.maximum(norm, 1e-6))[:length]


def envelope(mag: np.ndarray, lifter: int) -> np.ndarray:
    """Smooth spectral envelope per frame (cepstral liftering)."""
    cep = np.fft.irfft(np.log(mag + 1e-9), axis=1)
    cep[:, lifter:-lifter] = 0.0
    return np.exp(np.fft.rfft(cep, axis=1).real)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("modulator")
    ap.add_argument("carrier")
    ap.add_argument("out")
    ap.add_argument("--keep", type=float, default=0.25, help="how much plain modulator to mix back in")
    ap.add_argument("--lifter", type=int, default=40, help="envelope detail (higher = more of the call's timbre)")
    args = ap.parse_args()

    mod = load(args.modulator)
    car = load(args.carrier)
    car = np.resize(car, len(mod))                      # loop the carrier under the whole call
    M = stft(mod)
    C = stft(car)
    frames = min(len(M), len(C))
    M, C = M[:frames], C[:frames]
    m_env = envelope(np.abs(M), args.lifter)
    c_env = envelope(np.abs(C), args.lifter)
    voiced = C / c_env * m_env                           # carrier texture, modulator's shape and loudness
    y = istft(voiced, len(mod))
    y = y / (np.max(np.abs(y)) + 1e-9)
    plain = mod / (np.max(np.abs(mod)) + 1e-9)
    y = (1.0 - args.keep) * y + args.keep * plain
    save(args.out, 0.95 * y / (np.max(np.abs(y)) + 1e-9))


if __name__ == "__main__":
    main()
