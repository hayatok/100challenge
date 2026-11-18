"""Write the original harbor race music and one-shot cues using standard Python."""
import array
import math
import random
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "game" / "media"
RATE = 22050
TAU = math.tau
BEAT = 60 / 146
rng = random.Random(711)


def pcm(path, samples):
    with wave.open(str(path), "wb") as writer:
        writer.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        writer.writeframes(array.array("h", (int(30000 * math.tanh(v)) for v in samples)).tobytes())


def pitch(note):
    return 440 * 2 ** ((note - 69) / 12)


def play(buf, start, length, sample, volume=1.0, wrap=False):
    offset = round(start * RATE)
    for i in range(round(length * RATE)):
        j = i + offset
        if wrap:
            j %= len(buf)
        if 0 <= j < len(buf):
            buf[j] += volume * sample(i / RATE)


def note(buf, beat, midi, beats, voice, volume):
    f = pitch(midi)
    length = beats * BEAT
    def oscillator(t):
        phase = TAU * f * t
        if voice == "mallet":
            return (math.sin(phase) + .23 * math.sin(phase * 3.02)) * math.exp(-t * 9)
        if voice == "bass":
            return (math.sin(phase) + .29*math.sin(phase*2) + .15*math.sin(phase*3)) * math.exp(-t * 4)
        vibrato = .047 * math.sin(TAU * 5.1 * t)
        return (math.sin(phase + vibrato) + .3*math.sin(2*phase+vibrato) + .12*math.sin(phase*3)) * math.exp(-t*.9)
    def enveloped(t):
        return oscillator(t) * min(1, t/.012, max(0, length-t)/.046)
    play(buf, beat*BEAT, length, enveloped, volume, True)


def soundtrack():
    track = [0.0] * round(32 * BEAT * RATE)
    chords = [(50,54,57),(47,50,54),(43,47,50),(45,49,52),
              (50,54,57),(42,45,50),(43,47,50),(45,49,52)]
    melodies = [
        [(0,74,.65),(.75,78,.25),(1,81,.85),(2.5,78,.38),(3,76,.7)],
        [(0,74,.8),(1.5,71,.4),(2,74,.6),(3.25,78,.55)],
        [(0,79,.56),(.75,78,.25),(1,74,.9),(2.5,71,.4),(3,74,.65)],
        [(0,73,.7),(1,76,.6),(2.5,81,.42),(3.25,76,.5)],
        [(0,78,.6),(.75,81,.25),(1,86,.85),(2.5,81,.4),(3,78,.65)],
        [(0,76,.8),(1.5,74,.4),(2,73,.55),(3,69,.72)],
        [(0,71,.55),(.75,74,.25),(1,79,.7),(2.5,78,.45),(3,74,.7)],
        [(0,76,.5),(.75,73,.23),(1,69,.65),(2.5,73,.36),(3,76,.54)],
    ]
    for bar, chord in enumerate(chords):
        start = bar*4
        for beat, midi, duration in melodies[bar]:
            note(track,start+beat,midi,duration,"lead",.15)
        for j in range(4):
            beat = start+j
            note(track,beat,chord[0]-12 + (7 if j in (1,3) else 0),.66,"bass",.30)
            for midi in chord:
                note(track,beat+.54,midi+12,.34,"mallet",.070)
            for eighth in (0,.54):
                play(track,(beat+eighth)*BEAT,.055,lambda t: rng.uniform(-1,1)*math.exp(-t*85),.055,True)
            if j in (0,2):
                play(track,beat*BEAT,.16,lambda t: math.sin(TAU*(50*t + .85*(1-math.exp(-30*t))))*math.exp(-22*t),.36,True)
            else:
                play(track,beat*BEAT,.095,lambda t: (.65*rng.uniform(-1,1)+.35*math.sin(TAU*187*t))*math.exp(-41*t),.24,True)
    pcm(OUT/"regatta.wav",track)


def cues():
    for name, length, f, glide, noise in [
        ("jump",.14,390,1750,.02),("land",.10,125,-270,.26),
        ("step",.052,155,-590,.52),("bump",.25,145,-240,.24),
        ("splash",.36,400,-447,.89),("count",.10,700,0,0),
        ("go",.26,1046,210,0),
    ]:
        out = [0.0]*round(length*RATE)
        def sample(t):
            env = min(1,t/.004)*math.exp(-4*t/length)*min(1,(length-t)/.007)
            return ((1-noise)*math.sin(TAU*(f*t+glide*t*t/2)) + noise*rng.uniform(-1,1))*env
        play(out,0,length,sample,.72)
        pcm(OUT/(name+".wav"),out)
    out = [0.0]*RATE
    for i,midi in enumerate([74,78,81,86]):
        f = pitch(midi)
        play(out,i*.125,.35,lambda t,f=f: math.sin(TAU*f*t)*min(1,t/.008)*math.exp(-12*t),.62)
    pcm(OUT/"finish.wav",out)

    # Air cutting past the ribbon, followed by a short cloth-on-wood landing.
    for name, length in [("boost", .24), ("dive", .18), ("slide", .25)]:
        out = []
        filtered = 0.0
        for i in range(round(length * RATE)):
            t = i / RATE
            u = t / length
            filtered += 0.14 * (rng.uniform(-1, 1) - filtered)
            envelope = math.sin(math.pi * u) ** (1.2 if name == "boost" else .8)
            if name == "boost":
                tone = math.sin(TAU * (290*t + 1000*t*t))
                value = .30 * tone + .63 * filtered
            elif name == "dive":
                tone = math.sin(TAU * (410*t - 740*t*t))
                value = .13 * tone + .90 * filtered
            else:
                value = filtered * (1.05 + .38 * math.sin(TAU * 29*t)) * (1-u)
            out.append(envelope * value)
        pcm(OUT/(name+".wav"), out)


if __name__ == "__main__":
    soundtrack()
    cues()
