"""Cut and weight a bias satin gown, cowl, rhinestone cuffs, pearl drops and camellia."""
import sys,struct
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
out=Path(sys.argv[1]);verts=[];uv=[];bones=[];faces=[];seams=[]
def add_grid(shape,skin,tile):
    rows,cols=shape.shape[:2];base=len(verts)
    for i in range(rows):
        for j in range(cols):
            verts.append(shape[i,j]);u=j/(cols-1);v=i/(rows-1)
            uv.append((u*.99+.005,(tile+.025+.95*v)/8));bones.append(skin(shape[i,j]))
            if j==0:seams.append((len(verts)-1,len(verts)+cols-2))
            if i and j:
                n=base+i*cols+j;faces.extend([(n-cols-1,n-cols,n),(n-cols-1,n,n-1)])
def row(y,rx,rz,tile,skin,x=0,z=0,fold=0,cowl=0):
    rings=[]
    for h,w,d in zip(y,rx,rz):
        t=(h-y[0])/max(.001,y[-1]-y[0]);a=np.linspace(-np.pi,np.pi,97)
        front=np.maximum(0,np.cos(a))
        relief=fold*(1-t)*(.65*np.sin(13*a+t*1.4)+.35*np.cos(21*a-t*1.9))
        yy=h+cowl*front**2*(.8+.2*np.sin(3*a))+.002*fold/.022*np.cos(6*a)*(1-t)
        rings.append(np.stack([x+np.sin(a)*(w+relief),yy+0*a,z+np.cos(a)*(d+relief)],axis=-1))
    add_grid(np.array(rings),skin,tile)
def fixed(i):return lambda p:{i:1}
def mid(p):
    x,y,z=p
    if y>1.15:return {1:1}
    if y>.89:
        t=(y-.89)/.26;return {0:1-t,1:t}
    t=np.clip((.89-y)/.65,0,1);q=np.clip(.5+x*2.6,0,1)
    return {0:1-t,6:t*(1-q),8:t*q}
row([.055,.075,.12,.29,.50,.69,.85,.96,1.05,1.15,1.26,1.34,1.37],[.34,.346,.335,.27,.225,.19,.19,.172,.146,.15,.176,.187,.18],[.245,.249,.238,.194,.157,.136,.13,.125,.111,.122,.143,.132,.113],0,mid,fold=.022)
# Tiny contrasting selvedge catches the footlights when the bias-cut hem swings.
row([.067,.072],[.351,.351],[.251,.251],2,mid,fold=.017)
row([1.325,1.35,1.374,1.40,1.433,1.45],[.183,.193,.201,.18,.102,.065],[.136,.143,.136,.122,.083,.063],1,mid,cowl=-.037)
# The gathered front drops away from the throat. Close the neckline underneath the outer drape.
row([1.355,1.399,1.431,1.466,1.471],[.169,.139,.094,.064,.061],[.111,.096,.074,.061,.058],0,mid)
# A folded, gathered outer collar drapes forward in three descending arcs.
for h in [1.371,1.391,1.411]:
 row([h-.009,h-.003,h+.005],[.186,.191,.186],[.136,.146,.135],1,mid,cowl=-.062)
for side in [-1,1]:
 def arm(p):
    t=np.clip((1.131-p[1])/.095,0,1);a=2 if side<0 else 4;return {a:1-t,a+1:t}
 row([.827,.841,.946,1.076,1.176,1.27,1.31,1.35,1.38,1.397],[.031,.033,.042,.051,.057,.061,.071,.072,.06,.022],[.032,.035,.043,.053,.061,.069,.075,.073,.056,.024],0,arm,x=side*.196)
 row([.827,.831,.842,.846],[.035,.037,.036,.034],[.036,.037,.037,.036],2,arm,x=side*.196)
def oval(center,scale,tilt,tile,bone):
    t,a=np.meshgrid(np.linspace(-np.pi/2+.01,np.pi/2-.01,12),np.linspace(-np.pi,np.pi,21),indexing='ij')
    x=np.cos(t)*np.sin(a)*scale[0];y=np.sin(t)*scale[1];z=np.cos(t)*np.cos(a)*scale[2]
    c,s=np.cos(tilt),np.sin(tilt)
    add_grid(np.stack([x*c-y*s+center[0],x*s+y*c+center[1],z+center[2]],axis=-1),fixed(bone),tile)
# Head rest pivot is 1.477. The red comb pins into the left-side roll, behind the temple.
for ring,n in [(0,7),(1,5),(2,3)]:
 for j in range(n):
    a=j*2*np.pi/n+ring*.45
    rad=.014-ring*.0046
    oval((-.071+rad*np.cos(a),1.623+rad*np.sin(a),.039+ring*.004),(.010-ring*.001,.015-ring*.0025,.006),a-np.pi/2,3,10)
oval((-.071,1.623,.054),(.004,.005,.003),0,4,10)
for side in [-1,1]:
 for j in range(2):
    oval((side*.084,1.554-j*.012,.018),(.0047+j*.001,.005+j*.002,.005),0,4,10)
verts=np.array(verts);faces=np.array(faces);norm=np.zeros_like(verts)
cross=np.cross(verts[faces[:,1]]-verts[faces[:,0]],verts[faces[:,2]]-verts[faces[:,0]])
for i in range(3):np.add.at(norm,faces[:,i],cross)
for a,b in seams:norm[a]=norm[b]=norm[a]+norm[b]
norm/=np.maximum(1e-9,np.linalg.norm(norm,axis=1,keepdims=True))
with (out/'Camellia.bytes').open('wb') as f:
 f.write(struct.pack('<ii',len(verts),faces.size))
 for p,n,t,w in zip(verts,norm,uv,bones):
    ww=list(w.items())+[(0,0)]*(4-len(w))
    f.write(struct.pack('<8f4B4f',*p,*n,*t,*[i for i,_ in ww],*[v for _,v in ww]))
 f.write(faces.astype('<u2').tobytes())
y,x=np.indices((1024,1024));v=1-y/1024;u=x/1024;region=np.clip((v*8).astype(int),0,7)
colors=np.array([[63,34,54],[90,55,76],[162,136,103],[154,31,48],[215,193,150],[60,35,45],[60,35,45],[60,35,45]])
weave=1+.045*np.sin((x+y*2)*2.2)+.03*np.sin((x-y*.2)*2.56)+.11*np.cos(u*2*np.pi*13+np.sin(v*8*np.pi)*.9)
rgb=colors[region]*weave[:,:,None]
hem=(region==2)&((np.cos(2*np.pi*u*87+v*220)>.5)|(np.cos(2*np.pi*u*87-v*220)>.5))
rgb[hem]*=1.35
Image.fromarray(np.uint8(np.clip(rgb,0,255))).save(out/'CamelliaSatin.png')
print(len(verts),len(faces))

