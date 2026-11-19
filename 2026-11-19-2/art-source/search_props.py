"""Bake pocket radios, field records and the portable aid post for city searches."""
from pathlib import Path
import struct
import bpy

out=Path(__file__).resolve().parents[1]/"Game/Assets/Resources/World"
def box(x,y,z,w,h,d,color):
    start=len(vertices)
    vertices.extend((x+sx*w/2,z+sz*d/2,y+sy*h/2)
                    for sy in (-1,1) for sz in (-1,1) for sx in (-1,1))
    for idx in ((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)):
        faces.append(tuple(start+i for i in idx));styles.append(bytes.fromhex(color))

def bake(asset):
    mesh=bpy.data.meshes.new(asset);mesh.from_pydata(vertices,[],faces);mesh.update();mesh.calc_loop_triangles()
    with (out/(asset+".bytes")).open("wb") as target:
        target.write(struct.pack("<I",len(mesh.loop_triangles)*3))
        for tri in mesh.loop_triangles:
            n=tri.normal
            for v in tri.vertices:
                p=mesh.vertices[v].co
                target.write(struct.pack("<3f3b3BB2H",p.x,p.z,p.y,round(n.x*126),round(n.z*126),round(n.y*126),
                                         *styles[tri.polygon_index],0,0,0))
    bpy.data.meshes.remove(mesh)

for item in ("searchRecords","searchRadio","searchAid"):
    vertices=[];faces=[];styles=[]
    for x in (-.5,.5):
        for z in (-.27,.27):box(x,.43,z,.048,.86,.048,"727d75")
    box(0,.876,0,1.14,.072,.69,"74644f")
    if item=="searchAid":
        for x in (-.25,.27):
            box(x,1.07,0,.45,.32,.42,"d6d3b5")
            box(x,1.24,0,.46,.045,.43,"b0b5a4")
            for z in (-.217,.217):
                box(x,1.077,z,.075,.21,.01,"9b5242");box(x,1.077,z,.21,.074,.012,"9b5242")
    elif item=="searchRecords":
        for j in range(3):
            x=-.28+j*.22;z=-.05+j*.06;y=.927+j*.027
            box(x,y,z,.34,.026,.43,"ccc6aa");box(x,y+.019,z-.09,.24,.012,.043,"637672")
            for k in range(4):box(x,y+.020,z-.012+k*.038,.23-k*.014,.012,.009,"857e6c")
        box(.38,1.016,.1,.12,.20,.12,"455958")
    else:
        box(-.12,1.07,0,.58,.31,.28,"4c5852")
        box(-.12,1.23,0,.62,.032,.31,"768276")
        box(.09,1.45,.061,.019,.42,.019,"b3b7a1")
        box(-.20,1.10,-.145,.29,.085,.016,"b2a578")
        for j in range(4):box(-.21,1.02-j*.018,-.151,.25,.01,.011,"293736")
        box(.30,.935,-.035,.19,.035,.28,"d1cbb3")
    bake(item)

# Street event rigs keep the working part separate from the frame.
from math import sin, cos, pi
from mathutils import Vector

def face(points,color):
    start=len(vertices)
    vertices.extend((x,z,y) for x,y,z in points)
    faces.append(tuple(range(start,start+len(points))));styles.append(bytes.fromhex(color))

def pipe(a,b,r,color,n=12,end=None):
    a,b=Vector(a),Vector(b)
    axis=(b-a).normalized()
    tangent=axis.cross(Vector((0,1,0)) if abs(axis.y)<.8 else Vector((0,0,1))).normalized()
    other=axis.cross(tangent)
    rings=[]
    for center,radius in ((a,r),(b,end if end is not None else r)):
        rings.append([center+(tangent*cos(k*2*pi/n)+other*sin(k*2*pi/n))*radius for k in range(n)])
    face(rings[0],color);face(list(reversed(rings[1])),color)
    for k in range(n):face([rings[0][k],rings[0][k-1],rings[1][k-1],rings[1][k]],color)

