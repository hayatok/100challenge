"""Convert City Building Game Art's CC0 Horror Game Monster into a GLB.

Unzip Poses.zip from OpenGameArt into /tmp/nightshift-monster before running.
The source archive is not included in the shipped site.
"""

import bpy
import os

ROOT = "/tmp/nightshift-monster/Poses"
OUTPUT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../public/assets/characters/horror-creature.glb")
)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "Walk.fbx"))
body = bpy.data.objects["Creature1"]
rig = next(mod.object for mod in body.modifiers if mod.type == "ARMATURE")
base_bones = {bone.name for bone in rig.data.bones}

material = body.material_slots[0].material
material.use_nodes = True
nodes = material.node_tree.nodes
links = material.node_tree.links
bsdf = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
image = nodes.new("ShaderNodeTexImage")
image.image = bpy.data.images.load(
    os.path.join(ROOT, "UnityTexture", "test_StingrayPBS1SG_AlbedoTransparency.png"),
    check_existing=True,
)
links.new(image.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.84
bsdf.inputs["Metallic"].default_value = 0
material.blend_method = "OPAQUE"

walk = rig.animation_data.action
walk.name = "Walk"
rig.animation_data_clear()
rig.animation_data_create()
track = rig.animation_data.nla_tracks.new()
track.name = "Walk"
track.strips.new("Walk", int(walk.frame_range[0]), walk)

for filename, name in (("Idle.fbx", "Idle"), ("Run.fbx", "Run")):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, filename))
    imported = set(bpy.data.objects) - before
    animated_rig = next(
        obj for obj in imported
        if obj.type == "ARMATURE" and {bone.name for bone in obj.data.bones} == base_bones
    )
    action = animated_rig.animation_data.action
    action.name = name
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, int(action.frame_range[0]), action)
    for obj in imported:
        bpy.data.objects.remove(obj, do_unlink=True)

for obj in list(bpy.data.objects):
    if obj not in {rig, body}:
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format="GLB",
    export_animation_mode="NLA_TRACKS",
    export_nla_strips=True,
    export_optimize_animation_size=True,
)
print("HORROR_CREATURE_OUTPUT", OUTPUT, os.path.getsize(OUTPUT))
