"""Render the original station chimes, field foley and adaptive music stems."""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "Game/Assets/Resources/Sound"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(3107)

def timeline(length):
    return np.arange(round(RATE * length)) / RATE

def tone(t, hz):
    return np.sin(2 * np.pi * hz * t)

def colored(t, width):
    return np.convolve(rng.uniform(-1, 1, len(t)), np.ones(width) / np.sqrt(width), "same")

def render(name, t, samples, gain=.78):
    fade = np.minimum(1, np.minimum(t * 220, (len(t) / RATE - t) * 100))
    pcm = np.clip(gain * fade * np.tanh(samples), -1, 1)
    with wave.open(str(OUT / (name + ".wav")), "wb") as w:
        w.setparams((1, 2, RATE, 0, "NONE", ""))
        w.writeframes((pcm * 32767).astype("<i2").tobytes())

for name, notes in {
    "dispatch": (784, 1046), "dial": (1175,), "board": (660, 880),
    "radio": (1320, 990), "warning": (392, 392, 311),
    "arrival": (523, 659, 784, 1046), "loss": (392, 330, 262),
    "relay": (262, 349), "action": (587, 784),
}.items():
    t = timeline(.16 * len(notes) + .36)
    y = np.zeros_like(t)
    for i, hz in enumerate(notes):
        s = np.maximum(t - i * .16, 0)
        y += (tone(s, hz) + .17 * tone(s, hz * 2.006)) * (1 - np.exp(-s * 110)) * np.exp(-s * 12)
    render(name, t, y, .6)

for name, duration, filt, body, attack in (
    ("fire", .48, 3, 87, 17), ("distant", .5, 14, 124, 11),
    ("impact", .24, 8, 68, 18), ("step1", .2, 12, 73, 23),
    ("step2", .23, 10, 66, 20), ("fallen", .53, 10, 54, 12),
    ("paper", .29, 4, 450, 15), ("reload", .58, 3, 440, 20)
):
    t = timeline(duration)
    env = np.exp(-t * attack)
    if name == "reload":
        env = env * .45 + np.where(t>.28,np.exp(-np.maximum(0,t-.28)*40),0)
    y = env*(colored(t, filt)*1.6 + .55*tone(t, body)*np.exp(-t*10))
    if name == "fire":
        y += .28*colored(t, 17)*np.exp(-np.maximum(t-.07,0)*11)*(t>.07)
    render(name, t, y)
t = timeline(1.4)
rattle = np.sin(2*np.pi*(68*t+11*t*t+1.2*np.sin(7*t)))
render("infected",t, (.9*rattle+.3*rattle**3+.16*colored(t,26))*np.sin(np.pi*t/1.4)**1.5)
t = timeline(10)
rain = .3 * colored(t, 42) + .12 * colored(t, 3)
for start in rng.uniform(0, 9.9, 90):
    s = np.maximum(0,t-start)
    rain += .075*(t>start)*np.exp(-s*70)*tone(s,rng.uniform(670,1860))
render("rain",t,rain,.65)
t = timeline(16)
y = np.zeros_like(t)
for bar, hz in enumerate((73.416, 65.406, 58.270, 65.406)):
    s = np.clip(t - bar * 4, 0, 4)
    swell=np.sin(np.pi*s/4)**.6
    y += swell*(.25*tone(s,hz)+.18*tone(s,hz*1.498)+.09*tone(s,hz*3.007))
for i in range(32):
    s = np.maximum(0,t-i*.5)
    y += np.exp(-s*12)*(t>=i*.5)*(.26*tone(s,49+(i%2)*7)+.09*colored(t,27))
render("pulse",t,y,.8)
