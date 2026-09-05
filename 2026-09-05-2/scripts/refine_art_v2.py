"""One-time sculpt refinement of the v2 source after close-up review."""
import bpy,math
from mathutils import Vector
assert bpy.data.filepath.endswith('amedori-v2.blend')
assert not bpy.context.scene.get('closeup_refined',False),'Refinement already applied'
# Open-front jacket: connected curved shell with a real opening and fabric thickness.
o=bpy.data.objects['tailored_jacket'];mesh=o.data
rings=[(1.02,.27,.17,0,0),(1.04,.29,.18,0,0),(1.12,.31,.185,0,0),(1.3,.26,.175,0,0),(1.48,.30,.19,0,0),(1.62,.34,.175,0,.015),(1.68,.23,.125,0,.02)]
vs=[];fs=[];n=40
for z,rx,ry,x,y in rings:
 for j in range(n+1):
  a=-math.pi/2+.55+j*(math.tau-1.1)/n;vs.append((rx*math.cos(a)+x,ry*math.sin(a)+y,z))
for k in range(len(rings)-1):
 for j in range(n):a=k*(n+1)+j;fs.append((a,a+1,a+n+2,a+n+1))
me=bpy.data.meshes.new('open_tailored_jacket');me.from_pydata(vs,[],fs);me.materials.append(bpy.data.materials['pink']);o.data=me
for f in me.polygons:f.use_smooth=True
sol=o.modifiers.new('fabric_thickness','SOLIDIFY');sol.thickness=.012
# Folded lapels with visible edges rather than thick round curves.
for o in list(bpy.data.objects):
 if o.name=='collar' or o.name.startswith('collar.'):
  bpy.data.objects.remove(o,do_unlink=True)
body=bpy.data.objects['body']
for s in [-1,1]:
 verts=[(s*.09,-.135,1.7),(s*.22,-.164,1.63),(s*.155,-.227,1.49),(s*.108,-.215,1.59),(s*.155,-.244,1.615)]
 me=bpy.data.meshes.new('folded_lapel');me.from_pydata(verts,[],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)]);me.materials.append(bpy.data.materials['pinklight'])
 ob=bpy.data.objects.new('folded_lapel',me);bpy.context.collection.objects.link(ob);ob.parent=body
 sol=ob.modifiers.new('cloth_thickness','SOLIDIFY');sol.thickness=.016
 bevel=ob.modifiers.new('stitched_edge','BEVEL');bevel.width=.008;bevel.segments=3
 ob.modifiers.new('lapel_normals','WEIGHTED_NORMAL')
for o in list(bpy.data.objects):
 if o.name.startswith('cheek_tint'):
  bpy.data.objects.remove(o,do_unlink=True);continue
 if o.name.startswith('eye_white'):o.location.y+=.006;o.scale.y*=.45
 if o.name.startswith('amber_iris'):o.location.y+=.014;o.scale.y*=.35
 if o.name.startswith('pupil'):o.location.y+=.019;o.scale.y*=.5
 if o.name.startswith('eye_glint'):o.location.y+=.021;o.scale.y*=.5
 if o.name.startswith('upper_lash') or o.name.startswith('lower_lid'):
  for sp in o.data.splines:
   for pt in sp.bezier_points:pt.co.y+=.017;pt.handle_left.y+=.017;pt.handle_right.y+=.017
 if o.name.startswith('crossed_laces'):o.location.z+=.021
 if o.name.startswith('sleeve_fold'):o.data.bevel_depth=.002
 if o.name.startswith('hood_fold'):o.scale.z*=.68
for name in ['hair','hairlight','hairshine']:
 bs=bpy.data.materials[name].node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.45
bpy.context.scene['closeup_refined']=True
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('V2_REFINED')
