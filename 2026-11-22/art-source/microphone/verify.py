import bpy,sys,numpy as np
from pathlib import Path
from mathutils import Vector
file=Path(sys.argv[-1]);bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(file),use_custom_normals=True)
objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
for ob in objs:
 pts=np.array([list(ob.matrix_world@v.co) for v in ob.data.vertices])
 print(ob.name,len(pts), np.round(pts.min(0),5),np.round(pts.max(0),5))
 if ob.name.startswith('04 '):
  assert np.allclose(pts.max(0)-pts.min(0),[.0584,.0424,.1184],atol=.001)
 if ob.name.startswith('14 '):assert pts[:,1].max()<-.02
 if ob.name.startswith('02 '):
  radius=np.linalg.norm(pts[(pts[:,2]>1.337)&(pts[:,2]<1.374),:2],axis=1)
  assert .016<radius.max()<.018
assert len(objs)==14
print('Triangles:',sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objs))
