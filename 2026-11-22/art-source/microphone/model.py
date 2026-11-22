"""Build, separate and export the Kinsei ribbon microphone in metres. Blender 5.3 background.
blender -b -P model.py -- <resource-directory> <inspection-directory>
"""
from pathlib import Path
import sys,math
import bpy,numpy as np
from mathutils import Vector
out,qa=map(Path,sys.argv[-2:]);bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
material=bpy.data.materials.new('Ribbon Finishes');material.use_nodes=True
bs=material.node_tree.nodes.get('Principled BSDF');ct=material.node_tree.nodes.new('ShaderNodeTexImage');ct.image=bpy.data.images.load(str(out/'RibbonFinish.png'))
mt=material.node_tree.nodes.new('ShaderNodeTexImage');mt.image=bpy.data.images.load(str(out/'RibbonReflectance.png'));mt.image.colorspace_settings.name='Non-Color'
sep=material.node_tree.nodes.new('ShaderNodeSeparateColor');inv=material.node_tree.nodes.new('ShaderNodeMath');inv.operation='SUBTRACT';inv.inputs[0].default_value=1
links=material.node_tree.links;links.new(ct.outputs[0],bs.inputs['Base Color']);links.new(mt.outputs[0],sep.inputs[0]);links.new(sep.outputs[0],bs.inputs['Metallic']);links.new(mt.outputs[1],inv.inputs[1]);links.new(inv.outputs[0],bs.inputs['Roughness'])
def unit(v):
 v=np.array(v,dtype=float);return v/max(1e-12,np.linalg.norm(v))
def cubic(a,b,c,d,n):
 t=np.linspace(0,1,n)[:,None];return (1-t)**3*np.array(a)+3*t*(1-t)**2*np.array(b)+3*t*t*(1-t)*np.array(c)+t**3*np.array(d)
