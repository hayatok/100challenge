"""Build the Kinsei fan leaves, gilded letters, lamp fittings and velvet returns in metres."""
import argparse, math, struct
from pathlib import Path
import numpy as np
from fontTools.ttLib import TTFont
from fontTools.pens.basePen import BasePen
from shapely.geometry import Polygon
import mapbox_earcut as earcut
from PIL import Image, ImageDraw
from collections import defaultdict
ap=argparse.ArgumentParser();ap.add_argument('font',type=Path);ap.add_argument('out',type=Path);ap.add_argument('--proof',type=Path)
args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
V=lambda *v:np.array(v,dtype=float)
groups=defaultdict(lambda:[[],[],[]])
def face(mat,p,uv=None):
    p=np.array(p);v,coords,tri=groups[mat];i=len(v);v.extend(p)
    coords.extend(uv if uv is not None else [(0,0),(1,0),(1,1),(0,1)][:len(p)])
    tri.extend([(i,i+j,i+j+1) for j in range(1,len(p)-1)])
def tube(mat,a,b,ra,rb=None,n=8):
    a,b=np.array(a),np.array(b);axis=b-a;axis/=np.linalg.norm(axis)
    x=np.cross(axis,V(0,1,0) if abs(axis[1])<.9 else V(0,0,1));x/=np.linalg.norm(x);z=np.cross(axis,x)
    ring=[x*math.cos(2*math.pi*j/n)+z*math.sin(2*math.pi*j/n) for j in range(n)]
    for i,r in enumerate(ring):
        s=ring[(i+1)%n];r2=ra if rb is None else rb
        face(mat,[a+r*ra,a+s*ra,b+s*r2,b+r*r2])
def surface(u,t):
    theta=math.radians(-79+158*u);lobe=math.sin(math.pi*((9*u)%1))
    radial=t*(.906+.094*lobe)
    return V(-5+2.70*math.sin(theta)*radial,.77+3.90*math.cos(theta)*radial,5.54+.21*t-.093*lobe*t)
def UV(p):return ((p[0]+7.72)/5.44,(p[1]-.73)/4)
def edge(a,b,r=.018):tube('metal',a,b,r)
for leaf in range(9):
    # A formed backing, turned outer edge and two fluted bead lines on every leaf.
    for k in range(12):
        u=(leaf+k/12)/9;uu=u+1/108
        for t,tt in zip((.030,.39,.73),(.39,.73,1)):
            poly=[surface(u,t),surface(u,tt),surface(uu,tt),surface(uu,t)]
            face('leaves',poly,[UV(p) for p in poly])
        a,b=surface(u,1),surface(uu,1)
        face('bronze',[a,b,b+V(0,0,.056),a+V(0,0,.056)])
        edge(a+V(0,0,-.015),b+V(0,0,-.015),.021)
        edge(surface(u,.923)+V(0,0,-.015),surface(uu,.923)+V(0,0,-.015),.008)
    for k in (0.07,.5,.93):
        u=(leaf+k)/9;edge(surface(u,.075)+V(0,0,-.017),surface(u,.985)+V(0,0,-.017),.013 if k==.5 else .007)
    for k in (.16,.50,.84):
        u=(leaf+k)/9;p=surface(u,.963)
        tube('bronze',p+V(0,0,-.005),p+V(0,0,-.045),.061,.050,12)
        tube('metal',p+V(0,0,-.041),p+V(0,0,-.054),.048,.046,12)
        tube('glass',p+V(0,0,-.052),p+V(0,0,-.083),.042,.039,12)
        tube('glass',p+V(0,0,-.083),p+V(0,0,-.104),.039,.026,12)
        tube('glass',p+V(0,0,-.104),p+V(0,0,-.114),.026,.002,12)
