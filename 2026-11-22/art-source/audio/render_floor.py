"""Render the two local voices and their matching 60 Hz mouth tracks."""
import argparse
from pathlib import Path
import subprocess
import tempfile

import numpy as np
import pyopenjtalk
from scipy.io import wavfile
from render_testimony import mouth_track


def render(engine, model, destination, name, script, pace, pitch):
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        labels = pyopenjtalk.extract_fullcontext(script)
        (work / "input.lab").write_text("\n".join(labels) + "\n", encoding="ascii")
        subprocess.run([str(engine), "-m", str(model), "-r", pace, "-fm", pitch, "-od", "timing.lab",
                        "-ow", "voice.wav", "input.lab"], check=True, cwd=work)
        frequency, pcm = wavfile.read(work / "voice.wav")
        timing = (work / "timing.lab").read_text(encoding="ascii").splitlines()
    signal = pcm.astype(np.float64)
    signal *= .80 * 32767 / np.max(np.abs(signal))
    wavfile.write(destination / (name + ".wav"), frequency, np.rint(signal).astype("<i2"))
    mouth_track(timing, len(signal) / frequency).tofile(destination / (name + "-mouth.bytes"))
    print(name, round(len(signal) / frequency, 3), "s")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("engine", type=Path)
    parser.add_argument("model", type=Path)
    args = parser.parse_args()
    destination = Path(__file__).resolve().parents[2] / "Game/Assets/Resources/KinseiAudio"
    render(args.engine.resolve(), args.model.resolve(), destination, "kontani-yield",
           "わかった。もうおりる。", "1.08", "-2.0")
    render(args.engine.resolve(), args.model.resolve(), destination, "ura-yield",
           "まってくれ。わしはおりる。", "1.17", "1.2")
