from pathlib import Path
import math, struct, numpy as np
from shapely.geometry import Polygon
from shapely.ops import triangulate
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[2]
assets=root/'Game/Assets/Resources/KinseiPrintworks'
p=[];n=[];t=[];m=[]
palette=[(.13,.22,.205,.37,.48),(.64,.45,.215,.76,.52),(.355,.337,.289,.72,.50),(.060,.070,.068,.32,.33),(.76,.68,.49,.13,.35),(.30,.22,.125,.65,.34)]
groups=[]
def unit(x):
 a=np.array(x,float);return a/max(np.linalg.norm(a),1e-12)
def face(a,b,c,material,out,normals=None):
 a,b,c=map(np.array,(a,b,c));normal=unit(np.cross(b-a,c-a))
 if np.linalg.norm(normal)<.1:return
 if np.dot(normal,out)<0:b,c=c,b;normal=-normal;normals=None if normals is None else [normals[0],normals[2],normals[1]]
 start=len(p);p.extend((a,b,c));n.extend(normals if normals is not None else [normal]*3);m.extend([material]*3);t.append((start,start+1,start+2))
def quad(a,b,c,d,material,out):
 face(a,b,c,material,out);face(a,c,d,material,out)
def shape(contour,levels,coord,mat):
 # Convex and concave cross-sections share the same front and back triangulation.
 rings=[np.array([coord(x,y,depth) for x,y in contour]) for depth in levels]
 poly=Polygon(contour)
 assert poly.is_valid and poly.area>0
 for j in (0,-1):
  depth=levels[j];direction=unit(rings[j][0]-rings[-1 if j==0 else 0][0])
  for tri in triangulate(poly):
   if not poly.covers(tri):continue
   dots=[coord(x,y,depth) for x,y in list(tri.exterior.coords)[:3]]
   face(*dots,mat,direction)
 for ring,nextRing in zip(rings,rings[1:]):
  for i in range(len(contour)):
   k=(i+1)%len(contour);x,y=contour[i];xx,yy=contour[k]
   dx,dy=xx-x,yy-y;sgn=1 if poly.exterior.is_ccw else -1
   out=np.array(coord(x+sgn*dy,y-sgn*dx,0))-coord(x,y,0)
   quad(ring[i],ring[k],nextRing[k],nextRing[i],mat,out)
def roundrect(w,h,r,steps=4):
 result=[]
 for cx,cy,start in [(w/2-r,h/2-r,0),(-w/2+r,h/2-r,90),(-w/2+r,-h/2+r,180),(w/2-r,-h/2+r,270)]:
  for a in np.linspace(start,start+90,steps):
   a=np.radians(a);result.append((cx+r*np.cos(a),cy+r*np.sin(a)))
 return result
def slab(x,y,z,w,h,depth,rad,bevel,mat,axis='y'):
 def coord(a,b,c):return np.array((x+a,y+c,z+b) if axis=='y' else (x+a,y+b,z+c))
 # Separate fillet strips from broad, perfectly planar caps.
 rings=[]
 profile=[(-depth/2,bevel),(-depth/2+bevel,0),(depth/2-bevel,0),(depth/2,bevel)]
 if bevel>1: profile=[profile[0],(-depth/2+.30*bevel,.31*bevel),*profile[1:3],(depth/2-.30*bevel,.31*bevel),profile[-1]]
 for dy,inset in profile:
  rings.append([coord(a,b,dy) for a,b in roundrect(w-2*inset,h-2*inset,max(.1,rad-inset),4 if w>12 else 2)])
 for j,(a,b) in enumerate(zip(rings,rings[1:])):
  for i in range(len(a)):
   k=(i+1)%len(a);mid=(a[i]+a[k]+b[i]+b[k])*.25
   lateral=mid-coord(0,0,np.dot(mid-coord(0,0,0),coord(0,0,1)-coord(0,0,0)))
   out=unit(lateral)+(coord(0,0,1)-coord(0,0,0))*([-1,-.45,0,.45,1] if len(profile)==6 else [-1,0,1])[j]
   quad(a[i],a[k],b[k],b[i],mat,out)
 for j in [0,-1]:
  r=rings[j];center=np.mean(r,axis=0);out=center-coord(0,0,0)
  for i in range(len(r)):face(center,r[i],r[(i+1)%len(r)],mat,out)
