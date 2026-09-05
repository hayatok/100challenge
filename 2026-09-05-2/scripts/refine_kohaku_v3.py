"""One-time refinement of the saved V3 prototype after first actual render."""
import bpy,os
from mathutils import Vector
R=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=os.path.join(R,'art/source/kohaku-v3.blend'))
head=bpy.data.objects['head'];head.location.z=1.445;head.scale=(1.14,1.14,1.10)
for o in list(bpy.data.objects):
 if o.name in ['nape_blade','nape_blade.001','nape_blade.010','nape_blade.011'] or o.name.startswith('fringe_tonal_break'):
  bpy.data.objects.remove(o,do_unlink=True)
# Reduce neck length, preserve roots under shirt and jaw.
o=bpy.data.objects['neck']
for v in o.data.vertices:v.co.z=1.39+(v.co.z-1.39)*.70
for m in bpy.data.materials:
 if not m.use_nodes:continue
 bs=m.node_tree.nodes.get('Principled BSDF')
 if bs:bs.inputs['Emission Strength'].default_value=.06;bs.inputs['Specular IOR Level'].default_value=.05
for o in bpy.data.objects:
 if o.type=='LIGHT':o.data.energy*=.6
sc=bpy.context.scene;sc.cycles.samples=16;sc.cycles.use_denoising=True
sc.world.node_tree.nodes.get('Background').inputs[1].default_value=.5
sc.render.resolution_x=1000;sc.render.resolution_y=1200
sc.camera.location=(1.4,-5.7,1.85);sc.camera.rotation_euler=(Vector((0,0,.9))-sc.camera.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(R,'art/source/kohaku-v3.blend'))
