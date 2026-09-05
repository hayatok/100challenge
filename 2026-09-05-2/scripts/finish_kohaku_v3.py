"""Refine saved original V3: welded seams, wispy tapered hair, controlled toon materials.
No external character meshes are used in this source.
"""
import bpy,os,bmesh,math
from mathutils import Vector
R=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=R+'/art/source/kohaku-v3.blend')
for o in bpy.data.objects:
 if o.type=='MESH':
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);bm.to_mesh(o.data);bm.free()
# A ribbon's root should join the crown, not expose a flat cut edge.
for o in bpy.data.objects:
 if o.name.startswith('feathered_fringe'):
  for row in range(3):
   verts=list(o.data.vertices)[row*7:(row+1)*7];c=sum((v.co for v in verts),Vector())/7
   for v in verts:v.co=c+(v.co-c)*[.08,.55,.84][row]
  # UVs follow the hair flow, so painted strands bend with the surface.
  uv=o.data.uv_layers.new(name='HairFlow');rows=len(o.data.vertices)//7
  for l in o.data.loops:uv.data[l.index].uv=((l.vertex_index%7)/6,1-(l.vertex_index//7)/(rows-1))
for o in bpy.data.objects:
 if o.type=='MESH' and any(o.name.startswith(s) for s in ['tapered_side_hair','loose_bun_lock','nape_blade']):
  uv=o.data.uv_layers.new(name='HairFlow');rows=len(o.data.vertices)//7
  for l in o.data.loops:uv.data[l.index].uv=((l.vertex_index%7)/6,1-(l.vertex_index//7)/(rows-1))
# Extra narrow, irregular wisps, kept away from the eyes.
head=bpy.data.objects['head']
def strand(name,pts,r):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=18;c.bevel_depth=r;c.bevel_resolution=2;s=c.splines.new('BEZIER');s.bezier_points.add(len(pts)-1)
 for i,(b,v) in enumerate(zip(s.bezier_points,pts)):b.co=v;b.handle_left_type='AUTO';b.handle_right_type='AUTO';b.radius=1-i/(len(pts)-1)*.95
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=head;c.materials.append(bpy.data.materials['hair_mid'])
for s in [-1,1]:
 for j in range(4):
  strand('fine_side_wisp',[(s*(.07+j*.007),-.024,.277),(s*(.136+j*.006),-.063,.196),(s*(.138+j*.004),-.067,.105),(s*(.12+j*.009),-.091,.04-j*.012)],.0014)
 strand('soft_crown_wisp',[(s*.014,.009,.29),(s*.064,-.001,.313),(s*.102,-.008,.295),(s*.116,-.02,.272)],.0012)
# Cloth folds are deformations of the fabric, not raised decorative wires.
for o in bpy.data.objects:
 if o.name.startswith('parka_sleeve'):
  for v in o.data.vertices:
   z=v.co.z;front=max(0,min(1,(-v.co.y+.005)/.085))
   crease=.004*math.sin((z+.31)*65+v.co.x*35)*math.exp(-((z+.31)/.09)**2)
   v.co.y+=crease*front
# Store export inputs explicitly; custom Blender preview nodes are reconstructed in Godot.
hairimage=bpy.data.images.load(R+'/game/assets/textures/kohaku-hair-v3.png');hairimage.pack()
for m in bpy.data.materials:
 if not m.use_nodes:continue
 bs=m.node_tree.nodes.get('Principled BSDF')
 if not bs:continue
 base=tuple(bs.inputs['Base Color'].default_value);texture=next((n.image for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image),None)
 if m.name in ['hair','hair_mid']:texture=hairimage;base=(1,1,1,1)
 m['kohaku_base']=list(base);m['kohaku_texture']=texture.name if texture else '';m['kohaku_face']=m.name in ['face_painted','skin']
 nodes=m.node_tree.nodes;links=m.node_tree.links;nodes.clear()
 out=nodes.new('ShaderNodeOutputMaterial');em=nodes.new('ShaderNodeEmission');links.new(em.outputs[0],out.inputs['Surface'])
 diffuse=nodes.new('ShaderNodeBsdfDiffuse');diffuse.inputs['Color'].default_value=(1,1,1,1);rgb=nodes.new('ShaderNodeShaderToRGB');links.new(diffuse.outputs[0],rgb.inputs[0]);ramp=nodes.new('ShaderNodeValToRGB');links.new(rgb.outputs[0],ramp.inputs[0]);ramp.color_ramp.interpolation='EASE'
 a,b=ramp.color_ramp.elements;a.position=.18;b.position=.65;a.color=(.72,.63,.69,1) if m['kohaku_face'] else (.49,.46,.57,1);b.color=(1,1,1,1)
 mid=ramp.color_ramp.elements.new(.36);mid.color=(.94,.89,.88,1) if m['kohaku_face'] else (.8,.75,.81,1)
 mult=nodes.new('ShaderNodeMixRGB');mult.blend_type='MULTIPLY';mult.inputs[0].default_value=1;mult.inputs[1].default_value=base;links.new(ramp.outputs['Color'],mult.inputs[2]);links.new(mult.outputs[0],em.inputs['Color'])
 if texture:
  tex=nodes.new('ShaderNodeTexImage');tex.image=texture;links.new(tex.outputs['Color'],mult.inputs[1])
# Preserve undecorated materials on the scalp and bun core; hair flow UVs are on the ribbons.
for o in bpy.data.objects:
 if o.type=='MESH' and o.name in ['cropped_hair_mass','loose_bun_core']:
  plain=bpy.data.materials.get('hair_light').copy();plain.name='hair_crown_plain';plain['kohaku_base']=[.022,.017,.028,1];plain['kohaku_texture']=''
  for n in plain.node_tree.nodes:
   if n.type=='MIX_RGB':n.inputs[1].default_value=(.022,.017,.028,1)
  o.data.materials.clear();o.data.materials.append(plain)
sc=bpy.context.scene;sc.render.engine='BLENDER_EEVEE';sc.render.resolution_x=1100;sc.render.resolution_y=1300
sc.world.node_tree.nodes.get('Background').inputs[0].default_value=(.57,.60,.63,1)
sc.world.node_tree.nodes.get('Background').inputs[1].default_value=.65
sc.camera.location=(1.4,-5.7,1.85);sc.camera.rotation_euler=(Vector((0,0,.9))-sc.camera.location).to_track_quat('-Z','Y').to_euler();sc.camera.data.ortho_scale=2.05
bpy.ops.wm.save_as_mainfile(filepath=R+'/art/source/kohaku-v3.blend')
