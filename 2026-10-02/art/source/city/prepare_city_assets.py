"""Prepare licensed City Zombie source GLB without changing the existing app.
Run with system Python; preserves authored skin and animation channels, appends
original muted clothing/skin textures and a physically directed death clip.
"""
from pathlib import Path
import struct,json,copy,io,hashlib
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
OLD=ROOT.parent/'2026-09-28'/'public'/'assets'
OUT=ROOT/'game'/'assets'/'models'/'city'
OUT.mkdir(parents=True,exist_ok=True)

def read_glb(p):
 b=p.read_bytes();s=struct.unpack_from('<I',b,12)[0]
 return json.loads(b[20:20+s]),bytearray(b[28+s:])
def values(d,b,idx):
 a=d['accessors'][idx];v=d['bufferViews'][a['bufferView']]
 dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
 width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
 off=v.get('byteOffset',0)+a.get('byteOffset',0)
 stride=v.get('byteStride',np.dtype(dtype).itemsize*width)
 return np.ndarray((a['count'],width),dtype=dtype,buffer=b,offset=off,strides=(stride,np.dtype(dtype).itemsize)).copy()
def append_view(d,b,payload):
 b.extend(b'\0'*(-len(b)%4));offset=len(b);b.extend(payload)
 idx=len(d['bufferViews']);d['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload)});return idx
def append_values(d,b,arr,kind,ct=5126):
 arr=np.asarray(arr,dtype='<f4' if ct==5126 else '<u4');vi=append_view(d,b,arr.tobytes())
 idx=len(d['accessors']);a={'bufferView':vi,'componentType':ct,'count':len(arr),'type':kind}
 if kind=='SCALAR':a.update(min=[float(arr.min())],max=[float(arr.max())])
 d['accessors'].append(a);return idx
def write_glb(p,d,b):
 b.extend(b'\0'*(-len(b)%4));d['buffers'][0]['byteLength']=len(b)
 j=json.dumps(d,separators=(',',':')).encode();j+=b' '*(-len(j)%4)
 p.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(j)+len(b))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(b),b'BIN\0')+b)
def image_array(d,b,idx):
 v=d['bufferViews'][d['images'][idx]['bufferView']];off=v.get('byteOffset',0)
 return np.asarray(Image.open(io.BytesIO(bytes(b[off:off+v['byteLength']]))).convert('RGBA')).astype(np.float32)/255

d,b=read_glb(OLD/'characters'/'zombie.glb')
# Reconstruct rest-height in texture space. The skin/morph/UV buffers stay exact.
prim=d['meshes'][0]['primitives'][0]
pos=values(d,b,prim['attributes']['POSITION']);uv=values(d,b,prim['attributes']['TEXCOORD_0']);tri=values(d,b,prim['indices']).reshape(-1,3)
height=np.full((1024,1024),1.2,np.float32)
for ids in tri:
 p=uv[ids].copy();p[:,0]*=1023;p[:,1]*=1023
 xmin=max(0,int(np.floor(p[:,0].min())));xmax=min(1023,int(np.ceil(p[:,0].max())))
 ymin=max(0,int(np.floor(p[:,1].min())));ymax=min(1023,int(np.ceil(p[:,1].max())))
 if xmax<xmin or ymax<ymin:continue
 den=(p[1,1]-p[2,1])*(p[0,0]-p[2,0])+(p[2,0]-p[1,0])*(p[0,1]-p[2,1])
 if abs(den)<1e-6:continue
 yy,xx=np.mgrid[ymin:ymax+1,xmin:xmax+1]
 w0=((p[1,1]-p[2,1])*(xx-p[2,0])+(p[2,0]-p[1,0])*(yy-p[2,1]))/den
 w1=((p[2,1]-p[0,1])*(xx-p[2,0])+(p[0,0]-p[2,0])*(yy-p[2,1]))/den
 w2=1-w0-w1;mask=(w0>=-.025)&(w1>=-.025)&(w2>=-.025)
 region=height[ymin:ymax+1,xmin:xmax+1];region[mask]=(w0*pos[ids[0],1]+w1*pos[ids[1],1]+w2*pos[ids[2],1])[mask]
