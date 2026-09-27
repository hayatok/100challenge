import bpy
import os

app = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
root = os.path.join(app, "public/assets/weapons/para-fps-arms")
source = os.path.join(root, "FPS ARMS RIG 1.fbx")
output = os.path.join(app, "public/assets/weapons/fps-arms.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=source)
for obj in bpy.data.objects:
    print("ARMS_OBJECT", obj.name, obj.type, len(obj.data.vertices) if obj.type == "MESH" else "", obj.animation_data.action.name if obj.animation_data and obj.animation_data.action else "")
for mat in bpy.data.materials:
    print("ARMS_MATERIAL", mat.name)
    if not mat.use_nodes:
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        texture = mat.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image = bpy.data.images.load(os.path.join(root, "new_diff.png"), check_existing=True)
        mat.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
for action in bpy.data.actions:
    print("ARMS_ACTION", action.name, action.frame_range[:])
bpy.ops.export_scene.gltf(filepath=output, export_format="GLB")
print("ARMS_OUTPUT", output, os.path.getsize(output))
