"""Render the posed wardrobe buffers with the game's head, hair, eyes and anatomical hands.
blender -b -t 4 -P render.py -- <Game/Assets/Resources> <KinseiMakabe> <pose.py output>
"""
import bpy,sys,math
import numpy as np
from mathutils import Vector
from pathlib import Path
lib,custom,out=map(Path,sys.argv[-3:]);cast=lib/'KinseiCast';ward=lib/'KinseiWardrobe'
def world(p):return (p[0],-p[2],p[1])
def mat(name,texture,tint=(1,1,1),normal=None,rough=.72):
 m=bpy.data.materials.new(name);m.use_nodes=True;nodes=m.node_tree.nodes;links=m.node_tree.links;bs=nodes.get('Principled BSDF')
 tx=nodes.new('ShaderNodeTexImage');tx.image=bpy.data.images.load(str(texture),check_existing=True)
 mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*tint,1);links.new(tx.outputs[0],mix.inputs[1]);links.new(mix.outputs[0],bs.inputs['Base Color']);bs.inputs['Roughness'].default_value=rough
 if normal:
  n=nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(normal),check_existing=True);n.image.colorspace_settings.name='Non-Color'
  b=nodes.new('ShaderNodeNormalMap');b.inputs['Strength'].default_value=.65;links.new(n.outputs[0],b.inputs['Color']);links.new(b.outputs[0],bs.inputs['Normal'])
 return m
def mesh(label,p,faces,uv,material,normals=None,detail=None):
 m=bpy.data.meshes.new(label);m.from_pydata([world(i) for i in p],[],faces);m.update();layer=m.uv_layers.new().data
 for poly,tuv in zip(m.polygons,uv):
  poly.use_smooth=True
  for ix,value in zip(poly.loop_indices,tuv):layer[ix].uv=value
 if detail is not None:
  second=m.uv_layers.new(name="Measured weave").data
  for loop in m.loops:second[loop.index].uv=detail[loop.vertex_index]
  m.uv_layers.active_index=0;m.uv_layers[0].active_render=True
 if normals is not None:m.normals_split_custom_set_from_vertices([world(n) for n in normals])
 obj=bpy.data.objects.new(label,m);bpy.context.collection.objects.link(obj);m.materials.append(material)
def parse(file):
 v=[];uv=[];faces=[];coords=[]
 for line in file.read_text().splitlines():
  w=line.split()
  if not w:continue
  if w[0]=='v':v.append([float(j) for j in w[1:4]])
  elif w[0]=='vt':uv.append(tuple(map(float,w[1:3])))
  elif w[0]=='f':
   fields=[j.split('/') for j in w[1:]]
   faces.append([int(j[0])-1 for j in fields]);coords.append([uv[int(j[1])-1] for j in fields])
 return np.array(v),faces,coords
