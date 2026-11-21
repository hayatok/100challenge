"""Fit three stage hairstyles and create their texture maps and an eye atlas."""
import sys
from pathlib import Path
from math import cos, pi, sin
import numpy as np
from PIL import Image

assets = Path(sys.argv[2])
source_assets = Path(sys.argv[1])
head_styles = {
    "Adult": (0.174, 0.143, 0.033, 0.011, 1.09),
    "Young": (0.180, 0.138, 0.022, 0.018, -1.12),
    "Brother": (0.147, 0.132, 0.029, 0.012, -1.33),
    "Elder": (0.172, 0.139, 0.028, 0.007, 1.04),
}

def build_hair(label, style):
    front, temple, nape, volume, sweep = style
    head = "Young" if label == "Brother" else label
    source = source_assets / f"Head{head}.obj"
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
                line -= .010 * sin(angle*2+.9) * max(0,c)
            else:
                line += .032 * np.exp(-((cheek-.61)/.19)**2) * max(0,c)
                line -= .013 * np.exp(-((cheek-.98)/.036)**2) * max(0,c)**.4
                line -= .010 * max(0,c)**9
            line += .0019*sin(angle*14+.1)+.0012*sin(angle*33+1.1)+.0011*sin(angle*49)
            end = np.arctan2(.078, line - center[1])
            polar = .003 + (end - .003) * v
            bank = sweep * (.78+.27*c) * (1-v)**1.7
            direction = np.array([sin(angle + bank) * sin(polar), cos(polar),
                                  cos(angle + bank) * sin(polar) * 1.36])
            direction /= np.linalg.norm(direction)
            directions_to_sample.append(direction)
            coordinates.append((u, v))
            wave = 2 * pi * (u * 39 + sweep * v**1.8 * 1.65 + .14 * sin(angle * 4 + 5*v))
            relief = (.00046 + .00076*max(0, sin(wave))**3 + .00036*sin(2*wave)) * min(1,v*7)
            part = max(0, cos(angle + sweep*.70))**3
            crest = .002 + part*(.009 if label=="Elder" else .014) if label!="Brother" else .006 + part*.008
            fringe = crest * sin(pi*v)**2 * (1-.42*v)
            crown = volume * (sin(pi * v * .66)**1.35) * (1 - .83*v**8)
            # Taper the hairline against the scalp, with extra volume left on the swept lock.
            offsets.append(.0022 + crown + relief + fringe - .0019*v**17 + .0014*v**45)

    samples = np.array(directions_to_sample)
    fitted = []
    for first in range(0, len(samples), 64):
        dots = samples[first:first+64] @ directions.T
        nearest = np.argpartition(dots, -7, axis=1)[:, -7:]
        weights = 1 / np.maximum(1 - np.take_along_axis(dots, nearest, axis=1), .000004)**1.25
        fitted.extend((radii[nearest] * weights).sum(axis=1) / weights.sum(axis=1))
    fitted = fit_surface(source, center, samples, np.array(fitted))
    vertices = center + samples * (fitted + offsets)[:, None]

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



def fit_surface(path, center, rays, fallback):
    vertices, ids = [], []
    for line in path.read_text().splitlines():
        if line.startswith("v "):
            vertices.append([float(x) for x in line.split()[1:]])
        elif line.startswith("f "):
            indices = [int(v.split("/")[0])-1 for v in line.split()[1:]]
            ids.extend((indices[0],indices[i],indices[i+1]) for i in range(1,len(indices)-1))
    triangles=np.float32(vertices)[np.array(ids)]-np.float32(center)
    triangles=triangles[triangles[:,:,1].max(axis=1)>-.089]
    a,b,c=triangles.transpose((1,0,2))
    start=-a
    edge1,edge2=b-a,c-a
    q=np.cross(start,edge1)
    tq=np.einsum('ij,ij->i',edge2,q)
    chosen=fallback.copy()
    for first in range(0,len(rays),32):
        batch=np.float32(rays[first:first+32])
        p=np.cross(batch[:,None,:],edge2)
        denominator=np.einsum('ijk,jk->ij',p,edge1)
        valid=abs(denominator)>1e-9
        safe=np.where(valid,denominator,1)
        u=np.einsum('ijk,jk->ij',p,start)/safe
        v=(batch@q.T)/safe
        t=tq/safe
        correct=valid & (u>=0) & (v>=0) & (u+v<=1) & (t>0)
        out=np.where(correct,t,0).max(axis=1)
        chosen[first:first+len(batch)]=np.where(out>0,out,chosen[first:first+len(batch)])
    return chosen

rng=np.random.default_rng(72)
Y,X=np.mgrid[:512,:512]/512
for label in ('Adult','Elder','Brother'):
 style=head_styles[label]
 build_hair(label,style)
 flow=X*39+style[-1]*(1-Y)**1.8*1.65+.14*np.sin(2*pi*X*4+5*(1-Y))
 filament=np.cos(2*pi*(flow*6+Y*.52+.8*np.sin(X*2*pi*137)))
 broad=.06*np.sin(2*pi*(X*13+(1-Y)*1.7))+.035*np.sin(2*pi*(X*9+Y*9))
 strand=.05*filament
 if label=='Elder':
  strand+=.15*np.maximum(0,np.sin(2*pi*(flow*2.8+.52*np.sin(X*2*pi*67))))**9
 # Lighter short hairs along the nape and temples. Saturation stays low in warm light.
 taper=np.clip((.20-Y)*4,0,.38)*(np.maximum(0,-np.cos(2*pi*X))+.35)
 tone=np.clip(.38+broad+strand+taper*.17+rng.normal(0,.024,X.shape),0,1)
 tip_width = .018 + .005*np.sin(X*2*pi*117)+.005*np.sin(X*2*pi*193)
 opacity = np.clip(Y/np.maximum(tip_width,.004),0,1)
 opacity = opacity*opacity*(3-2*opacity)
 Image.fromarray(np.uint8(np.stack((tone,tone,tone,opacity),axis=2)*255),'RGBA').save(assets / f'Hair{label}Grain.png')

N=256
y,x=(np.mgrid[:N,:N]+.5-N/2)/(N/2)
# Eye surface uses 15 mm horizontal and 11 mm vertical cap radii.
x*=.015/.0056
y*=.011/.0056
r=np.hypot(x,y)
angle=np.arctan2(y,x)
texture=np.empty(x.shape+(3,))
sclera=.48-.13*np.clip((r-.82)/1.9,0,1)-.11*np.maximum(0,-y)*.45
texture[:]=sclera[:,:,None]*np.array([1,.94,.925])
vessel=np.exp(-((y-.13*np.sin(7*x)-.21)**2)/.00024)*np.clip((r-1.38)/.50,0,1)
texture[:,:,1:]-=vessel[:,:,None]*.033
fibers=.033*np.sin(angle*89+6*r)+.014*np.sin(angle*167-14*r)+.015*np.sin(angle*37-19*r)
iris=np.clip(.15+fibers+.042*np.sin(14*r),.06,.22)*np.array([1.38,1,.79])[:,None,None]
iris=np.moveaxis(iris,0,-1)
ring=.15+.85*np.clip((1-r)/.15,0,1)
iris*=ring[:,:,None]
use=np.clip((1.02-r)/.068,0,1)
texture=texture*(1-use[:,:,None])+iris*use[:,:,None]
pupil=np.clip((.485-r)/.049,0,1)
texture=texture*(1-pupil[:,:,None])+np.array([.025,.022,.020])*pupil[:,:,None]
Image.fromarray(np.uint8(np.clip(texture,0,1)*255),'RGB').save(assets / 'EyeGlobe.png')
