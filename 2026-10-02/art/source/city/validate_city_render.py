import bpy,math,json
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];PATH=ROOT/'game'/'assets'/'models'/'city'/'zombie_city.glb';ART=ROOT/'art'/'source'/'city'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(PATH))
for obj in list(bpy.data.objects):
 if obj.name=='Icosphere':bpy.data.objects.remove(obj,do_unlink=True)
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for track in arm.animation_data.nla_tracks:track.mute=True
report={'source':str(PATH.relative_to(ROOT)), 'bones':len(arm.data.bones),'animations':{}}
for action in bpy.data.actions:
 arm.animation_data.action=action
 frames=[]
 for f in [action.frame_range[0],sum(action.frame_range)/2,action.frame_range[1]]:
  bpy.context.scene.frame_set(int(f));bpy.context.view_layer.update()
  hips=arm.matrix_world@arm.pose.bones['mixamorig:Hips'].head;head=arm.matrix_world@arm.pose.bones['mixamorig:Head'].head
  frames.append({'frame':f,'hips_blender_z_up':list(hips),'head_blender_z_up':list(head)})
 report['animations'][action.name]={'frames':list(action.frame_range),'samples':frames}
arm.animation_data.action=next(a for a in bpy.data.actions if a.name=='Zombie_Idle_Armature');bpy.context.scene.frame_set(8);bpy.context.view_layer.update()
bpy.ops.object.camera_add(location=(.15,-2.8,1.65));c=bpy.context.object;c.rotation_euler=(Vector((0,0,1.30))-c.location).to_track_quat('-Z','Y').to_euler();c.data.lens=55;bpy.context.scene.camera=c
for loc,power,size in [((-.8,-2.5,3),150,2),((1.4,-.4,2),50,1)]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=power;l.data.size=size;l.rotation_euler=(Vector((0,0,1.3))-l.location).to_track_quat('-Z','Y').to_euler()
s=bpy.context.scene;s.world=bpy.data.worlds.new('World');s.world.color=(.03,.035,.04);s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=False;s.render.resolution_x=900;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.filepath=str(ART/'city_zombie_material_preview.png');bpy.ops.render.render(write_still=True)
with open(ART/'blender_validation.json','w')as f:json.dump(report,f,indent=2)
print('CITY_RENDER_PROOF',str(ART/'city_zombie_material_preview.png'))
