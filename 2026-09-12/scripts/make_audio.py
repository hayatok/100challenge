import math,random,wave,struct
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'game/assets/audio';sr=24000;random.seed(22)
def save(name,a):
 peak=max(1,max(abs(x) for x in a));a=[int(max(-1,min(1,x/peak*.88))*32767) for x in a]
 with wave.open(str(out/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(struct.pack('<'+'h'*len(a),*a))
for name,length in [('bite',.21),('crash',.42),('dash',.25),('shot',.28),('hurt',.32),('warn',.21),('power',.65),('grow',1.2),('victory',2.0)]:
 a=[]
 for i in range(int(length*sr)):
  t=i/sr;p=t/length;env=(1-p)**2;noise=random.uniform(-1,1)
  if name=='bite':v=math.sin(2*math.pi*(280*t+360*t*t))*math.exp(-t*19)+noise*.22*env
  elif name=='crash':v=(noise*.40+math.sin(2*math.pi*(95*t-55*t*t))*.65)*math.exp(-t*10)
  elif name=='dash':v=(noise*.5+math.sin(2*math.pi*(220*t-180*t*t))*.25)*env
  elif name=='shot':v=(noise*.4+math.sin(2*math.pi*(170*t-180*t*t))*.6)*math.exp(-t*21)
  elif name=='hurt':v=math.sin(2*math.pi*(300*t-210*t*t))*env*.8
  elif name=='warn':v=(math.sin(2*math.pi*660*t)+math.sin(2*math.pi*990*t)*.15)*math.sin(math.pi*p)*.4
  else:
   notes=[261.63,329.63,392,523.25,659.25,783.99];freq=notes[min(5,int(p*6))]
   v=(math.sin(2*math.pi*freq*t)+math.sin(2*math.pi*freq*2*t)*.22)*min(1,t*30)*(1-p)*.6
  a.append(v)
 save(name,a)
# Original playful bass / mallet loop, 16 bars at 112 BPM, with variation and restrained percussion.
beat=60/112;duration=beat*64;a=[0.0]*int(sr*duration)
def note(start,dur,freq,amp,kind='mallet'):
 for i in range(int(dur*sr)):
  j=int(start*sr)+i
  if j>=len(a):break
  t=i/sr
  if kind=='kick':v=math.sin(2*math.pi*(70*t-32*t*t))*math.exp(-t*19)
  elif kind=='hat':v=random.uniform(-1,1)*math.exp(-t*75)*.35
  elif kind=='bass':v=(math.sin(2*math.pi*freq*t)+.18*math.sin(2*math.pi*freq*2*t))*min(1,t*80)*math.exp(-t*4)
  else:v=(math.sin(2*math.pi*freq*t)+.35*math.sin(2*math.pi*freq*3*t))*math.exp(-t*8)
  a[j]+=v*amp
chords=[[48,52,55,59],[45,48,52,55],[41,45,48,52],[43,47,50,55]]
melody=[0,2,3,2,1,2,0,1]
for b in range(64):
 chord=chords[(b//4)%4];start=b*beat
 note(start,.25,0,.30,'kick')
 note(start+.5*beat,.10,0,.16,'hat')
 note(start,beat*.8,440*2**((chord[0]-12-69)/12),.40,'bass')
 if b%2==0 or b//16%2==1:
  pitch=chord[melody[b%8]]+24
  note(start+.5*beat,beat*.8,440*2**((pitch-69)/12),.16)
 if b%4==2:
  for pitch in chord[1:]:note(start,beat,440*2**((pitch+12-69)/12),.055)
# Small fade only at wrap boundary.
for i in range(300):a[i]*=i/300;a[-i-1]*=i/300
save('town',a)
