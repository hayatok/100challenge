"""Export saved Kohaku V3 without modifying the source; retain UVs and authored pivots."""
import bpy,os,json,hashlib
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE=os.path.join(ROOT,'art/source/kohaku-v3.blend')
bpy.ops.wm.open_mainfile(filepath=SOURCE)
# Export portable albedo inputs. The EEVEE preview's Shader-to-RGB is not glTF.
for m in bpy.data.materials:
 if 'kohaku_base' not in m:continue
 base=tuple(m['kohaku_base']);texture=bpy.data.images.get(m.get('kohaku_texture',''))
 nodes=m.node_tree.nodes;links=m.node_tree.links;nodes.clear()
 outnode=nodes.new('ShaderNodeOutputMaterial');bs=nodes.new('ShaderNodeBsdfPrincipled');links.new(bs.outputs[0],outnode.inputs['Surface'])
 bs.inputs['Base Color'].default_value=(1,1,1,1) if texture else base
 bs.inputs['Roughness'].default_value=1;bs.inputs['Specular IOR Level'].default_value=0
 if texture:
  tex=nodes.new('ShaderNodeTexImage');tex.image=texture;links.new(tex.outputs['Color'],bs.inputs['Base Color'])
out=os.path.join(ROOT,'game/assets/models/v3');os.makedirs(out,exist_ok=True)
manifest={'source':'art/source/kohaku-v3.blend','source_sha256':hashlib.sha256(open(SOURCE,'rb').read()).hexdigest(),'blender':bpy.app.version_string,'models':{}}
for name in ['kohaku']:
 src=bpy.data.objects[name];src.location=(0,0,0);bpy.context.view_layer.update()
 owners=[src]+[o for o in src.children_recursive if o.type=='EMPTY']
 clones={}
 for o in owners:
  c=bpy.data.objects.new(o.name+'_export',None);bpy.context.collection.objects.link(c);clones[o]=c
 for o,c in clones.items():
  c.parent=clones.get(o.parent);c.matrix_world=o.matrix_world.copy()
 deps=bpy.context.evaluated_depsgraph_get();all_mesh=[];triangles=0
 for owner in owners:
  copies=[]
  for obj in list(owner.children):
   if obj.type not in ['MESH','CURVE','FONT']:continue
   mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
   # Joined face/hair meshes must share the same UV layer name. Otherwise joining
   # keeps HairFlow as UV2 and the game samples the empty UVMap at a single pixel.
   if mesh.uv_layers.active:mesh.uv_layers.active.name='UVMap'
   c=bpy.data.objects.new(obj.name+'_baked',mesh);bpy.context.collection.objects.link(c);c.parent=clones[owner];c.matrix_world=obj.matrix_world.copy();copies.append(c)
  if not copies:continue
  bpy.ops.object.select_all(action='DESELECT')
  for c in copies:c.select_set(True)
  bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();merged=bpy.context.object;merged.name=owner.name+'_surface'
  merged.data.calc_loop_triangles();triangles+=len(merged.data.loop_triangles);all_mesh.append(merged)
 bpy.ops.object.select_all(action='DESELECT')
 for c in list(clones.values())+all_mesh:c.select_set(True)
 path=os.path.join(out,name+'.glb')
 bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,export_yup=True,export_apply=False)
 manifest['models'][name]={'triangles':triangles,'bytes':os.path.getsize(path),'mesh_parts':len(all_mesh)}
 for obj in all_mesh+list(reversed(list(clones.values()))):bpy.data.objects.remove(obj,do_unlink=True)
with open(os.path.join(out,'manifest.json'),'w') as f:json.dump(manifest,f,indent=2)
print('V3_EXPORT_OK',manifest)
