"""Offline camera test of the actual wardrobe buffers under an opal key light.
blender -b -t 4 --python fitting.py -- /path/to/Game/Assets/Resources /path/to/KinseiStage /path/to/output
"""
import bpy,numpy as np,sys,math,struct
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
lib,stage,out=map(Path,sys.argv[-3:]);cast=lib/'KinseiCast';ward=lib/'KinseiWardrobe'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def world(x,y,z):return Vector((-x,z,y))
def mat(name,col=(1,1,1),tex=None,gloss=.55):
 m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF')
 b.inputs['Base Color'].default_value=(*col,1);b.inputs['Roughness'].default_value=gloss
 if tex:
  t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(tex),check_existing=True)
  mix=m.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*col,1)
  m.node_tree.links.new(t.outputs[0],mix.inputs[1]);m.node_tree.links.new(mix.outputs[0],b.inputs[0])
 return m
def mesh(name,p,tri,uv,material):
 m=bpy.data.meshes.new(name);m.from_pydata([world(*v) for v in p],[],tri);m.update();u=m.uv_layers.new().data
 for f,coords in zip(m.polygons,uv):
  f.use_smooth=True
  for i,c in zip(f.loop_indices,coords):u[i].uv=c
 obj=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(obj);m.materials.append(material)
def obj(path,transfer,material):
 p=[];t=[];f=[];uv=[]
 for row in path.read_text().splitlines():
  w=row.split()
  if not w:continue
  if w[0]=='v':p.append(list(map(float,w[1:4])))
  elif w[0]=='vt':t.append(tuple(map(float,w[1:3])))
  elif w[0]=='f':
   idx=[e.split('/') for e in w[1:]];f.append([int(i[0])-1 for i in idx]);uv.append([t[int(i[1])-1] for i in idx])
 mesh(path.stem,transfer(np.array(p)),f,uv,material)
def rot(deg,axis):return np.array(Matrix.Rotation(math.radians(deg),3,axis))
def align(a,b):
 return np.array(Vector(a).rotation_difference(Vector(b)).to_matrix())
def norm(a):return a/np.linalg.norm(a)
def handorientation(normal,fingers):
 z=norm(np.array(normal));y=norm(-np.array(fingers)-z*np.dot(-np.array(fingers),z));return np.stack([np.cross(y,z),y,z],axis=1)
def box(name,at,dim,material):
 bpy.ops.mesh.primitive_cube_add(size=1,location=world(*at));o=bpy.context.object;o.name=name;o.dimensions=(dim[0],dim[2],dim[1]);o.data.materials.append(material)
def ball(name,at,dim,material):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=world(*at));o=bpy.context.object;o.name=name;o.scale=(dim[0],dim[2],dim[1]);o.data.materials.append(material)
 for p in o.data.polygons:p.use_smooth=True
