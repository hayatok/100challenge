"""Import-only Blender render fixture. Never saves or exports altered geometry.

Read-only GLB audit. No mesh or source-file mutation.

OLD always means the legacy model from commit 07c2730, never the current
candidate at game/assets/models/mio.glb. The expected legacy SHA256 is
70a343c829f5e4b79802435bbd24365219cd24c5e4e38e197393aeaf9536b074.
If the ignored legacy cache is missing, restore it from the repository root:
    mkdir -p 2026-10-24-2/.cache/rework
    git show 07c2730:2026-10-24-2/game/assets/models/mio.glb > 2026-10-24-2/.cache/rework/legacy-mio.glb
Restore only a missing cache; do not overwrite either source model.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector

base=Path(__file__).resolve().parent.parent
out=base/'previews';out.mkdir(exist_ok=True)
sources={'old':base.parents[2]/'.cache/rework/legacy-mio.glb','new':Path('/Users/hayatok/Downloads/cloudsea-mio-v2-rigged-source.glb')}
if not sources['old'].exists(): raise FileNotFoundError('Legacy cache missing; follow this helper docstring recovery instructions.')
if hashlib.sha256(sources['old'].read_bytes()).hexdigest()!='70a343c829f5e4b79802435bbd24365219cd24c5e4e38e197393aeaf9536b074': raise ValueError('Unexpected legacy hash; refusing to render it as OLD.')
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=640;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world=bpy.data.worlds.new('Review World');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.21,.25,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
scene.view_settings.view_transform='Standard'
scene.view_settings.look='Medium High Contrast' if 'Medium High Contrast' in [e.identifier for e in scene.view_settings.bl_rna.properties['look'].enum_items] else 'None'
scene.view_settings.exposure=0;scene.view_settings.gamma=1
models={};bounds={}
for key,path in sources.items():
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects=[o for o in scene.objects if o not in before]
    meshes=[o for o in objects if o.type=='MESH' and len(o.data.vertices)>1000]
    print('RENDER_MESHES',key,[(o.name,len(o.data.vertices)) for o in meshes])
    bpy.context.view_layer.update()
    points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
    low=Vector([min(p[i]for p in points)for i in range(3)]);high=Vector([max(p[i]for p in points)for i in range(3)])
    roots=[o for o in objects if o.parent not in objects]
    anchor=bpy.data.objects.new(key+'_normalization',None);scene.collection.objects.link(anchor)
    for o in roots:o.parent=anchor
    factor=1.68/(high.z-low.z)
    anchor.scale=(factor,)*3
    anchor.location=(-((low.x+high.x)/2)*factor,-((low.y+high.y)/2)*factor,-low.z*factor)
    bounds[key]={'native_min':list(low),'native_max':list(high),'height_normalization':factor,'source':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_commit':'07c2730' if key=='old' else None}
    models[key]=objects
    bpy.context.view_layer.update()
    for o in objects:o.hide_render=True
camera_data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera
camera_data.type='ORTHO';camera_data.ortho_scale=1.92
for name,pos,power,size in [('Key',(-3,-4,5),450,4),('Fill',(4,-2,2.5),250,3),('Rim',(1,3,4),350,3)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=pos
    obj.rotation_euler=(Vector((0,0,.95))-obj.location).to_track_quat('-Z','Y').to_euler()
views={'front':(0,-4,.9),'left':(4,0,.9),'right':(-4,0,.9),'back':(0,4,.9),'threequarter':(3,-4,1.0)}
manifest={'models':bounds,'views':views,'normalization':'Both whole characters normalized to 1.68m height; identical orthographic camera/light/material inputs. Source geometry and materials unmodified.','renders':[]}
for key,objects in models.items():
    for o in objects:o.hide_render=False
    for view,position in views.items():
        camera.location=position;target=Vector((0,0,.84));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        path=out/f'{key}_{view}.png';scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        manifest['renders'].append(str(path.name))
    scene.render.resolution_x=768;scene.render.resolution_y=768;camera_data.ortho_scale=.43
    for view,position in {'face_front':(0,-4,1.49),'face_left':(4,0,1.49),'face_right':(-4,0,1.49),'face_back':(0,4,1.49),'face_threequarter':(3,-4,1.49)}.items():
        camera.location=position;target=Vector((0,0,1.49));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        path=out/f'{key}_{view}.png';scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        manifest['renders'].append(str(path.name))
    scene.render.resolution_x=640;scene.render.resolution_y=960;camera_data.ortho_scale=1.92
    for o in objects:o.hide_render=True
(base/'reports/render-manifest.json').write_text(json.dumps(manifest,indent=2))
print('COMPARISON_RENDER_COMPLETE')
