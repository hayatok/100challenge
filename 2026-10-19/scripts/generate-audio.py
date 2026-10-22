from pathlib import Path
import math, wave, struct, random, hashlib, json

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
SCORES = [
    ('garden', 64, [50, 57, 62, 65, 53, 60, 65, 69], [74, 77, 81, 79, 77, 74, 72, 69]),
    ('mirror', 78, [47, 54, 59, 62, 50, 57, 62, 66], [78, 74, 71, 73, 78, 81, 78, 74]),
    ('bell', 88, [48, 55, 60, 64, 53, 60, 65, 69], [76, 79, 83, 84, 83, 79, 76, 72]),
    ('boss', 104, [38, 45, 50, 53, 41, 48, 53, 57], [74, 77, 76, 73, 74, 81, 77, 76]),
]

def freq(note): return 440 * 2 ** ((note - 69) / 12)

def make_theme(name, bpm, harmony, melody):
    beat = 60 / bpm
    duration = beat * 32
    count = round(RATE * duration)
    left = [0.0] * count
    right = [0.0] * count
    def note(start, midi, seconds, gain, pan=0.0, voice='bell'):
        f = freq(midi)
        for j in range(round(seconds * RATE)):
            t = j / RATE
            if voice == 'bell':
                env = min(1, t * 120) * math.exp(-t * 2.4)
                x = (math.sin(2 * math.pi * f * t) + .24 * math.sin(2 * math.pi * f * 2.01 * t) * math.exp(-t * 3) + .07 * math.sin(2 * math.pi * f * 4 * t) * math.exp(-t * 6)) * env
            elif voice == 'pad':
                env = min(1, t * 2) * min(1, max(0, (seconds - t) * 2))
                x = (.65 * math.sin(2 * math.pi * f * t) + .18 * math.sin(2 * math.pi * f * 1.002 * t) + .08 * math.sin(2 * math.pi * f * 2 * t)) * env
            else:
                x = math.sin(2 * math.pi * (f * t - 17 * t * t)) * math.exp(-t * 16)
            k = (round(start * RATE) + j) % count
            left[k] += x * gain * (1 - pan * .45)
            right[k] += x * gain * (1 + pan * .45)
    for bar in range(8):
        root = harmony[(bar // 2) * 2]
        note(bar * beat * 4, root, beat * 4, .075, -.18, 'pad')
        note(bar * beat * 4, root + 7, beat * 4, .036, .2, 'pad')
        for step in range(8):
            at = bar * beat * 4 + step * beat / 2
            tone = harmony[(bar // 2) * 2 + step % 2] + (12 if step % 4 >= 2 else 0)
            note(at, tone, 2.4, .047 if name != 'boss' else .06, -.55 if step % 2 == 0 else .55)
        note(bar * beat * 4 + beat / 4, melody[bar], 2.8, .083, .25)
        if bar % 2:
            note(bar * beat * 4 + beat * 2.5, melody[(bar + 2) % 8], 2.4, .053, -.3)
        if name in ('bell', 'boss'):
            for b in (0, 2): note((bar * 4 + b) * beat, 31, .18, .065, 0, 'pulse')
    peak = max(max(abs(x) for x in left), max(abs(x) for x in right))
    scale = min(1, .78 / max(peak, .001))
    data = bytearray()
    for l, rr in zip(left, right): data.extend(struct.pack('<hh', round(l * scale * 32767), round(rr * scale * 32767)))
    dest = ROOT / 'game/assets/audio' / ('theme-' + name + '.wav')
    dest.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(dest), 'wb') as out:
        out.setparams((2, 2, RATE, count, 'NONE', 'not compressed')); out.writeframes(data)
    return {'file': str(dest.relative_to(ROOT)), 'bpm': bpm, 'seconds': count / RATE, 'peak': peak * scale, 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()}

if __name__ == '__main__':
    results = [make_theme(*score) for score in SCORES]
    output = ROOT / 'docs/verification/campaign/audio-source.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({'method': 'Original local deterministic PCM synthesis; 32 beats per theme; no external samples.', 'sample_rate': RATE, 'files': results}, indent=2))
    print(json.dumps(results, indent=2))
