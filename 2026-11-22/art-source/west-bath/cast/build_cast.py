from pathlib import Path
import numpy as np,struct,json
from PIL import Image,ImageFilter,ImageDraw
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];src=ROOT/'Game/Assets/Resources/KinseiWardrobe';out=ROOT/'Game/Assets/Resources/KinseiWestCast';out.mkdir(exist_ok=True,parents=True)
dt=np.dtype([('p','<f4',3),('n','<f4',3),('uv','<f4',2),('b','u1',4),('w','<f4',4)])
report={};rng=np.random.default_rng(1515)
for role,cut,palette,cloth_color in [('Fumiko','Single','Navy',(39,70,61)),('Kiichi','Single','Navy',(103,74,53)),('Seo','Double','Rust',(56,60,48))]:
 raw=(src/(cut+'.bytes')).read_bytes();n,nt=struct.unpack_from('<ii',raw);a=np.frombuffer(raw,dt,count=n,offset=8).copy();tri=np.frombuffer(raw,'<u2',offset=8+n*52).reshape(-1,3);par=list(range(n))
 def find(i):
  while par[i]!=i:par[i]=par[par[i]];i=par[i]
  return i
 for face in tri:
  for i in face[1:]:par[find(i)]=find(face[0])
 groups={}
 for i in range(n):groups.setdefault(find(i),[]).append(i)
 remove=set()
 for ids in groups.values():
  p=a['p'][ids];lo,hi=p.min(0),p.max(0);k=len(ids)
  necktie=lo[0]>-.045 and hi[0]<.045 and lo[1]>1.23 and hi[1]<1.42 and k>150
  if necktie:remove.update(ids)
  if role!='Seo':
   # Remove tailored blazer lapels/collar and breast welt, retain the fitted skinned coat.
   if k in [222,211,105] or(k==100 and lo[1]>1.39)or k in [470,378]:remove.update(ids)
   if k==65 and hi[1]>1.02 and hi[1]<1.19:remove.update(ids) # jacket front buttons
  if role=='Seo':
   pass
 keep=~np.isin(tri[:,0],list(remove));tri=tri[keep]
 # Open the central champagne shirt neck, rather than just recolouring a tie.
 if role=='Seo':
  c=a['p'][tri].mean(1);hole=(abs(c[:,0])<.025)&(c[:,1]>1.355)&(c[:,1]<1.435)&(c[:,2]>.035);tri=tri[~hole]
 with (out/(role+'Cut.bytes')).open('wb') as f:f.write(struct.pack('<ii',n,tri.size));f.write(a.tobytes());f.write(tri.astype('<u2').tobytes())
 im=Image.open(src/(palette+'.jpg')).convert('RGB').resize((2048,2048));rgb=np.asarray(im,float);r,g,b=rgb.transpose(2,0,1);lum=rgb@[.3,.59,.11];soft=np.asarray(Image.fromarray(np.uint8(lum)).filter(ImageFilter.GaussianBlur(8)),float)
 if role=='Seo':mask=(r>g*1.12)&(r>b*1.4)&(r>65);normal=src/(cut+'Normal.png');clothmask=mask
 else:clothmask=(b>r*1.15)&(b>g*1.1)&(g<110)
 factor=np.clip(soft/(85 if role=='Seo' else 45),.5,1.65);rgb[clothmask]=factor[clothmask,None]*cloth_color
 # Trouser islands are separated in UV; use their original dark cloth where sampled by vertices.
 grain=rng.normal(0,.025,(2048,2048));rgb[clothmask]*=(1+grain[clothmask,None])
 if role=='Seo':
  white=(r>130)&(g>125)&(b>100);rgb[white]=np.clip(lum[white,None]/210,.55,1.35)*np.array([218,203,163])
 if role!='Seo':
  pants_vertices=set()
  for ids in groups.values():
   if a['p'][ids,1].min()<.15:pants_vertices.update(ids)
  pants=Image.new('L',(2048,2048));draw=ImageDraw.Draw(pants)
  for face in tri:
   if all(int(i) in pants_vertices for i in face):draw.polygon([(float(u)*2048,(1-float(v))*2048)for u,v in a['uv'][face]],fill=255)
  mask=np.asarray(pants)>0;rgb[mask]=np.clip(soft[mask,None]/45,.5,1.4)*np.array([56,54,47]if role=='Fumiko'else[49,52,51])
 Image.fromarray(np.uint8(np.clip(rgb,0,255))).save(out/(role+'Cloth.png'))
 # Remove the base pinstripe normal from casual knit/twill; retain the cut's major seams.
 norm=np.array(Image.open(src/(cut+'Normal.png')).resize((2048,2048)).convert('RGB'));norm[clothmask]=[128,128,255]
 nx=rng.normal(0,2.3 if role=='Fumiko' else 1.2,(2048,2048));ny=rng.normal(0,2.3 if role=='Fumiko' else 1.2,(2048,2048));norm[clothmask,0]=np.clip(128+nx[clothmask],0,255);norm[clothmask,1]=np.clip(128+ny[clothmask],0,255)
 Image.fromarray(norm).save(out/(role+'ClothNormal.png'));report[role]={'vertices':n,'triangles':len(tri),'removed_island_vertices':len(remove)}
# Cotton/terry detail, original deterministic patterns.
n=512;y,x=np.mgrid[:n,:n];grain=rng.normal(0,.025,(n,n));cotton=np.clip(.84+grain+.025*np.sin(x*2),0,1);Image.fromarray(np.uint8(cotton*255)).convert('RGB').save(out/'TerryCotton.png')
hair=np.clip(.69+np.sin(x*.7+y*.3)*.11+rng.normal(0,.025,(n,n)),0,1);Image.fromarray(np.uint8(hair*255)).convert('RGB').save(out/'SilverHair.png')
(HERE/'generation.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(report)
