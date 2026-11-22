"""Render the broadcast and its 60 Hz mouth track with HTS engine API 1.10."""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile

import numpy as np
import pyopenjtalk
from scipy.io import wavfile
from scipy.signal import butter, sosfilt


def mouth_track(labels, duration):
    # The formants come from the voice model. These values only drive the mesh.
    vowels = {"a": (.98, .01), "i": (.33, .01), "u": (.34, .72),
              "e": (.65, .03), "o": (.68, .96), "w": (.31, .74)}
    closures = {"sil", "pau", "cl", "p", "b", "m"}
    sampled = np.zeros((int(np.ceil(duration * 60)) + 1, 2))
    times = np.arange(len(sampled)) / 60
    for line in labels:
        start, stop, context = line.split()
        phone = re.search(r"-(.*?)\+", context).group(1)
        pose = vowels.get(phone.lower(), (.04, 0) if phone in closures else (.22, .10))
        if phone in ("sil", "pau"):
            pose = (0, 0)
        sampled[(times >= int(start) / 1e7) & (times < int(stop) / 1e7)] = pose
    kernel = np.array([.1, .22, .36, .22, .1])
    for column in range(2):
        sampled[:, column] = np.convolve(sampled[:, column], kernel, mode="same")
    return np.rint(sampled * 255).astype(np.uint8)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("engine", type=Path)
    parser.add_argument("voice", type=Path)
    args = parser.parse_args()
    target = Path(__file__).resolve().parents[2] / "Game/Assets/Resources/KinseiAudio"
    # Kana disambiguates the venue name from the reading 'kinboshi'.
    line = "キンセイをとったんは、わしや。まくをかえす。"
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        (work / "input.lab").write_text("\n".join(pyopenjtalk.extract_fullcontext(line)) + "\n", encoding="ascii")
        subprocess.run([str(args.engine.resolve()), "-m", str(args.voice.resolve()), "-r", "1.02",
                        "-fm", "-1.2", "-od", "timing.lab", "-ow", "dry.wav", "input.lab"],
                       cwd=work, check=True)
        rate, pcm = wavfile.read(work / "dry.wav")
        aligned = (work / "timing.lab").read_text(encoding="ascii").splitlines()
    dry = pcm.astype(np.float64) / 32768
    panel = sosfilt(butter(2, [270, 3900], btype="bandpass", fs=rate, output="sos"), dry)
    # The voice reaches the listener directly and returns quietly from the two hall speakers.
    def delayed(delay_ms):
        delay = round(rate * delay_ms / 1000)
        return np.pad(panel, (delay, 0))[:len(panel)]
    stereo = np.column_stack((dry * .78 + panel * .18 + delayed(27) * .09,
                              dry * .78 + panel * .18 + delayed(42) * .075))
    stereo *= .82 / np.max(np.abs(stereo))
    wavfile.write(target / "stage-testimony.wav", rate, np.rint(stereo * 32767).astype("<i2"))
    timing = mouth_track(aligned, len(dry) / rate)
    timing.tofile(target / "stage-testimony-mouth.bytes")
    print(f"{len(dry) / rate:.3f} s, {rate} Hz, {len(timing)} mouth samples")


if __name__ == "__main__":
    main()
