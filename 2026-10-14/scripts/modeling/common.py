"""Blender 4.3 toy-office modeling helpers.

All public positions, dimensions, axes and Euler rotations use Godot coordinates:
X right, Y up, Z back (forward -Z). Rotations are radians. Colors accept sRGB
hex strings or sRGB float tuples. Geometry is local to the supplied parent.
Run scripts with ``blender --background --python path/to/generator.py``.
"""
from __future__ import annotations

import math
from pathlib import Path
from collections import defaultdict

import bpy
from mathutils import Euler, Matrix, Vector

HERE = Path(__file__).resolve().parent
APP = HERE.parents[1]
FONT = APP / 'game/assets/fonts/NotoSansCJKjp-Medium.otf'
PALETTE = {
    'cream': '#FFF0D0', 'teal': '#159B9C', 'dark_teal': '#164E59',
    'orange': '#FF8D3C', 'red': '#F4433E', 'yellow': '#FFD45B',
    'ink': '#223443', 'white': '#FFFAED', 'skin': '#F7BB83',
    'pink': '#F783A2', 'blue': '#4B7DAA', 'green': '#4BBE83',
    'paper': '#FFF8E8', 'brown': '#B57E4E',
}
# Proper rotation, determinant +1: Godot (x,y,z) -> Blender (x,-z,y).
BASIS = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
MATERIAL_NAME = 'ToyOffice_VertexColor'
COLOR_ATTRIBUTE = 'Color'


def vec(value):
    """Map a logical Godot vector to Blender."""
    return BASIS @ Vector(value)


def linear_color(color):
    """Convert an sRGB hex/tuple to linear RGBA for mesh color attributes."""
    if isinstance(color, str):
        value = color.lstrip('#')
        if len(value) == 3:
            value = ''.join(c * 2 for c in value)
        if len(value) not in (6, 8):
            raise ValueError(f'Expected RGB/RGBA hex color, received {color!r}')
        color = tuple(int(value[i:i + 2], 16) / 255 for i in range(0, len(value), 2))
    if len(color) not in (3, 4):
        raise ValueError('Colors need three or four sRGB components')
    def convert(c):
        return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4
    return (*[convert(float(c)) for c in color[:3]], float(color[3]) if len(color) == 4 else 1.0)


def reset_scene():
    """Remove scene objects and unused model datablocks; retain no cameras/lights."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for datablock in list(collection):
            if datablock.users == 0:
                collection.remove(datablock)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1


def material():
    """One white, rough, vertex-colored Principled material for every solid."""
    mat = bpy.data.materials.get(MATERIAL_NAME)
    if mat:
        return mat
    mat = bpy.data.materials.new(MATERIAL_NAME)
    mat.diffuse_color = (1, 1, 1, 1)
    mat.use_backface_culling = True
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (1, 1, 1, 1)
    shader.inputs['Metallic'].default_value = 0
    shader.inputs['Roughness'].default_value = .72
    colors = mat.node_tree.nodes.new('ShaderNodeVertexColor')
    colors.layer_name = COLOR_ATTRIBUTE
    mat.node_tree.links.new(colors.outputs['Color'], shader.inputs['Base Color'])
    return mat


def paint(obj, color):
    """Give a mesh the shared material and a uniform linear color attribute."""
    obj.data.materials.clear()
    obj.data.materials.append(material())
    attr = obj.data.color_attributes.get(COLOR_ATTRIBUTE)
    if attr is None:
        attr = obj.data.color_attributes.new(name=COLOR_ATTRIBUTE, type='FLOAT_COLOR', domain='CORNER')
    rgba = linear_color(color)
    for entry in attr.data:
        entry.color = rgba
    obj.data.color_attributes.active_color = attr
    return obj


def _active(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _place(obj, name, pos, parent=None, rotation=(0, 0, 0)):
    obj.name = name
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.location = vec(pos)
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = (BASIS @ Euler(rotation, 'XYZ').to_matrix() @ BASIS.transposed()).to_quaternion()
    return obj


def node(name, parent=None, pos=(0, 0, 0), rotation=(0, 0, 0)):
    """Create a named exportable Empty. Use for root and runtime animation pivots."""
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type = 'PLAIN_AXES'
    obj.empty_display_size = .15
    return _place(obj, name, pos, parent, rotation)


pivot = node


def _smooth(obj):
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def rounded_box(name, size, pos=(0, 0, 0), color=PALETTE['cream'], parent=None,
                bevel=.06, segments=2, rotation=(0, 0, 0)):
    """Box with applied bevel and weighted normals, logical full dimensions."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new('Soft toy edges', 'BEVEL')
        mod.width = min(bevel, min(size) * .45)
        mod.segments = segments
        mod.limit_method = 'ANGLE'
        mod.harden_normals = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    _smooth(obj)
    mod = obj.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
    mod.keep_sharp = True
    mod.weight = 50
    bpy.ops.object.modifier_apply(modifier=mod.name)
    paint(obj, color)
    return _place(obj, name, pos, parent, rotation)


