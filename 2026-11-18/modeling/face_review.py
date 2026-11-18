"""Check the exported facial rigs, render them in Blender and compose a review sheet.

From modeling/, run:
  blender -b --python-exit-code 2 --python face_review.py -- ../game/racers /tmp/rally-faces
  python3 face_review.py --sheet /tmp/rally-faces review/expressions.webp
"""
import math
import sys
from pathlib import Path

NAMES=('Nagi','Suzu','Rikka','An','Nene','Mio')
VIEWS=('Basis','Focus','Startle','Cheer','Blink')
KEYS=('Focus','Startle','Cheer','Blink','FocusBlink','StartleBlink')


def check_face(arm, face, scene):
    import bpy
    from mathutils import Quaternion, Vector
    keys=face.data.shape_keys.key_blocks
    assert tuple(key.name for key in keys)[1:]==KEYS, face.name+' has unexpected expression targets'
    assert all(abs(key.value)<1.e-6 for key in list(keys)[1:]), face.name+' imports with active targets'
    assert len(face.data.materials)==1 and len(face.data.polygons)>0, face.name
    head=arm.pose.bones['Head']
    group=face.vertex_groups['Head'].index
    assert all(any(g.group==group and abs(g.weight-1.)<1e-6 for g in v.groups)
               for v in face.data.vertices), face.name+' is not entirely weighted to the head'
    def samples():
        mesh=face.evaluated_get(bpy.context.evaluated_depsgraph_get())
        return [mesh.matrix_world@v.co for v in mesh.data.vertices]
    before=samples()
    old_matrix=arm.matrix_world@head.matrix
    head.rotation_mode='QUATERNION'
    initial=head.rotation_quaternion.copy()
    head.rotation_quaternion=initial@Quaternion(Vector((.6,.3,.7)),.38)
    scene.view_layers[0].update()
    transformed=arm.matrix_world@head.matrix@old_matrix.inverted()
    error=max((a-transformed@b).length for a,b in zip(samples(),before))
    assert error<.0001, (face.name,'head follow error in m',error)
    head.rotation_quaternion=initial
    scene.view_layers[0].update()
    print(f'{face.name}: all six weights zero, one material, {len(face.data.vertices)} imported vertices, head error {error:.8f} m')


def check_lids(face, scene):
    """Look through the complete, posed GLB, including skin, bangs and glasses."""
    import bpy
    from mathutils import Vector
    sys.path.insert(0,str(Path(__file__).resolve().parent))
    from face_paint import IRIS, SCLERA
    cornea=set()
    lower_iris=[]
    for polygon in face.data.polygons:
        sample=face.data.uv_layers.active.data[polygon.loop_start].uv
        x,y=1024*sample.x,1024*(1-sample.y)
        for x0,y0,x1,y1 in (IRIS,SCLERA):
            if x0-.1<=x<=x1+.1 and y0-.1<=y<=y1+.1:
                cornea.add(polygon.index)
        u=(x-IRIS[0])/(IRIS[2]-IRIS[0])
        v=(y-IRIS[1])/(IRIS[3]-IRIS[1])
        if .31<u<.69 and .64<v<.85:
            lower_iris.append(polygon.index)
    assert lower_iris, face.name+' has no identifiable iris'
    keys=face.data.shape_keys.key_blocks
    def visible(polygons, view, state, strength):
        for key in list(keys)[1:]:
            key.value=strength if key.name==state else 0.
        scene.view_layers[0].update()
        graph=bpy.context.evaluated_depsgraph_get()
        actual=face.evaluated_get(graph)
        hits=0
        for index in polygons:
            center=actual.matrix_world@actual.data.polygons[index].center
            hit,_,_,which,obj,_=scene.ray_cast(graph,center+2*view,-view,distance=2.12)
            hits+=int(hit and obj==face and which in cornea)
        return hits
    samples=sorted(cornea)[::6]
    for state in ('Startle','Blink','FocusBlink','StartleBlink','Cheer'):
        for angle in (-.47,0.,.47):
            view=Vector((math.sin(angle),math.cos(angle),.035)).normalized()
            count=visible(samples,view,state,1.)
            if state=='Startle':
                assert count>8,(face.name,state,angle,count)
            else:
                assert count==0,(face.name,state,angle,count)
    # The cheek must not slice through a partially closing iris before the lash
    # reaches it. Suzu's resting eye is already closed at these happy weights.
    expected=0 if 'Suzu' in face.name else len(lower_iris)
    view=Vector((.15,1.,.06)).normalized()
    for strength in (0.,.35,.55):
        count=visible(lower_iris,view,'Cheer',strength)
        assert count==expected,(face.name,strength,count,expected)
    for key in list(keys)[1:]:
        key.value=0.
    scene.view_layers[0].update()
    print(f'{face.name}: four closed poses, three angles, partial-smile iris coverage {expected}/{len(lower_iris)}')



