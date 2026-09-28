"""Convert Rosswet Mobile's CC-BY 3.0 Thin Zombie to a textured, animated GLB.

Unzip new_thin_zom.zip into /tmp/nightshift-thin before running with Blender 5.2.
The source archive is available without an account from OpenGameArt.
"""

import bpy
import os

SOURCE = "/tmp/nightshift-thin/new_thin_zombie.blend"
TEXTURE = "/tmp/nightshift-thin/new_thin_zombie.png"
OUTPUT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../public/assets/characters/thin-zombie.glb")
)

bpy.ops.wm.open_mainfile(filepath=SOURCE)
rig = bpy.data.objects["Armature"]
body = bpy.data.objects["new_thin_zombie"]

# The old Blend material predates Principled texture nodes; explicitly reconnect
# the author's bundled color image before exporting to glTF.
material = bpy.data.materials.new("ThinZombie_Color")
material.use_nodes = True
body.material_slots[0].material = material
nodes = material.node_tree.nodes
links = material.node_tree.links
bsdf = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
image = nodes.new("ShaderNodeTexImage")
image.image = bpy.data.images.load(TEXTURE, check_existing=True)
links.new(image.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.88
bsdf.inputs["Metallic"].default_value = 0

# Preserve the source actions as individual glTF clips.
rig.animation_data_clear()
rig.animation_data_create()
for name in ("walk", "walk2", "run", "idle", "attack1_l", "attack1_r", "hurt", "dead1"):
    action = bpy.data.actions[name]
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, int(action.frame_range[0]), action)

# The source armature has additional parent transforms. At 0.88 root scale the
# exported mesh stands about 1.8 m tall, with its feet at the ground plane.
rig.scale = (0.88, 0.88, 0.88)
rig.location.z += 0.05
bpy.context.view_layer.update()

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
print("THIN_ZOMBIE_OUTPUT", OUTPUT, os.path.getsize(OUTPUT))
