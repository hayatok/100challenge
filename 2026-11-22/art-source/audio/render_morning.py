"""Render the request that Sumiko receives from Sakai. The piano reads the same score in Unity."""
import json

import numpy as np

from instruments import OUT, SR, mix, note, stats, write


def render():
    score = json.loads((OUT / 'MorningScore.json').read_text(encoding='utf8'))
    beat = 60 / score['bpm']
    bars = score['bars']
    track = np.zeros((round(len(bars) * 3 * beat * SR), 2))
    for index, bar in enumerate(bars):
        start = index * 3 * beat
        chord = bar['chord']
        mix(track, note(chord[0] - 12, 1.32, 'bass'), start, .17, -.13, True)
        for pulse in (1, 2):
            for finger, pitch in enumerate(chord):
                mix(track, note(pitch, 1.18), start + pulse * beat + finger * .012, .048, -.28, True)
        for melody in bar['melody']:
            onset = start + melody['beat'] * beat
            mix(track, note(melody['midi'], melody['beats'] * beat + .12), onset, .14, .1, True)
        if 'horn' in bar:
            pitch, offset, length = bar['horn']
            mix(track, note(pitch, length * beat, 'horn'), start + offset * beat, .19, .22, True)
    dry = track.copy()
    for delay, amount in ((.052, .09), (.117, .055)):
        track += np.roll(dry[:, ::-1], round(delay * SR), axis=0) * amount
    write('sakai-morning', track, .66, True)
    print(json.dumps(stats['sakai-morning'], indent=2))


if __name__ == '__main__':
    render()
