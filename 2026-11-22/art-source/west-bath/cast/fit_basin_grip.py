"""Reproduce Kiichi's final rim grasp from the Editor-exported imported neutral mesh.
The exported study is data, not a replacement for the game's existing licensed hand asset.
"""
from pathlib import Path
import json,numpy as np
ROOT=Path(__file__).resolve().parent
def fit():
 a=json.loads((ROOT/'kiichi-hand-study.json').read_text(encoding='utf-8-sig'))
 v=np.array([[d[k]for k in'xyz']for d in a['vertices']]);tri=np.array(a['triangles']).reshape(-1,3)
 def ease(lo,hi,x):
  t=np.clip((x-lo)/(hi-lo),0,1);return t*t*(3-2*t)
 def rx(p,angle,pivot):
  t=np.deg2rad(angle);q=p-pivot;return np.stack([q[:,0],q[:,1]*np.cos(t)-q[:,2]*np.sin(t),q[:,1]*np.sin(t)+q[:,2]*np.cos(t)],1)+pivot
 thumb=ease(.020,.035,-v[:,0])*(1-ease(-.003,.006,v[:,2]))*ease(.064,.090,-v[:,1]);finger=ease(.074,.092,-v[:,1])*(1-thumb)
 first=rx(v,12,np.array([0,-.079,.005]));distal=rx(first,-48,np.array([0,-.124,.005]));four=first+(distal-first)*ease(.115,.145,-v[:,1])[:,None]
 angle=np.deg2rad(85);q=v-[-.024,-.068,-.004];opposed=np.stack([q[:,0]*np.cos(angle)+q[:,2]*np.sin(angle),q[:,1],-q[:,0]*np.sin(angle)+q[:,2]*np.cos(angle)],1)+[-.024,-.068,-.004]
 result=v+(four-v)*finger[:,None]+(opposed-v)*thumb[:,None]-np.array([0,0,.011])*finger[:,None]
 result+=np.array([-.000187,-.002872,-.000795])*thumb[:,None]+np.array([-.000031,-.000364,.000941])*finger[:,None]
 return dict(v=result,tri=tri)
if __name__=='__main__':
 a=fit();print('Final imported-surface grasp:',len(a['v']),'vertices;',len(a['tri']),'triangles')
