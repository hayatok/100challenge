"""Original Tideglass score and foley. Standard-library, deterministic offline synth.

Run this file to rebuild committed WAVs. No recordings, external samples or API.
Music uses an eight-bar 96 BPM D-major phrase; notes crossing the loop boundary
are wrapped into the start, preserving their decays without a seam fade/pause.
"""
from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import wave

ROOT = Path(__file__).resolve().parent
RATE = 22050
BEAT = 60 / 96
LENGTH = 32 * BEAT
TAU = math.tau
metrics = {}


def empty(seconds):
    return array('d', [0.0]) * round(seconds * RATE)


def note(out, start, duration, midi, gain, voice='pluck', wrap=False):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    count = round(duration * RATE)
    offset = round(start * RATE)
    for i in range(count):
        at = offset + i
        if at >= len(out):
            if not wrap:
                break
            at %= len(out)
        t = i / RATE
        end = max(0.0, min(1.0, (duration - t) / 0.06))
        phase = TAU * frequency * t
        if voice == 'pad':
            env = min(1.0, t / 0.32) * min(1.0, (duration - t) / 0.55)
            sample = math.sin(phase) * 0.72 + math.sin(phase * 2) * 0.16
        elif voice == 'bass':
            env = min(1.0, t / 0.015) * math.exp(-t * 3.2) * end
            sample = math.sin(phase) + math.sin(phase * 2) * 0.12
        elif voice == 'bell':
            env = min(1.0, t / 0.006) * math.exp(-t * 4.3) * end
            sample = math.sin(phase) * 0.7 + math.sin(phase * 2.997) * 0.22 * math.exp(-t * 7)
        else:
            env = min(1.0, t / 0.004) * math.exp(-t * 5) * end
            sample = math.sin(phase) * 0.76 + math.sin(phase * 2) * 0.2 * math.exp(-t * 10) + math.sin(phase * 3) * 0.09 * math.exp(-t * 15)
        out[at] += sample * env * gain


def noise(out, start, duration, gain, low=0.5, thump=0.0, seed=23):
    rng = random.Random(seed)
    state = 0.0
    offset = round(start * RATE)
    for i in range(round(duration * RATE)):
        at = offset + i
        if at >= len(out):
            break
        t = i / RATE
        state = state * low + rng.uniform(-1, 1) * (1 - low)
        env = min(1.0, t / 0.004) * math.exp(-t * (7 / duration))
        out[at] += (state + math.sin(TAU * (110 * t - 45 * t * t)) * thump) * env * gain


