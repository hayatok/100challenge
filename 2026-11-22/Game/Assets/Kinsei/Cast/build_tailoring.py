"""Build fitted hairstyles and tileable wool/hair color maps from canonical head OBJs."""
from pathlib import Path
from math import cos, pi, sin
import numpy as np
from PIL import Image

assets = Path(__file__).resolve().parents[2] / "Resources" / "KinseiCast"
head_styles = {
    "Adult": (0.184, 0.135, 0.011, 0.017, 1.20),
    "Young": (0.180, 0.138, 0.022, 0.018, -1.12),
    "Brother": (0.143, 0.105, 0.020, 0.017, -0.98),
    "Elder": (0.157, 0.122, 0.011, 0.013, 0.93),
}

def build_hair(label, style):
    front, temple, nape, volume, sweep = style
    head = "Young" if label == "Brother" else label
    source = assets / f"Head{head}.obj"
    center = np.array([-.008 if sweep>0 else .009, .112 if head != "Elder" else .101, -.014])
    points = np.array([list(map(float, row.split()[1:])) for row in source.read_text().splitlines()
                       if row.startswith("v ")]) - center
    radii = np.linalg.norm(points, axis=1)
    directions = points / radii[:, None]

    steps, rings = 112, 40
    directions_to_sample, coordinates, offsets = [], [], []
    for ring in range(rings + 1):
        v = ring / rings
        for section in range(steps + 1):
            u = section / steps
            angle = 2 * pi * u
            c = cos(angle)
            line = temple + (front - temple) * max(0, c)**2 + (nape - temple) * max(0, -c)**.77
            cheek = abs(sin(angle))
            line += .008 * sin(angle * 2) * max(0, c)**2
            if label=="Brother":
                line -= .022 * sin(angle)**2 * max(0, c)
            else:
                line += .032 * np.exp(-((cheek-.61)/.19)**2) * max(0,c)
                line -= .028 * np.exp(-((cheek-.98)/.045)**2) * max(0,c)**.3
                line -= .010 * max(0,c)**9
            line += .0017 * sin(angle * 39) + .0015 * sin(angle * 23)
            end = np.arctan2(.078, line - center[1])
            polar = .003 + (end - .003) * v
            bank = sweep * (.71+.21*c) * (1-v)**1.7
            direction = np.array([sin(angle + bank) * sin(polar), cos(polar),
                                  cos(angle + bank) * sin(polar) * 1.36])
            direction /= np.linalg.norm(direction)
            directions_to_sample.append(direction)
            coordinates.append((u, v))
            wave = 2 * pi * (u * 26 + sweep * v**1.8 * 1.65 + .14 * sin(angle * 4 + 5*v))
            relief = (.0007 + .0016*max(0, sin(wave))**3 + .0005*sin(2*wave)) * min(1,v*7)
            part = max(0, cos(angle + sweep*.70))**3
            crest = .004 + part*.018 if label!="Brother" else .008 + part*.005
            fringe = crest * sin(pi*v)**2 * (1-.42*v)
            crown = volume * (sin(pi * v * .66)**1.35) * (1 - .83*v**8)
            # Taper the hairline against the scalp, with extra volume left on the swept lock.
            offsets.append(.0035 + crown + relief + fringe - .009 * v**25)

    samples = np.array(directions_to_sample)
    fitted = []
    for first in range(0, len(samples), 64):
        dots = samples[first:first+64] @ directions.T
        nearest = np.argpartition(dots, -7, axis=1)[:, -7:]
        weights = 1 / np.maximum(1 - np.take_along_axis(dots, nearest, axis=1), .000004)**1.25
        fitted.extend((radii[nearest] * weights).sum(axis=1) / weights.sum(axis=1))
    vertices = center + samples * (np.array(fitted) + offsets)[:, None]

    # Normals are continuous across the longitudinal texture seam.
    grid = vertices.reshape(rings + 1, steps + 1, 3)
    horizontal = np.roll(grid[:, :-1], -1, 1) - np.roll(grid[:, :-1], 1, 1)
    vertical = np.gradient(grid[:, :-1], axis=0)
    normals = np.cross(vertical, horizontal)
    normals /= np.maximum(np.linalg.norm(normals, axis=2, keepdims=True), 1e-8)
    normals[0] = [0,1,0]
    normals = np.concatenate((normals,normals[:,:1]),axis=1).reshape(-1,3)
    obj = [f"o Hair{label}"]
    obj.extend(f"v {x:.6f} {y:.6f} {z:.6f}" for x, y, z in vertices)
    obj.extend(f"vt {u:.6f} {v:.6f}" for u, v in coordinates)
    obj.extend(f"vn {x:.6f} {y:.6f} {z:.6f}" for x, y, z in normals)
    obj.append("s 1")
    for row in range(rings):
        for col in range(steps):
            a = row * (steps + 1) + col + 1
            b = a + steps + 1
            obj.append("f " + " ".join(f"{i}/{i}/{i}" for i in (a, b, b+1, a+1)))
    (assets / f"Hair{label}.obj").write_text("\n".join(obj) + "\n")

for label, style in head_styles.items():
    build_hair(label, style)

rng = np.random.default_rng(1989)
y, x = np.mgrid[:512, :512] / 512
warp = np.cos(2*pi*(x*90 + y*44))
weft = np.cos(2*pi*(y*102 - x*22))
herringbone = .6 * np.cos(2*pi*(y*34 + 6*np.abs(np.mod(8*x,1)-.5)))
grain = rng.normal(0, .052, x.shape)
wool = .77 + .07*warp + .055*weft + .035*herringbone + grain
Image.fromarray(np.uint8(np.clip(wool,0,1)*255), "L").convert("RGB").save(assets / "Wool.png")
height = .34*warp + .26*weft + .1*herringbone
dx = (np.roll(height,-1,1) - np.roll(height,1,1)) * .125
dy = (np.roll(height,-1,0) - np.roll(height,1,0)) * .125
normal = np.stack((-dx, dy, np.ones_like(dx)), axis=2)
normal /= np.linalg.norm(normal,axis=2,keepdims=True)
Image.fromarray(np.uint8((normal*.5+.5)*255),"RGB").save(assets / "WoolNormal.png")

for label, style in head_styles.items():
    sweep = style[-1]
    flow = x * 26 + sweep * (1-y)**1.8 * 1.65 + .14*np.sin(2*pi*x*4 + 5*(1-y))
    fibers = np.cos(2*pi*(flow*4 + 1.3*np.sin(x*2*pi*67)))
    bands = np.maximum(0,np.sin(2*pi*flow))
    tone = .40 + .24*bands**.75 + .10*fibers + grain
    if label == "Elder":
        tone += .32*np.maximum(0,np.cos(2*pi*(flow*1.5)))**8
    Image.fromarray(np.uint8(np.clip(tone,0,1)*255),"L").convert("RGB").save(assets / f"Hair{label}Grain.png")
