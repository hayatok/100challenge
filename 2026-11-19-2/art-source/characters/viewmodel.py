"""MakeHuman-based viewmodel gloves. Contact poses are authored in streets.py."""
from functools import lru_cache
from math import sin, cos, pi

from mathutils import Vector
from mathutils.bvhtree import BVHTree

from characters.bake import anatomy, reduced


SOURCE_WRIST=Vector((4.315,2.455,1.755))
SOURCE_REACH=Vector((.30,-.52,.80)).normalized()
SOURCE_WIDTH=Vector((0,1,0)).cross(SOURCE_REACH).normalized()
SOURCE_NORMAL=SOURCE_REACH.cross(SOURCE_WIDTH)


@lru_cache(maxsize=1)
def bind_glove():
    points,faces=reduced("viewmodel glove",lambda p:p.x>3.55 and
                         (p-SOURCE_WRIST).dot(SOURCE_REACH)>-.20,1750,anatomy())
    positions=[]
    for point in points:
        delta=point-SOURCE_WRIST
        positions.append((delta.dot(SOURCE_WIDTH)*.117,
                          delta.dot(SOURCE_NORMAL)*.112,
                          delta.dot(SOURCE_REACH)*.113))
    return positions,faces


def glove(batch,wrist,direction,palm,dominant,curl):
    forward=Vector(direction).normalized()
    palm=Vector(palm)
    palm=(palm-forward*palm.dot(forward)).normalized()
    across=forward.cross(palm)*(1 if dominant else -1)
    points,faces=bind_glove()
    wrist=Vector(wrist)
    def pose(width,normal,length):
        thumb=width<-.047
        joint=.049 if thumb else .085-.14*abs(width)
        distal=max(0,length-joint)
        bend=distal*curl*(.74 if thumb else 1)
        reach=min(length,joint)+sin(bend)/curl
        wrap=(1-cos(bend))/curl
        return (wrist+across*width+forward*(reach-normal*sin(bend))+
                palm*(wrap+normal*cos(bend)))

    posed=[pose(*point) for point in points]
    for face in faces:
        width,normal,length=(sum(points[i][axis] for i in face)/3 for axis in range(3))
        if length<.013:
            color="344444"
        else:
            color="6e5846"
        indices=face[::-1] if dominant else face
        batch.poly([posed[i] for i in indices],color,3*16)

    # Raised guards follow the back of the actual hand in each contact pose.
    surface=glove_surface()
    def back(x,z,lift):
        hit=surface.ray_cast(Vector((x,-.15,z)),Vector((0,1,0)))[0]
        return pose(x,hit.y-lift,z) if hit is not None else None
    def pad(x,z,rx,rz):
        perimeter=[(cos(i*pi/4)*rx,sin(i*pi/4)*rz) for i in range(8)]
        edge=[back(x+dx,z+dz,.001) for dx,dz in perimeter]
        face=[back(x+dx*.74,z+dz*.77,.0047) for dx,dz in perimeter]
        if any(p is None for p in edge+face): return
        batch.poly(face,"454840",16)
        for i in range(8):
            batch.poly([edge[i-1],edge[i],face[i],face[i-1]],"89735b",3*16)
    for x,z in ((-.030,.084),(-.012,.093),(.007,.094),(.026,.083)):
        pad(x,z,.008,.013)
    pad(-.006,.045,.021,.017)
    # Two oversewn rows join the finger-side panel to the wrist.
    for x in (-.024,.018):
        for step in range(6):
            z=.027+step*.007
            stitch=[back(x+dx,z+dz,.0016) for dx,dz in
                    ((-.0007,0),(.0007,.0002),(.0008,.004),(-.0006,.0038))]
            if all(p is not None for p in stitch):
                batch.poly(stitch,"ab9575",2*16)


@lru_cache(maxsize=1)
def glove_surface():
    positions,faces=bind_glove()
    return BVHTree.FromPolygons(positions,faces,all_triangles=True)
