"""Bake three reference postures from KinseiActor's ten bind pivots, using the same skin weights and sleeve drivers."""
from pathlib import Path
import struct,sys
import numpy as np
from scipy.spatial.transform import Rotation as Rot
ward,custom,out=map(Path,sys.argv[1:])
base=np.array([[0,.96,0],[0,1.02,0],[-.196,1.345,.004],[-.196,1.080,.004],[.196,1.345,.004],[.196,1.080,.004],[-.084,.905,0],[-.084,.515,0],[.084,.905,0],[.084,.515,0],[0,1.477,0],[-.196,.825,.004],[.196,.825,.004]])
def q(x,y,z):return Rot.from_euler('zxy',[z,x,y],degrees=True).as_matrix()
def norm(x):return x/max(1e-12,np.linalg.norm(x))
def align(a,b):
 a,b=norm(a),norm(b);return Rot.from_rotvec(norm(np.cross(a,b))*np.arccos(np.clip(a@b,-1,1))).as_matrix()
def ramp(lo,hi,x):
 t=np.clip((x-lo)/(hi-lo),0,1);return t*t*(3-2*t)
def pose(name):
 R=np.array([np.eye(3) for _ in base]);p=base.copy();local=R.copy()
 local[2]=q(-5,0,-4);local[4]=q(-5,0,4);local[3]=q(-9,0,2);local[5]=q(-10,0,-2)
 local[11]=q(-8,68,2);local[12]=q(-8,-68,-2)
 if name=='guard':
  p[0]+=[-.024,-.047,-.006];local[0]=q(0,-13,2);local[1]=q(7,20,-5)
  local[2]=q(-27,-12,-13);local[4]=q(-47,13,10);local[3]=q(-47,2,-4);local[5]=q(-61,-2,4)
  local[11]=q(-12,38,0);local[12]=q(-9,-30,0)
  local[6]=q(-11,0,-8);local[7]=q(19,0,0);local[8]=q(8,0,7);local[9]=q(22,0,0)
 elif name=='reach':
  local[1]=q(6,-7,1);local[4]=q(-40,5,5);local[5]=q(-28,0,0)
  local[2]=q(-21,-4,-8);local[3]=q(-36,0,0)
 R[0]=local[0]
 for child,parent in [(1,0),(2,1),(3,2),(4,1),(5,4),(6,0),(7,6),(8,0),(9,8),(10,1),(11,3),(12,5)]:
  p[child]=p[parent]+R[parent]@(base[child]-base[parent]);R[child]=R[parent]@local[child]
 if name=='reach':
  target=np.array([.248,1.313,.464]);upper=p[4];direc=norm(target-upper);length=np.linalg.norm(target-upper);a,b=.265,.255
  pole=np.array([.44,-1,0]);bend=norm(pole-direc*(pole@direc));co=(a*a+length**2-b*b)/(2*a*length)
  elbow=upper+direc*a*co+bend*a*np.sqrt(1-co*co)
  straighten=align(p[5]-upper,elbow-upper);R[4]=straighten@R[4];R[5]=align(straighten@(p[12]-p[5]),target-elbow)@straighten@R[5]
  p[5]=elbow;p[12]=target;R[12]=q(-80,-20,15)
 loads=[]
 for side,bone in [(-1,2),(1,4)]:
  arm=R[1].T@R[bone]@[0,-1,0];loads.append(ramp(.18,.91,arm[2]+.24*max(0,side*arm[0]-.35)))
 return p,R,loads
def read(path,new):
 buf=path.read_bytes();n,ni=struct.unpack_from('<ii',buf);off=8+n*52
 arr=np.ndarray((n,8),'<f4',buffer=buf,offset=8,strides=(52,4)).copy()
 bi=np.ndarray((n,4),'u1',buffer=buf,offset=40,strides=(52,1)).copy();wt=np.ndarray((n,4),'<f4',buffer=buf,offset=44,strides=(52,4)).copy()
 tr=np.frombuffer(buf,'<u2',count=ni,offset=off).reshape(-1,3).copy();off+=ni*2;frames=[]
 if new:
  for i in range(2):
   count,=struct.unpack_from('<i',buf,off);off+=4;delta=np.zeros((n,6))
   for j in range(count):
    idx,*v=struct.unpack_from('<H6h',buf,off);off+=14;delta[idx]=np.array(v)*np.array([1e-5]*3+[1e-4]*3)
   frames.append(delta)
 detail=np.frombuffer(buf,dtype="<f4",offset=off,count=n*2).reshape(n,2).copy() if new else np.zeros((n,2));off+=n*8 if new else 0
 assert off==len(buf) and np.max(abs(wt.sum(1)-1))<.00001 and tr.max()<n
 return arr,bi,wt,tr,frames,detail
for name in ['idle','guard','reach']:
 P,R,load=pose(name);print(name,'left/right load',np.round(load,3))
 for version,path in [('old',ward/'Single.bytes'),('new',custom/'MakabeCut.bytes')]:
  arr,bi,wt,tri,frames,detail=read(path,version=='new')
  rest=arr[:,:3].copy()
  for weight,frame in zip(load,frames):arr[:,:6]+=weight*frame
  vertices=np.zeros((len(arr),3));normals=np.zeros_like(vertices)
  for j in range(4):
   b=bi[:,j];weight=wt[:,j,None]
   vertices+=(np.einsum('nij,nj->ni',R[b],arr[:,:3]-base[b])+P[b])*weight
   normals+=np.einsum('nij,nj->ni',R[b],arr[:,3:6])*weight
  normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-10)
  assert np.isfinite(vertices).all()
  top=np.all((rest[tri][:,:,1]>.80)&(rest[tri][:,:,1]<1.438),axis=1)
  def cross(v):
   return np.cross(v[tri[:,1]]-v[tri[:,0]],v[tri[:,2]]-v[tri[:,0]])
  a,b=cross(rest),cross(vertices)
  valid=top&(np.linalg.norm(a,axis=1)>1.0e-7)
  ratio=np.linalg.norm(b[valid],axis=1)/np.linalg.norm(a[valid],axis=1)
  print(version,'area ratio 1%/99%',np.round(np.quantile(ratio,[.01,.99]),3),'faces <10%',int((ratio<.10).sum()))
  # UV duplicates sharing rest positions should remain coincident through the entire pose.
  unique,rev=np.unique(np.round(rest,7),axis=0,return_inverse=True);mini=np.full((len(unique),3),1e3);maxi=-mini
  np.minimum.at(mini,rev,vertices);np.maximum.at(maxi,rev,vertices)
  print('max UV split separation mm',round(np.max(np.linalg.norm(maxi-mini,axis=1))*1000,4))
  np.savez(out/f'{name}-{version}.npz',p=vertices,n=normals,uv=arr[:,6:8],tri=tri,P=P,R=R,detail=detail)
