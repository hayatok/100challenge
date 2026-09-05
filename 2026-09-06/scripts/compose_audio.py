"""Original loopable score and refrigerator ambience. Python standard library only."""
from array import array
from pathlib import Path
import math, random, wave
RATE=22050
OUT=Path(__file__).resolve().parents[1]/'game/assets/audio'
BEAT=0.32
PHRASES=[
 [0,None,4,7,9,None,7,4,2,None,4,2,0,None,-1,2],
 [4,None,7,11,12,None,11,7,9,7,4,None,2,None,4,None],
 [5,None,9,12,14,None,12,9,7,None,9,7,5,None,4,2],
 [7,None,11,14,16,14,11,7,9,None,7,4,2,None,-1,None],
 [0,None,7,4,9,7,4,None,2,4,7,None,4,2,0,None],
 [4,None,7,9,11,None,7,4,9,None,12,11,7,None,4,None],
 [5,None,9,7,12,None,9,5,7,None,11,9,7,4,2,None],
 [7,None,11,14,12,None,9,7,4,None,2,-1,0,None,None,None],
]
def add(buf,start,duration,freq,amp,kind='bell'):
 n=int(duration*RATE);offset=int(start*RATE)
 for i in range(n):
  t=i/RATE;phase=2*math.pi*freq*t
  env=min(1,t/0.009)*math.exp(-t*(9 if kind=='bell' else 4))*min(1,(duration-t)/0.04)
  val=math.sin(phase)
  if kind=='bell':val=val*.82+math.sin(phase*2)*.13+math.sin(phase*3)*.05
  elif kind=='pad':val=val*.8+math.sin(phase*2.002)*.2
  buf[(offset+i)%len(buf)]+=val*amp*env

def save(name,buf):
 samples=array('h',(round(max(-.96,min(.96,v))*32767) for v in buf))
 with wave.open(str(OUT/name),'wb') as f:f.setparams((1,2,RATE,0,'NONE',''));f.writeframes(samples.tobytes())
 print(name,'seconds',round(len(buf)/RATE,2),'peak',round(max(abs(v) for v in buf),3))

for night in [False,True]:
 buf=[0.0]*round(BEAT*128*RATE)
 for phrase,notes in enumerate(PHRASES):
  root=[0,9,5,7,0,9,5,7][phrase]
  for beat,note in enumerate(notes):
   pos=(phrase*16+beat)*BEAT
   if note is not None and (not night or beat%2==0):add(buf,pos,.75 if night else .42,220*2**((note+(0 if night else 12))/12),.11 if night else .13)
   if beat%4==0:
    add(buf,pos,.9,110*2**(root/12),.11,'bass')
    for interval in [0,3 if root==9 else 4,7]:add(buf,pos+.03,1.1,220*2**((root+interval)/12),.026,'pad')
   if not night and beat%2==1:add(buf,pos,.04,1800,.011)
 save('night.wav' if night else 'day.wav',buf)
rng=random.Random(24)
buf=[];previous=0
for i in range(RATE*2):
 previous=.95*previous+.05*rng.uniform(-1,1)
 t=i/RATE
 buf.append(.12*math.sin(2*math.pi*55*t)+.025*math.sin(2*math.pi*110*t)+.09*previous)
save('room.wav',buf)
