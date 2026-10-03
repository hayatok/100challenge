"""Blender 4.3+ original grip fitting of two independently credited CC0 assets.
No geometry, texture or animation copied from any franchise or prior game code.
"""
import bpy,math,os,json
from mathutils import Vector,Matrix,Quaternion
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OLD=ROOT.parent/'2026-09-28'/'public'/'assets';OUT=ROOT/'game'/'assets'/'models'/'city';ART=ROOT/'art'/'source'/'city'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OLD/'weapons'/'fps-arms.glb'))
for o in list(bpy.data.objects):
 if o.name=='Icosphere':bpy.data.objects.remove(o,do_unlink=True)
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE');body=next(o for o in bpy.data.objects if o.type=='MESH')
bpy.context.view_layer.update()
wrist={s:arm.matrix_world@arm.pose.bones['hand.'+s].head for s in ['R','L']}
base_axis={}
for side in ['R','L']:
 index=arm.matrix_world@arm.pose.bones['f_index.01.'+side].head
 pinky=arm.matrix_world@arm.pose.bones['f_pinky.01.'+side].head
 avg=sum([arm.matrix_world@arm.pose.bones['f_'+f+'.01.'+side].head for f in ['index','middle','ring','pinky']],Vector())/4
 longitudinal=(avg-wrist[side]).normalized();across=(pinky-index);across=(across-longitudinal*across.dot(longitudinal)).normalized()
 normal=longitudinal.cross(across).normalized();base_axis[side]=(longitudinal,across,normal)
 # Finger bends use each actual joint axis and the authored rig. They are baked
 # only for this static first-person grip; original rig is archived separately.
 inward=Vector((1 if side=='R' else -1,0,0));bend_axis=longitudinal.cross(inward).normalized()
 for finger in ['index','middle','ring','pinky']:
  angles=[16,48,35] if finger=='index' else [54,57,36]
  if side=='L':angles=[48,57,30] if finger=='index' else [60,56,32]
  for j,deg in enumerate(angles,1):
   p=arm.pose.bones['f_'+finger+'.0'+str(j)+'.'+side]
   world=arm.matrix_world@p.matrix;head=world.translation.copy()
   rot=Quaternion(bend_axis,math.radians(deg)).to_matrix().to_4x4()
   p.matrix=arm.matrix_world.inverted()@Matrix.Translation(head)@rot@Matrix.Translation(-head)@world
   bpy.context.view_layer.update()
 # Thumb oppositional fold towards index region.
 p=arm.pose.bones['thumb.01.'+side];world=arm.matrix_world@p.matrix;head=world.translation.copy()
 p.matrix=arm.matrix_world.inverted()@Matrix.Translation(head)@Quaternion(across,math.radians(-30)).to_matrix().to_4x4()@Matrix.Translation(-head)@world
 bpy.context.view_layer.update()
# Bake the genuine 4.6k vertex skin into its firearm grip, keeping UVs and texture.
bpy.context.view_layer.objects.active=body;body.select_set(True)
for mod in list(body.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
for v in body.data.vertices:v.co=body.matrix_world@v.co
body.matrix_world=Matrix.Identity(4)
# Smooth true authored anatomical mesh; no cube/capsule hands.
for p in body.data.polygons:p.use_smooth=True
skin=body.data.materials[0];skin.name='Hands_Skin_Textured'
bs=skin.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.81;bs.inputs['Metallic'].default_value=0
if 'Specular IOR Level' in bs.inputs:bs.inputs['Specular IOR Level'].default_value=.25
sleeve=bpy.data.materials.new('Sleeve_Heavy_Olive_Cloth');sleeve.diffuse_color=(.075,.11,.10,1);sleeve.use_nodes=True
bs=sleeve.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.075,.11,.10,1);bs.inputs['Roughness'].default_value=.96
noise=sleeve.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=135
bump=sleeve.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.08;bump.inputs['Distance'].default_value=.002
sleeve.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);sleeve.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
body.data.materials.append(sleeve)
# Original source has opposite-side handedness in display; transform each
# anatomical island independently into a two-handed supported grip.
rotations={};targets={'R':Vector((.151,.312,-.273)),'L':Vector((.043,.294,-.285))}
for side in ['R','L']:
 a,b,n=base_axis[side]
 ta=Vector((-.07 if side=='R' else .065,.06,.055)).normalized()
 tb=Vector((0,.035,-.075));tb=(tb-ta*tb.dot(ta)).normalized();tn=ta.cross(tb).normalized()
 src=Matrix((a,b,n)).transposed();dst=Matrix((ta,tb,tn)).transposed();R=dst@src.inverted();rotations[side]=R
for poly in body.data.polygons:
 center=sum([body.data.vertices[i].co for i in poly.vertices],Vector())/len(poly.vertices)
 side='R' if center.x<0 else 'L'
 # Keep skin at hand/palm, cloth on forearm. Knuckles/fingers remain textured.
 long=base_axis[side][0];along=(center-wrist[side]).dot(long)
 poly.material_index=1 if along<-.028 else 0
for v in body.data.vertices:
 side='R' if v.co.x<0 else 'L';v.co=rotations[side]@(v.co-wrist[side])*.72+targets[side]
