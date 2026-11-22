"""Build UV-preserving resident heads from MakeHuman base.obj and macro targets.

Usage: python heads.py <base.obj> <target directory> <human_parts.json> <skins01/skins> <output> <parts-output.json>
Run the existing build_human_parts.py subdivision/export pass on the resulting JSON.
"""
from pathlib import Path
import sys,json
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
base,targets,parts,skins,out,dest=map(Path,sys.argv[1:])
v=[]; uv=[]; by_uv={}
for line in base.read_text().splitlines():
    w=line.split()
    if not w:continue
    if w[0]=='v':v.append(list(map(float,w[1:4])))
    elif w[0]=='vt':uv.append(tuple(map(float,w[1:3])))
    elif w[0]=='f':
        for corner in w[1:]:
            i,j,*_=corner.split('/')
            by_uv[uv[int(j)-1]]=int(i)-1
v=np.array(v)
def morph(file):
    delta=np.zeros_like(v)
    for line in (targets/(file+'.target')).read_text().splitlines():
        w=line.split()
        if w and w[0].isdigit():delta[int(w[0])]=list(map(float,w[1:4]))
    return delta
reference=json.loads(parts.read_text())[0]
indices=np.empty(len(reference['verts']),int)
for face,coords in zip(reference['faces'],reference['uv']):
    for i,c in zip(face,coords):indices[i]=by_uv[tuple(c)]
female=v+morph('universal-female-young-averagemuscle-averageweight')
young=morph('asian-female-young');old=morph('asian-female-old')
ref=np.array(reference['verts'])
orbital=(np.abs(np.abs(ref[:,0])-.03)<.016)&(np.abs(ref[:,1]-.1107)<.007)&(ref[:,2]>.086)
result=[]
for name,age,skin in [('Singer',.36,'young')]:
    points=(female+young*(1-age)+old*age)[indices]*.1
    # Align the two lid rims to the actor's existing gaze articulation; preserve their sockets' separation.
    shift=np.median(ref[orbital]-points[orbital],axis=0)
    shift[0]=0
    points+=shift
    x,y,z=points.T.copy()
    front=np.clip((z-.055)/.035,0,1)
    # A broad cheek and long tapering chin echo the lacquer sleeve portrait.
    points[:,0]*=1+.039*np.exp(-((y-.087)/.027)**2)-.065*np.exp(-((y-.020)/.025)**2)
    points[:,2]+=.003*np.exp(-((np.abs(x)-.04)/.024)**2-((y-.085)/.021)**2)*front
    points[:,1]+=.0027*np.exp(-((np.abs(x)-.022)/.012)**2-((y-.046)/.012)**2)*front
    # Retain the original collar overlap at the neck crop.
    neck=np.clip((.0-ref[:,1])/.060,0,1)[:,None]
    points=points*(1-neck)+ref*neck
    result.append(dict(name='Head'+name,verts=points.tolist(),faces=reference['faces'],uv=reference['uv']))
    src=next((skins/('onlytheghosts_'+skin+'_eurasian_female')).glob('*.png'))
    atlas=Image.open(src).convert('RGB').resize((2048,2048),Image.Resampling.LANCZOS)
    mask=Image.new('L',atlas.size);draw=ImageDraw.Draw(mask)
    for part in [reference,*json.loads(parts.read_text())[-2:]]:
        for f in part['uv']:draw.polygon([(u*2048,(1-vv)*2048) for u,vv in f],fill=255)
    Image.composite(atlas,Image.new('RGB',atlas.size,(157,115,94)),mask.filter(ImageFilter.MaxFilter(9))).save(out/('Skin'+name+'.png'))
    print(name,points[orbital].mean(0),points.min(0),points.max(0))
dest.write_text(json.dumps(result))
