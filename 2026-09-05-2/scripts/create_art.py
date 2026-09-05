"""Initial asset construction. Execute from Blender's Python console; never overwrite reviewed source."""
import bpy, math, os
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET=os.path.join(ROOT,'art/source/yofukashi-kit.blend')
if os.path.exists(TARGET): raise RuntimeError('Reviewed source exists. Open it; do not regenerate.')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
COLORS={'ink':'172635','pink':'ED7183','skin':'F4CCB0','cream':'FFF0CD','cyan':'5EE5E1','orange':'FA9D5C','hair':'352F43','blue':'47677F','lime':'CFDB76','gold':'FBD783','wood':'715747'}
mats={}
for name,h in COLORS.items():
 m=bpy.data.materials.new(name); m.diffuse_color=tuple(int(h[i:i+2],16)/255 for i in (0,2,4))+(1,); m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=m.diffuse_color;bs.inputs['Roughness'].default_value=.85;mats[name]=m
roots={}
def group(name,pos):
 e=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(e);e.location=pos;roots[name]=e;return e
def piece(name,root,loc,scale,mat,shape='cube',rot=(0,0,0)):
 if shape=='sphere':bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8)
 elif shape=='cylinder':bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=1,depth=2)
 elif shape=='cone':bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=1,radius2=.75,depth=2)
 else:bpy.ops.mesh.primitive_cube_add()
 o=bpy.context.object;o.name=name;o.parent=root;o.location=loc;o.scale=scale;o.rotation_euler=rot;o.data.materials.append(mats[mat]);
 if shape=='cube':
  mod=o.modifiers.new('soft_edges','BEVEL');mod.width=.12;mod.segments=1
 return o
p=group('kohaku',(-4,0,0))
piece('jacket',p,(0,0,1.04),(.31,.20,.35),'pink','cone')
piece('shirt',p,(0,-.202,1.02),(.14,.014,.23),'cream')
piece('zip',p,(0,-.224,.97),(.015,.008,.24),'ink')
piece('collar_left',p,(-.12,-.2,1.33),(.105,.05,.09),'pink',rot=(0,.3,0))
piece('collar_right',p,(.12,-.2,1.33),(.105,.05,.09),'pink',rot=(0,-.3,0))
piece('skirt',p,(0,0,.69),(.31,.22,.14),'ink','cone')
piece('neck',p,(0,0,1.41),(.09,.08,.09),'skin','cylinder')
piece('face',p,(0,-.018,1.66),(.24,.21,.29),'skin','sphere')
piece('hair_cap',p,(0,.03,1.79),(.258,.22,.24),'hair','sphere')
for s in [-1,1]:
 piece('sleeve',p,(s*.36,0,1.10),(.13,.18,.26),'pink',rot=(0,s*.17,0))
 piece('hand',p,(s*.39,-.012,.83),(.08,.10,.105),'skin','sphere')
 piece('leg',p,(s*.16,0,.39),(.085,.09,.24),'ink','cylinder')
 piece('shoe',p,(s*.16,-.10,.13),(.13,.22,.09),'cream')
 piece('sole',p,(s*.16,-.10,.055),(.135,.225,.025),'cyan')
 piece('eye',p,(s*.085,-.212,1.67),(.026,.018,.04),'ink','sphere')
 piece('cheek',p,(s*.15,-.188,1.60),(.042,.018,.017),'pink','sphere')
 piece('half_twin',p,(s*.285,.06,1.69),(.11,.13,.23),'hair','sphere',rot=(0,s*.3,0))
 piece('hair_clip',p,(s*.22,-.105,1.85),(.045,.026,.045),'gold','sphere')
 piece('bang',p,(s*.10,-.18,1.80),(.095,.075,.13),'hair','sphere',rot=(0,s*.25,0))
piece('star_patch',p,(-.21,-.215,1.20),(.05,.012,.05),'gold',rot=(0,math.pi/4,0))
piece('mic_handle',p,(.4,-.14,1.03),(.033,.033,.16),'ink','cylinder',rot=(.25,0,0))
piece('mic_head',p,(.4,-.19,1.20),(.07,.065,.075),'cream','sphere')
e=group('call_bit',(0,0,0))
piece('shell',e,(0,0,.50),(.27,.19,.26),'orange')
piece('speaker',e,(0,-.195,.50),(.20,.025,.19),'ink','cylinder',rot=(math.pi/2,0,0))
piece('speaker_inner',e,(0,-.23,.50),(.11,.012,.11),'gold','sphere')
for s in [-1,1]:
 piece('eye',e,(s*.085,-.223,.69),(.03,.012,.035),'cream')
 piece('leg',e,(s*.17,0,.13),(.035,.035,.14),'ink','cylinder',rot=(0,s*.3,0))
 piece('foot',e,(s*.20,-.055,.05),(.075,.105,.04),'ink')
piece('antenna',e,(.16,0,.89),(.015,.015,.16),'ink','cylinder')
piece('antenna_light',e,(.16,0,1.06),(.055,.05,.055),'cyan','sphere')
s=group('stall',(4,0,0))
piece('counter',s,(0,0,.55),(.9,.48,.55),'wood')
piece('top',s,(0,-.08,1.13),(1,.59,.06),'cream')
for x in [-.88,.88]:piece('post',s,(x,.35,1.55),(.045,.05,.8),'ink')
for i in range(6):piece('awning',s,(-.85+i*.34,0,2.31),(.18,.75,.075),'pink' if i%2 else 'cream',rot=(.12,0,0))
piece('sign',s,(0,-.42,1.88),(.44,.06,.19),'gold')
for x in [-.65,0,.65]:piece('bowl',s,(x,-.1,1.25),(.14,.14,.09),'cyan','sphere')
b=group('building',(8,0,0))
piece('facade',b,(0,0,2),(1.2,.7,2),'blue')
piece('roof',b,(0,0,4.06),(1.32,.85,.1),'ink')
for x in [-.6,.6]:
 for z in [1.1,2.3,3.5]:piece('window',b,(x,-.72,z),(.30,.025,.28),'gold')
piece('door',b,(0,-.72,.6),(.29,.03,.6),'ink')
sp=group('speaker',(11,0,0))
piece('cabinet',sp,(0,0,.65),(.36,.26,.65),'ink')
for z in [.36,.98]:
 piece('cone',sp,(0,-.27,z),(.23,.025,.23),'blue','cylinder',rot=(math.pi/2,0,0))
 piece('cone_cap',sp,(0,-.3,z),(.08,.02,.08),'cream','sphere')
# Studio setup remains in the editable source, excluded from model exports.
bpy.ops.object.light_add(type='AREA',location=(1,-5,8));bpy.context.object.data.energy=1000;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=8
bpy.ops.object.camera_add(location=(7,-12,9));cam=bpy.context.object;cam.rotation_euler=(Vector((2,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=19;bpy.context.scene.camera=cam
bpy.context.scene.world.color=(.3,.3,.3)
bpy.ops.object.select_all(action='DESELECT')
for o in p.children:o.select_set(True)
bpy.context.view_layer.objects.active=p.children[0]
bpy.ops.wm.save_as_mainfile(filepath=TARGET)
print('LOOP_ART_CREATED',TARGET)
