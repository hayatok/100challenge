"""Render original harbor ambience and game cues to mono PCM without external packages."""
from array import array
from math import exp, pi, sin
from pathlib import Path
from random import Random
from wave import open as wave_open

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "game/media/sfx"
OUT.mkdir(parents=True, exist_ok=True)
lengths = dict(fire0=.17, fire1=.43, fire2=.79, reload=.84, switch=.15,
               empty=.1, flesh=.12, kill=.46, hurt=.34, attack=.33,
               charge_warning=1.14, flare=.94, bell=2.5, gate=1.36,
               crash=1.42, depart=3.5, hum0=4, hum1=4, hum2=4, step0=.21, step1=.19, step2=.27, chain=1.05)
for index, (name, length) in enumerate(lengths.items()):
    rng = Random(index + 417)
    samples = array("h")
    previous = 0.
    for i in range(round(RATE * length)):
        t = i / RATE
        n = rng.uniform(-1, 1)
        previous = .80 * previous + .20 * n
        def tone(hz):
            return sin(2*pi*hz*t)
        def decay(rate):
            return exp(-rate*t)
        if name.startswith("fire"):
            fall, low, tail = {"fire0":(20,75,9), "fire1":(10,51,6), "fire2":(8,94,5)}[name]
            sound = .64*n*decay(fall*2) + .76*sin(2*pi*(low*t + 2*(1-decay(36))))*decay(tail)
            if name == "fire2": sound += .23*sin(2*pi*(600*t-270*t*t))*decay(3)
        elif name == "bell":
            sound = sum(amp*tone(freq)*decay(rate) for amp,freq,rate in
                        [(.46,583,2.2),(.26,1293,1.45),(.19,1684,3.4),(.12,2890,3)])
        elif name in ("empty","switch","reload"):
            hits = {"empty":[0], "switch":[0,.082],"reload":[0,.14,.32,.61,.66]}[name]
            sound = sum((.7*n+.23*tone(944))*exp(-75*(t-p)) for p in hits if t>=p)
        elif name in ("attack","charge_warning","hurt","kill"):
            freq = {"attack":115,"charge_warning":64,"hurt":85,"kill":53}[name]
            sound = (tone(freq+.5*sin(t*13))*.32 + tone(freq*1.51)*.18 + previous*.95) * (1+.4*tone(19)) * sin(pi*min(1,t/length))**.6
        elif name.startswith("step"):
            base = {"step0":66,"step1":103,"step2":84}[name]
            sound = (.59*previous+.35*tone(base))*decay(24)
            if name == "step0": sound += .12*n*decay(10)
            if name == "step1": sound += .22*n*decay(35)
            if name == "step2": sound += .13*tone(392)*decay(12)
        elif name == "chain":
            sound = sum((.29*tone(650+104*j)+.44*previous)*exp(-12*(t-p)) for j,p in enumerate([0,.17,.34,.42,.62]) if t>=p)
        elif name == "flesh": sound = (n*.46 + tone(117)*.65)*decay(34)
        elif name == "flare": sound = (previous*1.4+tone(66)*.7)*decay(4)
        elif name == "gate": sound = (.32*tone(69)+.5*previous+ .18*tone(192))*(.4+.5*abs(tone(11)))*sin(pi*t/length)
        elif name == "crash": sound = (.7*n + .48*tone(52) + .3*tone(511))*decay(3)
        elif name == "depart": sound = (.52*tone(82)+.25*tone(123)+.23*tone(165))*min(1,t*4)*min(1,(length-t)*1.5)
        elif name == "hum0": sound = .24*tone(50)+.08*tone(100)+.02*tone(704)+.08*previous
        elif name == "hum1": sound = .22*tone(45)*(.7+.3*tone(3))+.12*tone(90)+previous*.25
        else: sound = .23*tone(29)+.13*tone(58)+previous*(.24+.19*tone(.25))
        samples.append(round(27800*max(-1,min(1,sound))*min(1,i/12,(RATE*length-i)/60)))
    with wave_open(str(OUT / (name+".wav")), "wb") as stream:
        stream.setparams((1,2,RATE,0,"NONE","not compressed"))
        stream.writeframes(samples.tobytes())
