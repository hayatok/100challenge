"""Package Rikindle3D's original FBX mesh and motions into one textured GLB."""

import bpy
import os

app = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
root = os.path.join(app, "public/assets/characters/rikindle-city-zombie")
output = os.path.join(app, "public/assets/characters/zombie.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(root, "InfectedCityMan.fbx"))
base_rig = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
for bone in base_rig.data.bones:
    bone.name = bone.name.replace("CityDeadOutfit:", "mixamorig:")
for obj in bpy.data.objects:
    if obj.type == "MESH":
        for group in obj.vertex_groups:
            group.name = group.name.replace("CityDeadOutfit:", "mixamorig:")
base_rig.animation_data_clear()
base_rig.animation_data_create()

for material in bpy.data.materials:
    if material.name.startswith("City_Infected_Man_Body1"):
        prefix = "InfectedCityMan_City_Infected_Man_Body1_"
    elif material.name.startswith("City_Man_Infected_Outfit1"):
        prefix = "InfectedCityMan_City_Man_Infected_Outfit1_"
    else:
        continue
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    base = nodes.new("ShaderNodeTexImage")
    base.image = bpy.data.images.load(os.path.join(root, prefix + "BaseColor.png"), check_existing=True)
    links.new(base.outputs["Color"], bsdf.inputs["Base Color"])
    normal = nodes.new("ShaderNodeTexImage")
    normal.image = bpy.data.images.load(os.path.join(root, prefix + "Normal.png"), check_existing=True)
    normal.image.colorspace_settings.name = "Non-Color"
    normal_map = nodes.get("Normal Map") or nodes.new("ShaderNodeNormalMap")
    links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    orm = nodes.new("ShaderNodeTexImage")
    orm.image = bpy.data.images.load(os.path.join(root, prefix + "OcclusionRoughnessMetallic.png"), check_existing=True)
    orm.image.colorspace_settings.name = "Non-Color"
    channels = nodes.new("ShaderNodeSeparateColor")
    links.new(orm.outputs["Color"], channels.inputs["Color"])
    links.new(channels.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(channels.outputs["Blue"], bsdf.inputs["Metallic"])

motions = (
    ("Walking.fbx", "Walking"),
    ("Zombie Walk.fbx", "Zombie_Walk"),
    ("Zombie Idle.fbx", "Zombie_Idle"),
    ("Zombie Idle2.fbx", "Zombie_Idle2"),
    ("Zombie Attack.fbx", "Zombie_Attack"),
    ("Zombie Attack2.fbx", "Zombie_Attack2"),
    ("Zombie Attack3.fbx", "Zombie_Attack3"),
    ("Zombie Reaction Hit.fbx", "Zombie_Reaction_Hit"),
    ("Zombie Dying.fbx", "Zombie_Dying"),
    ("Zombie Running.fbx", "Zombie_Running"),
    ("Zombie Scream.fbx", "Zombie_Scream"),
)
base_bones = {bone.name for bone in base_rig.data.bones}
for filename, name in motions:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(root, filename))
    imported = next(obj for obj in set(bpy.data.objects) - before if obj.type == "ARMATURE")
    imported_bones = {bone.name for bone in imported.data.bones}
    assert imported_bones == base_bones, (name, sorted(base_bones - imported_bones)[:10], sorted(imported_bones - base_bones)[:10])
    action = imported.animation_data.action
    action.name = name
    track = base_rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, int(action.frame_range[0]), action)
    print("MOTION", name, tuple(action.frame_range))
    for obj in set(bpy.data.objects) - before:
        bpy.data.objects.remove(obj, do_unlink=True)

for obj in list(bpy.data.objects):
    if obj.type != "MESH" and obj is not base_rig:
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.export_scene.gltf(
    filepath=output,
    export_format="GLB",
    export_animation_mode="NLA_TRACKS",
    export_nla_strips=True,
    export_optimize_animation_size=True,
)
print("ZOMBIE_OUTPUT", output, os.path.getsize(output))
