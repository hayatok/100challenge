"""Draw both existing camera directions from the shipped triangle and UV streams (no Unity lighting)."""
from pathlib import Path
import math,struct
import numpy as np
from PIL import Image
here=Path(__file__).resolve().parent
assets=here.parent.parent/'Game/Assets/Resources/KinseiBroadcastConsole'
atlas=np.asarray(Image.open(assets/'Finish.jpg'))
parts={}
with (assets/'Console.bytes').open('rb') as f:
    assert f.read(4)==b'KSG1'
    for _ in range(struct.unpack('<I',f.read(4))[0]):
        key=f.read(f.read(1)[0]).decode()
        nv,ni=struct.unpack('<II',f.read(8))
        vertices=np.frombuffer(f.read(32*nv),'<f4').reshape(-1,8).copy()
        indices=np.frombuffer(f.read(4*ni),'<i4').reshape(-1,3)
        if key in ('level','ivory'):
            a=math.radians(-43)
            R=np.array([[math.cos(a),-math.sin(a),0],[math.sin(a),math.cos(a),0],[0,0,1]])
            vertices[:,:3]=vertices[:,:3]@R.T+[.179,-.018,.108]
            vertices[:,3:6]=vertices[:,3:6]@R.T
        parts[key]=vertices,indices
    assert not f.read()
def unit(v):return v/np.linalg.norm(v)
solid={'steel':[142,136,120],'trim':[140,112,76],'gasket':[35,32,28],
       'glasslip':[121,142,140],'ivory':[229,218,172]}
def render(eyes,focus,field):
    eye=np.array(eyes);forward=unit(focus-eye)
    # Desk is tilted -18 degrees. Convert world up into the panel coordinate system.
    up=np.array([0,math.cos(math.radians(18)),math.sin(math.radians(18))])
    right=unit(np.cross(up,forward));up=unit(np.cross(forward,right))
    w,h=1440,810;focal=.5*h/math.tan(math.radians(field/2))
    pix=np.full((h,w,3),[52,43,37],dtype=np.uint8);depth=np.full((h,w),np.inf)
    for key,(verts,tris) in parts.items():
        v=verts[:,:3]-eye
        z=v@forward
        screen=np.column_stack([w*.5+focal*(v@right)/z,h*.5-focal*(v@up)/z])
        for tri in tris:
            n=verts[tri[0],3:6];at=verts[tri,:3].mean(0)
            if np.dot(n,eye-at)<=0:continue
            pts=screen[tri];a,b,c=pts
            x0,y0=np.maximum(np.floor(pts.min(0)).astype(int),0)
            x1,y1=np.minimum(np.ceil(pts.max(0)).astype(int)+1,[w,h])
            if x0>=x1 or y0>=y1:continue
            e=b-a;g=c-a;det=e[0]*g[1]-e[1]*g[0]
            if abs(det)<1e-8:continue
            yy,xx=np.ogrid[y0:y1,x0:x1];xx=xx+.5-a[0];yy=yy+.5-a[1]
            t=(xx*g[1]-yy*g[0])/det;u=(e[0]*yy-e[1]*xx)/det
            weight=np.stack((1-t-u,t,u),axis=-1)/z[tri]
            distance=1/weight.sum(-1);old=depth[y0:y1,x0:x1]
            mask=(t>=0)&(u>=0)&(t+u<=1)&(distance<old)
            if not mask.any():continue
            old[mask]=distance[mask]
            light=unit(np.array([-.35,.74,.65]));half=unit(light+unit(eye-at))
            metal=key not in ('case','ivory','gasket')
            diffuse=.65+.38*max(0,np.dot(n,light))
            spec=(35 if metal else 17)*max(0,np.dot(n,half))**(22 if metal else 42)
            if key in solid:base=np.array(solid[key])
            else:
                uv=(weight[mask]@verts[tri,6:8])*distance[mask,None]
                ix=np.clip((uv[:,0]*1024).astype(int),0,1023)
                iy=np.clip(((1-uv[:,1])*1024).astype(int),0,1023)
                base=atlas[iy,ix]
            pix[y0:y1,x0:x1][mask]=np.clip(base*diffuse+spec,0,255).astype('uint8')
    return Image.fromarray(pix).resize((720,405),Image.Resampling.LANCZOS)
proof=Image.new('RGB',(1440,405))
proof.paste(render([.335,.170,.432],np.array([.145,.006,.120]),43),(0,0))
proof.paste(render([-.249,.104,.53],np.array([-.071,.008,.110]),38),(720,0))
proof.save(here/'console-geometry.jpg',quality=94)
