"""Render exported GLBs back in a clean Blender scene; no source-scene objects are used."""
import bpy, sys, math
from pathlib import Path
from mathutils import Vector
from math import pi
HERE=Path(__file__).resolve().parent
root=HERE.parent
args=sys.argv[sys.argv.index('--')+1:]
out=Path(args[0]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene
sc.render.engine='CYCLES';sc.cycles.samples=4;sc.cycles.use_denoising=True
sc.render.threads_mode='FIXED';sc.render.threads=5
sc.world=bpy.data.worlds.new('Soft studio');sc.world.use_nodes=True
sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.81,.80,.76,1)
sc.world.node_tree.nodes['Background'].inputs[1].default_value=.82
sc.view_settings.view_transform='Standard'
sc.render.image_settings.file_format='PNG';sc.render.image_settings.color_mode='RGBA';sc.render.film_transparent=True
def lamp(p,power,size):
    l=bpy.data.lights.new('Softbox','AREA');l.energy=power;l.shape='DISK';l.size=size
    o=bpy.data.objects.new('Softbox',l);sc.collection.objects.link(o);o.location=p;o.rotation_euler=(Vector((0,0,.85))-o.location).to_track_quat('-Z','Y').to_euler()
lamp((1.6,3.2,5),135,5);lamp((-2,-2,3),100,4)
c=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Studio camera',c)
sc.collection.objects.link(cam);sc.camera=cam;c.type='ORTHO'
def camera(p,target,scale,w,h):
    cam.location=p;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();c.ortho_scale=scale
    sc.render.resolution_x=w;sc.render.resolution_y=h;sc.render.resolution_percentage=100
models=[]
def add(i):
    before=set(sc.objects);bpy.ops.import_scene.gltf(filepath=str(root/'game'/'racers'/f'{i+1:02}.glb'))
    new=set(sc.objects)-before
    roots=[o for o in new if not o.parent];arm=next(o for o in new if o.type=='ARMATURE')
    if arm.animation_data:
        arm.animation_data.action=None
        for tr in arm.animation_data.nla_tracks:tr.mute=True
    models.append((roots,arm));return roots,arm
def act(arm,name,fraction):
    if not arm.animation_data:return
    for tr in arm.animation_data.nla_tracks:
        tr.mute=True
        if tr.name.lower().startswith(name):
            strip=tr.strips[0]
            arm.animation_data.action=strip.action
            if strip.action_slot:arm.animation_data.action_slot=strip.action_slot
            sc.frame_set(round(strip.action.frame_range[0]+fraction*(strip.action.frame_range[1]-strip.action.frame_range[0])))
def save(name):
    sc.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
if '--single' in args:
    rt,arm=add(0);act(arm,'idle',0)
    for name,pos in [('front',(0,4,.78)),('side',(-4,0,.78)),('rear',(0,-4,.78)),('three-quarter',(-2.2,4,1.25))]:
        camera(pos,(0,0,.75),1.66,390,390);save(name)
else:
    for i in range(6):
        roots,arm=add(i);act(arm,'idle',0)
        for r in roots:r.location.x=-(i-2.5)*.98
    camera((0,7,.85),(0,0,.76),6,1560,420);save('cast-front')
    camera((0,-7,1.45),(0,0,.75),6,1560,420);save('cast-rear')
    for i,(roots,arm) in enumerate(models):
        for r in roots:r.hide_render=i>0
        for ob in arm.children_recursive:ob.hide_render=i>0
        if i==0:
            for r in roots:r.location.x=0
    arm=models[0][1]
    camera((-2.6,4,.98),(0,0,.75),1.68,390,390)
    for state,time in [('idle',0),('jump',.5),('land',.3),('run',.21),('stumble',.36),('finish',.4)]:
        act(arm,state,time);save(state)
