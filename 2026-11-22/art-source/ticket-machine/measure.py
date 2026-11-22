from pathlib import Path
import struct,numpy as np
d=Path(__file__).resolve().parents[2]
buf=(d/'Game/Assets/Resources/KinseiPrintworks/TicketMachine.bytes').read_bytes()
magic,vc,ic=struct.unpack_from('<III',buf);assert magic==0x3252504b
v=np.frombuffer(buf,offset=12,count=vc,dtype=[('p','<f4',3),('n','<f4',3),('m','u1')]);idx=np.frombuffer(buf,offset=12+25*vc,dtype='<u2').reshape(-1,3)
p=v['p'].astype(float)*1000
tri=p[idx];norm=v['n'][idx];face=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);area=np.linalg.norm(face,axis=1)
assert min(area)>1e-8 and idx.max()<vc and np.max(abs(np.linalg.norm(norm,axis=2)-1))<1e-5
assert np.min(np.einsum('ij,ij->i',face/area[:,None],norm.mean(axis=1)))>.05
# Entire moving sheet, plus elevated printed face. Separating-axis test for each triangle.
lo=np.array([-43.5,19.1,-210.5]);hi=np.array([43.5,21.3,41.0])
q=tri-(lo+hi)/2;half=(hi-lo)/2
inside=np.ones(len(q),bool)
def axis(a):
 global inside
 proj=np.einsum('ijk,ik->ij',q,a);radius=abs(a)@half
 inside &= (proj.min(1)<=radius+1e-9)&(proj.max(1)>=-radius-1e-9)
for a in np.eye(3):axis(np.tile(a,(len(q),1)))
axis(face)
for edge in [q[:,1]-q[:,0],q[:,2]-q[:,1],q[:,0]-q[:,2]]:
 for a in np.eye(3):axis(np.cross(edge,a))
assert not inside.any(),f'{sum(inside)} triangles hit the ticket feed'
print('bounds mm',p.min(0),p.max(0))
print('ticket sweep (all feed positions) intersects',sum(inside),'triangles; vertices',vc,'triangles',ic//3,'mesh stream bytes',36*vc+2*ic)
