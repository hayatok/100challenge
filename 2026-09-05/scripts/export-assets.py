"""Export the artist-reviewed .blend, preserving GUI edits. Never regenerate geometry here."""
import bpy, os, json
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
path=os.path.join(ROOT,'assets/source/cleaning-kit.blend')
bpy.ops.wm.open_mainfile(filepath=path)
names=['robot','dust','dash','box','boss','nozzle','mop','spray','disc','battery','heal','tile','pallet','crate','fence']
manifest={}
for name in names:
    root=bpy.data.objects.get('disc.001' if name=='disc' else name)
    assert root and root.type=='EMPTY',name
    old=root.location.copy();root.location=Vector((0,0,0))
    bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
    for o in root.children_recursive:o.select_set(True)
    bpy.context.view_layer.update()
    target=os.path.join(ROOT,'public/models',name+'.glb')
    bpy.ops.export_scene.gltf(filepath=target,export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
    tris=0
    for o in root.children_recursive:
        if o.type=='MESH':o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
    manifest[name]={'file':name+'.glb','bytes':os.path.getsize(target),'triangles':tris}
    root.location=old
with open(os.path.join(ROOT,'public/models/manifest.json'),'w') as f:json.dump({'generator':'Blender '+bpy.app.version_string,'source':'GUI-reviewed cleaning-kit.blend','assets':manifest},f,indent=2)
print('REVIEWED_EXPORT_COMPLETE',len(manifest))
