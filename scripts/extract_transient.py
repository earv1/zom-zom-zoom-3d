#!/usr/bin/env python3
"""
Extract a transient spike from an audio file and save it as a short clip.
Useful for pulling a clean gear-shift click out of a longer recording.

Usage:
    python scripts/extract_transient.py <input> <output> [onset_index]

    onset_index defaults to 0 (first transient). Run without it to see all onsets listed.

Example:
    python scripts/extract_transient.py assets/audio/engine/shift/raw_shift.mp3 \\
                                        assets/audio/engine/shift/shift.ogg 23

Install dependencies:
    pip install librosa soundfile
"""

import sys
import numpy as np

try:
    import librosa
    import soundfile as sf
except ImportError:
    print("Missing dependencies. Run:  pip install librosa soundfile")
    sys.exit(1)


def extract_transient(input_path: str, output_path: str,
                      onset_index: int = 0,
                      pre_ms: float = 5.0, post_ms: float = 300.0) -> None:
    print(f"Loading {input_path}...")
    y, sr = librosa.load(input_path, sr=None, mono=True)

    onset_samples = librosa.onset.onset_detect(y=y, sr=sr, units="samples",
                                               backtrack=True)
    if len(onset_samples) == 0:
        print("No transients found — try a file with a sharper attack.")
        sys.exit(1)

    print(f"\nAll onsets ({len(onset_samples)} found):")
    for i, s in enumerate(onset_samples):
        marker = " ←" if i == onset_index else ""
        print(f"  [{i}] {s/sr*1000:.0f}ms{marker}")

    idx   = min(onset_index, len(onset_samples) - 1)
    first = int(onset_samples[idx])
    pre   = int(pre_ms  * sr / 1000)
    post  = int(post_ms * sr / 1000)
    start = max(0, first - pre)
    end   = min(len(y), first + post)

    clip = y[start:end]

    # Fade out the tail so the clip doesn't click when it ends
    fade_samples = min(int(20 * sr / 1000), len(clip) // 4)
    fade = np.linspace(1.0, 0.0, fade_samples)
    clip[-fade_samples:] *= fade

    sf.write(output_path, clip, sr)

    duration_ms = (end - start) / sr * 1000
    print(f"\nExtracted {duration_ms:.0f}ms clip from onset [{idx}] "
          f"at {first/sr*1000:.0f}ms → {output_path}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    index = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    extract_transient(sys.argv[1], sys.argv[2], onset_index=index)