for idx,kind in [(1,'outfit'),(4,'skin')]:
 src=image_array(d,b,idx);rgb=src[:,:,:3]
 lum=rgb@np.array([.18,.43,.39]);wound=np.clip((rgb[:,:,0]-np.maximum(rgb[:,:,1],rgb[:,:,2])-.18)/.34,0,1)
 if kind=='outfit':
  garment=np.clip((height-.88)/.18,0,1)[:,:,None]
  palette=np.array([.105,.135,.15])[None,None,:]*(1-garment)+np.array([.29,.36,.37])[None,None,:]*garment
  value=np.clip(.48+1.20*np.sqrt(lum),.40,1.20)
  out=palette*value[:,:,None];out=out*(1-wound[:,:,None]*.15)+np.array([.19,.14,.12])*wound[:,:,None]*.15
 else:
  value=np.clip(.39+1.20*np.sqrt(lum),.38,1.17)
  out=np.array([.58,.61,.52])*value[:,:,None]
  out=out*(1-wound[:,:,None]*.38)+np.array([.23,.16,.13])*wound[:,:,None]*.38
 rgba=np.concatenate([np.clip(out,0,1),src[:,:,3:4]],axis=2)
 im=Image.fromarray((rgba*255).astype('uint8'),'RGBA');buf=io.BytesIO();im.save(buf,format='PNG',optimize=True)
 view=append_view(d,b,buf.getvalue());oldview=d['images'][idx]['bufferView'];d['images'][idx]['bufferView']=view;d['images'][idx]['name']='City_'+kind+'_muted_original_recolor'
 im.save(ROOT/'art'/'source'/'city'/('city_'+kind+'_albedo.png'))
for i,mat in enumerate(d['materials']):
 mat.pop('extensions',None);pbr=mat.setdefault('pbrMetallicRoughness',{});pbr.pop('metallicRoughnessTexture',None);pbr['metallicFactor']=0;pbr['roughnessFactor']=.9 if i==0 else .82
 if i<2:mat['normalTexture']['scale']=.16 if i==0 else .11
 else:pbr['baseColorFactor']=[.64,.62,.51,1]
# The supplied idle loops leave the upper arms in a T pose. Apply a muted
# variation of the licensed walk conversion's safe arm pose to both idles.
from scipy.spatial.transform import Rotation as Rotation
idle_corrections={
 'mixamorig:LeftArm':(-.44,.50,1.00),
 'mixamorig:LeftForeArm':(-.75,1.00,.50),
 'mixamorig:RightArm':(.13,-.69,-1.31),
 'mixamorig:RightForeArm':(-.39,.49,-.24),
}
for idle in [a for a in d['animations'] if a['name'] in ['Zombie_Idle','Zombie_Idle2']]:
 for c in idle['channels']:
  name=d['nodes'][c['target']['node']]['name']
  if c['target']['path']!='rotation' or name not in idle_corrections:continue
  sampler=idle['samplers'][c['sampler']];q=values(d,b,sampler['output'])
  q=(Rotation.from_quat(q)*Rotation.from_euler('XYZ',idle_corrections[name])).as_quat()
  sampler['output']=append_values(d,b,q,'VEC4')
 idle.setdefault('extras',{})['city_slice_pose']='arms lowered and bent from source T pose'
# Forward collapse: source was a get-up. Reverse all samples, retime to 1.55 s,
# and raise the terminal pelvis so chest/back don't sink below the pavement.
source=next(a for a in d['animations'] if a['name']=='Zombie_Dying')
death={'name':'City_Death','samplers':[],'channels':copy.deepcopy(source['channels']), 'extras':{'source':'Rikindle3D Zombie_Dying reversed','modified':'1.55 second forward collapse; hip height clamped to 0.20m'}}
for sampler in source['samplers']:
 times=values(d,b,sampler['input']).reshape(-1);outputs=values(d,b,sampler['output']);times=(times[-1]-times[::-1])*(1.55/(times[-1]-times[0]))
 outputs=outputs[::-1].copy()
 targets=[c['target'] for c in source['channels'] if c['sampler']==len(death['samplers'])]
 if any(t['path']=='translation' and d['nodes'][t['node']]['name']=='mixamorig:Hips' for t in targets):outputs[:,1]=np.maximum(20,outputs[:,1])
 death['samplers'].append({'input':append_values(d,b,times.reshape(-1,1),'SCALAR'),'output':append_values(d,b,outputs,d['accessors'][sampler['output']]['type']),'interpolation':sampler.get('interpolation','LINEAR')})
# Original source floor pose holds hands in the air. Settle the last part of
# the new forward collapse with arms resting alongside the body on pavement.
from scipy.spatial.transform import Rotation as Rotation
parents={child:i for i,node in enumerate(d['nodes']) for child in node.get('children',[])}
node_ids={node['name']:i for i,node in enumerate(d['nodes'])}
channel_data=[]
for c in death['channels']:
 sampler=death['samplers'][c['sampler']]
 channel_data.append((c['target']['node'],c['target']['path'],values(d,b,sampler['input']).reshape(-1),values(d,b,sampler['output'])))
