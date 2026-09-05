"""Export reviewed v2 source without changing it; keep articulation, combine parts by parent."""
import bpy,os,json,hashlib
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE=os.path.join(ROOT,'art/source/amedori-v2.blend')
bpy.ops.wm.open_mainfile(filepath=SOURCE)
out=os.path.join(ROOT,'game/assets/models/v2');os.makedirs(out,exist_ok=True)
manifest={'source':'art/source/amedori-v2.blend','source_sha256':hashlib.sha256(open(SOURCE,'rb').read()).hexdigest(),'blender':bpy.app.version_string,'models':{}}
for name in ['kohaku','call_bit','street']:
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
print('V2_EXPORT_OK',manifest)
