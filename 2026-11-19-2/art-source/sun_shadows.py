"""Bake directional occluder height from the final Blender-built static scenery.
Projection is onto the ground along the shader's sun direction, for use at any receiver height.
Run Blender -b -P art-source/sun_shadows.py.
"""
from pathlib import Path
import struct
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT=Path(__file__).resolve().parents[1]/"Game/Assets/Resources/World"
WIDTH,HEIGHT=896,1792
EXTENT_X,EXTENT_Z=80,224
SUN=Vector((-.48,.88,-.36)).normalized()
DTYPE=np.dtype([("xyz","<f4",3),("normal","i1",3),("color","u1",3),("tag","u1"),("uv","<u2",2)])


def bake(region):
    names=["district"+str(region),"landmark"+str(region)]
    if region in (0,3):names.append("landmark"+str(region)+"Roof")
    for end in ("North","South"):
        names.extend(("approach"+str(region)+end,"approach"+str(region)+end+"Roof"))
    if region==2:names.append("stationRoof")
    plates=[]
    for name in names:
        data=(OUT/(name+".bytes")).read_bytes()
        count=struct.unpack_from("<I",data)[0]
        plates.append(np.frombuffer(data,offset=4,dtype=DTYPE,count=count)["xyz"])
    points=np.concatenate(plates)
    tree=BVHTree.FromPolygons(points.tolist(),np.arange(len(points)).reshape(-1,3).tolist(),all_triangles=True)
    out=np.zeros((HEIGHT,WIDTH),dtype="<u2")
    span=72/SUN.y
    start_x=-EXTENT_X*.5+.5*EXTENT_X/WIDTH+SUN.x*span
    start_z=-EXTENT_Z*.5+.5*EXTENT_Z/HEIGHT+SUN.z*span
    for iy,row in enumerate(out):
        z=start_z+iy*EXTENT_Z/HEIGHT
        for ix in range(WIDTH):
            hit,_,_,_=tree.ray_cast(Vector((start_x+ix*EXTENT_X/WIDTH,72,z)),-SUN,span+.8)
            if hit is not None:
                row[ix]=min(65535,max(0,round(hit.y*65535/64)))
    (OUT/("sun"+str(region)+".bytes")).write_bytes(out.tobytes())
    print("Sun occlusion:",region,len(points)//3,"triangles",np.count_nonzero(out),flush=True)


for region in range(4):
    bake(region)
