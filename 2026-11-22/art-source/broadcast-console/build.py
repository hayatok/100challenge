"""Build metre-scale console parts and the four quadrants of their colour atlas, offline."""
from pathlib import Path
from collections import defaultdict
from math import sin, cos, pi
import hashlib,json,struct
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
OUT=HERE.parent.parent/'Game/Assets/Resources/KinseiBroadcastConsole'
OUT.mkdir(parents=True,exist_ok=True)
atlas=Image.new('RGB',(1024,1024))
patches=['enamel-a','enamel-b','brass-a','brass-b']
for record in json.loads((HERE/'originals/runs.json').read_bytes()):
    src=HERE/'originals'/(record['name']+'.png')
    assert hashlib.sha256(src.read_bytes()).hexdigest()==record['sha256']
    im=Image.open(src).convert('RGB')
    k=patches.index(record['name'])
    if k<2:
        if k==1: im=im.crop((1,0,1002,506))
        im=im.point(lambda t:min(255,round(12+t*1.47)))
    elif k==2:
        im=im.crop((85,85,939,939))
    else:
        # Remove the studio edge gradients, mirror the surviving band around the circumference.
        im=im.crop((178,102,841,918)).resize((256,512),Image.Resampling.LANCZOS)
        band=Image.new('RGB',(512,512));band.paste(im);band.paste(im.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(256,0));im=band
    atlas.paste(im.resize((512,512),Image.Resampling.LANCZOS),(k%2*512,k//2*512))
atlas.save(OUT/'Finish.jpg',quality=94,subsampling=0)

groups=defaultdict(lambda:[[],[],{}])
def emit(name,points,uv=None,patch=0):
    vertices,indices,cache=groups[name]
    points=np.asarray(points)
    n=np.cross(points[1]-points[0],points[2]-points[0]);n=n/np.linalg.norm(n)
    uv=uv if uv is not None else [(0,0)]*len(points)
    ids=[]
    for p,(u,v) in zip(points,uv):
        t=((patch%2+.008+.984*u)*.5,(1-patch//2+.008+.984*v)*.5)
        row=tuple(np.round([*p,*n,*t],7))
        if row not in cache:cache[row]=len(vertices);vertices.append(row)
        ids.append(cache[row])
    for j in range(1,len(ids)-1):indices.extend((ids[0],ids[j],ids[j+1]))
def rect(w,h,r,z,cx=0,cy=0):
    # Rounded XY profile, CCW viewed from the operator at +Z.
    points=[]
    for j,(sx,sy) in enumerate([(1,1),(-1,1),(-1,-1),(1,-1)]):
        for k in range(7):
            a=(j+k/6)*pi/2
            points.append((cx+sx*(w/2-r)+r*cos(a),cy+sy*(h/2-r)+r*sin(a),z))
    return np.array(points)
def wall(name,a,b,patch=1):
    for i in range(len(a)):
        j=(i+1)%len(a)
        p=[a[i],a[j],b[j],b[i]]
        # On the long top/bottom use X as U, around the short returns use Y.
        span=a[j]-a[i]
        uv=[((q[0]/.56+.5) if abs(span[0])>abs(span[1]) else (q[1]/.16+.5),q[2]/.19+.5) for q in p]
        emit(name,p,uv,patch)
def cap(name,ring,patch=0):
    mid=ring.mean(axis=0)
    low,high=ring[:,:2].min(0),ring[:,:2].max(0)
    for i in range(len(ring)):
        p=[mid,ring[i],ring[(i+1)%len(ring)]]
        emit(name,p,[(np.asarray(q)[:2]-low)/(high-low) for q in p],patch)
# Stepped lid: 2.4mm deep reveal and rolled 3mm nose.
sections=[(.547,.147,.015,-.095),(.560,.160,.020,-.089),(.560,.160,.020,.066),
          (.555,.155,.018,.068),(.555,.155,.018,.0705),(.560,.160,.020,.0725),
          (.560,.160,.020,.088),(.557,.157,.018,.092),(.550,.150,.016,.095)]
rows=[rect(*r) for r in sections]
cap('case',rows[0][::-1],1)
for i in range(len(rows)-1):wall('case',rows[i],rows[i+1])
cap('case',rows[-1])
# Small fasteners with a recessed straight slot cut between two halves of the head.
def screw(x,y,angle):
    count=16
    centre=np.array([x,y,.0951]);ca,sa=cos(angle),sin(angle)
    def vertex(u,v,h):return centre+[ca*u-sa*v,sa*u+ca*v,h]
    for side in (1,-1):
        pts=[]
        for j in range(count+1):
            a=.16+(pi-.32)*j/count
            pts.append(vertex(side*.0036*cos(a),side*.0036*sin(a),.0017))
        emit('steel',pts)
        for i in range(len(pts)):
            j=(i+1)%len(pts);p,q=pts[i],pts[j]
            r=p.copy();r[2]-=.0017;s=q.copy();s[2]-=.0017
            emit('steel',[r,s,q,p])
for x,y,a in [(-.252,.056,.61),(.250,.056,1.13),(-.252,-.055,2.44),(.250,-.055,-.3)]:screw(x,y,a)
def profile(w,h,z):
    a=np.arange(64)*2*pi/64
    def power(v):return np.sign(v)*abs(v)**.53
    return np.column_stack((-.104+w*power(np.cos(a)),.005+h*power(np.sin(a)),np.full(64,z)))
# The final lip follows the original superelliptic CRT opening; the glass retains its live UV.
rim=[(.120,.071,.0951),(.122,.073,.099),(.121,.072,.105),(.1175,.069,.110),(.106,.0645,.111)]
loops=[profile(*row) for row in rim]
for a,b in zip(loops,loops[1:]):wall('trim',a,b)
wall('gasket',loops[-1],profile(.1038,.0629,.1118))
wall('glasslip',profile(.1046,.0636,.1119),profile(.1038,.0629,.1124))
# 46 mm face, thirty-six axial flutes physically relieved by 0.75 mm.
def dial(name,centre):
    cx,cy,cz=centre;N=144
    def ring(radius,z,flute):
        return np.array([(cx+(radius-flute*(1-cos(i*pi/2))*.5)*cos(i*2*pi/N),
                          cy+(radius-flute*(1-cos(i*pi/2))*.5)*sin(i*2*pi/N),cz+z) for i in range(N)])
    rows=[ring(r,z,f) for r,z,f in [(.018,-.013,0),(.021,-.0115,0),(.023,-.009,.00075),
                  (.023,.0075,.00075),(.0223,.010,0),(.021,.011,0),(.021,.012,0),(.0195,.013,0)]]
    for k,(a,b) in enumerate(zip(rows,rows[1:])):
        for i in range(N):
            j=(i+1)%N
            emit(name,[a[i],a[j],b[j],b[i]],[(i/N,k/7),((i+1)/N,k/7),((i+1)/N,(k+1)/7),(i/N,(k+1)/7)],3)
    mid=(cx,cy,cz+.013)
    for i in range(N):
        p=[mid,rows[-1][i],rows[-1][(i+1)%N]]
        emit(name,p,[(.5+(v[0]-cx)/.0395,.5+(v[1]-cy)/.0395) for v in p],2)
dial('gain',(.076,-.018,.108))
dial('level',(0,0,0))
# Bevels stop below the unchanged two finger contact surfaces (x +/-4.5 mm at z=20 mm).
marker=[rect(w,h,r,z,0,.012) for w,h,r,z in [(.008,.017,.001,.0105),(.009,.018,.0013,.012),(.009,.018,.0013,.022),(.0075,.0165,.001,.0235)]]
for a,b in zip(marker,marker[1:]):wall('ivory',a,b)
cap('ivory',marker[-1])
with (OUT/'Console.bytes').open('wb') as out:
    out.write(b'KSG1'+struct.pack('<I',len(groups)))
    for key,(verts,indices,_) in groups.items():
        assert np.isfinite(verts).all() and max(indices)<len(verts)<65535
        out.write(bytes([len(key)])+key.encode()+struct.pack('<II',len(verts),len(indices)))
        out.write(np.array(verts,'<f4').tobytes()+np.array(indices,'<i4').tobytes())
        print(key,len(verts),len(indices)//3)
