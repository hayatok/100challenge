"""Dependency-free glTF geometry checks for the shared toy-office pipeline.

Usage: python3 verify_glb.py path.glb --max-triangles 15000 --require-node HeadPivot
Godot material import is verified separately; this checks the exported artifact.
"""
from __future__ import annotations

import argparse
import json
import math
import struct
from pathlib import Path


def verify(path, max_triangles=None, required_nodes=()):
    raw = Path(path).read_bytes()
    magic, version, total = struct.unpack_from('<4sII', raw)
    assert magic == b'glTF' and version == 2 and total == len(raw), 'Invalid GLB header'
    offset, document, binary = 12, None, None
    while offset < len(raw):
        length, kind = struct.unpack_from('<I4s', raw, offset)
        chunk = raw[offset + 8:offset + 8 + length]
        if kind == b'JSON':
            document = json.loads(chunk)
        elif kind == b'BIN\x00':
            binary = chunk
        offset += 8 + length
    assert document and binary is not None, 'Expected embedded geometry'
    names = [node.get('name', '') for node in document.get('nodes', [])]
    for name in required_nodes:
        assert name in names, f'Missing named pivot: {name}'
    materials = document.get('materials', [])
    assert len(materials) == 1, f'Expected one shared material, got {len(materials)}'
    pbr = materials[0].get('pbrMetallicRoughness', {})
    assert pbr.get('baseColorFactor', [1, 1, 1, 1]) == [1, 1, 1, 1], 'Albedo must be white'
    assert pbr.get('metallicFactor', 1) == 0, 'Toy office material must be non-metallic'
    formats = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}
    widths = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}

    def accessor(index):
        item = document['accessors'][index]
        view = document['bufferViews'][item['bufferView']]
        fmt = '<' + formats[item['componentType']] * widths[item['type']]
        size = struct.calcsize(fmt)
        stride = view.get('byteStride', size)
        at = view.get('byteOffset', 0) + item.get('byteOffset', 0)
        values = [struct.unpack_from(fmt, binary, at + i * stride) for i in range(item['count'])]
        if item.get('normalized') and item['componentType'] in (5121, 5123):
            divisor = 255 if item['componentType'] == 5121 else 65535
            values = [tuple(c / divisor for c in v) for v in values]
        return values

    triangles, surfaces, vertex_count, colors = 0, 0, 0, set()
    for mesh in document.get('meshes', []):
        assert len(mesh['primitives']) == 1, 'Rigid meshes must have one surface'
        for primitive in mesh['primitives']:
            assert primitive.get('mode', 4) == 4, 'Expected triangles'
            assert primitive.get('material') == 0, 'Expected shared material'
            attributes = primitive['attributes']
            assert {'POSITION', 'NORMAL', 'COLOR_0'} <= attributes.keys(), 'Missing position/normal/color'
            positions = accessor(attributes['POSITION'])
            normals = accessor(attributes['NORMAL'])
            rgba = accessor(attributes['COLOR_0'])
            assert len(positions) == len(normals) == len(rgba), 'Attribute size mismatch'
            for vertex in positions:
                assert all(math.isfinite(c) for c in vertex), 'Non-finite position'
            for normal in normals:
                assert abs(sum(c * c for c in normal) - 1) < .025, 'Non-unit normal'
            for color in rgba:
                assert all(math.isfinite(c) and -.00001 <= c <= 1.00001 for c in color), 'Invalid linear color'
                colors.add(tuple(round(c, 5) for c in color))
            indices = accessor(primitive['indices']) if 'indices' in primitive else list(range(len(positions)))
            assert len(indices) % 3 == 0, 'Invalid triangle indices'
            triangles += len(indices) // 3
            surfaces += 1
            vertex_count += len(positions)
    assert triangles > 0, 'No geometry'
    if max_triangles:
        assert triangles <= max_triangles, f'Triangle budget exceeded: {triangles} > {max_triangles}'
    return {'path': str(path), 'bytes': len(raw), 'triangles': triangles,
            'surfaces': surfaces, 'vertices': vertex_count, 'materials': len(materials),
            'unique_colors': len(colors), 'nodes': names}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb', type=Path)
    parser.add_argument('--max-triangles', type=int)
    parser.add_argument('--require-node', action='append', default=[])
    args = parser.parse_args()
    print(json.dumps(verify(args.glb, args.max_triangles, args.require_node), ensure_ascii=False))
