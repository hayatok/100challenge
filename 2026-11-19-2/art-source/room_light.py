"""Bake light visibility and contact shadows from the room meshes. Run in Blender's Python."""
import math
import struct
from pathlib import Path

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT = Path(__file__).resolve().parents[1] / "Game/Assets/Resources/World"
VERTEX = np.dtype([("p","<f4",3),("n","i1",3),("c","u1",3),("tag","u1"),("uv","<u2",2)])
WIDTH, HEIGHT = 256, 512
X_MIN, Z_MIN = -16., 89.
X_SPAN, Z_SPAN = 32., 64.


def geometry(region):
    pieces = []
    for suffix in ("", "Roof"):
        data = (OUT / f"roomWing{region}{suffix}.bytes").read_bytes()
        triangles = np.frombuffer(data, VERTEX, struct.unpack_from("<I",data)[0], 4).reshape(-1,3)
        # Floor markings, glazing and the luminous strip itself transmit light.
        triangles = triangles[~np.isin(triangles[:,0]["tag"], [5,6,7,10,15])]
        pieces.append(triangles["p"].reshape(-1,3))
    points = np.concatenate(pieces)
    return BVHTree.FromPolygons(points.tolist(),np.arange(len(points)).reshape(-1,3).tolist(),all_triangles=True)


def bake(region):
    tree = geometry(region)
    result = np.empty((HEIGHT,WIDTH,4),dtype="u1")
    lamp_y = (3.61,5.72,5.96,5.55)[region] - (.38 if region==0 else .67)
    hemisphere = []
    for index in range(10):
        up = .12 + .72 * (index+.5) / 10
        angle = index * 2.39996323
        radial = math.sqrt(1-up*up)
        hemisphere.append(Vector((math.cos(angle)*radial,up,math.sin(angle)*radial)))
    for zi in range(HEIGHT):
        z = Z_MIN+(zi+.5)*Z_SPAN/HEIGHT
        front = max(0,min(8,math.floor((z-94.68)/5.60)))
        for xi in range(WIDTH):
            x = X_MIN+(xi+.5)*X_SPAN/WIDTH
            # Four closest ceiling fixtures. Blend visibility across adjacent pools.
            axes = (-10.4,0.) if x<0 else (0.,10.4)
            for level, y in enumerate((.071,1.47)):
                origin = Vector((x,y,z))
                open_light = total = 0.
                for lamp_x in axes:
                    for row in (front,front+1):
                        target = Vector((lamp_x,lamp_y,94.68+5.60*row)) - origin
                        length = target.length
                        weight = (lamp_y-y)/max(length**3,.001)
                        total += weight
                        if tree.ray_cast(origin,target.normalized(),max(.01,length-.20))[0] is None:
                            open_light += weight
                occlusion = 0.
                for direction in hemisphere:
                    hit = tree.ray_cast(origin,direction,2.85)[3]
                    if hit is not None:
                        occlusion += (1-hit/2.85)**1.45
                result[zi,xi,level*2] = round(255*open_light/max(total,.00001))
                result[zi,xi,level*2+1] = round(255*(1-occlusion/len(hemisphere)))
    (OUT/f"roomLight{region}.bytes").write_bytes(result.tobytes())
    print(f"District {region}: {WIDTH}x{HEIGHT} light field, mean {result.mean(axis=(0,1))}",flush=True)


for district in range(4):
    bake(district)
