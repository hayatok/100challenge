"""Postprocess an authentic Tripo GLB; never synthesize replacement geometry.

Blender --background --factory-startup --python-exit-code 1 --python process_asset.py -- \
  --source /absolute/source.glb --output /absolute/game/assets/models/board.glb \
  --id TRIPO_TASK_ID --triangle-budget 12000 --length 1.85 \
  --rotate-deg 0 0 90 --expected-long-axis Z

Rotation arguments use Blender XYZ degrees (Z up). Export and reported game axes
use glTF/Godot coordinates (Y up). A Blender +90 degree Z rotation maps the source
board's X length to game -Z. Only a uniform scale is applied. Skins, shape keys and
armatures prohibit automatic decimation; a budget at least as large as their input
mesh is required. Such assets retain hierarchy, skin and animation export.
Optional renders go to --preview-dir (use a temporary directory, not source art).
"""

import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import shutil
import struct
import sys
import tempfile

import bpy
import bmesh
from mathutils import Vector, Euler


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def glb_summary(path):
    data = Path(path).read_bytes()
    magic, version, size = struct.unpack_from("<III", data)
    if magic != 0x46546C67 or version != 2 or size != len(data):
        raise ValueError("Expected a complete glTF 2.0 binary")
    offset = 12
    document = None
    binary = b""
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        content = data[offset + 8:offset + 8 + length]
        if kind == 0x4E4F534A:
            document = json.loads(content)
        elif kind == 0x004E4942:
            binary = content
        offset += 8 + length
    if document is None:
        raise ValueError("Missing glTF JSON")
    images = []
    for image in document.get("images", []):
        if "bufferView" not in image:
            raise ValueError("Only self-contained GLB images are supported")
        view = document["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        encoded = binary[start:start + view["byteLength"]]
        images.append({"name": image.get("name"), "mime": image.get("mimeType"),
                       "bytes": len(encoded), "sha256": hashlib.sha256(encoded).hexdigest()})
    primitives = [primitive for mesh in document.get("meshes", []) for primitive in mesh["primitives"]]
    triangles = 0
    for primitive in primitives:
        if primitive.get("mode", 4) != 4:
            raise ValueError("Non-triangle glTF primitive")
        accessor = primitive.get("indices", primitive["attributes"]["POSITION"])
        triangles += document["accessors"][accessor]["count"] // 3
    bindings = []
    for material in document.get("materials", []):
        roles = dict(material.get("pbrMetallicRoughness", {}))
        roles.update({key: material[key] for key in ["normalTexture", "occlusionTexture", "emissiveTexture"] if key in material})
        binding = {}
        for role, reference in roles.items():
            if role.endswith("Texture") and isinstance(reference, dict):
                texture = document["textures"][reference["index"]]
                binding[role] = {"image_sha256": images[texture["source"]]["sha256"],
                                 "texcoord": reference.get("texCoord", 0)}
        bindings.append(binding)
    return {"bytes": len(data), "sha256": sha256(path), "triangles": triangles,
            "meshes": len(document.get("meshes", [])), "primitives": len(primitives),
            "uv_primitives": sum("TEXCOORD_0" in p["attributes"] for p in primitives),
            "materials": len(document.get("materials", [])), "images": images,
            "material_texture_bindings": bindings,
            "skins": len(document.get("skins", [])),
            "skin_joints": [len(s["joints"]) for s in document.get("skins", [])],
            "animations": len(document.get("animations", [])),
            "animation_channels": [len(a["channels"]) for a in document.get("animations", [])]}


def meshes():
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def triangle_count(objects):
    count = 0
    for obj in objects:
        obj.data.calc_loop_triangles()
        count += len(obj.data.loop_triangles)
    return count


def bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    low = Vector([min(p[axis] for p in points) for axis in range(3)])
    high = Vector([max(p[axis] for p in points) for axis in range(3)])
    return low, high


def mesh_summary():
    objects = meshes()
    low, high = bounds(objects)
    dimensions = high - low
    return {"triangles": triangle_count(objects), "mesh_objects": len(objects),
            "vertices": sum(len(obj.data.vertices) for obj in objects),
            "blender_min": list(low), "blender_max": list(high),
            "blender_dimensions": list(dimensions),
            "game_dimensions_xyz": [dimensions.x, dimensions.z, dimensions.y],
            "uv_layer_counts": [len(obj.data.uv_layers) for obj in objects],
            "armatures": sum(obj.type == "ARMATURE" for obj in bpy.context.scene.objects),
            "material_slots": sum(len(obj.data.materials) for obj in objects)}


def texture_pixels():
    result = []
    for image in bpy.data.images:
        if image.type != "IMAGE" or image.size[0] == 0:
            continue
        pixels = array.array("f", [0]) * len(image.pixels)
        image.pixels.foreach_get(pixels)
        result.append({"width": image.size[0], "height": image.size[1],
                       "channels": image.channels,
                       "pixel_sha256": hashlib.sha256(pixels.tobytes()).hexdigest()})
    return sorted(result, key=lambda image: image["pixel_sha256"])


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def opening_qa(reference_bounds):
    low, high = [Vector(value) for value in reference_bounds]
    center_x = (low.x + high.x) / 2
    width, depth, height = high - low
    extent = max(width, depth, height)
    graph = bpy.context.evaluated_depsgraph_get()
    blocked = 0
    for horizontal in [-0.18, -0.09, 0, 0.09, 0.18]:
        for vertical in [0.1, 0.225, 0.35, 0.475, 0.6]:
            origin = Vector((center_x + width * horizontal, high.y + extent, low.z + height * vertical))
            hit, *_ = bpy.context.scene.ray_cast(graph, origin, Vector((0, -1, 0)), distance=depth + extent * 2)
            blocked += int(hit)
    return {"rays": 25, "blocked": blocked, "clear": 25 - blocked}


def render_comparison(directory):
    result = {}
    for name in ["top", "bottom", "threequarter", "game-front-minus-z", "game-back-plus-z"]:
        source = Path(directory) / f"source-{name}.png"
        reduced = Path(directory) / f"reduced-{name}.png"
        if not source.exists() or not reduced.exists():
            continue
        images = [bpy.data.images.load(str(file), check_existing=False) for file in [source, reduced]]
        values = []
        for image in images:
            pixels = array.array("f", [0]) * len(image.pixels)
            image.pixels.foreach_get(pixels)
            values.append(pixels)
        errors = [abs(a - b) for i, (a, b) in enumerate(zip(*values)) if i % 4 != 3]
        result[name] = {"rgb_mean_absolute_error_0_to_1": sum(errors) / len(errors),
                        "rgb_max_absolute_error_0_to_1": max(errors)}
        for image in images:
            bpy.data.images.remove(image)
    return result


def preview(directory, label):
    """Render actual mesh only; cameras/lights are removed before GLB export."""
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.render.resolution_x = 768
    scene.render.resolution_y = 576
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new("QAWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.15, 0.2, 0.25, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    created = []
    low, high = bounds(meshes())
    center = (low + high) * 0.5
    extent = max(high - low)
    light_data = bpy.data.lights.new("QALight", "AREA")
    light_data.energy = 550 * extent * extent
    light_data.shape = "DISK"
    light_data.size = extent * 2
    light = bpy.data.objects.new("QALight", light_data)
    scene.collection.objects.link(light)
    light.location = center + Vector((0.4, -0.5, 2.5)) * extent
    created.append(light)
    camera_data = bpy.data.cameras.new("QACamera")
    camera = bpy.data.objects.new("QACamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    created.append(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = extent * 1.35
    for name, direction in [("top", (0, 0, 1)), ("bottom", (0, 0, -1)),
                            ("threequarter", (1, -1.5, 1.5)),
                            ("game-front-minus-z", (0, 1, 0)), ("game-back-plus-z", (0, -1, 0))]:
        camera.location = center + Vector(direction).normalized() * extent * 3
        camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(directory / f"{label}-{name}.png")
        bpy.ops.render.render(write_still=True)
    for obj in created:
        bpy.data.objects.remove(obj, do_unlink=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--id", required=True, help="Original Tripo generation task ID")
    parser.add_argument("--triangle-budget", type=int, required=True)
    parser.add_argument("--length", type=float, required=True, help="Longest-axis size in metres")
    parser.add_argument("--size-axis", choices=["X", "Y", "Z"],
                        help="Game axis to size with --length; omitted uses longest axis")
    parser.add_argument("--rotate-deg", type=float, nargs=3, default=[0, 0, 0], metavar=("X", "Y", "Z"))
    parser.add_argument("--expected-long-axis", choices=["X", "Y", "Z"])
    parser.add_argument("--preview-dir")
    parser.add_argument("--opening-qa", action="store_true",
                        help="Compare 25 central-opening rays along game Z before/after processing")
    parser.add_argument("--report")
    parser.add_argument("--weld-distance", type=float, default=0.000001,
                        help="Merge only coincident imported vertices in source-local units; UVs remain per face corner")
    parser.add_argument("--verified-source-top", choices=["X", "Y", "Z"],
                        help="Positive Blender axis visually verified as the source top by the operator")
    parser.add_argument("--verified-source-front", choices=["+X", "-X", "+Y", "-Y", "+Z", "-Z"],
                        help="Signed Blender axis visually verified as source front; must rotate to game -Z")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    source, output = Path(args.source).resolve(), Path(args.output).resolve()
    if (source == output or args.triangle_budget < 4 or not math.isfinite(args.length) or args.length <= 0
            or not math.isfinite(args.weld_distance) or args.weld_distance < 0
            or not all(math.isfinite(angle) for angle in args.rotate_deg)):
        raise ValueError("Source/output must differ; budget and length must be positive")
    report_path = Path(args.report) if args.report else Path(__file__).parent / "reports" / f"{output.stem}.json"
    original = glb_summary(source)
    reset()
    bpy.ops.import_scene.gltf(filepath=str(source))
    before = mesh_summary()
    original_pixels = texture_pixels()
    has_deformation = original["skins"] > 0 or before["armatures"] > 0 or any(obj.data.shape_keys for obj in meshes())
    if has_deformation and before["triangles"] > args.triangle_budget:
        raise ValueError("Refusing automatic decimation of a skin, armature or shape-key asset; supply a safe rig-aware retopology")

    # Keep imported local coordinates and skin hierarchy intact under one root.
    asset_root = bpy.data.objects.new("TripoAsset", None)
    bpy.context.scene.collection.objects.link(asset_root)
    for obj in list(bpy.context.scene.objects):
        if obj != asset_root and obj.parent is None:
            obj.parent = asset_root
    asset_root.rotation_euler = Euler([math.radians(x) for x in args.rotate_deg], "XYZ")
    bpy.context.view_layer.update()
    low, high = bounds(meshes())
    dimensions = high - low
    game_dimensions = [dimensions.x, dimensions.z, dimensions.y]
    sized_dimension = game_dimensions["XYZ".index(args.size_axis)] if args.size_axis else max(dimensions)
    scale = args.length / sized_dimension
    asset_root.scale = Vector((scale, scale, scale))
    bpy.context.view_layer.update()
    low, high = bounds(meshes())
    # Ground the mesh, center its footprint. No anisotropic deformation.
    asset_root.location = Vector((-(low.x + high.x) / 2, -(low.y + high.y) / 2, -low.z))
    bpy.context.view_layer.update()
    normalized_before = mesh_summary()
    reference_bounds = bounds(meshes())
    source_opening = opening_qa(reference_bounds) if args.opening_qa else None
    if args.preview_dir:
        preview(args.preview_dir, "source")

    decimated = []
    welded = []
    ratio = min(1.0, args.triangle_budget / before["triangles"])
    if ratio < 1:
        for obj in meshes():
            vertices_before = len(obj.data.vertices)
            if args.weld_distance > 0:
                # glTF duplicates positions at UV/normal seams. BMesh retains UV
                # data on loops while welding only positions, allowing collapse
                # across coincident geometric boundaries without unwrapping.
                mesh = bmesh.new()
                mesh.from_mesh(obj.data)
                bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=args.weld_distance)
                mesh.to_mesh(obj.data)
                mesh.free()
                obj.data.update()
            welded.append({"object": obj.name, "vertices_before": vertices_before,
                           "vertices_after": len(obj.data.vertices)})
            bpy.context.view_layer.objects.active = obj
            modifier = obj.modifiers.new("TripoCollapseBudget", "DECIMATE")
            modifier.decimate_type = "COLLAPSE"
            modifier.ratio = ratio
            modifier.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
            decimated.append(obj.name)
    reduced = mesh_summary()
    if reduced["triangles"] > args.triangle_budget * 1.05:
        raise ValueError(f"Decimated mesh exceeds budget: {reduced['triangles']}")
    if args.preview_dir:
        preview(args.preview_dir, "reduced")

    staging_directory = tempfile.TemporaryDirectory(prefix="cloudsea-asset-")
    candidate = Path(staging_directory.name) / output.name
    bpy.ops.export_scene.gltf(filepath=str(candidate), export_format="GLB", export_yup=True,
                              export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO",
                              export_skins=True, export_animations=True)
    exported = glb_summary(candidate)
    reset()
    bpy.ops.import_scene.gltf(filepath=str(candidate))
    reimported = mesh_summary()
    reimported_pixels = texture_pixels()
    output_opening = opening_qa(reference_bounds) if args.opening_qa else None
    actual_axis = "XYZ"[max(range(3), key=lambda i: reimported["game_dimensions_xyz"][i])]
    actual_size = reimported["game_dimensions_xyz"]["XYZ".index(args.size_axis)] if args.size_axis else max(reimported["game_dimensions_xyz"])
    verified_top = False
    verified_front = False
    if args.verified_source_top:
        source_top = Vector([1 if axis == args.verified_source_top else 0 for axis in "XYZ"])
        rotated_top = Euler([math.radians(x) for x in args.rotate_deg], "XYZ").to_matrix() @ source_top
        verified_top = rotated_top.dot(Vector((0, 0, 1))) > 0.999
    if args.verified_source_front:
        source_front = Vector([1 if axis == args.verified_source_front[1] else 0 for axis in "XYZ"])
        source_front *= -1 if args.verified_source_front[0] == "-" else 1
        rotated_front = Euler([math.radians(x) for x in args.rotate_deg], "XYZ").to_matrix() @ source_front
        verified_front = rotated_front.dot(Vector((0, 1, 0))) > 0.999
    checks = {
        "source_unchanged": sha256(source) == original["sha256"],
        "length_within_1_percent": abs(actual_size - args.length) <= args.length * 0.01,
        "triangles_match_clean_reimport": exported["triangles"] == reimported["triangles"],
        "within_triangle_budget_5_percent": exported["triangles"] <= args.triangle_budget * 1.05,
        "uvs_present": exported["uv_primitives"] == exported["primitives"],
        "material_count_preserved": original["materials"] == exported["materials"],
        "material_texture_bindings_preserved": original["material_texture_bindings"] == exported["material_texture_bindings"],
        "image_count_preserved": len(original["images"]) == len(exported["images"]),
        "decoded_texture_pixels_preserved": original_pixels == reimported_pixels,
        "skin_joint_counts_preserved": original["skin_joints"] == exported["skin_joints"],
        "animation_channel_counts_preserved": original["animation_channels"] == exported["animation_channels"],
    }
    if args.expected_long_axis:
        checks["long_axis_matches"] = actual_axis == args.expected_long_axis
    if args.opening_qa:
        checks["central_opening_clear_in_source"] = source_opening["blocked"] == 0
        checks["central_opening_clear_after_reimport"] = output_opening["blocked"] == 0
    report = {"tripo_task_id": args.id, "blender_version": bpy.app.version_string,
              "source_file": source.name, "output_file": output.name,
              "parameters": {"triangle_budget": args.triangle_budget, "length_metres": args.length,
                             "blender_rotation_xyz_degrees": args.rotate_deg,
                             "uniform_scale": scale, "expected_game_long_axis": args.expected_long_axis,
                             "source_local_weld_distance": args.weld_distance,
                             "sized_game_axis": args.size_axis or "LONGEST",
                             "operator_verified_source_top": args.verified_source_top,
                             "operator_verified_source_front": args.verified_source_front},
              "source_glb": original, "source_import": before,
              "normalized_source": normalized_before, "reduced_mesh": reduced,
              "output_glb": exported, "clean_reimport": reimported,
              "source_decoded_images": original_pixels, "output_decoded_images": reimported_pixels,
              "welded_vertices": welded, "decimated_objects": decimated, "checks": checks,
              "uv_processing": {"original_layer_retained": all(reimported["uv_layer_counts"]),
                                "coordinates_exact_preserved": ratio == 1,
                                "unwrapped": False, "textures_repainted": False},
              "render_comparison": render_comparison(args.preview_dir) if args.preview_dir else {},
              "render_settings": {"width": 768, "height": 576, "cycles_samples": 16,
                                  "area_light_watts_per_squared_extent": 550,
                                  "area_light_size_per_extent": 2} if args.preview_dir else None,
              "relative_dimension_change": [abs(a - b) / a if a else 0 for a, b in zip(normalized_before["game_dimensions_xyz"], reimported["game_dimensions_xyz"])],
              "central_opening_qa": {"source": source_opening, "output": output_opening} if args.opening_qa else None,
              "orientation": {"game_up_axis": "+Y", "game_long_axis": actual_axis,
                              "front_back_semantic_verified": verified_front,
                              "game_front_axis": "-Z" if verified_front else None,
                              "top_semantic_verified": verified_top},
              "visual_quality_approved": False}
    report["committed_output"] = all(checks.values())
    if report["committed_output"]:
        output.parent.mkdir(parents=True, exist_ok=True)
        temporary_output = output.with_suffix(".glb.tmp")
        shutil.copyfile(candidate, temporary_output)
        temporary_output.replace(output)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print("ASSET_QA", json.dumps({"report": str(report_path), "checks": checks,
                                   "triangles": exported["triangles"], "game_dimensions": reimported["game_dimensions_xyz"]}))
    if not all(checks.values()):
        raise ValueError("Asset QA checks failed; inspect the report and retain the source")
    staging_directory.cleanup()


if __name__ == "__main__":
    main()