def render(directory, output):
    import bpy
    from mathutils import Vector
    output.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc=bpy.context.scene
    sc.render.engine='CYCLES'
    sc.cycles.samples=10
    sc.cycles.use_denoising=True
    sc.render.threads_mode='FIXED'
    sc.render.threads=5
    sc.view_settings.view_transform='Standard'
    sc.world=bpy.data.worlds.new('Daylight')
    sc.world.use_nodes=True
    back=sc.world.node_tree.nodes['Background']
    back.inputs[0].default_value=(.83,.83,.81,1.)
    back.inputs[1].default_value=.88
    sc.render.film_transparent=True
    sc.render.image_settings.color_mode='RGBA'
    sc.render.image_settings.file_format='PNG'
    for pos, power, size in (((1.8,3.1,4.),130,4.2),((-2.3,-2.,2.6),85,3.6)):
        light=bpy.data.lights.new('Softbox','AREA')
        light.energy=power
        light.shape='DISK'
        light.size=size
        obj=bpy.data.objects.new('Softbox',light)
        sc.collection.objects.link(obj)
        obj.location=pos
        obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
    camera=bpy.data.cameras.new('Portrait')
    camera.type='ORTHO'
    camera.ortho_scale=1.03
    cam=bpy.data.objects.new('Portrait',camera)
    sc.collection.objects.link(cam)
    sc.camera=cam
    sc.render.resolution_percentage=100
    sc.render.resolution_x=248
    sc.render.resolution_y=200
    for index,name in enumerate(NAMES):
        existing=set(sc.objects)
        bpy.ops.import_scene.gltf(filepath=str(directory/f'{index+1:02}.glb'))
        loaded=set(sc.objects)-existing
        arm=next(obj for obj in loaded if obj.type=='ARMATURE')
        face=next(obj for obj in loaded if obj.type=='MESH' and obj.data.shape_keys)
        if arm.animation_data:
            arm.animation_data.action=None
            for track in arm.animation_data.nla_tracks:
                track.mute=True
        for bone in arm.pose.bones:
            bone.matrix_basis.identity()
        sc.view_layers[0].update()
        check_face(arm,face,sc)
        check_lids(face,sc)
        target=Vector((0,.01,(1.126,1.085,1.089,1.12,1.091,1.115)[index]))
        cam.location=target+Vector((-math.sin(.32)*4,math.cos(.32)*4,.18))
        cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
        for state in VIEWS:
            for key in face.data.shape_keys.key_blocks:
                key.value=float(key.name==state and state!='Basis')
            sc.render.filepath=str(output/f'{name}-{state}.png')
            bpy.ops.render.render(write_still=True)
        for obj in loaded:
            bpy.data.objects.remove(obj,do_unlink=True)


def sheet(directory, output):
    from PIL import Image, ImageDraw, ImageFont
    cell=(194,151)
    label=66
    result=Image.new('RGB',(label+len(NAMES)*cell[0],32+len(VIEWS)*cell[1]),'#f8f3eb')
    draw=ImageDraw.Draw(result)
    try:
        font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf',14)
    except OSError:
        font=ImageFont.load_default()
    for j,name in enumerate(NAMES):
        draw.text((label+(j+.5)*cell[0],18),f'{j+1:02}  {name}',anchor='mm',fill='#413947',font=font)
        for i,state in enumerate(VIEWS):
            tile=Image.open(directory/f'{name}-{state}.png').convert('RGBA')
            tile.thumbnail(cell,Image.Resampling.LANCZOS)
            corner=(label+cell[0]*j+(cell[0]-tile.width)//2,32+i*cell[1])
            result.paste(tile,corner,tile)
    for i,title in enumerate(('Neutral','Focus','Startle','Cheer','Blink')):
        draw.text((7,32+(i+.5)*cell[1]),title,anchor='lm',fill='#413947',font=font)
    result.save(output,quality=91,method=6)


if __name__=='__main__':
    if '--sheet' in sys.argv:
        a,b=sys.argv[sys.argv.index('--sheet')+1:]
        sheet(Path(a),Path(b))
    else:
        a,b=sys.argv[sys.argv.index('--')+1:]
        render(Path(a),Path(b))
