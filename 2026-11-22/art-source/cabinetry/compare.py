"""Project real mesh front/top quads into the same material sampling space as the old box."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,struct,sys,json
project,src,dst=map(Path,sys.argv[1:4]);tex=np.asarray(Image.open(project/'Game/Assets/Resources/KinseiSurfaces/smoked_walnut_veneer_Diffuse.jpg').convert('RGB'))
W,H=500,205;sheet=Image.new('RGB',(2*W+16,3*(H+52)+15),(233,226,211));draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/meiryo.ttc',17)
def sample(u,v):return tex[((1-v)*tex.shape[0]).astype(int)%tex.shape[0],(u*tex.shape[1]).astype(int)%tex.shape[1]]
report={}
for row,(name,label,width,height,dims,axes) in enumerate([
 ('wall','客席奥壁・2.6 m幅の寄り',2.60,1.066,(18,6,.25),(0,1,2)),
 ('counter','店の腰板・2.1 m幅の寄り',2.10,.861,(4.45,.98,.78),(0,1,2)),
 ('stair','踏み板・幅1.90 m',1.90,.779,(1.9,1.60,.37),(0,2,1))]):
 with (src/(name+'.bin')).open('rb') as f:
  n=struct.unpack('<i',f.read(4))[0];data=np.frombuffer(f.read(20*n),'f4').reshape(-1,5)
  ni=struct.unpack('<i',f.read(4))[0];ix=np.frombuffer(f.read(),'i4').reshape(-1,3)
 v=data[:,:3];uv=data[:,3:]*[2,1];a,b,depth=axes
 normal=np.cross(v[ix[:,1]]-v[ix[:,0]],v[ix[:,2]]-v[ix[:,0]])
 centre=v[ix].mean(axis=1);areas=np.linalg.norm(normal,axis=1)
 assert np.all(areas>0)
 # A bevel can face away from the box centre; compare each triangle to its original face normal.
 counts=[]
 for axis,sign,w,h,vertical in [(2,1,dims[0],dims[1],row<2),(2,-1,dims[0],dims[1],row<2),(0,1,dims[2],dims[1],row<2),(0,-1,dims[2],dims[1],row<2),(1,1,dims[0],dims[2],dims[2]>dims[0]),(1,-1,dims[0],dims[2],dims[2]>dims[0])]:
  panels=int(np.ceil(w/(.56 if vertical else 2.42))*np.ceil(h/(2.42 if vertical else .56)))
  length=panels*(2 if panels==1 else 18);start=sum(counts)
  assert np.all(normal[start:start+length,axis]*sign>0);counts.append(length)
 assert sum(counts)==len(ix)
 assert np.allclose(np.ptp(v,axis=0),dims,atol=1e-5)
 fxy=np.array((width,height));xx,yy=np.meshgrid((np.arange(W)+.5)*width/W-width/2,height/2-(np.arange(H)+.5)*height/H)
 old=sample(2*(xx/dims[a]+.5),yy/dims[b]+.5).copy()
 mask=(abs(xx)>dims[a]/2)|(abs(yy)>dims[b]/2);old[mask]=[43,41,37]
 new=np.zeros_like(old)+np.array([43,41,37],dtype='uint8')
 for k,t in enumerate(ix):
  if normal[k,depth]<=0 or np.min(v[t,depth])<dims[depth]/2-.002:continue
  pt=v[t][:,[a,b]].copy();pt[:,0]=(pt[:,0]/width+.5)*W;pt[:,1]=(.5-pt[:,1]/height)*H
  x0,y0=np.maximum(0,np.floor(pt.min(0)).astype(int));x1,y1=np.minimum([W,H],np.ceil(pt.max(0)).astype(int))
  if x0>=x1 or y0>=y1:continue
  A=pt[1]-pt[0];B=pt[2]-pt[0];det=A[0]*B[1]-A[1]*B[0]
  if abs(det)<1e-10:continue
  X,Y=np.meshgrid(np.arange(x0,x1)+.5-pt[0,0],np.arange(y0,y1)+.5-pt[0,1])
  h=(X*B[1]-Y*B[0])/det;j=(A[0]*Y-A[1]*X)/det;inside=(h>=-.00001)&(j>=-.00001)&(h+j<=1.00001)
  u=uv[t,0];vv=uv[t,1]
  colors=sample(u[0]+(u[1]-u[0])*h+(u[2]-u[0])*j,vv[0]+(vv[1]-vv[0])*h+(vv[2]-vv[0])*j)
  new[y0:y1,x0:x1][inside]=(colors[inside]*(.7+.3*abs(normal[k,depth])/areas[k])).astype('uint8')
 for j,img in enumerate([old,new]):
  sheet.paste(Image.fromarray(img),(8+j*W,row*(H+52)+37))
  draw.text((13+j*W,row*(H+52)+8),('旧UV　' if j==0 else '新UV　')+label,font=font,fill='#362d2a')
 report[name]=dict(size_m=dims,vertices=n,triangles=ni//3,degenerate=0,inward=0)
sheet.save(dst/'comparison.jpg',quality=93,subsampling=0)
(dst/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
