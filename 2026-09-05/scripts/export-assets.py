"""Export the artist-reviewed .blend, preserving GUI edits. Never regenerate geometry here."""
import bpy, os, json
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
path=os.path.join(ROOT,'assets/source/cleaning-kit-v2.blend')
bpy.ops.wm.open_mainfile(filepath=path)
names=['robot','dust','dash','box','boss','nozzle','mop','spray','disc','battery','heal','tile','pallet','crate','fence','mud','station','storefront']
manifest={}
for boot in ['mud_boot','mud_boot.001']: print('GUI_BOOT',boot,tuple(bpy.data.objects[boot].scale))
print('GUI_BOX_COLOR', tuple(bpy.data.materials['box'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value))
for name in names:
    root=bpy.data.objects.get('disc.001' if name=='disc' else name)
    assert root and root.type=='EMPTY',name
    old=root.location.copy();root.location=Vector((0,0,0))
    bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
    copies=[]
    for o in list(root.children_recursive):
        if o.type!='MESH':continue
        cp=o.copy();cp.data=o.data.copy();bpy.context.collection.objects.link(cp)
        bpy.context.view_layer.objects.active=cp
        for mod in list(cp.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        copies.append(cp)
    groups={}
    for cp in copies:groups.setdefault(cp.active_material.name,[]).append(cp)
    merged=[]
    for group in groups.values():
        bpy.ops.object.select_all(action='DESELECT')
        for cp in group:cp.select_set(True)
        bpy.context.view_layer.objects.active=group[0]
        bpy.ops.object.join();merged.append(group[0])
    bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
    for o in merged:o.select_set(True)
    bpy.context.view_layer.update()
    target=os.path.join(ROOT,'public/models',name+'.glb')
    bpy.ops.export_scene.gltf(filepath=target,export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
    tris=0
    for o in merged:
        if o.type=='MESH':o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
    manifest[name]={'file':name+'.glb','bytes':os.path.getsize(target),'triangles':tris}
    for o in merged:bpy.data.objects.remove(o,do_unlink=True)
    root.location=old
with open(os.path.join(ROOT,'public/models/manifest.json'),'w') as f:json.dump({'generator':'Blender '+bpy.app.version_string,'source':'GUI-reviewed cleaning-kit-v2.blend','assets':manifest},f,indent=2)
print('REVIEWED_EXPORT_COMPLETE',len(manifest))
