"""Reviewed street dressing and inset shop-light correction."""
import bpy,math
from mathutils import Vector
assert bpy.data.filepath.endswith('amedori-v2.blend')
assert not bpy.context.scene.get('street_furnished',False)
st=bpy.data.objects['street']
mat=bpy.data.materials['light'].copy();mat.name='interior';mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.35
for o in bpy.data.objects:
 if o.name.startswith('warm_interior'):
  o.location.y=-1.005;o.scale.y=.2;o.data.materials.clear();o.data.materials.append(mat)
def finish(o,name,parent,loc,mat):
 o.name=name;o.parent=parent;o.location=loc;o.data.materials.append(bpy.data.materials[mat]);o.hide_render=True
 for f in o.data.polygons:f.use_smooth=True
 return o
def box(name,p,loc,size,mat):
 bpy.ops.mesh.primitive_cube_add();o=bpy.context.object;o.scale=Vector(size)/2;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);finish(o,name,p,loc,mat)
 b=o.modifiers.new('prop_edges','BEVEL');b.width=.012;b.segments=3;o.modifiers.new('prop_normals','WEIGHTED_NORMAL');return o
def cyl(name,p,loc,r,d,mat):
 bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=d);o=finish(bpy.context.object,name,p,loc,mat);b=o.modifiers.new('rim','BEVEL');b.width=.01;b.segments=2;return o
def tube(name,p,pts,r,mat):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=3;s=c.splines.new('POLY');s.points.add(len(pts)-1)
 for point,v in zip(s.points,pts):point.co=(*v,1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=p;c.materials.append(bpy.data.materials[mat]);o.hide_render=True;return o
def empty(name,loc):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=st;o.location=loc;return o
for at in [(-10,13.35,0),(16,13.35,0)]:
 b=empty('city_bicycle',at)
 for x in [-.63,.63]:
  for radius,thickness,mat in [(.43,.033,'rubber'),(.388,.012,'metal')]:
   bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=8,major_radius=radius,minor_radius=thickness)
   o=finish(bpy.context.object,'bicycle_wheel',b,(x,0,.46),mat);o.rotation_euler.x=math.pi/2
  for j in range(12):
   a=j*math.tau/12;tube('wheel_spoke',b,[(x,0,.46),(x+math.cos(a)*.38,0,.46+math.sin(a)*.38)],.003,'metal')
 for pts in [[(-.63,0,.46),(-.20,0,1.02),(.05,0,.46),(-.63,0,.46)], [(-.20,0,1.02),(.42,0,1.03),(.05,0,.46)],[(.42,0,1.03),(.63,0,.46)],[(.42,0,1.03),(.36,0,1.19),(.45,0,1.24)]]:tube('cycle_frame',b,pts,.025,'tilelight')
 tube('handlebar',b,[(.45,-.19,1.24),(.45,0,1.24),(.45,.19,1.24)],.019,'metal')
 box('saddle',b,(-.21,0,1.105),(.24,.17,.065),'rubber')
 tube('seat_post',b,[(-.20,0,.93),(-.20,0,1.1)],.019,'metal')
 tube('crank',b,[(.05,-.07,.46),(.05,-.09,.29),(.05,-.20,.29)],.013,'metal')
 box('pedal',b,(.05,-.20,.29),(.14,.08,.035),'rubber')
for x in [-18,-12.8]:
 t=empty('cafe_furniture',(x,13.8,0));cyl('table_top',t,(0,0,.84),.36,.055,'woodlight');cyl('table_stem',t,(0,0,.43),.035,.78,'metal');cyl('table_base',t,(0,0,.04),.25,.04,'ink')
 cyl('coffee_cup',t,(-.06,-.03,.927),.045,.09,'cream');cyl('saucer',t,(-.06,-.03,.88),.077,.009,'cream')
 for side in [-1,1]:
  y=side*.58;cyl('chair_seat',t,(0,y,.46),.20,.045,'wood')
  for xx in [-.13,.13]:
   for yy in [-.11,.11]:tube('chair_leg',t,[(xx*.9,y+yy,.44),(xx*1.25,y+yy*1.3,.03)],.017,'metal')
  tube('chair_back',t,[(-.17,y+side*.15,.46),(-.17,y+side*.19,.86),(.17,y+side*.19,.86),(.17,y+side*.15,.46)],.025,'woodlight')
# Cases, mixing deck and cable coils on the performance platform.
for x in [-1.2,1.2]:
 c=empty('flight_case',(x,-14.7,0));box('road_case',c,(0,0,.58),(.82,.60,.50),'ink')
 for z in [.34,.82]:box('case_edge',c,(0,0,z),(.85,.63,.035),'metal')
 for sx in [-.40,.40]:
  for sy in [-.30,.30]:box('case_corner',c,(sx,sy,.58),(.035,.035,.50),'metal')
 box('case_latch',c,(0,-.322,.67),(.12,.025,.1),'gold')
 box('mixer',c,(0,0,.9),(.7,.49,.10),'slate')
 for j in range(6):
  box('fader_track',c,(-.27+j*.105,-.06,.956),(.012,.21,.005),'ink')
  box('fader_knob',c,(-.27+j*.105,-.09+j*.019,.97),(.049,.038,.02),'cream')
  cyl('gain_knob',c,(-.27+j*.105,.13,.973),.02,.035,'cyan')
for x in [-2.1,2.1]:
 for k in range(3):
  bpy.ops.mesh.primitive_torus_add(major_segments=40,minor_segments=6,major_radius=.22+k*.015,minor_radius=.008)
  finish(bpy.context.object,'coiled_XLR',st,(x,-14.6,.355+k*.017),'ink')
bpy.context.scene['street_furnished']=True
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('STREET_FURNISHED')