def ellipsoid(name, size, pos=(0, 0, 0), color=PALETTE['cream'], parent=None,
              segments=16, rings=8, rotation=(0, 0, 0)):
    """Smooth UV ellipsoid; size gives full logical dimensions."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1)
    obj = bpy.context.object
    obj.scale = (size[0] / 2, size[2] / 2, size[1] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    paint(_smooth(obj), color)
    return _place(obj, name, pos, parent, rotation)


def cylinder(name, radius, depth, pos=(0, 0, 0), color=PALETTE['cream'], parent=None,
             axis=(0, 1, 0), vertices=16, radius_top=None, bevel=.015):
    """Cylinder/cone with a logical local axis and flat weighted end caps."""
    if radius_top is None:
        radius_top = radius
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                   radius2=radius_top, depth=depth)
    obj = bpy.context.object
    orientation = Vector((0, 0, 1)).rotation_difference(vec(axis).normalized())
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = orientation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    if bevel > 0:
        mod = obj.modifiers.new('Soft rim', 'BEVEL')
        mod.width = min(bevel, radius * .25, depth * .2)
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    _smooth(obj)
    mod = obj.modifiers.new('Weighted cap normals', 'WEIGHTED_NORMAL')
    mod.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    paint(obj, color)
    return _place(obj, name, pos, parent)


def tube(name, points, radius, color=PALETTE['ink'], parent=None, radii=None, sides=8,
         capped=True):
    """Smooth curved/tapered polyline tube in logical parent-local coordinates.

    Supply a densely sampled path for curves (e.g. 8 points for a hose). Optional
    radii has one radius per point. No bevel modifiers or curve export required.
    """
    path = [vec(p) for p in points]
    if len(path) < 2 or sides < 3:
        raise ValueError('A tube needs at least two path points and three sides')
    if radii is None:
        radii = [radius] * len(path)
    if len(radii) != len(path):
        raise ValueError('radii must have one item per path point')
    verts, faces = [], []
    prior_normal = None
    for i, point in enumerate(path):
        tangent = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
        if tangent.length < 1e-8:
            raise ValueError('Tube path has coincident neighboring points')
        tangent.normalize()
        if prior_normal is None:
            reference = Vector((0, 0, 1)) if abs(tangent.z) < .9 else Vector((1, 0, 0))
            normal = tangent.cross(reference).normalized()
        else:
            normal = prior_normal - tangent * prior_normal.dot(tangent)
            if normal.length < 1e-7:
                normal = tangent.orthogonal()
            normal.normalize()
        binormal = tangent.cross(normal).normalized()
        prior_normal = normal
        for k in range(sides):
            angle = math.tau * k / sides
            verts.append(point + radii[i] * (math.cos(angle) * normal + math.sin(angle) * binormal))
    for i in range(len(path) - 1):
        for k in range(sides):
            next_k = (k + 1) % sides
            faces.append((i * sides + k, i * sides + next_k,
                          (i + 1) * sides + next_k, (i + 1) * sides + k))
    if capped:
        faces.extend([tuple(reversed(range(sides))), tuple((len(path) - 1) * sides + k for k in range(sides))])
    mesh = bpy.data.meshes.new(name + '_Mesh')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    _smooth(obj)
    if capped:
        mesh.polygons[-1].use_smooth = False
        mesh.polygons[-2].use_smooth = False
    paint(obj, color)
    return _place(obj, name, (0, 0, 0), parent)


def text(name, body, size, pos=(0, 0, 0), color=PALETTE['ink'], parent=None,
         rotation=(0, 0, 0), extrude=.002, align='CENTER', font_path=FONT):
    """Outlined text on the logical -Z plane, pivot at its font baseline.

    The converted font plane has glyph-up at -Y. For upright front -Z text,
    pass rotation=(0, 0, math.pi); for front +Z use (math.pi, 0, 0), and for
    top +Y use (math.pi / 2, 0, 0). Verify glyphs in the three-view renderer.
    size is Blender font size in meters, not a fixed glyph height. Japanese font
    is loaded from the game; converted meshes use the same vertex-color material.
    """
    curve = bpy.data.curves.new(name + '_Text', 'FONT')
    curve.body = body
    curve.size = size
    curve.align_x = align
    curve.extrude = extrude
    curve.resolution_u = 3
    if font_path and Path(font_path).is_file():
        curve.font = bpy.data.fonts.load(str(font_path), check_existing=True)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    _active(obj)
    bpy.ops.object.convert(target='MESH')
    obj = bpy.context.object
    # Text is made in Blender XY; rotate its +Z normal to logical forward (+Y).
    obj.rotation_euler = (-math.pi / 2, 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    paint(obj, color)
    return _place(obj, name, pos, parent, rotation)


def descendants(root):
    return [root, *root.children_recursive]


def merge_rigid(root):
    """Join direct sibling meshes by parent and material; preserve all pivots.

    Create an Empty whenever geometry needs independent runtime movement. Joining
    retains each color and custom normals. One shared material = one surface per
    rigid group. Run after all geometry has been created and before export.
    """
    bpy.context.view_layer.update()
    groups = defaultdict(list)
    for obj in descendants(root):
        if obj.type == 'MESH':
            groups[(obj.parent, tuple(m.name for m in obj.data.materials))].append(obj)
    for (parent, _), objects in groups.items():
        if len(objects) < 2:
            continue
        _active(objects[0])
        for obj in objects[1:]:
            obj.select_set(True)
        bpy.ops.object.join()
        result = bpy.context.object
        result.name = (parent.name if parent else root.name) + '_Geometry'
    return root


def mesh_stats(root):
    """Triangle/surface counts after modifiers; useful for asset budgets."""
    triangles, surfaces, meshes = 0, 0, 0
    for obj in descendants(root):
        if obj.type == 'MESH':
            obj.data.calc_loop_triangles()
            triangles += len(obj.data.loop_triangles)
            surfaces += len(obj.data.materials)
            meshes += 1
    return {'triangles': triangles, 'surfaces': surfaces, 'meshes': meshes,
            'pivots': sum(obj.type == 'EMPTY' for obj in descendants(root))}


def export_glb(root, path, blend_path=None, merge=True):
    """Export selected root hierarchy with names, normals and linear COLOR_0.

    Only supplied hierarchy is selected; cameras/lights outside it are excluded.
    Optional .blend retains editable scene. Absolute or relative paths accepted.
    """
    if merge:
        merge_rigid(root)
    destination = Path(path).resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in descendants(root):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=str(destination), export_format='GLB',
                              use_selection=True, export_yup=True,
                              export_apply=True, export_materials='EXPORT',
                              export_vertex_color='MATERIAL', export_all_vertex_colors=False,
                              export_normals=True, export_texcoords=False,
                              export_animations=False, export_cameras=False,
                              export_lights=False, export_extras=False)
    if blend_path:
        source = Path(blend_path).resolve()
        source.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
    stats = mesh_stats(root)
    print(f'ASSET_EXPORT {destination.name}: {stats}')
    return stats
