"""Render six short, original layers of sole contact, heel and granular tails."""
import math
import random
import struct
import wave
from pathlib import Path

OUT=Path(__file__).resolve().parents[2]/"Game/Assets/Resources/Sound"
RATE=24000


def render(surface,side,seed):
    rng=random.Random(seed)
    duration,base,grains,decay={"road":(.36,86,12,25),"grit":(.41,72,36,18),"tile":(.38,127,5,34)}[surface]
    toe=.075 if side=="R" else .090
    grains_at=[(rng.uniform(.018,.22),rng.uniform(.4,1.2),rng.uniform(900,3100)) for _ in range(grains)]
    samples=[]
    slow=0
    fast=0
    for k in range(round(duration*RATE)):
        t=k/RATE
        white=rng.uniform(-1,1)
        slow+=.095*(white-slow)
        fast+=.48*(white-fast)
        heel=math.exp(-t*decay)*(1-math.exp(-t*190))
        follow=max(0,t-toe)
        roll=(1-math.exp(-follow*150))*math.exp(-follow*32)
        value=heel*(.39*math.sin(2*math.pi*(base*t+1.15*(1-math.exp(-t*19))))+.90*slow)
        value+=roll*(.13*math.sin(2*math.pi*base*.66*follow)+.61*(fast-slow))
        for at,level,pitch in grains_at:
            age=t-at
            if 0<age<.025:
                value+=(.055 if surface=="grit" else .026)*level*math.exp(-age*210)*math.sin(age*pitch*2*math.pi)
        if surface=="tile":
            value+=.08*heel*math.sin(t*2*math.pi*826)+.038*roll*math.sin(t*2*math.pi*1423)
        samples.append(value)
    peak=max(abs(x) for x in samples)
    with wave.open(str(OUT/(surface+side+".wav")),"wb") as stream:
        stream.setparams((1,2,RATE,0,"NONE","not compressed"))
        stream.writeframes(b"".join(struct.pack("<h",round(x/peak*22300)) for x in samples))


for n,surface in enumerate(("road","grit","tile")):
    for s,side in enumerate(("L","R")):
        render(surface,side,791+n*29+s)
