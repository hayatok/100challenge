"""Original synthesized TENSAI sound sources; no downloaded audio."""
from pathlib import Path
import math, random, struct, wave
root = Path(__file__).resolve().parents[1]/'game/assets/audio'
root.mkdir(parents=True, exist_ok=True)
rate=24000

def save(name, seconds, fn):
    random.seed(178)
    out=[]
    for i in range(int(seconds*rate)):
        t=i/rate
        out.append(max(-.92,min(.92,fn(t,seconds))))
    with wave.open(str(root/(name+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate)
        w.writeframes(b''.join(struct.pack('<h',int(x*32767)) for x in out))

def env(t,d): return min(1,t/.006)*max(0,1-t/d)**2
save('slash',.23,lambda t,d:env(t,d)*(.28*random.uniform(-1,1)+.1*math.sin(2*math.pi*(650*t-1000*t*t))))
save('wire',.35,lambda t,d:env(t,d)*(.20*math.sin(2*math.pi*(420*t+1700*t*t))+.06*random.uniform(-1,1)))
save('impact',.38,lambda t,d:env(t,d)*(.3*math.sin(2*math.pi*(100*t-70*t*t))+.2*random.uniform(-1,1)))
save('dash',.25,lambda t,d:env(t,d)*(.20*random.uniform(-1,1)+.10*math.sin(2*math.pi*190*t)))
save('chime',.8,lambda t,d:env(t,d)*sum(.09*math.sin(2*math.pi*f*t) for f in (440,660,880)))
# Sixteen-second loop: slowly voiced open fifths, gentle upper plucks, quiet drum pulse.
notes=(146.832,220.0,293.665,329.628,440.0)
def music(t,d):
    fade=min(1,t/.3,(d-t)/.3)
    pads=sum(.035*math.sin(2*math.pi*f*t)*(0.7+.3*math.sin(2*math.pi*.125*t+j)) for j,f in enumerate(notes[:4]))
    beat=t%1.0
    pulse=.07*math.sin(2*math.pi*65*t)*math.exp(-beat*18)
    pluck_time=t%.5
    index=int(t*2)%8
    freq=notes[(0,2,4,2,1,3,4,2)[index]]*2
    pluck=.045*math.sin(2*math.pi*freq*t)*math.exp(-pluck_time*12)
    return (pads+pulse+pluck)*fade
save('wind_music',16,music)
print('Created 6 original PCM WAVs')