class Piece:
 def __init__(self,name): self.name=name;self.p=[];self.f=[];self.uv=[]
 def gr(self,grid,tile,flip=False):
  grid=np.array(grid);h,w=grid.shape[:2];off=len(self.p);self.p.extend(grid.reshape(-1,3))
  if h<2 or w<2:return
  for j in range(h-1):
   for i in range(w-1):
    ids=[(j,i),(j,i+1),(j+1,i+1),(j+1,i)]
    if flip:ids.reverse()
    self.f.append([off+y*w+x for y,x in ids])
    self.uv.append([(((tile%4)+.012+.976*x/(w-1))/4,((tile//4)+.012+.976*y/(h-1))/4) for y,x in ids])
 def tube(self,path,radii,tile,steps=12):
  p=np.array(path,float);ts=np.array([unit(t) for t in np.gradient(p,axis=0)])
  # Parallel-transport cross-sections through the cable bends.
  ref=np.eye(3)[np.argmin(np.abs(ts[0]))];x=unit(np.cross(ref,ts[0]));rings=[]
  for j,(at,t) in enumerate(zip(p,ts)):
   x=unit(x-np.dot(x,t)*t);y=np.cross(t,x);a=np.linspace(0,2*np.pi,steps+1)
   radius=radii if np.isscalar(radii) else radii[j]
   rings.append(at+radius*(np.cos(a)[:,None]*x+np.sin(a)[:,None]*y))
  self.gr(rings,tile)
 def lathe(self,cx,cy,profile,tile,sections=48,exp=1):
  a=np.linspace(0,2*np.pi,sections+1)
  x=np.sign(np.cos(a))*np.abs(np.cos(a))**exp;y=np.sign(np.sin(a))*np.abs(np.sin(a))**exp
  self.gr([np.stack((cx+rx*x,cy+ry*y,z+0*a),axis=-1) for z,rx,ry in profile],tile)
 def rod(self,a,b,rad,tile,n=16):
  a,b=np.array(a),np.array(b);self.tube([a,a+(b-a)*.004,b-(b-a)*.004,b],[.00001,rad,rad,.00001],tile,n)
 def block(self,at,dims,tile):
  x,y,z=at;hx,hy,hz=np.array(dims)*.5
  self.lathe(x,y,[(z-hz,.00001,.00001),(z-hz,hx*.93,hy*.93),(z-hz+.12*hz,hx,hy),(z+hz-.12*hz,hx,hy),(z+hz,hx*.93,hy*.93),(z+hz,.00001,.00001)],tile,24,.23)
 def done(self):
  pos=np.array(self.p);center=(pos.min(0)+pos.max(0))*.5;m=bpy.data.meshes.new(self.name);m.from_pydata((pos-center).tolist(),[],self.f);m.update();layer=m.uv_layers.new().data
  for face,uv in zip(m.polygons,self.uv):
   face.use_smooth=True
   for i,co in zip(face.loop_indices,uv):layer[i].uv=co
  o=bpy.data.objects.new(self.name,m);bpy.context.collection.objects.link(o);o.location=center;m.materials.append(material);return o
def roundbody(p,z,rx,ry,tile):
 p.lathe(0,0,z,tile,52,.61)
base=Piece('01 Cast-iron base and rubber sole')
base.lathe(0,0,[(.002,.001,.001),(.002,.131,.131),(.005,.141,.141),(.014,.141,.141),(.016,.136,.136)],9)
base.lathe(0,0,[(.013,.134,.134),(.017,.143,.143),(.022,.145,.145),(.029,.141,.141),(.034,.133,.133),(.043,.101,.101),(.049,.056,.056),(.050,.018,.018)],5,72)
base.lathe(0,0,[(.027,.142,.142),(.029,.142,.142),(.030,.139,.139)],2,72);base.done()
shaft=Piece('02 Telescoping post and threaded bush')
shaft.lathe(0,0,[(.045,.025,.025),(.048,.029,.029),(.056,.029,.029),(.060,.020,.020),(.067,.019,.019),(.070,.012,.012),(.85,.012,.012),(.852,.009,.009),(1.416,.0084,.0084),(1.419,.011,.011)],0)
for z,r,h in [(.054,.028,.003),(.78,.017,.017),(.80,.018,.012),(1.413,.013,.010)]:
 shaft.lathe(0,0,[(z-h,r*.86,r*.86),(z-h*.80,r,r),(z+h*.80,r,r),(z+h,r*.86,r*.86)],1)
# The singer's palm still lands at local height 1.355 m, on the centreline of this removable grip.
shaft.lathe(0,0,[(1.327,.009,.009),(1.332,.016,.016),(1.338,.017,.017),(1.372,.017,.017),(1.378,.015,.015),(1.382,.009,.009)],4)
for z in [1.334,1.375]:
 shaft.lathe(0,0,[(z-.001,.0164,.0164),(z,.0176,.0176),(z+.001,.0165,.0165)],2)
shaft.done()
# Curved cast yoke has a rectangular cross-section; it passes below both suspension washers.
yoke=Piece('03 Bronze horseshoe yoke')
path=np.vstack([[[.036,0,1.515],[.036,0,1.459]],cubic([.036,0,1.459],[.036,0,1.436],[.026,0,1.425],[.013,0,1.425],14)[1:],[[0,0,1.425],[-.013,0,1.425]],cubic([-.013,0,1.425],[-.026,0,1.425],[-.036,0,1.436],[-.036,0,1.459],14)[1:],[[-.036,0,1.515]]])
rings=[]
for q,t in zip(path,np.gradient(path,axis=0)):
 n=unit(np.cross(unit(t),[0,1,0]));v=np.array([0,.006,0]);n*=.0022
 rings.append([q-n-v,q+n-v,q+n+v,q-n+v,q-n-v])
yoke.gr(rings,1,True);yoke.lathe(0,0,[(1.414,.011,.011),(1.416,.016,.016),(1.424,.016,.016),(1.430,.010,.010)],1);yoke.done()
head=1.518
caps=Piece('04 Worn nickel crown and tail')
for side in [-1,1]:
 profile=[(.041,.029,.021),(.045,.029,.021),(.050,.0283,.0204),(.054,.026,.019),(.057,.021,.015),(.059,.014,.010),(.0592,.0001,.0001)]
 caps.lathe(0,0,sorted([(head+side*z,rx,ry) for z,rx,ry in profile]),0,56,.62)
 # Narrow brass edge is visible where repeated polishes have worn through the plating.
 caps.lathe(0,0,[(head+side*.043-.00065,.0291,.0211),(head+side*.043+.00065,.0292,.0212)],8,56,.62)
caps.done()
cage=Piece('05 Nine open grille ribs and two spines')
for z in np.linspace(-.039,.039,9):
 cage.lathe(0,0,[(head+z-.00135,.0277,.0199),(head+z-.00086,.0291,.0212),(head+z+.00086,.0291,.0212),(head+z+.00135,.0277,.0199)],0,52,.62)
for side in [-1,1]:
 spine=[]
 for zz,dep in [(-.058,.012),(-.054,.019),(-.046,.0215),(-.038,.0218),(0,.0218),(.038,.0218),(.046,.0215),(.054,.019),(.058,.012)]:
  y=side*dep;spine.append([[-.0025,y,head+zz],[-.0020,y+side*.00072,head+zz],[.002,y+side*.00072,head+zz],[.0025,y,head+zz]])
 cage.gr(spine,6,side>0)
for side in [-1,1]:
 # The cast cheek plates carry the screw load from the two trunnions into the grille.
 cage.block((side*.0273,0,head),(.0036,.011,.090),0)
cage.done()
# Two individually removable woven screens. Open space and wire silhouettes survive close inspection.
for side in [-1,1]:
 grille=Piece(('06 Front' if side<0 else '07 Rear')+' woven acoustic basket')
 for x in np.arange(-.025,.0251,.00136):
  z=np.linspace(-.043,.043,8);y=side*(.0165-.0032*(abs(x)/.026)**3+.00012*np.cos(z*2*np.pi/.00272))
  grille.tube(np.stack([0*z+x,y,head+z],axis=-1),.00024,3,4)
 for z in np.arange(-.043,.0431,.00136):
  x=np.linspace(-.025,.025,8);y=side*(.0164-.0032*(abs(x)/.026)**3-.00012*np.cos(x*2*np.pi/.00272))
  grille.tube(np.stack([x,y,0*x+head+z],axis=-1),.00022,3,4)
 grille.done()
motor=Piece('08 Pole shoes and corrugated ribbon')
for x in [-.009,.009]:motor.block((x,0,head),(.011,.012,.084),3)
motor.block((0,.007,head),(.024,.002,.082),9)
z=np.linspace(-.038,.038,145);y=.0004*np.cos(np.arange(len(z))*np.pi)
motor.gr([[[x,h,head+k] for x in [-.002,.002]] for k,h in zip(z,y)],8)
for zz in [-.040,.040]:motor.block((0,0,head+zz),(.022,.009,.005),2)
motor.done()
susp=Piece('09 Compliant suspension and hinge washers')
for s in [-1,1]:
 susp.rod((s*.027,0,head),(s*.035,0,head),.0087,9)
 for z in [-.030,.030]:
  susp.rod((s*.012,0,head+z),(s*.027,.001,head+z*1.28),.00135,9)
susp.done()
for side in [-1,1]:
 screw=Piece(('10 Left' if side<0 else '11 Right')+' knurled pivot screw')
 screw.rod((side*.031,0,head),(side*.041,0,head),.0055,6)
 screw.rod((side*.0382,0,head),(side*.0438,0,head),.0095,6,48)
 for a in np.linspace(0,2*np.pi,37)[:-1]:
  y,z=.0095*np.cos(a),head+.0095*np.sin(a)
  screw.rod((side*.0388,y,z),(side*.0432,y,z),.00038,8,5)
 screw.block((side*.0439,0,head),(.00032,.011,.00125),3);screw.done()
conn=Piece('12 Lower plug and braided strain relief')
conn.rod((0,.008,head-.056),(.003,.008,head-.076),.0067,2)
conn.rod((.003,.008,head-.076),(.004,.008,head-.088),.0047,9)
for zz in np.arange(-.086,-.073,.002):conn.rod((.003,.008,head+zz),(.003,.008,head+zz+.0008),.0054,3)
conn.done()
cord=Piece('13 Cloth lead with overbraid')
spans=[([.004,.008,1.431],[.006,.009,1.397],[.048,.022,1.403],[.029,.023,1.341]),([.029,.023,1.341],[.012,.020,1.289],[.012,.009,1.19],[.011,.009,1.10]),([.011,.009,1.10],[.011,.009,.86],[.019,.021,.50],[.016,.035,.13]),([.016,.035,.13],[.015,.050,.064],[.043,.151,.005],[.092,.188,.005]),([.092,.188,.005],[.265,.368,.006],[.64,.23,.006],[.91,.69,.006])]
path=np.vstack([cubic(*arr,65)[int(i>0):] for i,arr in enumerate(spans)]);cord.tube(path,.0027,4,12)
# Short helical tracers near the connector and the handgrip, where the cloth is visible on camera.
q=cubic(*spans[0],155);ts=np.array([unit(t) for t in np.gradient(q,axis=0)]);phase=np.cumsum(np.r_[0,np.linalg.norm(np.diff(q,axis=0),axis=1)])*2*np.pi/.006
for a in [0,np.pi]:
 offsets=[]
 for p,t,v in zip(q,ts,phase):
  right=unit(np.cross(t,[0,1,0]));other=np.cross(t,right);offsets.append(p+.00255*(np.cos(v+a)*right+np.sin(v+a)*other))
 cord.tube(offsets,.00031,8,5)
cord.done()
badge=Piece('14 Kinsei burgundy enamel badge')
# Planar 31 x 10 mm removable enamel plate mounted between tail and front grille.
z=head-.0498;x=.0155;y=-.0212;h=.0047
badge.gr([[[-x,y,z-h],[x,y,z-h]],[[-x,y,z+h],[x,y,z+h]]],7)
badge.done()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.fbx(filepath=str(out/'KinseiRibbon.fbx'),use_selection=True,object_types={'MESH'},global_scale=1,
 apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',bake_anim=False,add_leaf_bones=False,path_mode='STRIP',mesh_smooth_type='FACE')
# Neutral product shot of the 3D meshes, plus an exploded service view of the fittings.
def point(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16;scene.world.color=(.23,.25,.26)
for loc,focus,energy,size,tint in [((-.25,-.35,1.73),(0,0,head),5,.30,(1,.86,.70)),((.27,-.19,1.56),(0,0,head),3.8,.21,(.81,.88,1)),((.04,.25,1.70),(0,0,head),7,.19,(1,.85,.65))]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.size=size;o.data.color=tint;point(o,focus)
for name,loc,focus,scale in [('assembled',(.14,-.31,1.61),(0,0,1.503),.22),('service',(.16,-.39,1.65),(0,-.016,1.505),.34)]:
 if name=='service':
  for o in list(scene.objects):
   shifts={'04':(0,0,.085),'05':(.064,.003,0),'06':(-.04,-.036,0),'07':(-.048,.025,0),'10':(-.030,0,0),'11':(.089,0,0),'14':(.064,-.014,0)}
   if o.name[:2] in shifts:o.location+=Vector(shifts[o.name[:2]])
 bpy.ops.object.camera_add(location=loc);cam=bpy.context.object;point(cam,focus);cam.data.type='ORTHO';cam.data.ortho_scale=scale;scene.camera=cam;scene.render.resolution_x=680;scene.render.resolution_y=580;scene.render.resolution_percentage=100
 scene.render.filepath=str(qa/(name+'.png'));bpy.ops.render.render(write_still=True)
