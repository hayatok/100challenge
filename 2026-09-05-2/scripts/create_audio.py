"""Original placeholder electro-pop loop and collection chime; deterministic PCM synthesis."""
import math, wave, struct, random
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'game/assets/audio';out.mkdir(exist_ok=True)
sr=22050
rng=random.Random(905)
def save(name,data):
 with wave.open(str(out/name),'w') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,v)) * 28000)) for v in data))
def note(m): return 440*2**((m-69)/12)
beat=60/140
melody=[76,79,81,79,74,76,72,74,76,79,83,81,79,76,74,72]
data=[]
for i in range(int(sr*beat*64)):
 t=i/sr;b=t/beat;step=int(b*2);local=(b*2)%1
 n=melody[step%16];env=math.exp(-local*5)
 lead=(math.sin(2*math.pi*note(n)*t)+.22*math.sin(4*math.pi*note(n)*t))*.13*env
 bass_m=[48,53,57,55][int(b/4)%4];bass=math.sin(2*math.pi*note(bass_m)*t)*.17*math.exp(-(b%1)*4)
 kick=math.sin(2*math.pi*(45*(b%1)*beat+12*(1-math.exp(-(b%1)*12))))*.25*math.exp(-(b%1)*17)
 hat=rng.uniform(-1,1)*.035*math.exp(-local*24)
 data.append(lead+bass+kick+hat)
save('rehearsal.wav',data)
save('loop.wav',[sum(math.sin(2*math.pi*note(n)*i/sr)*.14*math.exp(-i/sr*8) for n in [72,76,79]) for i in range(int(sr*.3))])
