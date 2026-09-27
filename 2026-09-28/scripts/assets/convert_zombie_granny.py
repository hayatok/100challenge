"""Convert Petrov_the_blind's CC0 Zombie Granny and her walk cycle to GLB.

Unzip the account-free itch.io Zombie Granny.zip into /tmp/nightshift-granny.
"""

import bpy
import os

ROOT = "/tmp/nightshift-granny/Zombie Granny"
OUTPUT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../public/assets/characters/zombie-granny.glb")
)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "granny.fbx"))
body = bpy.data.objects["Cylinder1"]
rig = next(mod.object for mod in body.modifiers if mod.type == "ARMATURE")
# The original has eight garment/skin materials referencing duplicate copies
# of one atlas. Preserve those materials and point them at one image datablock.
atlas = bpy.data.images.load(os.path.join(ROOT, "baked texture map2.png"), check_existing=True)
for slot in body.material_slots:
    material = slot.material
    if not material or not material.use_nodes:
        continue
    for node in material.node_tree.nodes:
        if node.type == "TEX_IMAGE":
            node.image = atlas

# The author also ships an 800-face version; keep the more detailed sculpt for
# the close camera, but reduce its 85k source faces to a web-friendly density.
decimate = body.modifiers.new("WebLOD", "DECIMATE")
decimate.ratio = 0.22
bpy.context.view_layer.objects.active = body
bpy.ops.object.modifier_move_up(modifier=decimate.name)
bpy.ops.object.modifier_apply(modifier=decimate.name)

action = rig.animation_data.action
action.name = "Walk"
rig.animation_data_clear()
rig.animation_data_create()
track = rig.animation_data.nla_tracks.new()
track.name = "Walk"
track.strips.new("Walk", int(action.frame_range[0]), action)

# The original FBX has a 3.5 m character centered on its origin. Scale the
# complete rig and mesh hierarchy to about 1.77 m and lift its feet to y=0.
root = bpy.data.objects.new("GrannyRoot", None)
bpy.context.collection.objects.link(root)
matrix = rig.matrix_world.copy()
rig.parent = root
rig.matrix_world = matrix
root.scale = (0.5, 0.5, 0.5)
root.location.z = 0.85
bpy.context.view_layer.update()

for obj in list(bpy.data.objects):
    if obj not in {root, rig, body}:
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format="GLB",
    export_animation_mode="NLA_TRACKS",
    export_nla_strips=True,
    export_optimize_animation_size=True,
)
print("ZOMBIE_GRANNY_OUTPUT", OUTPUT, os.path.getsize(OUTPUT))
