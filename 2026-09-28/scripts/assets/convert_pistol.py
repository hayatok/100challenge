import bpy
import os

app = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
source = os.path.join(app, "public/assets/weapons/loafbrr-pistol/GLTF/Pistol.gltf")
output = os.path.join(app, "public/assets/weapons/pistol.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
for obj in bpy.data.objects:
    print("PISTOL_OBJECT", obj.name, obj.type)
for image in bpy.data.images:
    print("PISTOL_IMAGE", image.name, image.size[:])
bpy.ops.export_scene.gltf(filepath=output, export_format="GLB")
print("PISTOL_OUTPUT", output, os.path.getsize(output))
