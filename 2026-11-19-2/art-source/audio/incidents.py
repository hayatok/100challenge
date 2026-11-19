"""Synthesize short diegetic signals for the district fixtures, as mono game audio."""
from math import sin, pi, exp
from pathlib import Path
import random
import struct
import wave

rate=22050
out=Path(__file__).resolve().parents[2]/"Game/Assets/Resources/Sound"
for name,duration in (("incidentBell",1.46),("incidentPump",1.10),("incidentRoll",.88)):
    random_source=random.Random(731)
    samples=bytearray();low=0.
    for frame in range(int(rate*duration)):
        t=frame/rate
        noise=random_source.uniform(-1,1)
        low=.93*low+.07*noise
        if name=="incidentBell":
            sample=0.
            for hit in (0,.34):
                d=t-hit
                if d>=0:
                    for f,g,decay in ((568,.33,3.1),(1251,.13,4.8),(1734,.07,6.1),(2317,.045,7.4)):
                        sample+=g*exp(-decay*d)*sin(2*pi*f*d)
        elif name=="incidentPump":
            sample=.21*sin(2*pi*76*t+.7*sin(2*pi*8*t))+.10*sin(2*pi*151*t)+.65*low
        else:
            impact=exp(-15*((t*4.8)%1))
            sample=(.63*low+.20*sin(2*pi*135*t))*impact+.08*noise*exp(-6*t)
        fade=min(1,t/.015,(duration-t)/.10)
        samples.extend(struct.pack("<h",round(max(-1,min(1,sample*fade))*26000)))
    with wave.open(str(out/(name+".wav")),"wb") as f:
        f.setparams((1,2,rate,len(samples)//2,"NONE","not compressed"));f.writeframes(samples)
