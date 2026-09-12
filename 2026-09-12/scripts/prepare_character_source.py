import bpy,os
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=root+'/source/miniatures.blend')
keep=bpy.data.collections.get('Mogu the kaiju')
for collection in list(bpy.data.collections):
 if collection!=keep:
  for obj in list(collection.objects):bpy.data.objects.remove(obj,do_unlink=True)
  bpy.data.collections.remove(collection)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=root+'/source/mogu.blend')