skin=mat('Singer skin',(.82,.80,.81),stage/'SkinSinger.png');gown=mat('Plum satin',tex=stage/'CamelliaSatin.png',gloss=.39)
ivory=mat('Dinner jacket',tex=stage/'DinnerJacket.jpg');wood=mat('Walnut',(.095,.043,.023));metal=mat('Mic brass',(.37,.26,.13),gloss=.23)
black=mat('Ebony',(.024,.023,.026));white=mat('Ivory',(.65,.60,.45))
def dress(singer):
 tx=-.50 if singer else .68
 root=np.array([tx,0,0]);rotWorld=rot(-14 if singer else -52,'Y')
 def place(p):return p@rotWorld.T+root
 base=np.array([[0,.96,0],[0,1.02,0],[-.196,1.345,.004],[-.196,1.080,.004],[.196,1.345,.004],[.196,1.080,.004],[-.084,.905,0],[-.084,.515,0],[.084,.905,0],[.084,.515,0],[0,1.477,0]])
 R=[np.eye(3) for _ in base];pos=base.copy()
 if not singer:
  pos[0]+=[-.021,-.412,-.012];R[0]=rot(7,'Y')@rot(-2,'Z');R[1]=R[0]@rot(6,'X')@rot(-5,'Y')
  for h,k,x,y in [(6,7,-85,79),(8,9,-92,94)]:
   R[h]=R[0]@rot(x,'X');R[k]=R[h]@rot(y,'X')
 else:R[1]=rot(-1,'X')@rot(-2,'Z')
 for i,j in [(1,0),(2,1),(4,1),(6,0),(8,0),(7,6),(9,8),(10,1)]:pos[i]=pos[j]+R[j]@(base[i]-base[j])
 R[10]=R[1]@rot(-3 if singer else 13,'X')
 for side,h,e in [(-1,2,3),(1,4,5)]:
  hmat=handorientation(([side,0,0] if singer else [0,-1,0]),([0,.25,1] if singer else [0,0,1]))
  localTip=np.array([0,-.077,.013]) if singer else np.array([0,-.138,.006])
  target=np.array([-.17,1.06,.23] if side<0 else [.06,1.355,.24]) if singer else np.array([side*.20,.79,.39])
  wrist=target-hmat@localTip
  d=np.linalg.norm(wrist-pos[h]);unit=(wrist-pos[h])/d;pole=np.array([side*.44,-1,0]);bend=norm(pole-unit*np.dot(pole,unit))
  co=(.265**2+d*d-.255**2)/(2*.265*d)
  mid=pos[h]+unit*.265*co+bend*.265*np.sqrt(max(0,1-co*co))
  R[h]=align([0,-1,0],mid-pos[h]);R[e]=align([0,-1,0],wrist-mid);pos[e]=mid
  def mount(p):
   # Existing hands are mounted at the wrist with left/right reflected source and anatomical yaw.
   p=p*.82;p=p@rot(-73 if side<0 else 73,'Y').T;p[:,1]+=.013
   curl=.65 if singer and side>0 else .28
   u=np.clip((-p[:,1]-.077)/.062,0,1);u=u*u*(3-2*u)
   knuckles=p.copy();knuckles[:,1]=-.077;knuckles[:,2]+=(.003-knuckles[:,2])*u*.33
   local=p-knuckles;angle=np.deg2rad(-91*u);cy=np.cos(angle);sy=np.sin(angle)
   yy=local[:,1]*cy-local[:,2]*sy;zz=local[:,1]*sy+local[:,2]*cy
   p[:,1]+=curl*(knuckles[:,1]+yy-p[:,1]);p[:,2]+=curl*(knuckles[:,2]+zz-p[:,2])
   return place(p@hmat.T+wrist)
  obj(cast/('HandL.obj' if side<0 else 'HandR.obj'),mount,skin if singer else mat('Hands',tex=cast/'SkinYoungStyled.png'))
 path=stage/'Camellia.bytes' if singer else ward/'Single.bytes';buf=path.read_bytes();n,ni=struct.unpack_from('<ii',buf)
 data=np.ndarray((n,8),'<f4',buffer=buf,offset=8,strides=(52,4));bi=np.ndarray((n,4),'u1',buffer=buf,offset=40,strides=(52,1));bw=np.ndarray((n,4),'<f4',buffer=buf,offset=44,strides=(52,4));f=np.frombuffer(buf,'<u2',count=ni,offset=8+n*52).reshape(-1,3)
 p=data[:,:3];deform=np.zeros(p.shape)
 for i in range(len(base)):
  w=(bw*(bi==i)).sum(axis=1)[:,None];deform+=((p-base[i])@R[i].T+pos[i])*w
 mesh(path.stem,place(deform),f.tolist(),data[:,6:8][f],gown if singer else ivory)
 def skull(p):return place(p@R[10].T+pos[10])
 def skinHead(p):
  p=p.copy();t=np.clip((-.016-p[:,1])/.019,0,1);t=t*t*(3-2*t)
  rad=p[:,[0,2]].copy();rad[:,1]+=.014
  short=rad*np.minimum(1,.061/np.maximum(1e-6,np.linalg.norm(rad,axis=1)))[:,None]
  rad=rad+(short-rad)*t[:,None];rad[:,1]-=.014;p[:,[0,2]]=rad;p[:,1]-=.020*t
  return skull(p)
 obj((stage/'HeadSinger.obj' if singer else cast/'HeadAdult.obj'),skinHead,skin if singer else mat('Pianist face',tex=cast/'SkinYoungStyled.png'))
 obj((stage/'HairSinger.obj' if singer else cast/'HairAdult.obj'),skull,mat('Hair',(.56,.5,.47),stage/'HairSingerGrain.png' if singer else cast/'HairAdultGrain.png'))
 # Textured spherical caps match game diameter, placement, and iris atlas.
 for side in [-1,1]:
  e=np.array([side*.028,.1106,.0824]) if singer else np.array([side*.0286,.0974,.085])
  p=[];coords=[];faces=[];rings=13;sections=48
  for i in range(rings):
   rad=max(.0001,i/(rings-1))
   for j in range(sections+1):
    x=rad*np.cos(j*2*np.pi/sections);y=rad*np.sin(j*2*np.pi/sections)
    p.append(e+rot(side*7,'Y')@np.array([x*.015,y*.011,.0136*np.sqrt(max(0,1-rad**2))]));coords.append((.5+x*.5,.5+y*.5))
    if i and j:
     c=i*(sections+1)+j;faces.append((c-sections-2,c-sections-1,c,c-1))
  mesh('Iris',skull(np.array(p)),faces,[[coords[k] for k in face] for face in faces],mat('Eye',tex=cast/'EyeGlobe.png'))
 if singer:
  at=place(np.array([.06,0,.24]));box('Ribbon pole',[at[0],.73,at[2]],[.024,1.46,.024],metal);ball('Microphone',at+[0,1.56,0],[.053,.085,.043],metal)
 else:
  for j in range(36):
   p=place(np.array([(j-17.5)*.035,.765,.41]));box('Ivory key',p,[.033,.026,.195],white);bpy.context.object.rotation_euler.z=math.radians(-52)
  for y,z,dim in [(.69,.51,[1.42,.12,.29]),(.58,.80,[1.38,1.16,.47]),(.39,-.01,[.69,.13,.31])]:
   box('Piano',place(np.array([0,y,z])),dim,wood);bpy.context.object.rotation_euler.z=math.radians(-52)
