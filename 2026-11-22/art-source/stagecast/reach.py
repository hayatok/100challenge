"""Metre-scale rest/playing reach check. Pass the game's StageScore.json."""
import json,sys
import numpy as np
from math import sin,cos,pi
def rotation(deg,axis):
 a=deg*pi/180;c=cos(a);s=sin(a)
 return np.array([[1,0,0],[0,c,-s],[0,s,c]]) if axis=='x' else np.array([[c,0,s],[0,1,0],[-s,0,c]]) if axis=='y' else np.array([[c,-s,0],[s,c,0],[0,0,1]])
def orientation(normal,fingers):
 z=np.array(normal,dtype=float);z/=np.linalg.norm(z)
 y=-np.array(fingers,dtype=float);y-=z*np.dot(y,z);y/=np.linalg.norm(y);return np.stack([np.cross(y,z),y,z],axis=1)
def reach(shoulder,point,hand,contact):
 wrist=point-hand@contact;return np.linalg.norm(wrist-shoulder)
# In piano-local coordinates the playable area follows the 36 natural keys and the narrower accidentals.
naturals=[0,2,4,5,7,9,11];keys={}
for i in range(36):
 n=i//7*12+naturals[i%7]+36
 keys[n]=np.array([(i-17.5)*.035,.779,-.326-.22*.198])
 if i%7 not in (2,6) and i<35:keys[n+1]=np.array([(i-17.5)*.035+.0175,.811,-.286-.22*.116])
score=json.load(open(sys.argv[1]));singer=np.array([.06,1.355,.24])
singerArm=reach(np.array([.196,1.345,.004]),singer,orientation([1,0,0],[0,.35,1]),np.array([0,-.077,.013]))
Rbody=rotation(7,'y')@rotation(-2,'z')
body=np.array([.015,-.02,-.75])+np.array([-.021,.548,-.012])
left=[];right=[];spread=[]
for bar in score['bars']:
 for note in bar['melody']:
  lo,hi=keys[bar['chord'][1]],keys[note['midi']]
  spread.append(hi[0]-lo[0])
  for nod in [7.2,8.8]:
   R=Rbody@rotation(nod,'x')@rotation(-5,'y')
   for side,target,res in [(-1,lo,left),(1,hi,right)]:
    shoulder=body+Rbody@[0,.06,0]+R@[side*.196,.325,.004]
    for pressed in [0,.008]:
     # Bound the middle fingertip displacement over the two mirrored fittings.
     for length in [.127,.139,.151]:
      for lateral in [-.016,.016]:
       res.append(reach(shoulder,target-np.array([0,pressed,0]),orientation([0,-1,0],[0,0,1]),np.array([lateral,-length,.01])))
print(f'Mic shoulder-to-wrist {singerArm:.3f} m; left/right piano maxima {max(left):.3f}/{max(right):.3f} m; arm span .520 m.')
print(f'Left/right keys separation {min(spread):.3f} to {max(spread):.3f} m.')
assert max(singerArm,max(left),max(right))<.519
assert min(spread)>0
