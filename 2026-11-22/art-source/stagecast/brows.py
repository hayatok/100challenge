from pathlib import Path
from PIL import Image,ImageDraw
import sys
import numpy as np
src,target=map(Path,sys.argv[1:])
rng=np.random.default_rng(792)
def paint(label,skin,dest,brow_base,shade):
 pos=[];uv=[];tri=[];tuv=[]
 for line in (src/f'Head{label}.obj').read_text().splitlines():
  a=line.split()
  if not a:continue
  if a[0]=='v':pos.append([float(x) for x in a[1:]])
  elif a[0]=='vt':uv.append([float(x) for x in a[1:3]])
  elif a[0]=='f':
   ids=[l.split('/') for l in a[1:]]
   for i in range(1,len(ids)-1):
    tri.append([int(ids[j][0])-1 for j in (0,i,i+1)])
    tuv.append([int(ids[j][1])-1 for j in (0,i,i+1)])
 v=np.array(pos)[np.array(tri)]; u=np.array(uv)[np.array(tuv)]
 select=np.where((v[:,:,2].max(1)>.078)&(v[:,:,1].max(1)>brow_base-.012)&(v[:,:,1].min(1)<brow_base+.017))[0]
 v=v[select];u=u[select]
 a=v[:,1]-v[:,0];b=v[:,2]-v[:,0]
 area=a[:,0]*b[:,1]-a[:,1]*b[:,0]
 area[np.abs(area)<1e-10]=1e20
 im=Image.open(skin).convert('RGB')
 mark=Image.new('RGBA',im.size,(0,0,0,0)); brush=ImageDraw.Draw(mark)
 def measure(x,y):
  d=np.array((x,y))-v[:,0,:2]
  p=(d[:,0]*b[:,1]-d[:,1]*b[:,0])/area
  q=(a[:,0]*d[:,1]-a[:,1]*d[:,0])/area
  good=np.flatnonzero((p>=0)&(q>=0)&((p+q)<=1)&(abs(area)<1))
  if not len(good):return None
  z=v[good,0,2]+p[good]*a[good,2]+q[good]*b[good,2]
  ix=good[z.argmax()]
  tex=u[ix,0]*(1-p[ix]-q[ix])+p[ix]*u[ix,1]+q[ix]*u[ix,2]
  return (float(tex[0]*im.width),float((1-tex[1])*im.height))
 for side in (-1,1):
  # Fine painted hairs follow the face UV rather than floating as geometry.
  for _ in range(650):
   t=rng.random()
   x=.014+.031*t
   top=brow_base+.0039*np.sin(np.pi*t*.9)-.0037*t**3+side*.00075
   y=top+rng.normal(0,(.0013-.0008*t))
   length=rng.uniform(.0014,.0042)
   rise=length*(.86-1.05*t)
   sweep=length*(.51+.47*t)
   end=measure(side*(x+sweep),y+rise)
   start=measure(side*x,y)
   if start is None or end is None or np.linalg.norm(np.subtract(start,end))>30:continue
   rgb=tuple(int(q+rng.integers(-8,9)) for q in shade)
   brush.line((start,end),fill=(*rgb,int(rng.integers(108,199))),width=int(rng.choice((1,1,2))))
 Image.alpha_composite(im.convert('RGBA'),mark).convert('RGB').save(dest)

for name,height,shade in [('Singer',.1275,(43,32,33))]:
 image=src/f'Skin{name}.png'
 paint(name,image,target/image.name,height,shade)