dress(True);dress(False)
box('Floor',[0,-.04,0],[12,.08,12],wood)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=14;scene.world.color=(.14,.12,.13)
def aim(o,target):o.rotation_euler=(world(*target)-o.location).to_track_quat('-Z','Y').to_euler()
for pos,power,size,color in [((-2,3.1,2.7),155,1.8,(1,.82,.68)),((2.4,2.0,2.75),135,1.7,(.78,.86,1)),((.9,2.7,-1.5),180,1.3,(1,.67,.47))]:
 bpy.ops.object.light_add(type='AREA',location=world(*pos));l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.data.color=color;aim(l,[0,1,0])
for name,eye,foc,scale,w,h in [('stage-fitting',[3.8,1.77,2.74],[.12,.91,.06],2.40,860,690),('singer-detail',[-1.66,1.63,1.87],[-.52,1.55,.015],.52,480,500),('pianist-detail',[2.8,1.56,1.62],[.65,.93,.15],1.02,540,480)]:
 bpy.ops.object.camera_add(location=world(*eye));cam=bpy.context.object;aim(cam,foc);cam.data.type='ORTHO';cam.data.ortho_scale=scale;scene.camera=cam
 scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.resolution_percentage=100
 scene.render.filepath=str(out/f'{name}.png');bpy.ops.render.render(write_still=True)
