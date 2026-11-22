"""Render the exported rest mesh, normals and UVs in Blender for a fitting check.
blender -b -P preview.py -- /absolute/path/to/output.png
"""
from pathlib import Path
import struct
import sys
import bpy
from mathutils import Vector

root=Path(__file__).resolve().parents[2]/"Game/Assets/Resources/KinseiWardrobe"
hall=root.parent/"KinseiHallWardrobe"
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.samples=12
scene.world=bpy.data.worlds.new("Fitting room")
scene.world.color=(.38,.38,.38)
for shift,cut,palette in [(-.35,"Single","Kontani"),(.35,"Single","Ura")]:
    with (root/(cut+".bytes")).open("rb") as f:
        count,indices=struct.unpack("<ii",f.read(8))
        records=[struct.unpack("<8f4B4f",f.read(52)) for _ in range(count)]
        corners=struct.unpack("<"+"H"*indices,f.read(2*indices))
    if palette=="Ura":
        raw=(hall/"UraLapelFit.bytes").read_bytes();n=struct.unpack_from("<i",raw)[0]
        points=struct.unpack_from("<"+"f"*(n*3),raw,4)
        records=[tuple(points[i*3:i*3+3])+tuple(r[3:]) for i,r in enumerate(records)]
    m=bpy.data.meshes.new(cut)
    # Swap horizontal and depth axes with a handedness-preserving rotation.
    m.from_pydata([(x+shift,-z,y) for x,y,z,*_ in records],[],list(zip(*[iter(corners)]*3)))
    m.update()
    uv=m.uv_layers.new(name="Tailor UV")
    for loop in m.loops:
        uv.data[loop.index].uv=records[loop.vertex_index][6:8]
    for poly in m.polygons: poly.use_smooth=True
    if palette!="Ura":m.normals_split_custom_set_from_vertices([(r[3],-r[5],r[4]) for r in records])
    obj=bpy.data.objects.new(palette,m)
    scene.collection.objects.link(obj)
    mat=bpy.data.materials.new(palette)
    mat.use_nodes=True
    nodes=mat.node_tree.nodes; links=mat.node_tree.links
    bs=nodes.get("Principled BSDF")
    bs.inputs["Roughness"].default_value=.70
    tex=nodes.new("ShaderNodeTexImage")
    tex.image=bpy.data.images.load(str(hall/(palette+"Atlas.png")))
    links.new(tex.outputs["Color"],bs.inputs["Base Color"])
    normal=nodes.new("ShaderNodeTexImage")
    normal.image=bpy.data.images.load(str(hall/(palette+"Normal.png")))
    normal.image.colorspace_settings.name="Non-Color"
    bump=nodes.new("ShaderNodeNormalMap");bump.inputs["Strength"].default_value=.65
    links.new(normal.outputs["Color"],bump.inputs["Color"]);links.new(bump.outputs["Normal"],bs.inputs["Normal"])
    m.materials.append(mat)
bpy.ops.object.camera_add(location=(.42,-5.2,1.55))
cam=bpy.context.object
cam.rotation_euler=(Vector((0,0,1.04))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type="ORTHO";cam.data.ortho_scale=1.58;scene.camera=cam
for pos,energy,size in [((-2,-3,3),180,2),((2,-1,2.2),85,1.4),((0,1.5,2.9),100,1)]:
    bpy.ops.object.light_add(type='AREA',location=pos)
    light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK'; light.data.size=size
    light.rotation_euler=(Vector((0,0,.8))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.filepath=sys.argv[-1]
bpy.ops.render.render(write_still=True)
