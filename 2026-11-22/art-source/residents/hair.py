"""Scalp-fitted hair with continuous crown, strand-flow UVs and a swept chignon."""
import math,sys
from pathlib import Path
import numpy as np
from PIL import Image
out=Path(sys.argv[1])
for name in ('Sumiko','Murase'):
    bob=name=='Sumiko'
    head=np.array([list(map(float,r.split()[1:])) for r in (out/f'Head{name}.obj').read_text().splitlines() if r.startswith('v ')])
    center=np.array([0,.115,.009])
    delta=head-center
    radii=np.linalg.norm(delta,axis=1)
    dirs=delta/radii[:,None]
    vertices=[];uv=[];faces=[]
    def surface(grid):
        start=len(vertices)
        rows,cols=grid.shape[:2]
        for i in range(rows):
            for j in range(cols):
                vertices.append(grid[i,j]);uv.append((j/(cols-1),1-i/(rows-1)))
                if i and j:
                    a=start+(i-1)*cols+j
                    faces.append((a,a+cols,a+cols+1,a+1))
    t,u=np.meshgrid(np.linspace(0,1,50),np.linspace(0,1,145),indexing='ij')
    a=u*2*np.pi
    front=np.cos(a);side=np.sin(a)
    hairline=.135+.031*np.maximum(front,0)**2-.056*np.maximum(-front,0)**.75
    hairline-=(.019*np.exp(-((a-.64)/.53)**2)+.014*np.exp(-((a-5.66)/.34)**2)) if bob else .010*np.exp(-((a-.45)/.37)**2)
    hairline+=.007*np.sin(2*a+.9)*np.maximum(front,0)**2
    hairline-=.014*np.exp(-((np.abs(side)-.976)/.043)**2)*np.maximum(front,0)**.4
    p=np.arctan2(.083,hairline-center[1])
    # The bob fans down from the temple and curls in toward the cheeks at the tips.
    angle=a+(.90 if bob else -.29)*(1-t)**1.65
    lat=.006+t*p
    direction=np.stack([np.sin(angle)*np.sin(lat),np.cos(lat),np.cos(angle)*np.sin(lat)*1.08],axis=-1)
    direction/=np.linalg.norm(direction,axis=-1,keepdims=True)
    distances=[]
    for batch in np.array_split(direction.reshape(-1,3),100):
        dots=batch@dirs.T
        ix=np.argpartition(dots,-7,axis=1)[:,-7:]
        weights=1/np.maximum(1-np.take_along_axis(dots,ix,axis=1),.000005)**1.4
        distances.extend((radii[ix]*weights).sum(1)/weights.sum(1))
    flow=2*np.pi*(u*35+.60*t+.22*np.sin(a*3+t*4))
    relief=.0010*np.sin(flow)+.00045*np.sin(flow*2)
    bank=(.013 if bob else .007)*np.sin(np.pi*t*.77)**1.2
    grid=center+direction*(np.asarray(distances).reshape(t.shape)+.004+bank+relief*t)[:,:,None]
    if bob:
        fringe=np.clip((.93-front)/.58,0,1)
        grid[:,:,1]-=t**2.4*fringe*(.071+.006*np.cos(a*3)+.0019*np.sin(flow))
        grid[:,:,0]+=side*fringe*(.011*np.sin(np.pi*t*.84)-.003*t**10)
    else:
        gather=np.maximum(-front,0)**1.3*t**2
        grid[:,:,2]-=.022*gather
    surface(grid)
    if not bob:
        t,u=np.meshgrid(np.linspace(.005,np.pi-.005,38),np.linspace(0,2*np.pi,97),indexing='ij')
        r=1+.042*np.cos(9*u+4*t)+.019*np.cos(19*u+7*t)
        grid=np.stack([.039*np.sin(t)*np.sin(u)*r,.119+.034*np.cos(t),-.066+.038*np.sin(t)*np.cos(u)*r],axis=-1)
        surface(grid)
    lines=['o Hair'+name]+['v %.6f %.6f %.6f'%tuple(v) for v in vertices]+['vt %.6f %.6f'%v for v in uv]+['s 1']
    lines+=['f '+' '.join(f'{i}/{i}' for i in f) for f in faces]
    (out/f'Hair{name}.obj').write_text('\n'.join(lines)+'\n')
    y,x=np.mgrid[0:768,0:1024]/np.array([768,1024])[:,None,None]
    rng=np.random.default_rng(43 if bob else 29)
    flow=x*41+y*.58+.23*np.sin(x*6*np.pi+4*y)
    band=.038*np.cos(flow*2*np.pi)+.036*np.cos(flow*4*np.pi)
    silk=.049*np.cos(2*np.pi*(flow*5+.24*np.sin(41*x+8*y)))+.025*np.cos(2*np.pi*(flow*10+y*.8))
    silver=np.maximum(0,np.cos(2*np.pi*(flow*2.48+.72*np.sin(89*x))))**5
    val=(.43 if bob else .19)+band+silk+silver*(.21 if bob else .047)+rng.normal(0,.015,x.shape)
    rgb=np.clip(val[:,:,None]*(np.array([1,.985,.95]) if bob else np.array([1.08,.93,.86])),0,1)
    edge=.018+.008*np.sin(2*np.pi*x*173)+.006*np.cos(2*np.pi*x*347)
    alpha=np.clip((1-y)/edge,0,1)
    Image.fromarray(np.uint8(np.dstack((rgb,alpha))*255)).save(out/f'Hair{name}Grain.png')