def arch(w,height,bottom,r):
 result=[(-w/2,bottom)]
 for side in [-1,1]:
  cx=side*(w/2-r)
  for a in np.linspace(180 if side<0 else 90,90 if side<0 else 0,15):
   a=np.radians(a);result.append((cx+r*np.cos(a),height-r+r*np.sin(a)))
 result.append((w/2,bottom));return np.array(result)
def frame(front,back,w,h,iw,ih,r,ir,mat):
 # Three front rolled-edge sections. Each side of the tunnel has a distinct normal.
 rings=[]
 for z,s in [(front,2.4),(front+.8,.8),(front+2.8,0),(back-2,0),(back,1.4)]:
  outer=arch(w-2*s,h-s,-36,r);inner=arch(iw+2*s,ih+s,-36,ir)
  rings.append((np.column_stack((outer,np.full(len(outer),z))),np.column_stack((inner,np.full(len(inner),z)))))
 for j in [0,-1]:
  o,i=rings[j]
  for k in range(len(o)-1):quad(o[k],o[k+1],i[k+1],i[k],mat,[0,0,-1 if j==0 else 1])
 for j,(cur,nxt) in enumerate(zip(rings,rings[1:])):
  for inner,(a,b) in enumerate(zip(cur,nxt)):
   for k in range(len(a)-1):
    v=a[k+1]-a[k];out=np.array([-v[1],v[0],0])*(-1 if inner else 1)
    out=unit(out);out[2]=[-1,-.42,0,.48][j]
    quad(a[k],a[k+1],b[k+1],b[k],mat,out)
  for k in [0,-1]:quad(cur[0][k],cur[1][k],nxt[1][k],nxt[0][k],mat,[0,-1,0])
def screw(x,y,z,rad,angle,axis='y',slotted=True):
 def coord(a,b,c):
  v=math.radians(angle);aa=a*math.cos(v)-b*math.sin(v);bb=a*math.sin(v)+b*math.cos(v)
  return np.array([x+aa,y+c,z+bb] if axis=='y' else [x+aa,y+bb,z-c])
 def disk(r):return [(r*math.cos(a),r*math.sin(a)) for a in np.linspace(0,math.tau,22,endpoint=False)]
 shape(disk(rad),[0,.65],coord,5)
 if slotted:
  # Split the raised crown into two circular segments. The base is the visible slot floor.
  theta=math.asin(.35/(rad*.91))
  for side in [0,math.pi]:
   arc=np.linspace(theta+side,math.pi-theta+side,15)
   shape([(rad*.91*math.cos(a),rad*.91*math.sin(a)) for a in arc],[.65,1.14],coord,2)
 else:shape(disk(rad*.77),[.65,1.2],coord,2)
def tube(points,radius,mat,sides=12):
 pts=np.array(points);rings=[]
 for i,point in enumerate(pts):
  axis=unit(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)])
  ref=[1,0,0] if len(pts)>2 else ([0,1,0] if abs(axis[1])<.9 else [0,0,1])
  a=unit(np.cross(axis,ref));b=np.cross(axis,a)
  norm=[a*math.cos(theta)+b*math.sin(theta) for theta in np.linspace(0,math.tau,sides,endpoint=False)]
  rings.append((point+radius*np.array(norm),norm))
 for i,((a,na),(b,nb)) in enumerate(zip(rings,rings[1:])):
  for j in range(sides):
   k=(j+1)%sides
   face(a[j],a[k],b[k],mat,na[j]+na[k],[na[j],na[k],nb[k]])
   face(a[j],b[k],b[j],mat,na[j]+na[k],[na[j],nb[k],nb[j]])
 for i,k in [(0,1),(-1,-2)]:
  a,_=rings[i]
  for j in range(sides):face(pts[i],a[j],a[(j+1)%sides],mat,pts[i]-pts[k])