def sample_at(t):
 overrides={}
 for node,path,times,outputs in channel_data:
  k=min(len(times)-2,max(0,int(np.searchsorted(times,t)-1)))
  if len(times)==1:v=outputs[0]
  else:
   f=np.clip((t-times[k])/max(1e-6,times[k+1]-times[k]),0,1);a=outputs[k];z=outputs[k+1]
   if path=='rotation' and np.dot(a,z)<0:z=-z
   v=a*(1-f)+z*f
   if path=='rotation':v=v/np.linalg.norm(v)
  overrides.setdefault(node,{})[path]=v
 return overrides
def world_pose(overrides):
 worlds={}
 def recurse(i,parent):
  node=d['nodes'][i];o=overrides.get(i,{});m=np.eye(4)
  m[:3,:3]=Rotation.from_quat(o.get('rotation',node.get('rotation',[0,0,0,1]))).as_matrix()@np.diag(o.get('scale',node.get('scale',[1,1,1])))
  m[:3,3]=o.get('translation',node.get('translation',[0,0,0]));worlds[i]=parent@m
  for child in node.get('children',[]):recurse(child,worlds[i])
 for root in d['scenes'][0]['nodes']:recurse(root,np.eye(4))
 return worlds
def aim(overrides,node,child,target,weight):
 world=world_pose(overrides);v=world[child][:3,3]-world[node][:3,3];goal=target-world[node][:3,3]
 v/=np.linalg.norm(v);goal/=np.linalg.norm(goal);axis=np.cross(v,goal);sn=np.linalg.norm(axis)
 if sn<1e-7:return
 correction=Rotation.from_rotvec(axis/sn*np.arctan2(sn,np.dot(v,goal))).as_matrix()
 parent=world[parents[node]][:3,:3];parent=parent/np.linalg.norm(parent,axis=0)
 q0=overrides[node]['rotation'];r0=Rotation.from_quat(q0).as_matrix()
 q1=Rotation.from_matrix(parent.T@correction@parent@r0).as_quat()
 if np.dot(q0,q1)<0:q1=-q1
 q=q0*(1-weight)+q1*weight;overrides[node]['rotation']=q/np.linalg.norm(q)
changed={}
for side in ['Left','Right']:
 for part in ['Arm','ForeArm']:
  node=node_ids['mixamorig:'+side+part];entry=next(x for x in channel_data if x[0]==node and x[1]=='rotation');changed[node]=np.zeros_like(entry[3])
ref_times=next(x[2] for x in channel_data if x[0]==node_ids['mixamorig:LeftArm'] and x[1]=='rotation')
for k,t in enumerate(ref_times):
 overrides=sample_at(float(t));w=np.clip((float(t)/1.55-.44)/.50,0,1);w=w*w*(3-2*w)
 for side,sign in [('Left',1),('Right',-1)]:
  upper=node_ids['mixamorig:'+side+'Arm'];lower=node_ids['mixamorig:'+side+'ForeArm'];hand=node_ids['mixamorig:'+side+'Hand']
  world=world_pose(overrides);shoulder=world[upper][:3,3]
  target=shoulder+np.array([sign*.10,.075-shoulder[1],.15]);aim(overrides,upper,lower,target,w)
  world=world_pose(overrides);elbow=world[lower][:3,3]
  target=elbow+np.array([sign*.15,.065-elbow[1],.12]);aim(overrides,lower,hand,target,w)
  changed[upper][k]=overrides[upper]['rotation'];changed[lower][k]=overrides[lower]['rotation']
for c in death['channels']:
 if c['target']['path']=='rotation' and c['target']['node'] in changed:
  death['samplers'][c['sampler']]['output']=append_values(d,b,changed[c['target']['node']],'VEC4')
death['extras']['modified']+='; relaxed arms settle to pavement'
d['animations'].append(death);d.setdefault('extras',{})['city_slice_provenance']='Derived only from repository credited CC0 Male City Zombie; original recolor + corrected death.'
write_glb(OUT/'zombie_city.glb',d,b)
(OUT/'thin_zombie.glb').write_bytes((OLD/'characters'/'thin-zombie.glb').read_bytes())
print('CITY_OUTPUT',OUT/'zombie_city.glb', 'bytes', (OUT/'zombie_city.glb').stat().st_size)
print('DEATH City_Death 1.55s; terminal pelvis Y >=0.20m')
