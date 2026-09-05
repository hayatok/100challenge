"""Render actual saved meshes from four angles. Does not modify or save source."""
import bpy,os,math
from mathutils import Vector
R=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=R+'/art/source/kohaku-v3.blend')
sc=bpy.context.scene
sc.render.resolution_x=1000;sc.render.resolution_y=1100
for name,location,target,scale in [('full',(1.8,-5.7,1.9),(0,0,.91),2.04),('front',(0,-3,1.59),(0,-.02,1.53),.67),('three-quarter',(1.7,-3,1.75),(0,0,1.52),.67),('side',(3,-.15,1.62),(0,0,1.5),.7)]:
 sc.camera.location=location;sc.camera.rotation_euler=(Vector(target)-sc.camera.location).to_track_quat('-Z','Y').to_euler();sc.camera.data.ortho_scale=scale;sc.render.filepath=R+'/art/review/kohaku-v3-'+name+'.png';bpy.ops.render.render(write_still=True)
