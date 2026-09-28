"""Render a short, approximate sample mix for v0.3/v0.4 level comparison.

Uses the distributed audio files, sample gains, EQ cuts, and tail lengths. This
does not reproduce WebAudio scheduling, compressor behavior, or speakers.
"""

from __future__ import annotations

import argparse
from array import array
from math import log10, sqrt
from pathlib import Path
import subprocess
import sys
import wave


AUDIO = Path(__file__).resolve().parents[2] / "public/assets/audio"
SAMPLE_RATE = 48_000


def events(v04: bool) -> list[tuple[str, float, float, float, str]]:
    # filename, timeline seconds, source gain, tail seconds, EQ bus
    result: list[tuple[str, float, float, float, str]] = []
    for i, at in enumerate((0.20, 0.43, 0.66, 1.30)):
        final = i == 3
        result.append((f"shot-{i % 3 + 1}.mp3", at, 0.808 if final and v04 else 0.76 if final else 0.69,
                       0.34 if final and v04 else 0.31, "gun"))
        result.append(("hit.ogg", at + 0.027, 0.16, 0.17, "impact"))
        if final and v04:
            result.extend((("shot-3.mp3", at + 0.009, 0.26, 0.19, "gun"),
                           ("metal.ogg", at + 0.011, 0.158, 0.12, "accent")))
    result.extend((("body.ogg", 1.30, 0.38, 0.29, "impact"),
                   ("metal.ogg", 1.37, 0.15, 0.25, "accent"),
                   ("glass.ogg", 1.345, 0.155, 0.28, "accent")))
    return result


def render(v04: bool) -> array:
    parts = events(v04)
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error"]
    for file, *_ in parts:
        command.extend(("-i", str(AUDIO / file)))
    filters: list[str] = []
    for i, (_, at, gain, tail, bus) in enumerate(parts):
        eq = "highpass=f=105" if bus == "gun" else "lowpass=f=5900" if bus == "impact" else "highpass=f=330"
        fade_start = max(0, tail - 0.11)
        filters.append(f"[{i}:a]atrim=0:{tail},asetpts=PTS-STARTPTS,{eq},volume={gain * 0.48},"
                       f"afade=t=out:st={fade_start}:d={tail - fade_start},"
                       f"adelay={round(at * 1000)}:all=1[s{i}]")
    inputs = "".join(f"[s{i}]" for i in range(len(parts)))
    filters.append(f"{inputs}amix=inputs={len(parts)}:duration=longest:normalize=0,"
                   f"aresample={SAMPLE_RATE},aformat=channel_layouts=mono[out]")
    command.extend(("-filter_complex", ";".join(filters), "-map", "[out]", "-t", "2.2",
                    "-f", "s16le", "-acodec", "pcm_s16le", "-ac", "1", "-ar", str(SAMPLE_RATE), "pipe:1"))
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    samples = array("h")
    samples.frombytes(result.stdout)
    if sys.byteorder != "little":
        samples.byteswap()
    return samples


def levels(samples: array, start: float, end: float) -> tuple[float, float]:
    segment = samples[int(start * SAMPLE_RATE):int(end * SAMPLE_RATE)]
    peak = max(abs(sample) for sample in segment) / 32768
    rms = sqrt(sum(sample * sample for sample in segment) / len(segment)) / 32768
    return 20 * log10(max(peak, 1e-12)), 20 * log10(max(rms, 1e-12))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--demo", type=Path, help="Write the v0.4 sample mix to a WAV file")
    args = parser.parse_args()
    for version in (False, True):
        samples = render(version)
        peak, rms = levels(samples, 0, 2.2)
        attack_peak, attack_rms = levels(samples, 1.30, 1.38)
        print(f"v0.{4 if version else 3}: full peak {peak:.2f} dBFS, RMS {rms:.2f} dBFS; "
              f"final 80 ms peak {attack_peak:.2f} dBFS, RMS {attack_rms:.2f} dBFS")
        if version and args.demo:
            args.demo.parent.mkdir(parents=True, exist_ok=True)
            with wave.open(str(args.demo), "wb") as output:
                output.setnchannels(1)
                output.setsampwidth(2)
                output.setframerate(SAMPLE_RATE)
                output.writeframes(samples.tobytes())
            print(f"Demo: {args.demo}")


if __name__ == "__main__":
    main()