ink="2a3639";safety="ce9e47";paint="52756c";steel="a1aaa1";lamp="fff1c6";rust="986b4e"
for model in ("Bell","Shutter","Lamp","Cart","Water","Points"):
    for moving in (False,True):
        vertices=[];faces=[];styles=[]
        if model=="Bell":
            if not moving:
                box(0,.09,0,.74,.18,.68,ink)
                pipe((0,.17,0),(0,2.55,0),.064,paint)
                box(0,1.12,0,.38,.52,.27,paint)
                for k in range(4):box(0,1.01+k*.057,-.142,.23,.02,.02,ink)
            else:
                for s in (-1,1):
                    pipe((s*.04,2.36,0),(s*.43,2.28,-.09),.095,steel,end=.29)
                    pipe((s*.43,2.28,-.09),(s*.445,2.278,-.094),.23,ink)
                box(0,2.57,0,.16,.10,.16,safety)
        if model=="Shutter":
            if not moving:
                for s in (-1,1):
                    box(s*1.23,1.53,0,.148,3.06,.26,paint)
                    box(s*1.23,.16,0,.29,.32,.39,steel)
                box(0,3.06,0,2.66,.37,.48,paint)
                box(1.38,1.26,0,.16,.31,.19,safety)
            else:
                for k in range(15):
                    box(0,.12+k*.17,0,2.33,.164,.095,"9aa89a" if k%2 else "919e94")
                    box(0,.05+k*.17,-.07,2.33,.034,.039,"64746c")
                box(0,.095,-.1,2.34,.095,.066,safety)
        if model=="Lamp":
            if not moving:
                for k in range(3):
                    x=.42*sin(2*pi*k/3);z=.42*cos(2*pi*k/3)
                    pipe((x,.03,z),(0,.81,0),.039,steel)
                pipe((0,.12,0),(0,2.05,0),.053,safety)
                box(0,.27,0,.45,.37,.32,ink)
            else:
                for side in (-1,1):
                    box(side*.25,2.10,0,.44,.31,.22,"c49951")
                    box(side*.25,2.10,-.122,.36,.22,.025,lamp)
                    for j in range(3):box(side*.25-.12+j*.12,2.10,-.143,.014,.23,.014,ink)
        if model=="Cart":
            if not moving:
                box(.23,.34,0,.61,.63,.4,paint)
                box(.23,.68,0,.65,.05,.45,steel)
                box(.23,.49,-.21,.31,.15,.028,lamp)
            else:
                box(0,.36,0,.93,.12,1.58,paint)
                box(0,.46,0,.82,.12,1.46,"a6926d")
                for x in (-.41,.41):
                    for z in (-.53,.53):
                        pipe((x-.073,.19,z),(x+.073,.19,z),.185,ink)
                        pipe((x-.078,.19,z),(x+.078,.19,z),.080,steel,n=8)
                    pipe((x,.40,-.69),(x,1.05,-.87),.036,steel)
                pipe((-.42,1.05,-.87),(.42,1.05,-.87),.045,ink)
        if model=="Water":
            if not moving:
                box(0,.1,0,1.17,.2,.87,ink)
                pipe((-.29,.53,0),(.23,.53,0),.31,paint,n=16)
                pipe((-.60,.13,-.24),(-.28,.50,-.12),.11,ink)
                pipe((.3,.47,0),(.53,.68,0),.12,paint)
                box(0,.87,.04,.46,.31,.27,steel)
                box(0,.87,-.107,.31,.19,.021,"4d6a68")
            else:
                pipe((.52,.66,0),(.52,.91,0),.045,rust)
                for k in range(8):
                    a=k*pi/4;b=(k+1)*pi/4
                    p=(.52+.21*cos(a),.92,.21*sin(a))
                    pipe(p,(.52+.21*cos(b),.92,.21*sin(b)),.026,rust,n=5)
                    if k%2==0:pipe((.52,.92,0),p,.020,rust,n=5)
        if model=="Points":
            if not moving:
                box(0,.1,0,1.05,.20,.77,ink)
                box(0,.34,0,.66,.40,.45,paint)
                pipe((-.35,.54,0),(.35,.54,0),.12,steel)
                box(0,1.08,.17,.085,1.38,.085,steel)
            else:
                pipe((0,.5,0),(.39,1.06,0),.048,ink)
                pipe((.38,1.04,0),(.49,1.19,0),.073,rust)
                box(0,1.64,.17,.69,.27,.10,safety)
                face([(-.25,1.62,.112),(.05,1.62,.112),(.05,1.56,.112),(.24,1.64,.112),(.05,1.73,.112),(.05,1.67,.112),(-.25,1.67,.112)],ink)
        bake("incident"+model+("Moving" if moving else "Base"))
