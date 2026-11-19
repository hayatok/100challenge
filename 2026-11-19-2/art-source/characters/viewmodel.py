"""MakeHuman-based viewmodel gloves. Contact poses are authored in streets.py."""
from functools import lru_cache
from math import sin, cos

from mathutils import Vector

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
    posed=[]
    for width,normal,length in points:
        thumb=width<-.047
        joint=.049 if thumb else .085-.14*abs(width)
        distal=max(0,length-joint)
        bend=distal*curl*(.74 if thumb else 1)
        reach=min(length,joint)+sin(bend)/curl
        wrap=(1-cos(bend))/curl
        posed.append(wrist+across*width+
                     forward*(reach-normal*sin(bend))+
                     palm*(wrap+normal*cos(bend)))
    for face in faces:
        width,normal,length=(sum(points[i][axis] for i in face)/3 for axis in range(3))
        if length<.012:
            color="333a34"
        elif normal<-.009 and .043<length<.111 and -.034<width<.024:
            color="555a4e"
        elif normal>.002 or length>.11:
            color="353d37"
        else:
            color="454e44"
        indices=face[::-1] if dominant else face
        batch.poly([posed[i] for i in indices],color)
