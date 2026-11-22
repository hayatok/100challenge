import bpy,json,os,sys,math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parent;sys.path.insert(0,str(root))
from fit_basin_grip import fit
a=fit();bpy.ops.wm.read_factory_settings(use_empty=True)
def obj(name,verts,faces,color):
 m=bpy.data.meshes.new(name);m.from_pydata([(float(x),float(-z),float(y))for x,y,z in verts],[],faces);m.update()
 for p in m.polygons:p.use_smooth=True
 o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);m.materials.append(mat);return o
obj('Actual imported Kiichi left hand candidate',a['v'],a['tri'].tolist(),(.53,.33,.22))
cy,cz=-.10975,.00825;R=.165
v=[];f=[]
for row,(r,y) in enumerate([(.11,cy-.086),(.165,cy),(.160,cy),(.105,cy-.075)]):
 for j in range(128):
  t=j*math.pi*2/128;v.append((r*math.cos(t),y,cz+R+r*math.sin(t)))
for row in range(3):
 for j in range(128):a0=row*128+j;b=row*128+(j+1)%128;c=a0+128;d=b+128;f.append((a0,b,d,c))
obj('Basin outer and inner wall',v,f,(.46,.65,.68))
v=[];f=[]
for i in range(128):
 t=i*math.pi*2/128
 for j in range(12):
  s=j*math.pi*2/12;r=R+.0027*math.cos(s);v.append((r*math.cos(t),cy+.0027*math.sin(s),cz+R+r*math.sin(t)))
for i in range(128):
 for j in range(12):f.append((i*12+j,((i+1)%128)*12+j,((i+1)%128)*12+(j+1)%12,i*12+(j+1)%12))
obj('Measured navy rolled rim',v,f,(.05,.10,.14))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.world=bpy.data.worlds.new('Study');scene.world.color=(.2,.2,.2)
for loc,power in [((.15,.10,.15),15),((-.12,-.2,.2),10)]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=power;l.data.size=.25;l.rotation_euler=(Vector((0,-.03,-.12))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=.25;scene.camera=cam;scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
for name,loc,target in [('outer',(.17,.27,.08),(0,-.04,-.11)),('side',(.35,-.04,.015),(0,-.04,-.11))]:
 cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(root/('kiichi-rim-offline-'+name+'.png'));bpy.ops.render.render(write_still=True)
