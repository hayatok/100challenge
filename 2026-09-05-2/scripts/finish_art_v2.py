"""Final source corrections found in studio and in-game views."""
import bpy,math
assert bpy.data.filepath.endswith('amedori-v2.blend')
assert not bpy.context.scene.get('finish_refined',False)
def rings_mesh(name,rings,mat,opening=None):
 n=40;vs=[];fs=[];cols=n+1 if opening else n
 for z,rx,ry in rings:
  for j in range(cols):
   a=(-math.pi/2+opening+j*(math.tau-2*opening)/n) if opening else j*math.tau/n
   vs.append((rx*math.cos(a),ry*math.sin(a),z))
 for k in range(len(rings)-1):
  for j in range(n):a=k*cols+j;b=k*cols+(j+1)%cols;fs.append((a,b,b+cols,a+cols))
 if not opening:fs.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+j for j in range(n))])
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.materials.append(bpy.data.materials[mat]);return me
shirt=bpy.data.objects['ivory_shirt'];shirt.data=rings_mesh('cotton_shirt',[(1.03,.19,.16),(1.045,.20,.17),(1.08,.205,.175),(1.3,.19,.175),(1.5,.175,.18),(1.60,.12,.12),(1.63,.095,.095)],'cream')
hem=bpy.data.objects['ribbed_hem'];hem.data=rings_mesh('open_hem',[(1.02,.283,.184),(1.055,.285,.184),(1.09,.29,.184)],'pinkdark',.55)
sol=hem.modifiers.new('hem_thickness','SOLIDIFY');sol.thickness=.012
for o in [shirt,hem]:
 for f in o.data.polygons:f.use_smooth=True
for o in bpy.data.objects:
 if o.name.startswith('side_annex'):o.rotation_euler.z*=-1
bpy.context.scene['finish_refined']=True
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('V2_FINISHED')