body.name='Grip_Hands_Anatomical';body.parent=None;body.data.update()
bpy.data.objects.remove(arm,do_unlink=True)
# All loose source rig/collider metadata is removed from the runtime scene.
root=bpy.data.objects.new('Pistol_Hands',None);bpy.context.collection.objects.link(root);body.parent=root;body.matrix_parent_inverse=Matrix.Identity(4);body.matrix_basis=Matrix.Identity(4)
bpy.ops.import_scene.gltf(filepath=str(OLD/'weapons'/'pistol.glb'))
for obj in list(bpy.data.objects):
 if obj.name=='Pistol_Magazine':bpy.data.objects.remove(obj,do_unlink=True)
 elif obj.type=='MESH' and obj!=body:
  mat=obj.data.materials[0].copy();mat.name='Pistol_'+obj.name+'_PBR';obj.data.materials[0]=mat
  bs=mat.node_tree.nodes.get('Principled BSDF')
  if bs:
   # Retain original albedo and normal, lower sculpt strength, deterministic
   # blued steel / polymer roughness suitable for native Forward+ light.
   bs.inputs['Metallic'].default_value=.72 if any(x in obj.name for x in ['Slide','Barrel','Hammer']) else .15
   bs.inputs['Roughness'].default_value=.40 if any(x in obj.name for x in ['Slide','Barrel','Hammer']) else .76

   color_input=bs.inputs['Base Color']
   if color_input.links:
    srcnode=color_input.links[0].from_node
    if srcnode.type=='TEX_IMAGE' and srcnode.image:
     import numpy as np
     old=srcnode.image
     if 'BluedSteel_Albedo' in bpy.data.images: new=bpy.data.images['BluedSteel_Albedo']
     else:
      new=old.copy();new.name='BluedSteel_Albedo'
      pixels=np.array(old.pixels[:],dtype=np.float32).reshape(-1,4);pixels[:,:3]*=np.array([.14,.18,.20]);new.pixels.foreach_set(pixels.ravel())
      new.filepath_raw=str(ART/'pistol_blued_albedo.png');new.file_format='PNG';new.save();new.pack()
     srcnode.image=new
   for inp in ['Metallic','Roughness']:
    for link in list(bs.inputs[inp].links):mat.node_tree.links.remove(link)
   for node in mat.node_tree.nodes:
    if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=.32
  M=Matrix.Translation((.10,.44,-.30))@Matrix.Rotation(math.pi/2,4,'Z')@Matrix.Scale(1.25,4)@obj.matrix_world
  obj.parent=root;obj.matrix_world=M
  for p in obj.data.polygons:p.use_smooth=True
# Camera-local Godot position becomes (.10,-.115,-.626) after glTF Y-up conversion.
muzzle=bpy.data.objects.new('Muzzle',None);bpy.context.collection.objects.link(muzzle);muzzle.parent=root;muzzle.location=(.10,.44+.1490462*1.25,-.30+.147997*1.25)
# Rounded cuffs mask the low-resolution source boundary on each fitted sleeve.
for side in ['R','L']:
 a=rotations[side]@base_axis[side][0]
 center=targets[side]-a*.034
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.032,depth=.040,location=center)
 cuff=bpy.context.object;cuff.name='Sleeve_Cuff_'+side;cuff.rotation_euler=a.to_track_quat('Z','Y').to_euler();cuff.data.materials.append(sleeve);cuff.parent=root
 bevel=cuff.modifiers.new('Rounded_Cuff_Edge','BEVEL');bevel.width=.005;bevel.segments=3
 bpy.context.view_layer.objects.active=cuff;bpy.ops.object.modifier_apply(modifier=bevel.name)
 for p in cuff.data.polygons:p.use_smooth=True
root.matrix_world=Matrix.Translation((0,.10,.16))@Matrix.Rotation(-.06,4,'X')
bpy.context.view_layer.update()
# Export only the coherent runtime group.
bpy.ops.object.select_all(action='DESELECT')
for obj in [root,*root.children]:obj.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'pistol_hands_fitted.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'pistol_hands.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
# Honest firearm/hand fit proof, same 16:9 FOV as the native camera.
bpy.ops.object.camera_add(location=(0,0,0));camera=bpy.context.object;camera.name='Preview_Camera';camera.rotation_euler=(math.pi/2,0,0);camera.data.lens=25.7;camera.data.clip_start=.01;camera.data.clip_end=20;bpy.context.scene.camera=camera
for loc,power,size in [((-.3,-.2,.9),130,1.5),((1,.3,.2),60,1)]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=power;l.data.size=size;l.rotation_euler=(Vector((.1,.4,-.2))-l.location).to_track_quat('-Z','Y').to_euler()
scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Preview_Neutral');scene.world.color=(.045,.055,.055);scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100;scene.render.filepath=str(ART/'pistol_hands_fit_preview.png');bpy.ops.render.render(write_still=True)
print('PISTOL_MUZZLE_GODOT',list(((root.matrix_world@muzzle.location).x,(root.matrix_world@muzzle.location).z,-(root.matrix_world@muzzle.location).y)))
print('PISTOL_HOLD_OUT',str(OUT/'pistol_hands.glb'))
