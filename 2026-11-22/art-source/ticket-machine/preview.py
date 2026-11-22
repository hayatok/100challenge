from pathlib import Path
import numpy as np,struct
from PIL import Image
d=Path(__file__).resolve().parent
resources=d.parents[1]/'Game/Assets/Resources/KinseiPrintworks'
buf=(resources/'TicketMachine.bytes').read_bytes()
_,vc,ic=struct.unpack_from('<III',buf)
v=np.frombuffer(buf,offset=12,count=vc,dtype=[('p','<f4',3),('n','<f4',3),('m','u1')]);idx=np.frombuffer(buf,offset=12+25*vc,dtype='<u2').reshape(-1,3)
p=v['p']*1000;n=v['n'];mat=v['m']
colors=np.array([[37,62,57],[168,122,65],[120,117,105],[26,30,29],[206,188,144],[99,76,45],[204,178,134],[101,40,28]])/255
def unit(a):
 a=np.asarray(a,float);return a/np.linalg.norm(a)
def render(cam,look,size,withPaper=False):
 eye=unit(np.array(cam)-look);right=unit(np.cross([0,1,0],-eye));up=unit(np.cross(-eye,right))
 q=p.copy();ns=n.copy();mi=mat.copy();tri=idx.copy()
 if withPaper:
  # Actual printed stock at the existing feed transform, midway through the 126 mm stroke.
  z=-84-63
  card=np.array([[-43.5,20.9,z],[43.5,20.9,z],[43.5,20.9,z+125],[-43.5,20.9,z+125]])
  tri=np.concatenate([tri,np.array([[0,2,1],[0,3,2]])+len(q)])
  q=np.vstack([q,card]);ns=np.vstack([ns,np.tile([0,1,0],(4,1))]);mi=np.r_[mi,[6]*4]
 x,y=640,420;scale=x/size;origin=np.array(look)
 proj=np.stack(((q-origin)@right*scale+x/2,-((q-origin)@up)*scale+y/2,(q-origin)@eye),axis=1)
 img=np.zeros((y,x,3));img[:]=[.132,.12,.106];zbuf=np.full((y,x),-1e4)
 key=unit([-.55,.85,-.58]);fill=unit([.78,.25,.48]);half=unit(key+eye)
 art=resources/'FirstTicket.png'
 printInk=np.asarray(Image.open(art).convert('RGB'))/255
 for ids in tri:
  pt=proj[ids];x0,y0=np.maximum(0,np.floor(pt[:,:2].min(0))).astype(int);x1,y1=np.minimum([x-1,y-1],np.ceil(pt[:,:2].max(0))).astype(int)
  if x0>x1 or y0>y1:continue
  v1=pt[1]-pt[0];v2=pt[2]-pt[0];det=v1[0]*v2[1]-v1[1]*v2[0]
  if abs(det)<1e-7:continue
  gy,gx=np.mgrid[y0:y1+1,x0:x1+1];dx=gx+.5-pt[0,0];dy=gy+.5-pt[0,1]
  u=(dx*v2[1]-dy*v2[0])/det;w=(dy*v1[0]-dx*v1[1])/det;zz=pt[0,2]+u*v1[2]+w*v2[2]
  old=zbuf[y0:y1+1,x0:x1+1];mask=(u>=0)&(w>=0)&(u+w<=1)&(zz>old)
  if not mask.any():continue
  old[mask]=zz[mask];P=q[ids[0]]+u[mask,None]*(q[ids[1]]-q[ids[0]])+w[mask,None]*(q[ids[2]]-q[ids[0]])
  N=ns[ids[0]]; alloy=mi[ids[0]];colour=colors[alloy]
  grain=np.sin(P@np.array([1.27,2.03,.93]))*np.sin(P@np.array([.82,-1.73,2.11]));patina=np.sin(P@np.array([.22,.13,.085]))*np.cos(P@np.array([.118,.19,.143]))
  if alloy==6:
   uz=np.clip(1-(P[:,2]-z)/125,0,.9999);ux=np.clip((P[:,0]+43.5)/87,0,.9999)
   colour=printInk[(uz*printInk.shape[0]).astype(int),(ux*printInk.shape[1]).astype(int)]
  wear=np.clip((1-max(abs(N)))*5.7,0,1)*np.clip((patina*.7+grain*.3-.39)*2.0,0,1) if alloy==0 else np.zeros(len(P))
  colour=colour*(1-wear[:,None])+np.array([.36,.30,.21])*wear[:,None]
  diffuse=.49+.70*max(0,N@key)+.29*max(0,N@fill);spec=max(0,N@half)**26*.28
  rgb=np.clip(colour*(diffuse*(1+.08*patina+.045*grain))[:,None]+spec,0,1)
  img[y0:y1+1,x0:x1+1][mask]=rgb
 return Image.fromarray(np.uint8(img*255))
views=[render([215,177,-320],[0,18,-12],340),render([-65,87,-260],[0,30,-76],235,True)]
sheet=Image.new('RGB',(1280,420));sheet.paste(views[0]);sheet.paste(views[1],(640,0));sheet.save(d/'press-inspection.png')
