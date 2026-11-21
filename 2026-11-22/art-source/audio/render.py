"""Original Kinsei score and effects. Pure additive/subtractive offline synthesis; no samples."""
import pathlib, json, hashlib
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile
SR=44100
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=ROOT/'Game/Assets/Resources/KinseiAudio'
OUT.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(19731122)
stats={}
def filt(x,hz,kind='lowpass'):
    return sosfilt(butter(2,hz,kind,fs=SR,output='sos'),x)
def edge(x):
    n=min(int(SR*.005),len(x)//3)
    x=x.copy(); fade=np.linspace(0,1,n)
    if x.ndim==2:fade=fade[:,None]
    x[:n]*=fade;x[-n:]*=fade[::-1]
    return x
def write(name,x,peak=.8,loop=False):
    x=edge(x);x=x/max(.00001,np.max(np.abs(x)))*peak
    pcm=np.int16(np.clip(x,-1,1)*32767)
    p=OUT/(name+'.wav');wavfile.write(p,SR,pcm)
    stats[name]={'seconds':round(len(x)/SR,3),'channels':1 if x.ndim==1 else x.shape[1], 'peak':round(float(np.max(np.abs(x))),3),'rms_db':round(float(20*np.log10(np.sqrt(np.mean(x*x))+1e-12)),2),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def note(m,d,kind='piano'):
    t=np.arange(int(d*SR))/SR; f=440*2**((m-69)/12)
    if kind=='piano':
        x=sum((1/h**1.6)*np.sin(2*np.pi*f*h*(1+.00012*h*h)*t)*np.exp(-t*(1.3+.45*h)) for h in range(1,8))
        x+=.018*filt(rng.normal(size=len(t)),2400)*np.exp(-t*70)
    elif kind=='bass':
        x=(np.sin(2*np.pi*f*t)+.34*np.sin(4*np.pi*f*t)+.1*np.sin(6*np.pi*f*t))*np.exp(-t*3)
    else:
        phase=2*np.pi*f*(t+.0011*np.sin(2*np.pi*4.8*t))
        x=sum(np.sin(h*phase)/h**1.8 for h in range(1,6))*np.minimum(1,t/.09)*np.exp(-t*.8)
        x=filt(x,1900)
    return edge(x)*np.minimum(1,np.maximum(0,(d-t)/.12))
def noise(d,hz=2500): return filt(rng.normal(size=int(d*SR)),hz)
def mix(dst,x,start,gain=1,pan=0,wrap=False):
    i=int(start*SR); xx=np.stack([x*np.sqrt((1-pan)/2),x*np.sqrt((1+pan)/2)],axis=1)*gain
    if wrap:
        ids=(np.arange(len(x))+i)%len(dst);np.add.at(dst,ids,xx)
    else:
        n=min(len(x),len(dst)-i)
        if n>0:dst[i:i+n]+=xx[:n]
# Original 16-bar minor jazz waltz, A A' B turnaround, 76 quarter notes/minute.
score=json.loads((OUT/'StageScore.json').read_text(encoding='utf-8'))
beat=60/score['bpm']; duration=len(score['bars'])*3*beat
music=np.zeros((round(duration*SR),2))
chords=[bar['chord'] for bar in score['bars']]
melody=[[(n['beat'],n['midi'],n['beats']) for n in bar['melody']] for bar in score['bars']]
for bar,c in enumerate(chords):
    at=bar*3*beat
    for b,m in [(0,c[0]-24),(1.9,c[0]-17)]:mix(music,note(m,1.2,'bass'),at+b*beat,.19,-.12,True)
    for b in [1,2]:
        for j,m in enumerate(c):mix(music,note(m,2.1),at+b*beat+j*.012,.078,-.35,True)
    for b,m,d in melody[bar]:mix(music,note(m,d*beat+.3),at+b*beat,.19,.22,True)
    # Warm brush circles and restrained low kick, softly accented first beat.
    for b in range(3):
        t=np.arange(int(.38*SR))/SR
        brush=filt(rng.normal(size=len(t)),5000)*np.exp(-t*13)*(1-np.exp(-t*100))
        mix(music,brush,at+b*beat,.055 if b else .035,.42,True)
    t=np.arange(int(.22*SR))/SR
    kick=np.sin(2*np.pi*(49*t+2*(1-np.exp(-18*t))))*np.exp(-t*24)
    mix(music,kick,at,.16,0,True)
# Sparse muted trumpet answers, not a constant lead.
for bar,m in [(3,64),(7,67),(11,68),(15,64)]:mix(music,note(m,1.4,'horn'),(bar*3+.2)*beat,.075,.45,True)
# Short reflected room, circular so the tail survives the loop boundary.
dry=music.copy()
for delay,g in [(.047,.12),(.103,.08),(.173,.05)]:music+=np.roll(dry,int(delay*SR),axis=0)[:,::-1]*g
write('kinsei-waltz',music,.72,True)
# Seamless restrained HVAC/room tone: low air, mains hum, distant glass-like partials.
d=12;t=np.arange(d*SR)/SR
amb=noise(d,450)*.14+.012*np.sin(2*np.pi*100*t)+.008*np.sin(2*np.pi*150*t)
amb*=.8+.13*np.sin(2*np.pi*t/d)
write('room',amb,.34,True)
for v in range(3):
    d=.45;t=np.arange(int(d*SR))/SR
    shot=(noise(d,4200)*np.exp(-t*42)+.65*np.sin(2*np.pi*(75*t+7*(1-np.exp(-20*t))))*np.exp(-t*25))
    shot+=np.roll(noise(d,1700)*np.exp(-t*30),int(.055*SR))*.21
    write('shot'+str(v),shot,.78)
    write('distant'+str(v),filt(shot,950),.52)
    step=noise(.22,1000);st=np.arange(len(step))/SR
    step=step*np.exp(-st*30)+.3*np.sin(2*np.pi*(95+v*8)*st)*np.exp(-st*40)
    write('step'+str(v),step,.55)
    strike=noise(.3,1800);st=np.arange(len(strike))/SR
    write('strike'+str(v),strike*np.exp(-st*23)+.45*np.sin(2*np.pi*140*st)*np.exp(-st*28),.7)
for name,notes in {'dial':[76,79],'choice':[69,71],'result':[69,72,76,79],'accord':[65,69,72,76],'loss':[64,60,57]}.items():
    x=np.zeros((int(2.8*SR),2))
    for i,m in enumerate(notes):mix(x,note(m,2.1),i*.17,.4,(i%2-.5)*.25)
    write(name,x,.65)
d=.85;t=np.arange(int(d*SR))/SR
door=noise(d,700)*np.exp(-t*7)*.13+np.sin(2*np.pi*(80*t+14*t*t))*np.exp(-t*6)*.25
door+=np.roll(noise(d,1300)*np.exp(-t*60),int(.48*SR))*.8
write('door',door,.7)
(ROOT/'art-source/audio/measurements.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
print(json.dumps(stats,indent=2))
