"""Build the three v0.4 toy-office particle meshes from reference sheet 09.

Each centered logical Godot-space asset exports one vertex-colored mesh/material.
Rebuild: blender --background --python scripts/modeling/build_fx.py
Pass -- --render to additionally save front/right/back previews under /tmp.
"""
from pathlib import Path
import math
import sys
import bpy
import bmesh
from mathutils import Matrix, Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
from common import _active, _smooth, _place

PAPER = '#FFF1D8'
RED = '#F44338'
TEAL = '#25979B'
GOLD = '#FFC447'
PANEL = '#F1B338'


def mesh(name, vertices, faces, color, root, smooth=False):
    data = bpy.data.meshes.new(name + '_Mesh')
    data.from_pydata([vec(p) for p in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    if smooth:
        _smooth(obj)
    paint(obj, color)
    return obj


def curve_depth(y):
    return .012 * ((2 * y / .35) ** 2 - .5)


def paper():
    reset_scene()
    root = node('FXPaper')
    ys = [-.175, -.165, -.12, -.065, 0, .065, .11, .165, .175]
    nx = 4
    verts = []
    # The top-right triangular corner is cut from the curved main sheet.
    for side in [-1, 1]:
        for y in ys:
            corner = .008 if abs(y) > .17 else 0
            left = -.125 + corner
            right = .125 - max(0, y - .11) - corner
            for j in range(nx + 1):
                x = left + (right - left) * j / nx
                verts.append((x, y, curve_depth(y) + side * .0016))
    count = len(ys) * (nx + 1)
    faces = []
    for i in range(len(ys) - 1):
        for j in range(nx):
            a = i * (nx + 1) + j
            faces.append((a, a + nx + 1, a + nx + 2, a + 1))
            faces.append((a + count, a + 1 + count, a + nx + 2 + count, a + nx + 1 + count))
    outline = list(range(nx + 1))
    outline += [(i + 1) * (nx + 1) - 1 for i in range(2, len(ys) + 1)]
    outline += list(reversed(range((len(ys) - 1) * (nx + 1), count - 1)))
    outline += [i * (nx + 1) for i in reversed(range(1, len(ys) - 1))]
    for a, b in zip(outline, outline[1:] + outline[:1]):
        faces.append((a, b, b + count, a + count))
    # Logical -X is image-right when the forward -Z face is viewed head-on.
    verts = [(-x,y,z) for x,y,z in verts]
    faces = [tuple(reversed(face)) for face in faces]
    # Keep opposing sides/edge strips split: averaging the front and back of a
    # thin shell creates a spurious dark diagonal crease along the outline.
    mesh('Curled ivory sheet', verts, faces, PAPER, root, False)
    # A real bent-back corner, not a color decal; cream upper surface/darker underside.
    fold = [( .060, .175, curve_depth(.175)-.001),
            ( .125, .11, curve_depth(.11)-.001),
            ( .087, .12, -.024),
            ( .063, .135, -.018)]
    fold = [(-x,y,z) for x,y,z in fold]
    obj = mesh('Folded corner', fold, [(1, 2, 3, 0)], '#FFE4C7', root, True)
    _active(obj)
    mod = obj.modifiers.new('Fold thickness', 'SOLIDIFY'); mod.thickness = .003
    bpy.ops.object.modifier_apply(modifier=mod.name)
    paint(obj, '#FFE4C7')
    for name, y, width in [('Long teal line', .056, .157), ('Short teal line', .013, .126)]:
        rounded_box(name, (width, .022, .0016), (.016, y, curve_depth(y)-.0030),
                    TEAL, root, bevel=.0006, segments=1)
    # Circular approval stamp conforms to the gently curled surface.
    cx, cy, outer, inner, n = -.035, -.083, .044, .038, 24
    ring = []
    for radius in [outer, inner]:
        for j in range(n):
            a = math.tau * j / n
            x, y = cx + radius * math.cos(a), cy + radius * math.sin(a)
            ring.append((x, y, curve_depth(y)-.0030))
    ring_faces = [(j, n+j, n+(j+1)%n, (j+1)%n) for j in range(n)]
    mesh('Red circular approval seal', ring, ring_faces, RED, root)
    glyph = text('Approved kanji', '済', .071, color=RED, parent=root,
                 extrude=0, rotation=(0,0,math.pi))
    bpy.context.view_layer.update()
    # Center the glyph itself rather than its font baseline; bake the fixed flip.
    points = [glyph.matrix_basis @ v.co for v in glyph.data.vertices]
    logical = [BASIS.transposed() @ p for p in points]
    lo = Vector((min(v.x for v in logical), min(v.y for v in logical), 0))
    hi = Vector((max(v.x for v in logical), max(v.y for v in logical), 0))
    mid = (lo + hi) * .5
    scale = .062 / max(hi.x-lo.x, hi.y-lo.y)
    for vertex, value in zip(glyph.data.vertices, logical):
        x, y = cx + (value.x-mid.x)*scale, cy + (value.y-mid.y)*scale
        vertex.co = vec((x, y, curve_depth(y)-.0034))
    glyph.matrix_basis = Matrix.Identity(4)
    return root


def powder():
    reset_scene()
    root = node('FXPowder')
    # Four fused lobes: larger crown, lower left/right, and a forward lower bulge.
    for name, size, pos in [
        ('Crown', (.24,.27,.26), (0,.082,.019)),
        ('Left lobe', (.23,.24,.27), (-.113,-.052,.008)),
        ('Right lobe', (.25,.24,.28), (.109,-.053,.006)),
        ('Front lobe', (.23,.23,.23), (-.012,-.079,-.084)),
    ]:
        ellipsoid(name, size, pos, '#FFFAF2', root, segments=20, rings=12)
    merge_rigid(root)
    obj = root.children[0]
    _active(obj)
    remesh = obj.modifiers.new('Coherent powder union', 'REMESH')
    remesh.mode = 'VOXEL'; remesh.voxel_size = .012
    remesh.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = obj.modifiers.new('Soft fused lobe transitions', 'SMOOTH')
    smooth.factor = .75; smooth.iterations = 3
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    obj.data.calc_loop_triangles()
    decimate = obj.modifiers.new('Particle triangle budget', 'DECIMATE')
    decimate.ratio = min(1, 420 / len(obj.data.loop_triangles))
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    _smooth(obj)
    # Center and normalize its final bounds to the requested particle dimensions.
    lower = Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)))
    upper = Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))
    center = (lower + upper) / 2
    target = Vector((.45,.34,.38))
    extent = upper-lower
    for vertex in obj.data.vertices:
        vertex.co = Vector(tuple((vertex.co[i]-center[i])*target[i]/extent[i] for i in range(3)))
    obj.location = (0,0,0)
    paint(obj, '#FFFAF2')
    # Mild underside blue-gray is baked into colors so unshaded runtime remains soft.
    attr = obj.data.color_attributes['Color']
    for loop in obj.data.loops:
        height = (obj.data.vertices[loop.vertex_index].co.z + .19) / .38
        t = min(1, max(0, height * 2.7))
        low, high = linear_color('#CCDCDD'), linear_color('#FFFAF2')
        attr.data[loop.index].color = tuple(low[i]*(1-t)+high[i]*t for i in range(4))
    return root