# Gilded script sits on a sloped sign bridge. Both the letter faces and thickness exist in world space.
ang=math.radians(36);up=V(0,math.cos(ang),math.sin(ang));front=V(0,math.sin(ang),-math.cos(ang))
origin=V(-5,2.99,5.34)
def title(x,y,d):return origin+V(x,0,0)+up*y+front*d
class Outline(BasePen):
    def __init__(self,g):super().__init__(g);self.loops=[];self.cur=[]
    def _moveTo(self,p):self.cur=[np.array(p)]
    def _lineTo(self,p):self.cur.append(np.array(p))
    def _qCurveToOne(self,b,c):
        a=self.cur[-1];b,c=np.array(b),np.array(c)
        for t in (.25,.5,.75,1):self.cur.append((1-t)**2*a+2*t*(1-t)*b+t*t*c)
    def _curveToOne(self,b,c,d):
        a=self.cur[-1];b,c,d=map(np.array,[b,c,d])
        for t in (.2,.4,.6,.8,1):self.cur.append((1-t)**3*a+3*(1-t)**2*t*b+3*(1-t)*t*t*c+t**3*d)
    def _closePath(self):
        if len(self.cur)>2:
            points=[v for j,v in enumerate(self.cur) if j==0 or np.linalg.norm(v-self.cur[j-1])>.05]
            if np.linalg.norm(points[0]-points[-1])<.05:points.pop()
            self.loops.append(points)
    def _endPath(self):self._closePath()
def shape(contours,mat,d,side=None,thickness=.035):
    loops=[Polygon(points) for points in contours]
    for j,shell in enumerate(loops):
        count=sum(p.contains(shell.representative_point()) and p.area>shell.area for p in loops)
        if count%2:continue
        holes=[k for k,p in enumerate(loops) if p.area<shell.area and shell.contains(p) and not any(
            q.area>p.area and q.area<shell.area and q.contains(p) for q in loops)]
        rings=[contours[j]]+[contours[k] for k in holes]
        pts=np.array([p for ring in rings for p in ring]);ends=np.cumsum([len(r) for r in rings],dtype=np.uint32)
        for tri in earcut.triangulate_float64(pts,ends).reshape(-1,3):
            poly=[title(*pts[k],d) for k in tri]
            if np.dot(np.cross(poly[1]-poly[0],poly[2]-poly[0]),front)<0:poly.reverse()
            face(mat,poly)
        if side:
            for ring in rings:
                for a,b in zip(ring,ring[1:]+ring[:1]):
                    face(side,[title(*a,d-thickness),title(*b,d-thickness),title(*b,d),title(*a,d)])
font=TTFont(args.font);glyphs=font.getGlyphSet(location={'wght':690} if 'fvar' in font else None)
for i,ch in enumerate('金星'):
    pen=Outline(glyphs);glyphs[font.getBestCmap()[ord(ch)]].draw(pen)
    allpts=np.concatenate(pen.loops);mid=(allpts.max(0)+allpts.min(0))/2
    rings=[[(v-mid)*(.91/(allpts[:,1].max()-allpts[:,1].min()))+V((i-.5)*1.13,0) for v in loop] for loop in pen.loops]
    shape([[v+V(.022,-.025) for v in ring] for ring in rings],'bronze',.046,'bronze')
    shape(rings,'letters',.086,'metal',.04)
# Eight rear stand-offs physically carry the letters above the folded fan.
for x in (-.83,-.35,.35,.83):
    for y in (-.19,.19):
        p=title(x,y,.04);tube('bronze',p,p+V(0,0,.46),.024)
# Densely pleated, gathered side returns and three gently draped upper swags.
for side in (-1,1):
    def curtain(u,v):
        width=.40+.21*math.cos(math.pi*v)**2
        return V(-5+side*(3.10-width*u),.49+4.32*v,5.69-.15*math.cos(u*9*math.pi)-.09*math.sin(v*math.pi))
    for a in range(32):
        for b in range(8):
            pts=[curtain(a/32,b/8),curtain(a/32,(b+1)/8),curtain((a+1)/32,(b+1)/8),curtain((a+1)/32,b/8)]
            if side==1:pts.reverse()
            face('velvet',pts,[(v[0],v[1]) for v in pts])
for section in range(3):
    for i in range(24):
        def swag(t,v):
            return V(-8.15+2.1*(section+t),4.84-.26*math.sin(math.pi*t)+v*(.40+.26*math.sin(math.pi*t)),5.63-.078*math.cos(t*8*math.pi))
        a,b=i/24,(i+1)/24
        face('velvet',[swag(a,0),swag(a,1),swag(b,1),swag(b,0)])
        edge(swag(a,0),swag(b,0),.012)
# Small shaded footlights assembled on the audience edge. No additional real-time lights.
for i in range(15):
    p=V(-7.79+i*.398,.508,2.612)
    tube('bronze',p,p+V(0,.037,-.01),.038,.032,10)
    tube('apron',p+V(0,.035,-.01),p+V(0,.064,-.017),.029,.031,10)
    tube('apron',p+V(0,.064,-.017),p+V(0,.084,-.021),.031,.002,10)
