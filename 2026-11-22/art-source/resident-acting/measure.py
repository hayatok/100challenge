"""CPU deformation probe for the metre-scale source OBJ, prior to head tracking.
Mirrors LipOffsets and the existing mandible skin weights in ImportSkin.
Run with the 2026-11-22/Game path as the first argument.
"""
from pathlib import Path
import sys,json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
root=Path(sys.argv[1])/'Assets/Resources'
out=Path(__file__).parent
def ease(a,b,v):
 t=np.clip((v-a)/(b-a),0,1);return t*t*(3-2*t)
def read(path):
 points=[];faces=[]
 for line in path.read_text().splitlines():
  if line.startswith('v '):points.append(list(map(float,line.split()[1:4])))
  if line.startswith('f '):
   ids=[int(c.split('/')[0])-1 for c in line.split()[1:]]
   faces.extend((ids[0],ids[j],ids[j+1]) for j in range(1,len(ids)-1))
 return np.array(points),np.array(faces)
def deform(v,seam,jawline,opening,rounding):
 x,y,z=v.T;h=y-seam
 band=1-ease(.005,.017,abs(h))
 mask=(1-ease(.010,.030,abs(x)))*band*ease(.082,.100,z); lower=1-ease(-.00065,.00065,h)
 om=np.column_stack((x*0,(.0013+(-.0046-.0013)*lower)*mask,-.0007*lower*mask))
 mask=(1-ease(.022,.033,abs(x)))*band*ease(.082,.102,z)
 rm=np.column_stack((-.095*x*mask,x*0,.0026*mask))
 p=v+opening*om+rounding*rm
 angle=np.deg2rad(opening*2.8);co,si=np.cos(angle),np.sin(angle)
 cy,cz=.046,-.033
 rotated=np.column_stack((p[:,0],cy+co*(p[:,1]-cy)-si*(p[:,2]-cz),cz+si*(p[:,1]-cy)+co*(p[:,2]-cz)))
 weight=ease(.028,.080,z)*(1-ease(jawline-.009,jawline+.004,y))*ease(-.026,-.008,y)
 return p+(rotated-p)*weight[:,None],om,rm
def normals(p,f):
 a,b,c=p[f].transpose(1,0,2);return np.cross(b-a,c-a)
def render(canvas,xy,v,f):
 angle=.22;rot=np.array([[np.cos(angle),0,np.sin(angle)],[0,1,0],[-np.sin(angle),0,np.cos(angle)]])
 p=v@rot.T
 uv=np.column_stack(((p[:,0]-.021)*2450+123,138-(p[:,1]-.039)*2450))
 keep=(p[f,2].mean(1)>.067)&(p[f,1].mean(1)<.092)
 ff=f[keep];n=normals(p,ff);n/=np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-12)
 light=np.abs(n@np.array([-.48,.35,.80]));draw=ImageDraw.Draw(canvas)
 for k in np.argsort(p[ff,2].mean(1)):
  pts=[(xy[0]+int(u),xy[1]+int(vv)) for u,vv in uv[ff[k]]]
  if min(y for x,y in pts)<xy[1] or max(y for x,y in pts)>xy[1]+209:continue
  shade=int(65+160*light[k]);draw.polygon(pts, fill=(shade,int(shade*.86),int(shade*.75)))
sheet=Image.new('RGB',(820,730),(28,26,27));d=ImageDraw.Draw(sheet)
for j,name in enumerate(('REST','OPEN','ROUNDED')):d.text((32+j*265,8),name,fill='white')
result={}
for i,(name,file,seam,jawline) in enumerate([('Sumiko','KinseiResidents/HeadSumiko',.0484,.035),('Hyodo','KinseiCast/HeadYoung',.03837,.030),('Murase','KinseiResidents/HeadMurase',.0483,.035)]):
 v,f=read(root/(file+'.obj'));q,om,rm=deform(v,seam,jawline,1,0);r,_,_=deform(v,seam,jawline,.65,1)
 n=normals(v,f);n2=normals(q,f);good=np.linalg.norm(n,axis=1)>1e-10
 mid=(abs(v[:,0])<.006)&(v[:,2]>.10)
 lower=mid&(v[:,1]<seam-.002)&(v[:,1]>seam-.008)
 upper=mid&(v[:,1]>seam+.002)&(v[:,1]<seam+.008)
 dd=(q-v)*1000
 result[name]=dict(vertices=len(v),triangles=len(f),upper_lower_separation_mm=round(float(dd[upper,1].mean()-dd[lower,1].mean()),3),
   central_rim_gap_rest_mm=round(float((v[520,1]-v[523,1])*1000),3),central_rim_gap_open_mm=round(float((q[520,1]-q[523,1])*1000),3),lower_lip_down_mm=round(float(-dd[lower,1].mean()),3),upper_lip_up_mm=round(float(dd[upper,1].mean()),3),
   largest_displacement_mm=round(float(np.linalg.norm(dd,axis=1).max()),3),
   reversed_nondegenerate_triangles=int(((n*n2).sum(1)[good]<0).sum()),neck_or_eye_morph_mm=round(float(np.linalg.norm(om[(v[:,1]<0)|(v[:,1]>.08)],axis=1).max()*1000),4))
 for j,points in enumerate([v,q,r]):render(sheet,(j*265+8,i*231+30),points,f)
 d.text((8,i*231+235),name,fill='white')
sheet.save(out/'source-lip-comparison.png')
(out/'source-measurements.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
