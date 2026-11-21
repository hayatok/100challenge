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
