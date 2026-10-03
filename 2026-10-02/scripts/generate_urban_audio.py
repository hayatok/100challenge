#!/usr/bin/env python3
"""Original wet-city zombie Foley extension for BLACK RELAY.

Generate: python scripts/generate_urban_audio.py
Check:    python scripts/generate_urban_audio.py --check
Requires Python 3.10+ and NumPy; imports the original audio pack's DSP/checks.
The optional licensed-gunshot mix check uses ffmpeg when it is installed.
Never modifies the licensed sounds, original typing cues, or Godot imports.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess

import numpy as np

import generate_audio as original


DESCRIPTIONS = {
    "zombie_breath": "Original nonverbal low throat groan with a raspy wet exhalation; no recorded voice, dialogue or recognizable speech.",
    "footstep_wet": "Original compact rubber/boot sole contact, damp asphalt thud and restrained shallow-puddle splash.",
}


def zombie_breath() -> np.ndarray:
    t = original.timeline(1.05)
    # Unsteady glottal pulses with broad vocal formants, not a pitched alert or
    # intelligible synthetic word. The noisy first breath keeps onset readable.
    frequency = 83 + 17 * np.sin(np.pi * t / 1.05) + 2.8 * np.sin(original.TAU * 6.3 * t)
    phase = original.TAU * np.cumsum(frequency) / original.SR
    throat = np.zeros_like(t)
    for harmonic in range(1, 22):
        hz = harmonic * 91
        formants = (.70 * np.exp(-((hz - 270) / 125) ** 2)
                    + .36 * np.exp(-((hz - 660) / 215) ** 2)
                    + .16 * np.exp(-((hz - 1260) / 280) ** 2))
        throat += (.12 + formants) / harmonic * np.sin(harmonic * phase + harmonic * .21)
    pressure = np.sin(np.pi * np.minimum(t / 1.05, 1)) ** 1.25
    pressure *= .84 + .16 * np.sin(original.TAU * 7.4 * t + .4)
    rasp = original.filtered_noise(len(t), 310, 260, 2400, -.25)
    rasp *= .55 + .45 * np.sin(phase) ** 2
    breath = original.filtered_noise(len(t), 311, 430, 2700, -.22)
    result = .74 * throat * pressure + .22 * rasp * pressure
    result += .20 * breath * original.envelope(t, .008, .11)
    result += .06 * breath * np.exp(-((t - .75) / .14) ** 2)
    return original.finalize(original.room(result, .045), -16.5)


def footstep_wet() -> np.ndarray:
    t = original.timeline(.30)
    sole = original.sweep(t, 145, 95, .014, .04) * original.envelope(t, .0017, .028)
    pavement = original.filtered_noise(len(t), 320, 190, 1450, -.22)
    splash = original.filtered_noise(len(t), 321, 1050, 3800, -.1)
    result = .52 * sole + .30 * pavement * original.envelope(t, .0009, .025)
    result += .17 * splash * original.envelope(t, .0035, .042)
    # Short unequal watery flecks after the contact; no heavy trailing reverb.
    for index, (when, decay, gain) in enumerate(((.018, .024, .070), (.048, .019, .045))):
        tt = original.timeline(.13)
        fleck = original.filtered_noise(len(tt), 322 + index, 780, 3200, -.15)
        original.add_at(result, fleck * original.envelope(tt, .001, decay), when, gain)
    return original.finalize(result, -18)


def inspect_and_validate(output: Path) -> dict:
    # Reuse the original FFT, endpoint, format, DC and headroom measurements.
    existing_descriptions = original.DESCRIPTIONS.copy()
    original.DESCRIPTIONS.update(DESCRIPTIONS)
    try:
        checked = {name + ".wav": original.inspect_file(output / (name + ".wav")) for name in DESCRIPTIONS}
    finally:
        original.DESCRIPTIONS.clear()
        original.DESCRIPTIONS.update(existing_descriptions)
    for name, info in checked.items():
        assert info["sample_rate"] == original.SR and info["sample_width"] == 2, f"{name}: format"
        assert info["channels"] == 1, f"{name}: expected mono"
        assert -24 <= info["peak_dbfs"] <= -8.9, f"{name}: peak headroom"
        assert info["dc_offset"] <= .001, f"{name}: DC"
        assert info["below_50hz_energy_fraction"] <= .025, f"{name}: sub-bass"
        assert info["above_8000hz_energy_fraction"] <= .005, f"{name}: ultra-high energy"
        assert info["first_last_sample_max"] == 0, f"{name}: endpoint discontinuity"
    return checked


def decode_licensed(path: Path) -> np.ndarray:
    completed = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f64le", "-acodec", "pcm_f64le",
         "-ar", str(original.SR), "-ac", "2", "pipe:1"],
        check=True, capture_output=True,
    )
    return np.frombuffer(completed.stdout, dtype="<f8").reshape(-1, 2)


def city_mix_stress_test(output: Path) -> dict:
    """Dense firing plus typed feedback, restrained Foley and no forced limiter."""
    if not shutil.which("ffmpeg") or not (output / "shot.mp3").exists() or not (output / "impact_body.ogg").exists():
        return dict(performed=False, note="Requires installed ffmpeg and the separately licensed shot.mp3/impact_body.ogg.")
    sources = {name: original.read_wav(output / f"{name}.wav")[0]
               for name in ("ambience", "zombie_breath", "footstep_wet", "hurt", "kill", "cut",
                            "error", "confirm", "typing_01", "typing_02", "typing_03", "typing_04")}
    sources["shot"] = decode_licensed(output / "shot.mp3")
    sources["impact_body"] = decode_licensed(output / "impact_body.ogg")
    gains = dict(ambience=-6, typing=-3, shot=-5, impact_body=-9, kill=-12,
                 zombie_breath=-6, footstep_wet=-8, hurt=-1, cut=-1, error=0, confirm=-6)
    result = sources["ambience"][:original.SR * 12].copy() * original.amp(gains["ambience"])

    def event(name: str, when: float, gain: float | None = None) -> None:
        value = sources[name]
        if value.ndim == 1:
            value = np.column_stack((value, value))
        original.add_at(result, value, when, original.amp(gains[name] if gain is None else gain))

    for index, when in enumerate(np.arange(.05, 11.8, .05)):
        event(f"typing_{index % 4 + 1:02}", float(when), gains["typing"])
    for when in np.arange(.30, 11.5, .60):
        for name in ("shot", "impact_body", "kill"):
            event(name, float(when))
    for when in (1.1, 3.8, 6.4, 9.6):
        event("zombie_breath", when)
    for when in (.3, 1.6, 2.9, 4.2, 5.5, 6.8, 8.1, 9.4, 10.7):
        event("footstep_wet", when)
    for name, when in (("hurt", .30), ("cut", .9), ("error", 3.1), ("confirm", 5.1),
                       ("hurt", 7.5), ("cut", 8.7)):
        event(name, when)
    result *= original.amp(-3)
    peak = float(np.max(np.abs(result)))
    assert peak < original.amp(-3), f"City mix lacks -3 dBFS headroom: {original.db(peak)} dBFS"
    return dict(performed=True, duration_seconds=12, master_db=-3,
                typing_characters_per_second=20, shots=19,
                peak_dbfs=original.db(peak), rms_dbfs=original.db(np.sqrt(np.mean(result ** 2))),
                clip_count=int(np.sum(np.abs(result) >= 1)), playback_gains_db=gains,
                note="Deterministic synthetic overlap including decoded licensed sounds. Does not establish subjective comfort or unbounded-polyphony safety.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--output", type=Path, default=original.OUTPUT)
    args = parser.parse_args()
    if not args.check:
        args.output.mkdir(parents=True, exist_ok=True)
        for name, generate in (("zombie_breath", zombie_breath), ("footstep_wet", footstep_wet)):
            original.write_wav(args.output / f"{name}.wav", generate())
    checked = inspect_and_validate(args.output)
    stress = city_mix_stress_test(args.output)
    manifest_path = args.output / "urban_audio_manifest.json"
    if args.check and manifest_path.exists():
        saved = json.loads(manifest_path.read_text(encoding="utf-8"))
        for name, info in checked.items():
            assert saved["assets"][name]["sha256"] == info["sha256"], f"{name}: checksum"
    manifest = dict(project="BLACK RELAY wet-city zombie slice", format="48kHz PCM16 mono WAV",
                    generation="Original deterministic NumPy DSP. No voice recordings, dialogue, external samples or melodies.",
                    license_record="ORIGINAL_AUDIO_LICENSE.txt", seed=original.SEED,
                    assets=checked, city_mix_stress_test=stress,
                    subjective_listening="Not claimed; final in-game speaker/headphone audition is required.")
    if not args.check:
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    for name, info in checked.items():
        print(f"{name:20} {info['duration_seconds']:.2f}s peak={info['peak_dbfs']:.2f}dBFS rms={info['rms_dbfs']:.2f}dBFS")
    print(f"PASS: {len(checked)} original city Foley assets; format, headroom, endpoints, DC and spectral limits")
    print("City mix: " + json.dumps(stress))


if __name__ == "__main__":
    main()