# Procedural patination and inlaid floral engraving, parametrised by the physical panel UV.
rng=np.random.default_rng(1969);N=768
grain=rng.normal(0,2.3,(N,N,1));xx,yy=np.meshgrid(np.arange(N)/N,np.arange(N)/N)
patina=3.7*np.sin(9*xx+4*yy)+2*np.sin(41*xx-12*yy)
im=Image.fromarray(np.uint8(np.clip(np.array([159,116,68])+patina[:,:,None]+grain,0,255)))
d=ImageDraw.Draw(im)
for i in range(9):
    u=(i+.5)/9
    for t in (.44,.66,.83):
        p=surface(u,t);cx,cy=UV(p);cx*=N;cy=(1-cy)*N
        radius=14+10*t
        for layer,rad in enumerate((radius, .65*radius)):
            for j in range(7):
                a=2*math.pi*j/7+layer*.40
                pts=[]
                for phi in np.linspace(0,2*math.pi,29):
                    X=rad*(.55+.52*math.cos(phi));Y=rad*.34*math.sin(phi)
                    pts.append((cx+X*math.cos(a)-Y*math.sin(a),cy+X*math.sin(a)+Y*math.cos(a)))
                d.line(pts,fill=(113,78,46),width=2)
im.save(args.out/'EtchedLeaves.jpg',quality=94)
# Indexed geometry includes UV seams; share positions only where UV and face normal match.
with (args.out/'StageSign.bytes').open('wb') as out:
    out.write(b'KSG1'+struct.pack('<I',len(groups)))
    for name,(pos,uv,tris) in groups.items():
        records=[];indices=[];lookup={}
        for ids in tris:
            a,b,c=[np.asarray(pos[i]) for i in ids]
            n=np.cross(b-a,c-a);length=np.linalg.norm(n)
            if length<1.e-12:continue
            n/=length
            for i in ids:
                vertex=tuple(np.round(np.concatenate([pos[i],n,uv[i]]),6))
                if vertex not in lookup:lookup[vertex]=len(records);records.append(vertex)
                indices.append(lookup[vertex])
        out.write(bytes([len(name)])+name.encode()+struct.pack('<II',len(records),len(indices)))
        out.write(np.asarray(records,'<f4').tobytes()+np.asarray(indices,'<i4').tobytes())
        print(name,len(records),len(indices)//3)
if args.proof:
    colors={'leaves':'#986d39','bronze':'#523b30','metal':'#ad8746','glass':'#ffdd95','letters':'#f4d899','velvet':'#872f31','apron':'#ffe4b1'}
    proof=Image.new('RGB',(1300,600),'#201e20')
    for offset,el in [(0,10),(650,math.degrees(math.atan2(18,11)))]:
        rad=math.radians(el)
        project=np.array([[1,0,0],[0,math.cos(rad),math.sin(rad)],[0,-math.sin(rad),math.cos(rad)]])
        pixels=np.full((600,650,3),[32,30,32],dtype=np.uint8)
        depth=np.full((600,650),np.inf)
        for name,(pos,uv,tris) in groups.items():
            q=(np.array(pos)-V(-5,2.55,5.45))@project.T
            q[:,0]=325+84*q[:,0]
            q[:,1]=282-84*q[:,1]
            rgb=bytes.fromhex(colors[name][1:])
            for tri in tris:
                a,b,c=q[list(tri)]
                x0,y0=np.maximum(np.floor(np.minimum(np.minimum(a,b),c)[:2]).astype(int),0)
                x1,y1=np.minimum(np.ceil(np.maximum(np.maximum(a,b),c)[:2]).astype(int)+1,[650,600])
                if x0>=x1 or y0>=y1:continue
                e=b-a;f=c-a;det=e[0]*f[1]-e[1]*f[0]
                if abs(det)<1e-8:continue
                y,x=np.ogrid[y0:y1,x0:x1]
                x=x+.5-a[0];y=y+.5-a[1]
                t=(x*f[1]-y*f[0])/det;u=(e[0]*y-e[1]*x)/det
                z=a[2]+t*e[2]+u*f[2]
                region=depth[y0:y1,x0:x1]
                mask=(t>=0)&(u>=0)&(t+u<=1)&(z<region)
                region[mask]=z[mask]
                pixels[y0:y1,x0:x1][mask]=tuple(rgb)
        proof.paste(Image.fromarray(pixels),(offset,0))
    proof.save(args.proof,quality=93)
