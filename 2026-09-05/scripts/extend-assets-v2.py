"""One-time extension of the reviewed v1 source; never overwrites either reviewed source."""
import bpy, math, os
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out=os.path.join(ROOT,'assets/source/cleaning-kit-v2.blend')
if os.path.exists(out): raise RuntimeError('v2 source already exists; edit it in Blender, then export.')
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'assets/source/cleaning-kit.blend'))
bpy.context.preferences.filepaths.save_version=0
mats={m.name:m for m in bpy.data.materials}
for key,rough in [('ink',.62),('cream',.44),('orange',.34),('mint',.48),('purple',.96)]:
 m=mats[key];m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=rough
# Preserve reviewed faces; bevel the robot's toy shell, not its silhouette or eyes.
for o in bpy.data.objects['robot'].children_recursive:
 if o.type=='MESH' and any(k in o.name for k in ['body','cap','bumper','wheel']):
  b=o.modifiers.new('Soft moulded edges','BEVEL');b.width=.045;b.segments=3
  for face in o.data.polygons: face.use_smooth=True
  o.modifiers.new('Stable surface normals','WEIGHTED_NORMAL')
current=[]
def part(name,loc,scale,mat,shape='cube',rot=None):
 if shape=='cyl': bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=1,depth=2,location=loc)
 elif shape=='ball': bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=loc)
 else: bpy.ops.mesh.primitive_cube_add(size=2,location=loc)
 o=bpy.context.object;o.name=name;o.scale=scale
 if rot:o.rotation_euler=rot
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(mats[mat])
 if shape!='ball':
  b=o.modifiers.new('Toy bevel','BEVEL');b.width=min(.08,min(scale)*.4);b.segments=3
  bpy.ops.object.modifier_apply(modifier=b.name)
  o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 else:
  for face in o.data.polygons: face.use_smooth=True
 current.append(o);return o

def finish(name,loc):
 root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
 for o in current:o.parent=root
 root.location=loc;current.clear();return root
# Mint cleaning station; apron remains navigable.
part('station_base',(0,0,.15),(.74,.57,.15),'ink')
part('station_shell',(0,0,.95),(.62,.48,.78),'mint')
part('station_lid',(0,0,1.72),(.69,.54,.12),'cream')
part('station_face',(0,-.493,1.16),(.44,.045,.30),'ink')
part('station_meter',(0,-.55,1.2),(.31,.015,.12),'cream')
part('station_button',(.38,-.55,.62),(.10,.025,.10),'orange','cyl',(math.pi/2,0,0))
part('station_mouth',(0,-.505,.45),(.27,.03,.16),'ink')
part('station_sign',(0,.02,2.17),(.53,.11,.42),'cream')
for x in [-.19,.19]:part('station_sign_eye',(x,-.10,2.21),(.07,.03,.09),'ink','ball')
part('station_sign_smile',(0,-.1,2.01),(.18,.02,.035),'orange')
finish('station', (0,12,0))
# Compact restored storefront. Blender -Y front -> glTF +Z front.
part('shop_wall',(0,0,1.5),(4,1.35,1.5),'cream')
part('shop_foot',(0,0,.12),(4.1,1.5,.12),'ink')
part('shop_shutter',(0,-1.38,1.18),(2.8,.06,1.05),'mint')
for z in [i*.22+.25 for i in range(9)]:part('shutter_rib',(0,-1.45,z),(2.76,.035,.026),'ink')
for x in [-3.35,3.35]:part('shop_pillar',(x,-1.4,1.4),(.14,.16,1.38),'box')
part('shop_sign',(0,-1.45,2.68),(3.15,.12,.30),'ink')
# Tiny geometric boxes on sign: no dependency on system fonts.
for x in [-.9,0,.9]:part('sign_package',(x,-1.59,2.7),(.23,.025,.15),'cream')
for i in range(10):part('awning',(i*.8-3.6,-1.75,2.29),(.40,.50,.09),'orange' if i%2==0 else 'cream',rot=(.13,0,0))
for x in [-3.4,3.4]:
 part('planter',(x,-2.0,.30),(.40,.38,.3),'box')
 for dx in [-.18,.18]:part('foliage',(x+dx,-2,.79),(.31,.29,.43),'mint','ball')
finish('storefront',(8,12,0))
# Mud-foot enemy: reuse reviewed dust silhouette, add oversized orange/brown boots.
src=bpy.data.objects['dust'];root=bpy.data.objects.new('mud',None);bpy.context.collection.objects.link(root);root.location=(16,12,0)
for child in src.children_recursive:
 if child.type=='MESH':
  ob=child.copy();ob.data=child.data.copy();bpy.context.collection.objects.link(ob);ob.parent=root
  ob.location.z+=.20
  if 'tuft' in ob.name or 'fluff' in ob.name: ob.scale*=.90
for x in [-.38,.38]:part('mud_boot',(x,-.18,.18),(.30,.44,.18),'box','ball')
for o in current:o.parent=root
current.clear()
# Small robot details carry personality at the closer play distance.
root=bpy.data.objects['robot']
part('robot_label',(0,.21,.925),(.16,.11,.015),'cream')
part('robot_label_stripe',(0,.21,.944),(.08,.065,.008),'ink')
for i in range(4):part('robot_vent',((i-1.5)*.13,.58,.56),(.035,.025,.12),'ink')
for o in current:o.parent=root
current.clear()
# Refined floor: 4m module with inlaid center diamond.
root=bpy.data.objects['tile']
part('tile_inlay',(0,0,-.002),(.40,.40,.006),'mint',rot=(0,0,math.pi/4))
for o in current:o.parent=root
current.clear()
# Nice material-preview starting view.
bpy.ops.object.select_all(action='DESELECT')
root=bpy.data.objects['station'];root.select_set(True);bpy.context.view_layer.objects.active=root
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.shading.type='MATERIAL'
   area.spaces.active.region_3d.view_distance=15
   area.spaces.active.region_3d.view_location=Vector((7,12,1))
bpy.ops.wm.save_as_mainfile(filepath=out)
print('V2_EXTENSION_READY',out)
