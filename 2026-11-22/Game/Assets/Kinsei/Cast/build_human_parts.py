import bpy,json,os,sys,math
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:]; source,out,texture=args
parts=json.load(open(source))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for p in parts:
 mesh=bpy.data.meshes.new(p['name']);mesh.from_pydata(p['verts'],[],p['faces']);mesh.update()
 layer=mesh.uv_layers.new()
 for poly,uvs in zip(mesh.polygons,p['uv']):
  poly.use_smooth=True
  for loop,uv in zip(poly.loop_indices,uvs):layer.data[loop].uv=uv
 obj=bpy.data.objects.new(p['name'],mesh);bpy.context.collection.objects.link(obj)
 bpy.context.view_layer.objects.active=obj;obj.select_set(True)
 mod=obj.modifiers.new('Production smooth surface','SUBSURF');mod.levels=1;bpy.ops.object.modifier_apply(modifier=mod.name)
 bpy.ops.wm.obj_export(filepath=os.path.join(out,p['name']+'.obj'),export_selected_objects=True,forward_axis='Y',up_axis='Z',export_materials=False,export_normals=True)
 obj.select_set(False);obj.hide_render=p['name']!='HeadAdult'
 mat=bpy.data.materials.new('Skin');mat.use_nodes=True;n=mat.node_tree.nodes;tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(texture);mat.node_tree.links.new(tex.outputs['Color'],n.get('Principled BSDF').inputs['Base Color']);n.get('Principled BSDF').inputs['Roughness'].default_value=.6;obj.data.materials.append(mat)
# Scene is Y-up geometry, camera looks towards -Z.
bpy.ops.object.camera_add(location=(.32,.06,.65));cam=bpy.context.object;cam.rotation_euler=(Vector((0,.09,.03))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=.38;bpy.context.scene.camera=cam
for loc,power,size in [((-.4,.6,.6),45,.5),((.4,.3,.3),20,.4)]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(Vector((0,.1,0))-l.location).to_track_quat('-Z','Y').to_euler()
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.world.color=(.18,.18,.18);cam.rotation_euler.rotate_axis('Z',-math.pi/2);s.render.resolution_x=700;s.render.resolution_y=700;s.render.resolution_percentage=100;s.render.filepath=os.path.join(os.environ['TEMP'],'kinsei-head-qa.png');bpy.ops.render.render(write_still=True)

