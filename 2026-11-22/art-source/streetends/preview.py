"""CPU projection of actual emitted quads, with flat QA colours (no Unity lights)."""
import struct,sys
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
p=Path(sys.argv[1]);out=Path(sys.argv[2])
col={'stone':(140,126,108),'sheet':(112,125,127),'timber':(80,65,52),'window':(235,192,123),'road':(75,73,73),'roof':(82,91,98),'canal':(56,92,94)}
col.update(fixture=(111,122,120),opal=(239,196,132),tube=(201,216,202),signal=(100,159,124))
with p.open('rb') as f:
    meshes={}
    while k:=f.read(1):
        name=f.read(k[0]).decode();n=struct.unpack('<i',f.read(4))[0]
        meshes[name]=np.frombuffer(f.read(12*n),np.float32).reshape(-1,4,3)
def draw(eye,target,label):
    eye=np.array(eye); v=np.array(target)-eye;v=v/np.linalg.norm(v)
    r=np.cross([0,1,0],v); r=r/np.linalg.norm(r); u=np.cross(v,r)
    im=Image.new('RGB',(760,390),(105,119,139));g=ImageDraw.Draw(im);faces=[]
    for name,q in meshes.items():
        rel=q-eye; d=rel@v
        # Clip near plane for the large ground surfaces crossing the edge of the train view.
        for i in np.flatnonzero(d.max(axis=1)>.18):
            poly=list(zip(rel[i],d[i]));clipped=[]
            for (a,da),(b,db) in zip(poly[-1:]+poly[:-1],poly):
                if (da>.18)!=(db>.18):
                    clipped.append(a+(b-a)*((.18-da)/(db-da)))
                if db>.18:clipped.append(b)
            if len(clipped)<3:continue
            t=np.array(clipped);dep=t@v; xy=np.column_stack([380+425*(t@r)/dep,190-425*(t@u)/dep])
            if xy[:,0].max()<0 or xy[:,0].min()>760 or xy[:,1].max()<0 or xy[:,1].min()>390:continue
            norm=np.cross(q[i,1]-q[i,0],q[i,2]-q[i,0]);norm/=max(1e-10,np.linalg.norm(norm))
            bright=.74+.22*max(0,norm@[.6,.7,.35]); c=tuple(int(a*bright) for a in col[name])
            faces.append((float(dep.mean()),xy.astype(int).flatten().tolist(),c))
    for _,pts,c in sorted(faces,key=lambda t:-t[0]):g.polygon(pts,fill=c)
    g.rectangle((0,0,759,25),fill=(26,28,31));g.text((10,6),label,fill='white')
    return im
views=[((-18.67,1.65,-10.17),(-42,2,-10.17),'West / street at reported position'),((19,1.65,-10.1),(47,2,-10.65),'East / street'),((-26,7.7,-23.75),(-39,3,-8),'West / elevated train'),((31,7.7,-23.75),(34,2,-8),'East / elevated train'),((-28,19,-16),(-33,0,-9),'West / overhead'),((31,20,-14),(31,0,-8),'East / overhead')]
sheet=Image.new('RGB',(1520,1170))
for i,view in enumerate(views):sheet.paste(draw(*view),((i%2)*760,(i//2)*390))
sheet.save(out/'views.jpg',quality=88)
for name,q in meshes.items():print(name,len(q)*2,'triangles',q.min(axis=(0,1)),q.max(axis=(0,1)))
print('Total triangles',2*sum(len(q) for q in meshes.values()))
