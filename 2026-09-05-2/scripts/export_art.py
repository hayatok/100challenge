"""Export saved Blender source, never re-create or save over the artist's file."""
import bpy, os, json, hashlib
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE=os.path.join(ROOT,'art/source/yofukashi-kit.blend')
bpy.ops.wm.open_mainfile(filepath=SOURCE)
manifest={'source':'art/source/yofukashi-kit.blend','source_sha256':hashlib.sha256(open(SOURCE,'rb').read()).hexdigest(),'blender':bpy.app.version_string,'models':{}}
out=os.path.join(ROOT,'game/assets/models');os.makedirs(out,exist_ok=True)
for name in ['kohaku','call_bit','stall','building','speaker']:
 candidates=[o for o in bpy.data.objects if o.type=='EMPTY' and (o.name==name or o.name.startswith(name+'.'))]
 assert len(candidates)==1, (name,[o.name for o in candidates])
 root=candidates[0];original=root.location.copy();root.location=(0,0,0)
 bpy.ops.object.select_all(action='DESELECT')
 copies=[]
 for o in list(root.children):
  if o.type!='MESH':continue
  c=o.copy();c.data=o.data.copy();bpy.context.collection.objects.link(c);copies.append(c);bpy.context.view_layer.objects.active=c
  for m in list(c.modifiers):bpy.ops.object.modifier_apply(modifier=m.name)
 for c in copies:c.select_set(True)
 bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();merged=bpy.context.object
 bpy.context.view_layer.update();merged.data.calc_loop_triangles()
 path=os.path.join(out,name+'.glb')
 bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
 manifest['models'][name]={'triangles':len(merged.data.loop_triangles),'bytes':os.path.getsize(path)}
 bpy.data.objects.remove(merged,do_unlink=True);root.location=original
with open(os.path.join(out,'manifest.json'),'w') as f:json.dump(manifest,f,indent=2)
print('LOOP_EXPORT_OK',manifest)