slab(0,-39,-12,232,178,18,15,3.4,0)
slab(0,-29,-27,216,167,5,11,1.2,5)
frame(-81,59,208,89,122,48,27,9,0)
slab(0,26.5,51,190,125,12,24,3,0,'z')
# Output ramp remains 2.4 mm below the unprinted side of the card.
# The die bed supports the thin brass shoe at the same elevation as the feed path.
shape([(-104,12.2),(-12,12.2),(-12,-26.5),(-84,-26.5),(-91,-22),(-95,-11)],[-54.5,54.5],lambda z,y,x:np.array([x,y,z]),3)
# Feed roller with turned collars, a return spring and two wall journals, above the passing ticket.
tube([(-62,37,-69),(62,37,-69)],3.1,2,16)
tube([(-40,37,-69),(40,37,-69)],6.6,1,28)
for side in [-1,1]:
 tube([(side*39,37,-69),(side*42,37,-69)],7.6,5,22)
 tube([(side*57,37,-69),(side*62,37,-69)],8.1,2,20)
coil=[(43+13*u,37+4.6*math.cos(10*math.pi*u),-69+4.6*math.sin(10*math.pi*u)) for u in np.linspace(0,1,81)]
tube(coil,.85,2,7)
# Cast cheek carries the existing rotating lever pivot, 107 mm right and 79 mm up.
shape([(91,47),(109,50),(115,72),(114,82),(108,87),(100,86),(94,78)],[-8,8],lambda x,y,z:np.array([x,y,z]),0)
screw(107,79,-9,6.1,16,'z')
slab(0,14.9,-58,113,98,5.2,7,1.1,1)
for side in [-1,1]:
 slab(side*52,21.5,-60,9,94,10,3.4,1.4,1)
 # Cantilever leaf spring: parabolic cross-section with bent-up entrance and anchored rear.
 def leaf(x,y,z):return np.array([side*44+x,y,z])
 for j in range(16):
  def spring(u):return 25.1+3.1*(2*u-1)**2+4*(1-u)**4
  a,b=j/16,(j+1)/16;za,zb=-89+61*a,-89+61*b
  for offset,yy in [(0,-1),(.88,1)]:
   quad(leaf(-2,spring(a)+offset,za),leaf(2,spring(a)+offset,za),leaf(2,spring(b)+offset,zb),leaf(-2,spring(b)+offset,zb),2,[0,yy,0])
  for x in [-2,2]:quad(leaf(x,spring(a),za),leaf(x,spring(b),zb),leaf(x,spring(b)+.88,zb),leaf(x,spring(a)+.88,za),2,[x,0,0])
 screw(side*44,29.3,-28,2,27)
 for z in [-86,55]:screw(side*107,-29.7,z,4.7,side*28+z,'y')
 for y in [-8,31]:screw(side*84,y,-81.3,3,0,'z',False)
slab(0,89,0,143,83,5,11,1,5)
slab(0,92,0,139,79,4,9,1.1,0)
for x in [-58,58]:
 for z in [-28,28]:screw(x,94,z,3.3,x+z)
slab(0,66,-82,93,24,4,5.2,.9,1,'z')
slab(0,66,-84.3,86,18,1.6,3.6,.45,3,'z')
# Four ivory mechanical number wheels with recessed separators.
for i,char in enumerate('0001'):
 x=-30+i*20
 slab(x,66,-85.35,15.8,14.3,1.6,2,.45,4,'z')
 if char=='0':
  for a,b,w,h in [(-3,0,1.3,7),(3,0,1.3,7),(0,4,5.4,1.3),(0,-4,5.4,1.3)]:
   slab(x+a,66+b,-86.35,w,h,.45,.60,.09,3,'z')
 else:
  slab(x+1,66,-86.35,1.5,9,.45,.6,.09,3,'z')
p=np.array(p)/1000;n=np.array(n);m=np.array(m);t=np.array(t)
# Index weld using exact authored normal and finish. Worn edges use material-dependent procedural patina.
lookup={};verts=[];idx=[]
for pos,norm,material in zip(p,n,m):
 key=tuple(np.round([*pos,*norm,material],7))
 if key not in lookup:lookup[key]=len(verts);verts.append((pos,norm,material))
 idx.append(lookup[key])
out=assets/'TicketMachine.bytes'
with out.open('wb') as f:
 f.write(struct.pack('<III',0x3252504b,len(verts),len(idx)))
 for pos,norm,material in verts:
  f.write(struct.pack('<6fB',*pos,*norm,material))
 f.write(np.array(idx,dtype='<u2').tobytes())
print(len(verts),'vertices',len(idx)//3,'triangles',out.stat().st_size,'bytes')
