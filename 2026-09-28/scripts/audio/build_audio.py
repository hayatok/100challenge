"""Rebuild the edited game sounds from the source archives listed in ALPHA_AUDIO.md.

Usage: python3 scripts/audio/build_audio.py /path/to/sounds.zip /path/to/kenney_impact-sounds.zip /path/to/darkness_road_remake_bpm165.ogg
Requires ffmpeg. The source files are intentionally kept outside the distributable app.
"""

from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "public/assets/audio"


def run(*args: str) -> None:
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    firearms, impact, music = map(Path, sys.argv[1:])
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        temp = Path(td)
        with zipfile.ZipFile(firearms) as z:
            pistol = temp / "cz.wav"
            pistol.write_bytes(z.read("sounds/cz.wav"))
        with zipfile.ZipFile(impact) as z:
            for src, dst in [
                ("Audio/impactPunch_heavy_001.ogg", "body.ogg"),
                ("Audio/impactPunch_medium_003.ogg", "hit.ogg"),
                ("Audio/impactMetal_heavy_002.ogg", "metal.ogg"),
                ("Audio/impactBell_heavy_000.ogg", "bell.ogg"),
                ("Audio/impactGlass_heavy_001.ogg", "glass.ogg"),
            ]:
                (OUTPUT / dst).write_bytes(z.read(src))
        for index, start in enumerate((0.265, 2.81, 4.035), start=1):
            # Trim silence before each real CZ-52 report; tighten low end and tail.
            run(
                "-ss", str(start), "-t", "0.54", "-i", str(pistol),
                "-af", "highpass=f=90,lowpass=f=9000,acompressor=threshold=-20dB:ratio=3:attack=2:release=90,afade=t=out:st=0.37:d=0.17,volume=2.1",
                "-c:a", "libmp3lame", "-b:a", "160k", str(OUTPUT / f"shot-{index}.mp3"),
            )
    # Original author supplied a seamless 128-second 165 BPM loop. Copy it intact.
    (OUTPUT / "darkness-road.ogg").write_bytes(music.read_bytes())


if __name__ == "__main__":
    main()