def save(name, samples):
    peak = max(abs(x) for x in samples)
    assert peak < 0.95, (name, peak)
    pcm = array('h', (round(x * 32767) for x in samples))
    path = ROOT / f'{name}.wav'
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    rms = math.sqrt(sum(x*x for x in samples) / len(samples))
    metrics[name] = {'seconds': round(len(samples)/RATE, 4), 'peak_dbfs': round(20*math.log10(max(peak, 1e-9)), 2), 'rms_dbfs': round(20*math.log10(max(rms, 1e-9)), 2), 'boundary_delta': round(abs(samples[-1] - samples[0]), 7), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def score():
    bed, tune, pulse, danger = [empty(LENGTH) for _ in range(4)]
    chords = [(50, 54, 57), (45, 49, 52), (47, 50, 54), (43, 47, 50), (50, 54, 57), (42, 45, 49), (43, 47, 50), (45, 49, 52)]
    melody = [[74, 78, 81, 78, 76], [73, 76, 81, 76], [74, 78, 81, 83, 81], [79, 78, 74, 71], [74, 78, 81, 86, 81], [78, 76, 73, 69], [71, 74, 79, 78, 76], [73, 76, 81, 76, 73]]
    for bar, chord in enumerate(chords):
        start = bar * 4 * BEAT
        for pitch in chord:
            note(bed, start, 4.3 * BEAT, pitch + 12, 0.035, 'pad', True)
        for beat in (0, 2):
            note(bed, start + beat * BEAT, 0.8, chord[0] - 12, 0.11, 'bass', True)
        for index, pitch in enumerate(melody[bar]):
            timing = [0, 0.75, 1.5, 2.5, 3.25][index]
            note(tune, start + timing * BEAT, 1.0, pitch, 0.18 if index == 0 else 0.13, 'pluck', True)
            # A soft octave echo supplies space without a runtime reverb.
            note(tune, start + (timing + 0.5) * BEAT, 0.8, pitch, 0.024, 'bell', True)
        for beat in range(4):
            noise(pulse, start + beat * BEAT, 0.11, 0.11 if beat % 2 else 0.15, 0.3, 0.5 if beat % 2 == 0 else 0.1, bar * 10 + beat)
            note(danger, start + beat * BEAT, 0.28, chord[0], 0.10, 'bass', True)
            if beat % 2:
                note(danger, start + (beat + 0.5) * BEAT, 0.16, chord[0] + 12, 0.055, 'bell', True)
    for name, samples in zip(['music_bed', 'music_melody', 'music_pulse', 'music_tide'], [bed, tune, pulse, danger]):
        save(name, samples)


def effects():
    for take in range(3):
        out = empty(0.22)
        noise(out, 0, 0.14, 0.52, 0.6, 0.4, 120 + take)
        noise(out, 0.045, 0.14, 0.18, 0.87, 0, 321 + take)
        save(f'step_{take}', out)
    for name, seconds in [('click', 0.14), ('attack', 0.38), ('hurt', 0.4), ('loot', 0.88), ('use', 0.72), ('tide', 1.65), ('extract', 1.95), ('death', 1.8), ('repair', 1.4), ('depart', 0.94)]:
        out = empty(seconds)
        if name == 'click':
            note(out, 0, 0.12, 86, 0.38, 'pluck')
            noise(out, 0, 0.035, 0.22, 0.2)
        elif name == 'attack':
            noise(out, 0, 0.25, 0.48, 0.25, 0)
            noise(out, 0.065, 0.25, 0.72, 0.78, 0.72)
        elif name == 'hurt':
            noise(out, 0, 0.35, 0.65, 0.8, 0.9)
            note(out, 0, 0.22, 45, 0.15, 'bass')
        elif name == 'tide':
            rng = random.Random(992)
            filtered = 0.0
            for i in range(len(out)):
                t = i / RATE
                filtered = filtered * 0.88 + rng.uniform(-1, 1) * 0.12
                out[i] += filtered * math.sin(math.pi * t / seconds)**2 * 0.6
            for j, midi in enumerate([62, 69, 74]):
                note(out, 0.2 + j*0.22, 0.9, midi, 0.15, 'bell')
        else:
            notes = {'loot': [81, 86, 90], 'use': [69, 74, 78], 'extract': [62, 66, 69, 74, 78, 81, 86], 'death': [62, 57, 54, 50], 'repair': [74, 78, 81, 86, 90], 'depart': [62, 69, 74, 78]}[name]
            gap = 0.16 if name in ['extract', 'death', 'repair'] else 0.115
            for j, midi in enumerate(notes):
                note(out, j*gap, min(0.75, seconds-j*gap), midi, 0.29 if j == len(notes)-1 else 0.22, 'bell' if name != 'death' else 'pluck')
        save(name, out)


def sea():
    # Integer-period bands give a seamless, non-drifting loop without a hard cut.
    out = empty(8)
    rng = random.Random(2710)
    bands = [(rng.randint(320, 7000), rng.random()*TAU, rng.uniform(0.002, 0.005)) for _ in range(90)]
    for i in range(len(out)):
        t = i / RATE
        swell = 0.65 + 0.3*math.sin(TAU*t/8) + 0.05*math.sin(TAU*t/2)
        out[i] = sum(math.sin(TAU*cycles*t/8 + phase)*gain for cycles, phase, gain in bands) * swell
    save('sea', out)


if __name__ == '__main__':
    score()
    effects()
    sea()
    (ROOT/'manifest.json').write_text(json.dumps({'title': 'Sunlit Tideglass', 'authoring': 'Original deterministic additive/filtered-noise synthesis by Codex for SHIOGAERI. No external recordings or samples.', 'license': 'Project-original audio; same repository use as the game.', 'music': {'bpm': 96, 'key': 'D major', 'bars': 8, 'loop_seconds': LENGTH}, 'sample_rate': RATE, 'channels': 1, 'encoding': 'PCM signed 16-bit', 'metrics': metrics, 'verification_limits': 'Peak/RMS and boundary delta are technical metrics, not LUFS or human listening approval.'}, indent=2)+'\n')
