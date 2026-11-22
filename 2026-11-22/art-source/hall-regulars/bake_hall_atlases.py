"""Bake hall-only color atlases over the established CC0 tailored garment UVs."""
from pathlib import Path
import struct,numpy as np
from PIL import Image,ImageFilter
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];ward=ROOT/'Game/Assets/Resources/KinseiWardrobe';out=ROOT/'Game/Assets/Resources/KinseiHallWardrobe'
b=(ward/'Single.bytes').read_bytes();count,indices=struct.unpack_from('<ii',b)
dtype=np.dtype([('p','<f4',3),('n','<f4',3),('uv','<f4',2),('bones','u1',4),('w','<f4',4)])
a=np.frombuffer(b,dtype,offset=8,count=count);tri=np.frombuffer(b,'<u2',offset=8+count*52).reshape(-1,3)
# Connected UV islands identify the entire necktie, including pale printed motifs.
parent=list(range(count))
def find(x):
 while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
 return x
for face in tri:
 for i in face[1:]:parent[find(int(i))]=find(int(face[0]))
groups={}
for i in range(count):groups.setdefault(find(i),[]).append(i)
tie_vertices=set()
for ids in groups.values():
 lo=a['p'][ids].min(0);hi=a['p'][ids].max(0)
 if 250<len(ids)<500 and lo[0]>-.04 and hi[0]<.04 and lo[1]>1.23 and hi[1]<1.41:tie_vertices.update(ids)
s=2048;original=np.array(Image.open(ward/'Navy.jpg').resize((s,s),Image.Resampling.LANCZOS),float);positions=np.zeros((s,s,3));covered=np.zeros((s,s),bool);tie_island=np.zeros((s,s),bool)
for face in tri:
 uv=a['uv'][face]*[s-1,-(s-1)]+[0,s-1];lo=np.maximum(0,np.floor(uv.min(0)).astype(int));hi=np.minimum(s-1,np.ceil(uv.max(0)).astype(int))
 if np.any(hi<lo):continue
 yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];p=np.stack([xx,yy],-1)-uv[0]
 v0=uv[1]-uv[0];v1=uv[2]-uv[0];den=v0[0]*v1[1]-v1[0]*v0[1]
 if abs(den)<1e-8:continue
 b1=(p[:,:,0]*v1[1]-v1[0]*p[:,:,1])/den;b2=(v0[0]*p[:,:,1]-p[:,:,0]*v0[1])/den;mask=(b1>=-.001)&(b2>=-.001)&(b1+b2<=1.001)
 xyz=a['p'][face[0]]+(a['p'][face[1]]-a['p'][face[0]])*b1[:,:,None]+(a['p'][face[2]]-a['p'][face[0]])*b2[:,:,None]
 if all(int(i) in tie_vertices for i in face):tie_island[lo[1]:hi[1]+1,lo[0]:hi[0]+1]|=mask
 positions[lo[1]:hi[1]+1,lo[0]:hi[0]+1][mask]=xyz[mask];covered[lo[1]:hi[1]+1,lo[0]:hi[0]+1]|=mask
r,g,blue=original.transpose(2,0,1);cloth=(blue>r*1.15)&(blue>g*1.1)&(g<110);tie=tie_island;lum=original@[.30,.59,.11]
soft=np.asarray(Image.fromarray(np.uint8(lum)).filter(ImageFilter.GaussianBlur(10)),float)
rng=np.random.default_rng(1414);grain=rng.normal(0,.025,(s,s))
normal_source=np.array(Image.open(ward/'SingleNormal.png').resize((s,s),Image.Resampling.LANCZOS))
for name,color in [('Kontani',(48,59,82)),('Ura',(108,68,72))]:
 rgb=original.copy();shade=np.clip((lum/45)**.85,.45,1.5);rgb[cloth]=shade[cloth,None]*color
 if name=='Kontani':
  # Continuous 16 mm chalk lines, measured in the fitted garment's rest metres.
  d=np.abs((positions[:,:,0]+.008)%.016-.008);line=np.exp(-.5*(d/.00029)**2)*covered
  rgb[cloth]+=line[cloth,None]*np.array([23,28,41]);rgb[tie]=np.array([39,42,57])*(.95+.07*np.cos(positions[tie,0]*80))[:,None]
 else:
  rgb[cloth]=np.clip(soft[cloth,None]/45,.55,1.5)*np.array(color)*(1+grain[cloth,None])
  rgb[tie]=np.array([82,25,34])*(.95+.07*np.cos(positions[tie,0]*80))[:,None]
  x,y=positions[:,:,0],positions[:,:,1]
  for center in [1.276,1.342]:
   dist=np.abs(y-center-x*1.25);fine=np.abs(y-(center-.005)-x*1.25)
   band=tie&covered&((dist<.0015)|(fine<.00055));rgb[band]=np.array([157,117,55])
 Image.fromarray(np.uint8(np.clip(rgb,0,255))).save(out/(name+'Atlas.png'))
 normal=normal_source.copy();normal[tie]=[128,128,255]
 if name=='Ura':
  nx=rng.normal(0,2,(s,s));ny=rng.normal(0,2,(s,s));normal[cloth,0]=np.clip(128+nx[cloth],0,255);normal[cloth,1]=np.clip(128+ny[cloth],0,255);normal[cloth,2]=255
 Image.fromarray(normal).save(out/(name+'Normal.png'))
# The two original connected lapel islands are widened without replacing the skinned cut.
parent=list(range(count))
def find(x):
 while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
 return x
for face in tri:
 for i in face[1:]:parent[find(int(i))]=find(int(face[0]))
groups={}
for i in range(count):groups.setdefault(find(i),[]).append(i)
p=a['p'].copy();selected=[]
for ids in groups.values():
 points=p[ids];lo,hi=points.min(0),points.max(0)
 if 180<len(ids)<250 and lo[1]>1.13 and hi[1]>1.39 and hi[1]<1.41 and hi[2]>.12:
  selected+=ids
  # Preserve inner roll, neck attachment and notch while broadening the outer leaf.
  for i in ids:
   x,y,z=p[i];edge=np.clip((abs(x)-.045)/.085,0,1);vertical=np.clip((y-1.15)/.08,0,1)*np.clip((1.41-y)/.045,0,1);p[i,0]+=np.sign(x)*.030*edge*vertical;p[i,2]+=.002*edge*vertical
with (out/'UraLapelFit.bytes').open('wb') as f:f.write(struct.pack('<i',count));f.write(p.astype('<f4').tobytes())
(HERE/'atlas-bake.txt').write_text(f'Existing Single garment: {count} vertices; {len(tri)} triangles. Widened original lapel vertices: {len(selected)}. Output atlases: 2048 x 2048. Pattern pitch 16 mm; gold band 3 mm plus 1.1 mm fine line.\n',encoding='utf-8')
print('Baked atlases; widened lapel vertices',len(selected))
