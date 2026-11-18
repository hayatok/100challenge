"""Render four loopable, location-specific alarm sounds for the evacuation routes."""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / 'Game/Assets/Resources/Sound'


def partials(t, frequencies, decay):
    return sum(weight * math.sin(2 * math.pi * hz * t) * math.exp(-decay * (i + 1) ** .6 * t)
               for i, (hz, weight) in enumerate(frequencies))


def bell(t, hz):
    attack = min(t * 350, 1)
    return attack * partials(t, [(hz, .5), (hz * 2.37, .29), (hz * 3.72, .19)], 6.2)


def sample(district, t):
    if district == 0:
        # A spring-driven striker against a shallow steel bell.
        return .67 * bell(t % .115, 924) * min(1, (2.4-t)*20) if t < 2.4 else 0
    if district == 1:
        beat = t % 1.6
        if beat > .73:
            return 0
        env = min(1, beat * 28, (.73-beat)*21)
        return .66 * env * sum(math.sin(2 * math.pi * h * beat) * w
                               for h,w in [(309,.42),(385,.33),(618,.15),(1155,.07)])
    if district == 2:
        # A three-note public-address call through a tinny platform speaker.
        return sum(.6 * bell(t-at, note) for at,note in [(0,698),(.36,554),(.73,831)]
                   if t >= at)
    return sum(.72 * bell(t-at, 645) for at in (0,.38,1.5,1.88) if t >= at)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for district in range(4):
        length = round(RATE * 3.2)
        pcm = bytearray()
        for i in range(length):
            t = i / RATE
            signal = sample(district, t) * min(1, (length-i)/150)
            pcm.extend(struct.pack('<h', round(max(-1, min(1, signal)) * 28000)))
        with wave.open(str(OUT / ('field_alarm_' + str(district) + '.wav')), 'wb') as clip:
            clip.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            clip.writeframes(pcm)


if __name__ == '__main__':
    main()