parts={name:parse(cast/f'{name}.obj') for name in ['HeadAdult','HairAdult','HandL','HandR']}
skin=mat('MakeHuman skin',cast/'SkinYoungStyled.png',(.73,.71,.72))
hair=mat('Combed hair',cast/'HairAdultGrain.png',(.10,.089,.084))
eye=mat('Iris',cast/'EyeGlobe.png',(.84,.82,.80),rough=.42)
fabric={'old':mat('Original navy',ward/'Navy.jpg',normal=ward/'SingleNormal.png'),'new':mat('Blue-black herringbone',custom/'MakabeWool.jpg',normal=custom/'MakabeWoolNormal.png')}
nodes=fabric['new'].node_tree.nodes;links=fabric['new'].node_tree.links
uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map='Measured weave'
micro=nodes.new('ShaderNodeTexImage');micro.image=bpy.data.images.load(str(custom/'WorstedThreads.png'));micro.image.colorspace_settings.name='Non-Color';links.new(uvnode.outputs[0],micro.inputs[0])
bump=nodes.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.000036;bump.inputs['Strength'].default_value=.42
links.new(micro.outputs['Alpha'],bump.inputs['Height']);links.new(nodes.get('Normal Map').outputs[0],bump.inputs['Normal']);links.new(bump.outputs[0],nodes.get('Principled BSDF').inputs['Normal'])
def aim(o,target):o.rotation_euler=(Vector(world(target))-o.location).to_track_quat('-Z','Y').to_euler()
def render(name,version):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 d=np.load(out/f'{name}-{version}.npz');p,n,uv,tri,P,R=[d[k] for k in ['p','n','uv','tri','P','R']]
 mesh('Tailored coat and trousers',p,tri.tolist(),uv[tri],fabric[version],n,d["detail"] if version=="new" else None)
 for label,(q,faces,coords) in parts.items():
  q=q.copy()
  if label.startswith('Hand'):
   side=-1 if label=='HandL' else 1;angle=np.deg2rad(side*73);c,s=np.cos(angle),np.sin(angle)
   q=q*.82@np.array([[c,0,-s],[0,1,0],[s,0,c]]);q[:,1]+=.013
   finger=np.clip((-q[:,1]-.077)/.062,0,1);finger=finger*finger*(3-2*finger);k=q.copy();k[:,1]=-.077;k[:,2]+=(.003-k[:,2])*finger*.33
   bend=q-k;theta=np.deg2rad(-91)*finger;dy=bend[:,1]*np.cos(theta)-bend[:,2]*np.sin(theta);dz=bend[:,1]*np.sin(theta)+bend[:,2]*np.cos(theta)
   weight=.65 if name=='guard' else (.32 if side<0 else .44)
   q[:,1]+=weight*(k[:,1]+dy-q[:,1]);q[:,2]+=weight*(k[:,2]+dz-q[:,2]);bone=11 if side<0 else 12
  else:
   bone=10
   if label=='HeadAdult':
    t=np.clip((-.016-q[:,1])/.019,0,1);t=t*t*(3-2*t);rad=q[:,[0,2]].copy();rad[:,1]+=.014
    short=rad*np.minimum(1,.061/np.maximum(1e-6,np.linalg.norm(rad,axis=1)))[:,None];rad+=t[:,None]*(short-rad);rad[:,1]-=.014;q[:,[0,2]]=rad;q[:,1]-=.020*t
  transformed=q@R[bone].T+P[bone]
  if label.startswith('Hand'):
   elbow=3 if side<0 else 5
   t=np.clip((.010-q[:,1])/.055,0,1);follow=t*t*(3-2*t)
   anchor=(q+[0,-.255,0])@R[elbow].T+P[elbow]
   transformed=anchor*(1-follow[:,None])+transformed*follow[:,None]
  mesh(label,transformed,faces,coords,hair if label.startswith('Hair') else skin)
 for side in [-1,1]:
  ep=[];ef=[];eu=[];center=np.array([side*.0286,.0974,.085]);phi=math.radians(side*7);co,si=np.cos(phi),np.sin(phi)
  for i in range(10):
   rad=max(.0001,i/9)
   for j in range(33):
    a=j*math.pi/16;xx=np.cos(a)*rad;yy=np.sin(a)*rad;zz=.0136*np.sqrt(max(0,1-rad*rad))
    ep.append(center+np.array([xx*.015*co+zz*si,yy*.011,-xx*.015*si+zz*co]));eu.append((.5+xx*.5,.5+yy*.5))
    if i and j:
     k=i*33+j;ef.append([k-34,k-33,k,k-1])
  mesh('Inset eye',np.array(ep)@R[10].T+P[10],ef,[[eu[k] for k in f] for f in ef],eye)
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16;scene.world.color=(.13,.13,.15);scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=-.25
 for xyz,power,size,col in [((-.90,2.32,-.85),60,.53,(1,.86,.73)),((1.0,1.56,-1.15),67,.55,(.74,.84,1)),((.35,2.25,1.17),87,.68,(1,.91,.77)),((-.83,1.41,.80),37,.75,(.80,.85,1))]:
  bpy.ops.object.light_add(type='AREA',location=world(xyz));o=bpy.context.object;o.data.energy=power;o.data.size=size;o.data.color=col;aim(o,[0,1.23,0])
 shots=[('front',(.13,1.37,2.85)),('side',(2.85,1.36,.16)),('back',(.13,1.41,-2.89))] if name=='idle' else [('rear-three-quarter',(.98,1.58,-2.70))]
 if version=='new' and name=='idle':
  shots+= [('cloth-collar',(.14,1.54,-.64)),('cloth-vent',(.15,.99,-.63))]
 if '--details-only' in sys.argv:shots=[s for s in shots if s[0].startswith('cloth')]
 for view,xyz in shots:
  bpy.ops.object.camera_add(location=world(xyz));cam=bpy.context.object;aim(cam,[0,1.18,0]);cam.data.type='ORTHO';cam.data.ortho_scale=1.15 if name=='idle' else 1.32;scene.camera=cam
  if view=='cloth-collar':aim(cam,[.042,1.381,-.073]);cam.data.ortho_scale=.201
  if view=='cloth-vent':aim(cam,[.003,.907,-.132]);cam.data.ortho_scale=.203
  scene.render.resolution_x=540;scene.render.resolution_y=660;scene.render.resolution_percentage=100
  scene.render.filepath=str(out/f'{name}-{view}-{version}.png');bpy.ops.render.render(write_still=True)
for pose in ['idle','guard','reach']:
 for version in ['old','new']:
  if '--details-only' not in sys.argv or (pose=='idle' and version=='new'):render(pose,version)
