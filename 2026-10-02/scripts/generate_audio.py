#!/usr/bin/env python3
"""BLACK RELAY original procedural sound pack.

Requires Python >= 3.10 and NumPy. No recordings, downloads or sample libraries.
Run from any directory: python scripts/generate_audio.py
Validate shipped files: python scripts/generate_audio.py --check
Make a development-only listening reel: python scripts/generate_audio.py --preview

Stable seeds, explicit sample rate and PCM conversion make assets reproducible.
Project ownership/license applies to the script and synthesized original assets.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import wave

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "game/assets/audio"
SR = 48_000
TAU = 2 * np.pi
SEED = 0xB1AC2026


def timeline(seconds: float) -> np.ndarray:
    return np.arange(round(seconds * SR), dtype=np.float64) / SR


def db(value: float) -> float:
    return round(20 * math.log10(max(float(value), 1e-12)), 4)


def amp(decibels: float) -> float:
    return 10 ** (decibels / 20)


def filtered_noise(n: int, seed: int, low: float, high: float, tilt: float = 0) -> np.ndarray:
    """FFT-periodic, smooth bandlimited stochastic texture, with unit RMS."""
    rng = np.random.default_rng(SEED + seed)
    bins = np.fft.rfftfreq(n, 1 / SR)
    response = np.ones_like(bins)
    if low:
        response *= (bins / np.maximum(bins, low)) ** 4
    if high:
        response /= np.sqrt(1 + (bins / high) ** 12)
    response *= np.maximum(bins, 30) ** tilt
    response[0] = 0
    result = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * response, n=n)
    return result / max(np.sqrt(np.mean(result**2)), 1e-12)


def envelope(t: np.ndarray, attack: float = 0.002, decay: float = 0.1) -> np.ndarray:
    return (1 - np.exp(-t / max(attack, 1 / SR))) * np.exp(-t / decay)


def fades(data: np.ndarray, attack: float = 0.001, release: float = 0.015) -> np.ndarray:
    result = data.copy()
    a, r = min(round(attack * SR), len(result)), min(round(release * SR), len(result))
    if a:
        result[:a] *= (np.sin(np.linspace(0, np.pi / 2, a)) ** 2).reshape((-1,) + (1,) * (result.ndim - 1))
    if r:
        result[-r:] *= (np.cos(np.linspace(0, np.pi / 2, r)) ** 2).reshape((-1,) + (1,) * (result.ndim - 1))
    result[0] = result[-1] = 0
    return result


def resonator(t: np.ndarray, base: float, decay: float, brightness: float = 1, phase: float = 0) -> np.ndarray:
    """Inharmonic ceramic/cable object. Its mode ratios are a project timbre."""
    result = np.zeros_like(t)
    for k, (ratio, weight) in enumerate(((1, 1), (1.487, .48), (2.173, .25), (3.731, .11))):
        result += weight * brightness**k * np.sin(TAU * base * ratio * t + phase) * np.exp(-t / (decay / (1 + k * .7)))
    return result * (1 - np.exp(-t / .0012))


def sweep(t: np.ndarray, start: float, end: float, tau: float, harmonics: float = .18) -> np.ndarray:
    frequency = end + (start - end) * np.exp(-t / tau)
    phase = TAU * np.cumsum(frequency) / SR
    return np.sin(phase) + harmonics * np.sin(phase * 2.03) + harmonics * .25 * np.sin(phase * 4.11)


def add_at(destination: np.ndarray, source: np.ndarray, seconds: float, gain: float = 1, circular: bool = False) -> None:
    start = round(seconds * SR)
    if circular:
        indices = (start + np.arange(len(source))) % len(destination)
        np.add.at(destination, indices, source * gain)
    else:
        count = min(len(source), len(destination) - start)
        if count > 0:
            destination[start:start + count] += source[:count] * gain


def room(data: np.ndarray, amount: float = .15) -> np.ndarray:
    result = data.copy()
    for delay, gain in ((.031, 1), (.053, .72), (.089, .43), (.137, .23)):
        n = round(delay * SR)
        if n < len(data):
            result[n:] += data[:-n] * gain * amount
    return result


def finalize(data: np.ndarray, peak_db: float, loop: bool = False) -> np.ndarray:
    result = np.asarray(data, dtype=np.float64)
    result -= np.mean(result, axis=0)
    if not loop:
        result = fades(result)
    result *= amp(peak_db) / max(np.max(np.abs(result)), 1e-12)
    return result


def typing(variant: int) -> np.ndarray:
    t = timeline(.095)
    pitch = (1, .948, 1.062, 1.018)[variant]
    # The low key-bed thock, ceramic keycap, filtered friction and tiny return
    # click have different decays. There is no persistent oscillator/beep.
    result = .72 * sweep(t, 215 * pitch, 151 * pitch, .012, .08) * envelope(t, .0012, .018)
    result += .14 * resonator(t, 910 * pitch, .010, .6)
    result += .18 * filtered_noise(len(t), 10 + variant, 400, 3400) * envelope(t, .0008, .007)
    return_t = timeline(.050)
    return_click = .06 * filtered_noise(len(return_t), 20 + variant, 700, 2400) * envelope(return_t, .001, .007)
    add_at(result, return_click, .026 + variant * .001)
    return finalize(result, (-18.5, -18.8, -18.3, -18.6)[variant])


def confirm() -> np.ndarray:
    t = timeline(.48)
    result = .7 * resonator(t, 324, .1, .5)
    tt = timeline(.36)
    add_at(result, resonator(tt, 486, .13, .5), .055, .55)
    result += .055 * filtered_noise(len(t), 30, 400, 2700) * envelope(t, .001, .018)
    return finalize(room(result, .12), -14)


def error() -> np.ndarray:
    t = timeline(.13)
    result = .6 * resonator(t, 171, .022, .3)
    result += .24 * filtered_noise(len(t), 31, 330, 1200) * envelope(t, .002, .020)
    return finalize(result, -20)


def cut() -> np.ndarray:
    t = timeline(.48)
    shear = filtered_noise(len(t), 40, 640, 4200)
    result = .46 * shear * envelope(t, .0015, .050)
    result += .74 * sweep(t, 265, 106, .023) * envelope(t, .001, .064)
    result += .22 * resonator(t, 740, .074, .85)
    result += .10 * resonator(t, 1150, .055, .6)
    return finalize(room(result, .13), -10)


def purge() -> np.ndarray:
    t = timeline(1.65)
    # Instant relay impact gives input feedback; the wide valve release follows.
    result = .6 * sweep(t, 244, 97, .060, .12) * envelope(t, .001, .11)
    release = (1 - np.exp(-t / .028)) * np.exp(-t / .29)
    result += .55 * filtered_noise(len(t), 50, 120, 2900, -.25) * release
    result += .2 * resonator(t, 287, .25, .7)
    for offset, pitch, gain in ((.034, 712, .13), (.090, 510, .10), (.175, 392, .075)):
        add_at(result, resonator(timeline(.60), pitch, .12, .7), offset, gain)
    return finalize(room(result, .24), -9)


def kill() -> np.ndarray:
    t = timeline(.78)
    result = .35 * sweep(t, 310, 102, .065) * envelope(t, .002, .105)
    result += .21 * filtered_noise(len(t), 60, 500, 3600) * envelope(t, .001, .028)
    # Small, irregular, descending ceramic shards: recognizable and unobtrusive.
    for offset, pitch, gain in ((.012, 1543, .15), (.064, 1121, .14), (.119, 938, .10), (.204, 718, .07), (.301, 554, .045)):
        add_at(result, resonator(timeline(.35), pitch, .044, .5), offset, gain)
    return finalize(room(result, .12), -12)


def attack() -> np.ndarray:
    t = timeline(.67)
    air = filtered_noise(len(t), 70, 140, 1750, -.25)
    tension = np.minimum(t / .09, 1) * np.exp(-t / .14)
    result = .34 * air * tension
    cable = sweep(t, 170, 360, .17, .28)
    result += .32 * cable * envelope(t, .011, .16) * (.72 + .28 * np.sin(TAU * 22 * t))
    result += .15 * resonator(t, 262, .09, .6)
    return finalize(room(result, .16), -13)


def hurt() -> np.ndarray:
    t = timeline(.58)
    result = .58 * sweep(t, 239, 89, .042, .17) * envelope(t, .001, .11)
    texture = filtered_noise(len(t), 80, 200, 2050)
    result += .24 * texture * envelope(t, .001, .070)
    result += .13 * resonator(t, 421, .070, .6)
    add_at(result, texture[:round(SR * .16)] * envelope(t[:round(SR * .16)], .002, .03), .091, .08)
    return finalize(room(result, .10), -11)


def boss() -> np.ndarray:
    t = timeline(2.9)
    result = np.zeros_like(t)
    # Three unequal power-coupling strikes, not an emergency siren.
    for offset, base, gain in ((0, 116, .82), (.36, 123, .55), (.93, 103, .62)):
        tt = timeline(1.8)
        strike = sweep(tt, base * 1.95, base, .11, .32) * envelope(tt, .004, .36)
        strike += .22 * resonator(tt, base * 3.13, .28, .7)
        add_at(result, strike, offset, gain)
    result += .15 * filtered_noise(len(t), 90, 130, 1300, -.4) * envelope(t, .022, .7)
    result += .055 * resonator(t, 811, .6, .5)
    return finalize(room(result, .22), -11)


def transition() -> np.ndarray:
    t = timeline(1.6)
    result = .15 * filtered_noise(len(t), 100, 420, 2100, -.2) * envelope(t, .06, .27)
    for offset, freq, gain in ((0, 216, .45), (.13, 324, .35), (.31, 432, .30)):
        add_at(result, resonator(timeline(1.0), freq, .19, .45), offset, gain)
    result += .13 * sweep(t, 104, 174, .3, .1) * envelope(t, .008, .26)
    return finalize(room(result, .21), -15)


def victory() -> np.ndarray:
    t = timeline(3.6)
    result = np.zeros_like(t)
    # Original short release motif. A changed material, not a borrowed tune.
    for offset, pitch, gain in ((0, 261.626, .52), (.23, 391.995, .41), (.60, 523.251, .35), (1.03, 587.330, .20), (1.22, 523.251, .33)):
        tt = timeline(2.35)
        note = resonator(tt, pitch, .41, .32)
        note += .17 * np.sin(TAU * pitch / 2 * tt) * envelope(tt, .025, .53)
        add_at(result, note, offset, gain)
    result += .014 * filtered_noise(len(t), 110, 250, 1800, -.3) * envelope(t, .15, .65)
    return finalize(room(result, .24), -14)


def defeat() -> np.ndarray:
    t = timeline(2.0)
    result = .45 * sweep(t, 246, 99, .38, .18) * envelope(t, .01, .4)
    result += .12 * filtered_noise(len(t), 120, 140, 1600, -.2) * envelope(t, .004, .32)
    add_at(result, resonator(timeline(1.2), 146, .28, .36), .25, .26)
    return finalize(room(result, .20), -15)


def ambience() -> np.ndarray:
    t = timeline(20)
    n = len(t)
    channels = []
    shared_rain = filtered_noise(n, 198, 650, 4400, -.08)
    shared_city = filtered_noise(n, 199, 95, 520, -.45)
    for ch in range(2):
        # Rain over a wet street, soft wind between buildings and distant road
        # wash. The low urban hum is noise, never a machinery/siren oscillator.
        # FFT textures, integer-cycle modulation and circular drops are periodic.
        rain = .066 * (.55 * shared_rain + .84 * filtered_noise(n, 200 + ch, 650, 4400, -.08))
        rain *= .88 + .12 * np.sin(TAU * .1 * t + ch * .7)
        pavement = .030 * filtered_noise(n, 210 + ch, 220, 1350, -.15)
        drizzle = .018 * filtered_noise(n, 220 + ch, 1800, 4800, -.1)
        gust = .018 * filtered_noise(n, 224 + ch, 170, 950, -.3)
        gust *= .48 + .52 * np.sin(TAU * .05 * t + .7 + ch * .2) ** 2
        city = .016 * (.75 * shared_city + .45 * filtered_noise(n, 226 + ch, 95, 520, -.45))
        city *= .82 + .18 * np.sin(TAU * .05 * t + 2.1)
        channel = rain + pavement + drizzle + gust + city
        rng = np.random.default_rng(SEED + 230 + ch)
        for index, when in enumerate((.93, 2.67, 5.14, 7.53, 10.21, 13.48, 16.17, 18.86, 19.94)):
            tt = timeline(.21)
            base = rng.uniform(510, 920)
            drop = .40 * sweep(tt, base, base * .45, .008, .06) * envelope(tt, .0008, .018)
            drop += .60 * filtered_noise(len(tt), 240 + ch * 16 + index, 720, 3800, -.15) * envelope(tt, .001, .032)
            add_at(channel, fades(drop, .0008, .025), when + ch * .079, rng.uniform(.007, .016), circular=True)
        channels.append(channel)
    result = np.column_stack(channels)
    return finalize(result, -15, loop=True)


DESCRIPTIONS = {
    "ambience": "Wet city at night: rain on asphalt, scattered drain/ledge drips, soft wind between buildings and distant non-tonal road wash. No machinery oscillator or periodic alarm. Seamless 20-second stereo loop.",
    "typing_01": "Short ceramic keycap / felt key-bed / quiet key-return, variation 1.",
    "typing_02": "Short ceramic keycap / felt key-bed / quiet key-return, variation 2.",
    "typing_03": "Short ceramic keycap / felt key-bed / quiet key-return, variation 3.",
    "typing_04": "Short ceramic keycap / felt key-bed / quiet key-return, variation 4.",
    "confirm": "Two compact upward resonant relay clicks: accepted menu choice or confirmed lock.",
    "error": "Very quiet hollow key rejection, optional wrong-letter feedback.",
    "cut": "Fast cable shear, short pressure punch and ceramic ring, CUT command.",
    "purge": "Instant relay hit followed by broad valve-pressure release, PURGE command.",
    "kill": "Cable power-down and irregular cascading ceramic shards, enemy eliminated.",
    "attack": "Rising cable strain / breathy mechanical rush, enemy attack telegraph.",
    "hurt": "Damped system shock and short textured interruption, player damaged.",
    "boss": "Three unequal industrial power-coupling strikes, boss arrival/phase entrance.",
    "transition": "Warm ascending relay handover, stage transition.",
    "victory": "Original restrained five-note release motif with ceramic/soft harmonic tail.",
    "defeat": "Falling relay power with a restrained final coupling tone, optional end-state.",
}


def write_wav(path: Path, data: np.ndarray) -> None:
    pcm = np.rint(np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1 if data.ndim == 1 else data.shape[1])
        stream.setsampwidth(2)
        stream.setframerate(SR)
        stream.writeframes(pcm.tobytes())


def read_wav(path: Path) -> tuple[np.ndarray, dict]:
    with wave.open(str(path), "rb") as stream:
        metadata = dict(sample_rate=stream.getframerate(), channels=stream.getnchannels(), sample_width=stream.getsampwidth(), frames=stream.getnframes())
        data = np.frombuffer(stream.readframes(stream.getnframes()), dtype="<i2").astype(np.float64) / 32768
    if metadata["channels"] > 1:
        data = data.reshape(-1, metadata["channels"])
    return data, metadata


def inspect_file(path: Path) -> dict:
    data, info = read_wav(path)
    mono = data if data.ndim == 1 else np.mean(data, axis=1)
    power = np.abs(np.fft.rfft(mono)) ** 2
    bins = np.fft.rfftfreq(len(mono), 1 / info["sample_rate"])
    total = max(float(np.sum(power)), 1e-20)
    active = np.flatnonzero(np.max(np.abs(data), axis=1) > .001 if data.ndim == 2 else np.abs(data) > .001)
    info.update(
        duration_seconds=round(len(data) / info["sample_rate"], 6),
        peak_dbfs=db(np.max(np.abs(data))),
        rms_dbfs=db(np.sqrt(np.mean(data**2))),
        dc_offset=float(np.max(np.abs(np.mean(data, axis=0)))),
        below_50hz_energy_fraction=round(float(np.sum(power[bins < 50]) / total), 7),
        above_8000hz_energy_fraction=round(float(np.sum(power[bins > 8000]) / total), 7),
        onset_ms=round(float(active[0] / info["sample_rate"] * 1000), 3) if len(active) else None,
        bytes=path.stat().st_size,
        sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        looping=path.stem == "ambience",
        description=DESCRIPTIONS[path.stem],
    )
    if info["looping"]:
        step = np.abs(np.diff(data, axis=0))
        seam_step = np.abs(data[0] - data[-1])
        # A seamless waveform need not have equal adjacent samples. Its seam
        # should behave like an ordinary sample step, not an inserted jump.
        info.update(loop_begin_frame=0, loop_end_frame_exclusive=len(data),
                    seam_max_step=float(np.max(seam_step)),
                    interior_step_p99=float(np.quantile(step, .99)),
                    seam_vs_p99_ratio=round(float(np.max(seam_step) / np.quantile(step, .99)), 5),
                    stereo_correlation=round(float(np.corrcoef(data.T)[0, 1]), 5))
    else:
        info["first_last_sample_max"] = float(max(np.max(np.abs(data[0])), np.max(np.abs(data[-1]))))
    return info


def validate(output: Path) -> dict:
    checked = {name + ".wav": inspect_file(output / (name + ".wav")) for name in DESCRIPTIONS}
    errors = []
    for name, info in checked.items():
        if info["sample_rate"] != SR or info["sample_width"] != 2:
            errors.append(f"{name}: unexpected format")
        if info["channels"] != (2 if info["looping"] else 1):
            errors.append(f"{name}: unexpected channels")
        if info["peak_dbfs"] > -8.9 or info["peak_dbfs"] < -24:
            errors.append(f"{name}: peak outside intended headroom")
        if info["dc_offset"] > .001:
            errors.append(f"{name}: too much DC")
        if info["below_50hz_energy_fraction"] > .025:
            errors.append(f"{name}: excessive sub-bass")
        if info["above_8000hz_energy_fraction"] > .005:
            errors.append(f"{name}: excessive ultra-high energy")
        if info["looping"]:
            if info["seam_vs_p99_ratio"] > 1.5 or info["frames"] != SR * 20:
                errors.append(f"{name}: loop seam or duration failed")
        elif info["first_last_sample_max"] != 0:
            errors.append(f"{name}: one-shot endpoints must be zero")
        if name.startswith("typing") and info["onset_ms"] > 3:
            errors.append(f"{name}: typing onset delayed")
    if errors:
        raise AssertionError("\n".join(errors))
    return checked


def mix_stress_test(output: Path) -> dict:
    """Deterministic dense combat mix, not a claim about unbounded polyphony."""
    samples = {name: read_wav(output / f"{name}.wav")[0] for name in DESCRIPTIONS}
    n = SR * 12
    result = samples["ambience"][:n].copy() * amp(-4)
    for index, when in enumerate(np.arange(.05, 11.8, .05)):
        click = samples[f"typing_{(index * 3) % 4 + 1:02}"]
        add_at(result, np.column_stack((click, click)), float(when))
    events = [
        ("boss", 0), ("attack", .5), ("cut", .65), ("kill", .69),
        ("attack", 1.4), ("purge", 1.5), ("kill", 1.51), ("kill", 1.535),
        ("hurt", 1.54), ("cut", 1.56), ("kill", 1.57),
        ("attack", 3), ("hurt", 3.08), ("error", 3.15),
        ("purge", 4.4), ("kill", 4.41), ("cut", 5.4), ("kill", 5.44),
        ("transition", 6.5), ("boss", 7.3), ("attack", 7.7),
        ("purge", 8), ("kill", 8.01), ("kill", 8.025), ("victory", 8.1),
    ]
    for name, when in events:
        value = samples[name]
        add_at(result, np.column_stack((value, value)), when)
    result *= amp(-3)
    peak = np.max(np.abs(result))
    assert peak < amp(-3), f"Dense combat mix exceeds -3dBFS headroom: {db(peak)}dBFS"
    return dict(duration_seconds=12, typing_characters_per_second=20,
                additional_event_count=len(events), master_db=-3, ambience_db=-4,
                peak_dbfs=db(peak), rms_dbfs=db(np.sqrt(np.mean(result**2))),
                clip_count=int(np.sum(np.abs(result) >= 1)),
                note="Synthetic worst-plausible overlap test; actual game mix/panning still needs runtime review.")


def preview(output: Path) -> Path:
    """Listening reel and timestamps stay outside Godot's exported assets."""
    pieces = []
    labels = []
    cursor = 0.0
    for name in DESCRIPTIONS:
        data, _ = read_wav(output / f"{name}.wav")
        if data.ndim == 1:
            data = np.column_stack((data, data))
        if name == "ambience":
            # Put the actual loop seam in this audition excerpt.
            data = np.concatenate((data[-SR * 3:], data[:SR * 3]))
        if name.startswith("typing"):
            click = data
            data = np.zeros((round(SR * .9), 2))
            for offset in (0, .13, .27, .40, .54, .68):
                add_at(data, click, offset)
        labels.append(f"{cursor:05.2f}s  {name}")
        pieces.extend((data, np.zeros((SR // 2, 2))))
        cursor += len(data) / SR + .5
    path = ROOT / "builds/audio_preview.wav"
    path.parent.mkdir(exist_ok=True)
    write_wav(path, np.concatenate(pieces))
    path.with_suffix(".txt").write_text("BLACK RELAY audio audition reel\n" + "\n".join(labels) + "\n", encoding="utf-8")
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate existing assets without changing them")
    parser.add_argument("--preview", action="store_true", help="Also create a developer listening reel outside game/")
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    if not args.check:
        args.output.mkdir(parents=True, exist_ok=True)
        generators = {"ambience": ambience, **{f"typing_{k+1:02}": (lambda v=k: typing(v)) for k in range(4)},
                      "confirm": confirm, "error": error, "cut": cut, "purge": purge, "kill": kill,
                      "attack": attack, "hurt": hurt, "boss": boss, "transition": transition,
                      "victory": victory, "defeat": defeat}
        for name, generate in generators.items():
            write_wav(args.output / f"{name}.wav", generate())
    checked = validate(args.output)
    stress = mix_stress_test(args.output)
    if args.check:
        manifest_path = args.output / "audio_manifest.json"
        if manifest_path.exists():
            saved = json.loads(manifest_path.read_text(encoding="utf-8"))
            for name, info in checked.items():
                assert saved["assets"][name]["sha256"] == info["sha256"], f"{name}: checksum differs from audio manifest"
    manifest = dict(project="BLACK RELAY / 黒の中継局", format="48kHz PCM16 WAV", generation="Original deterministic NumPy DSP; no external samples, melodies, audio downloads or AI audio-service assets.",
                    seed=SEED, license_record="ORIGINAL_AUDIO_LICENSE.txt", subjective_listening="Not claimed. Objective DSP/format/loop checks are reproducible; final speaker/headphone mix requires in-game audition.",
                    recommended_bus_db=dict(master=-3, sfx=0, typing=0, ambience=-4),
                    total_bytes=sum(v["bytes"] for v in checked.values()), mix_stress_test=stress, assets=checked)
    if not args.check:
        (args.output / "audio_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for name, info in checked.items():
        print(f"{name:18} {info['duration_seconds']:5.2f}s {info['channels']}ch peak={info['peak_dbfs']:6.2f}dBFS rms={info['rms_dbfs']:6.2f}dBFS onset={info['onset_ms']:5.2f}ms")
    print(f"PASS: {len(checked)} assets; {manifest['total_bytes'] / 1024**2:.2f} MiB; format, headroom, DC, spectral limits, onset and loop seam")
    print(f"PASS: Dense 20-characters/sec combat stress mix; peak={stress['peak_dbfs']:.2f}dBFS; clips={stress['clip_count']}")
    if args.preview:
        print(f"Preview: {preview(args.output)}")


if __name__ == "__main__":
    main()