def cube():
    reset_scene()
    root = node('FXCube')
    obj = rounded_box('Gold soft cube', (.12,.12,.12), color=GOLD, parent=root,
                      bevel=.011, segments=2)
    # Replace the six broad faces with a narrow frame and genuinely inset center.
    original_vertices = [v.co.copy() for v in obj.data.vertices]
    vertices, faces, face_colors = list(original_vertices), [], []
    for polygon in obj.data.polygons:
        ids = list(polygon.vertices)
        if polygon.area > .006:
            center = polygon.center.copy()
            inner_ids = []
            for index in ids:
                inner_ids.append(len(vertices))
                vertices.append(center + (original_vertices[index]-center)*.91 - polygon.normal*.0013)
            for i in range(len(ids)):
                faces.append((ids[i], ids[(i+1)%len(ids)], inner_ids[(i+1)%len(ids)], inner_ids[i]))
                face_colors.append(GOLD)
            faces.append(tuple(inner_ids)); face_colors.append(PANEL)
        else:
            faces.append(tuple(ids)); face_colors.append(GOLD)
    data = bpy.data.meshes.new('Gold cube inset panels')
    data.from_pydata(vertices, [], faces); data.update()
    obj.data = data
    _smooth(obj); paint(obj,GOLD)
    attr = data.color_attributes['Color']
    for polygon, color in zip(data.polygons,face_colors):
        for loop in polygon.loop_indices: attr.data[loop].color = linear_color(color)
    _active(obj)
    mod = obj.modifiers.new('Weighted panel normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # Chunky slanted red tape, clipped to the inset panel instead of overhanging.
    shape = [(-.044,-.044),(-.021,-.044),(.044,.021),(.044,.043),
             (.023,.044),(-.044,-.023)]
    z_front, z_back = -.0605, -.0580
    tape_verts = [(-x,y,z) for z in [z_front,z_back] for x,y in shape]
    n = len(shape)
    tape_faces = [tuple(reversed(range(n))),tuple(range(n,2*n))]
    tape_faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    tape = mesh('Red diagonal tape', tape_verts,tape_faces,RED,root)
    bm = bmesh.new();bm.from_mesh(tape.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(tape.data);bm.free()
    paint(tape,RED)
    return root


def preview(root, key):
    """Actual orthographic 3-view render, useful without editing game scenes."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 512;scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.world.color = (.25,.25,.25)
    scene.view_settings.view_transform = 'Standard'
    scene.render.film_transparent = False
    all_points = [o.matrix_world @ v.co for o in descendants(root) if o.type=='MESH' for v in o.data.vertices]
    extent = max(max(v[i] for v in all_points)-min(v[i] for v in all_points) for i in range(3))
    for name,position,energy,size in [('Key',(1,2,3),220,3),('Fill',(-2,0,1),80,2),
                                     ('Rear',(0,-2,2),120,3)]:
        light_data=bpy.data.lights.new(name,'AREA');light_data.energy=energy;light_data.shape='DISK';light_data.size=size
        light=bpy.data.objects.new(name,light_data);bpy.context.collection.objects.link(light)
        light.location=position;light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
    cam_data=bpy.data.cameras.new('Preview');cam_data.type='ORTHO';cam_data.ortho_scale=extent*1.3
    camera=bpy.data.objects.new('Preview',cam_data);bpy.context.collection.objects.link(camera);scene.camera=camera
    for view,position in [('front',(0,2,.04)),('side',(2,0,.04)),('back',(0,-2,.04))]:
        camera.location=position;camera.rotation_euler=(-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=f'/tmp/fx_{key}_{view}.png'
        bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    render = '--render' in sys.argv
    for key, builder, budget in [('paper',paper,1000),('powder',powder,450),('cube',cube,250)]:
        root=builder()
        merge_rigid(root)
        obj = next(o for o in root.children if o.type == 'MESH')
        bpy.context.view_layer.update()
        # Runtime takes the ArrayMesh directly; keep its vertices centered and
        # bake the last join object's transform rather than relying on scene nodes.
        for vertex in obj.data.vertices:
            vertex.co = obj.matrix_basis @ vertex.co
        obj.matrix_basis = Matrix.Identity(4)
        lower = Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)))
        upper = Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))
        center = (lower+upper)/2
        for vertex in obj.data.vertices:
            vertex.co -= center
        stats=export_glb(root,APP/f'game/assets/models/fx_{key}.glb',APP/f'art/models/fx_{key}.blend',merge=False)
        assert stats['triangles']<=budget,(key,stats)
        assert stats['surfaces']==1 and stats['meshes']==1,(key,stats)
        if render: preview(root,key)
