"""Bake the explorable annexes north and south of the original evacuation streets.
Run with Blender in background. Coordinates are game x, height, z in metres.
The footprint file supplies both the walls in this bake and the navigation solids.
"""
import json
import math
import struct
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Game/Assets/Resources/World"
FONT = bpy.data.fonts.load(str(OUT.parent / "UI/NotoSansJP.ttf"))
WALLS = json.loads((OUT / "ApproachFootprints.json").read_text())["walls"]
DISTRICTS = [
    (("市場診療所", "荷捌き所"), ("市民会館", "郵便集配所"), "ad6c4c", "718c79"),
    (("税関詰所", "冷蔵庫受付"), ("計量室", "配車センター"), "617e84", "b58d52"),
    (("駅員室", "遺失物窓口"), ("信号扱所", "乗務員詰所"), "487b79", "956455"),
    (("車両検査所", "河川管理所"), ("整備工場", "救急待機所"), "61756c", "b58f58"),
]


class Mesh:
    def __init__(self, end):
        self.end = end
        self.verts, self.faces, self.styles = [], [], []

    def face(self, vertices, color, tag=0, uvs=None):
        start = len(self.verts)
        self.verts.extend((x, self.end*z, y) for x, y, z in vertices)
        order = list(range(len(vertices)))
        if self.end < 0:
            order.reverse()
        self.faces.append([start+i for i in order])
        self.styles.append((bytes.fromhex(color), tag, start, uvs))

    def box(self, x, y, z, w, h, d, color):
        points = [(x+a*w/2, y+b*h/2, z+c*d/2) for b in (-1,1) for c in (-1,1) for a in (-1,1)]
        for face in ((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)):
            self.face([points[i] for i in face], color)

    def pole(self, x, z, y, h, radius, color, count=12):
        ring = [(x+radius*math.cos(i*2*math.pi/count),z+radius*math.sin(i*2*math.pi/count)) for i in range(count)]
        for i,(a,b) in enumerate(ring):
            c,d = ring[i-1]
            self.face([(a,y,b),(a,y+h,b),(c,y+h,d),(c,y,d)],color)
        self.face([(a,y+h,b) for a,b in reversed(ring)],color)

    def print_sign(self, text, x, y, z, size, side, color):
        curve=bpy.data.curves.new("Lettering","FONT")
        curve.font=FONT
        curve.body=text
        curve.align_x="CENTER"
        curve.align_y="CENTER"
        curve.size=size
        curve.resolution_u=2
        obj=bpy.data.objects.new("Type",curve)
        bpy.context.collection.objects.link(obj)
        mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        mesh.calc_loop_triangles()
        for tri in mesh.loop_triangles:
            points=[mesh.vertices[j].co for j in tri.vertices]
            self.face([(x,y+p.y,z+side*self.end*p.x) for p in points],color)
        bpy.data.meshes.remove(mesh)
        bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.curves.remove(curve)

    def write(self,name):
        mesh=bpy.data.meshes.new(name)
        mesh.from_pydata(self.verts,[],self.faces)
        mesh.update()
        mesh.calc_loop_triangles()
        # Tag 8 is round display stock. Preserve a continuous highlight across
        # its authored contours; adjacent shelves keep their own hard normals.
        rounded = {}
        for poly in mesh.polygons:
            if self.styles[poly.index][1] != 8:
                continue
            for index in poly.vertices:
                key = tuple(round(v,5) for v in mesh.vertices[index].co)
                rounded[key] = rounded.get(key, Vector((0,0,0))) + poly.normal
        with (OUT/(name+".bytes")).open("wb") as stream:
            stream.write(struct.pack("<I",len(mesh.loop_triangles)*3))
            for tri in mesh.loop_triangles:
                rgb,tag,start,uvs=self.styles[tri.polygon_index]
                n=tri.normal
                for index in tri.vertices:
                    v=mesh.vertices[index].co
                    if tag==8:
                        n=rounded[tuple(round(vv,5) for vv in v)].normalized()
                    uv=(0,0) if uvs is None else uvs[index-start]
                    stream.write(struct.pack("<3f3b3BB2H",v.x,v.z,v.y,round(n.x*126),round(n.z*126),round(n.y*126),
                                             *rgb,tag*16,round(uv[0]*65535),round(uv[1]*65535)))
        bpy.data.meshes.remove(mesh)


def backstreet(g, district, accent):
    b=g.box
    # The centre street already has pavement up to its original backdrop.
    b(0,-.14,69,53,.26,57,"52595a")
    for x in (-15.6,15.6):
        b(x,-.028,69,13.8,.09,57,"a4a297")
    for z in range(44,94,6):
        b(-.9,.008,z,.12,.012,2.9,"cbb787")
    for z in (50,86):
        for x in range(-6,8,2):
            b(x,.012,z,.91,.014,2.4,"c5c4b2")
    for side in (-1,1):
        for i in range(5):
            z=46+i*10.3
            h=(6.1,9.8,7.5,5.9,8.5)[(i+district+(side+1)//2)%5]
            x=side*21.3
            wall=("ab9f8e","969c9c","adab91","8b9a97","aa968b")[(i+district)%5]
            b(x,h/2,z,7.8,h,9.9,wall)
            b(x,h+.09,z,8.05,.18,10.1,"626e6c")
            face=side*17.36
            for y in (2.1,4.5,6.9,9.0):
                if y+.8>h: break
                for dz in (-3.5,-1.2,1.1,3.4):
                    b(face, y, z+dz,.12,1.33,1.74,"3b5155")
                    b(face-side*.08,y-.55,z+dz,.15,.13,1.85,"bcb8a8")
                    b(face-side*.09,y+.01,z+dz,.04,.041,1.72,"bfbcab")
            b(face-side*.16,3.23,z,.4,.25,9.7,accent)
            for dz in (-3.9,3.9):
                g.pole(face-side*.11,z+dz,0,h,.066,"67756e",8)
            b(x+.9,h+.31,z-1,1.7,.6,2.25,"738485")
        for z in (47,73,89):
            g.pole(side*16.4,z,0,5.1,.085,"65756f")
            b(side*15.9,5.12,z,1.08,.13,.22,"535f60")
            b(side*15.5,5.07,z,.69,.14,.44,"e5d9ae")
    for w in WALLS:
        col="788072" if w["height"]<1 else "b7b29d"
        b(w["x"],w["height"]/2,w["z"],w["width"],w["height"],w["depth"],col)
    # Raised traffic island between the two reception halls.
    b(1.8,.9,69,2.50,.10,4.89,"8f9388")
    for z in (67.3,69,70.7):
        g.pole(1.8,z,.9,.79,.12,"b09a55",10)
        g.pole(1.8,z,1.39,.16,.124,"ece4bc",10)


def annex(g,roof,side,z,district,end,label,accent):
    b=g.box
    # Open street frontage, lit work area and a tactical-view roof cutaway.
    b(side*10.72,.055,z,7.82,.10,12.05,"aaa894")
    roof.box(side*10.6,3.92,z,8.8,.25,13.15,"667476")
    roof.box(side*10.6,4.075,z,8.65,.065,13,"889492")
    for zz in (z-5.4,z-2.7,z,z+2.7,z+5.4):
        roof.box(side*10.62,3.72,zz,8.35,.18,.16,"526260")
    for dz in (-3.7,3.7):
        roof.box(side*10.2,3.54,z+dz,2.1,.09,.38,"424b49")
        roof.box(side*10.2,3.475,z+dz,1.9,.05,.22,"fff0c2")
    b(side*6.72,3.42,z,.16,.68,12.15,accent)
    g.print_sign(label,side*6.625,3.43,z,.63,-side,"f0ead4")
    for dz in (-5.96,5.96):
        b(side*6.8,1.72,z+dz,.19,3.44,.19,"72817d")
        b(side*10.8,1.03,z+dz,7.54,.11,.05,accent)
    for dz in (-4.1,-1.2,1.7,4.55):
        b(side*14.31,2.13,z+dz,.085,1.1,1.53,"3c5151")
        b(side*14.25,1.59,z+dz,.13,.06,1.62,"dfd8c2")
    # The front and centre aisle stay clear for evacuees and assisted movement.
    b(side*13.88,.82,z+.5,.75,.10,5.9,"afa38b")
    for dz in (-1.65,.7,2.8):
        b(side*13.94,.4,z+dz,.53,.8,.24,"737d72")
    for dz in (-1.1,1.3):
        b(side*13.94,1.14,z+dz,.39,.48,.73,"495958")
        b(side*13.72,1.16,z+dz,.025,.36,.61,"819896")
    bay=(district + (end<0)+(side<0))%4
    # Wards have folding bunks, freight has stillages, stations have bench seats,
    # and vehicle control has a workbench, lockers, and a warning beacon.
    for zz in (z-4.65,z+4.65):
        if bay==0:
            for x in (11.1,12.8):
                for dz in (-.48,.48):g.pole(side*x,zz+dz,0,.64,.042,"85918a",8)
            b(side*11.95,.64,zz,2.2,.10,1.1,"67786e")
            b(side*11.95,.77,zz,2.04,.19,1.0,"bec2ac")
            b(side*12.62,.9,zz,.49,.12,.76,"d9d8c2")
        elif bay==1:
            for x in (11.0,13.0):
                for dz in (-.69,.69):b(side*x,.96,zz+dz,.10,1.92,.10,"788080")
            for y in (.12,.92,1.83):
                b(side*12,y,zz,2.12,.1,1.55,"806d4d")
                for dz in (-.34,.34):b(side*12,y+.22,zz+dz,1.15,.37,.58,"ab9371")
        elif bay==2:
            for x in (10.8,11.55,12.3,13.05):
                b(side*x,.52,zz,.67,.14,.74,accent)
                b(side*x,.85,zz+.36,.67,.64,.10,accent)
                b(side*x,.25,zz,.09,.5,.46,"697576")
        else:
            for x in (11.3,12.3,13.3):
                b(side*x,.95,zz,.91,1.9,.73,"81938a")
                b(side*x,1.07,zz-.378,.84,1.58,.032,"75877d")
                for y in (1.55,1.61,1.67):b(side*x,y,zz-.4,.49,.018,.02,"4a5854")
    b(side*14.32,1.95,z-.1,.06,1.0,1.45,"8e7959")
    for i in range(4):
        b(side*14.28,2.02-(i%2)*.28,z-.52+i*.25,.023,.32,.24,"e2d6b8")


def shuttle():
    g=Mesh(1)
    b=g.box
    # The civic minibus has a rounded cab and a lower step than the transit bus.
    sections=[(-2.67,.86,.72,1.29),(-2.57,1.00,.48,1.41),(-2.12,1.07,.44,1.44),
              (-1.66,1.09,.44,2.12),(-1.31,1.10,.44,2.23),(2.20,1.10,.44,2.23),
              (2.48,1.06,.48,2.12),(2.62,.92,.55,1.93)]
    loops=[]
    for z,w,base,top in sections:
        loops.append([(x,y,z) for x,y in ((-w+.08,base),(-w,base+.12),(-w,top-.14),(-w+.12,top),
                                           (w-.12,top),(w,top-.14),(w,base+.12),(w-.08,base))])
    g.face(loops[0],"d1cdb9")
    g.face(loops[-1][::-1],"d1cdb9")
    for j,(front,back) in enumerate(zip(loops,loops[1:])):
        for i in range(8):
            g.face([front[i],back[i],back[(i+1)%8],front[(i+1)%8]],
                   "35484b" if i==7 else "ded9c6" if i in (2,3,4) else "c1c7b8")
    g.face([(-.91,1.45,-2.10),(-.88,2.074,-1.67),(.88,2.074,-1.67),(.91,1.45,-2.10)],"365659")
    for side in (-1,1):
        for j in range(4):
            z=-1.07+j*.87
            b(side*1.101,1.73,z,.026,.64,.78,"344d50")
            b(side*1.12,1.95,z,.018,.028,.71,"9caaa2")
        b(side*1.107,1.08,.41,.030,.19,4.22,"387f80")
        b(side*1.13,1.25,.48,.014,.035,4.10,"cf9953")
        for z in (-1.68,1.60):
            for x,radius,color in ((side*.98,.46,"293134"),(side*1.15,.42,"343c3c"),(side*1.19,.241,"8d9995"),(side*1.206,.10,"546060")):
                p=[(x,.495+radius*math.sin(i*math.pi/12),z+radius*math.cos(i*math.pi/12)) for i in range(24)]
                g.face(p,color)
                q=[(a-side*.09,y,zz) for a,y,zz in p]
                for i in range(24):g.face([p[i-1],q[i-1],q[i],p[i]],color)
        b(side*.68,1.04,-2.64,.38,.17,.045,"f4e6be")
        b(side*.78,.95,2.63,.23,.33,.05,"a55744")
        b(side*1.19,1.62,-1.47,.21,.14,.23,"4a5551")
    b(0,.73,-2.66,1.70,.24,.07,"525c58")
    b(0,1.00,-2.695,.53,.18,.03,"e5dfbd")
    for i in range(6):b(-.34+i*.14,1.2,-2.63,.07,.095,.034,"505d57")
    b(0,1.65,2.623,1.75,.57,.04,"425a5a")
    b(.63,.64,2.665,.41,.17,.032,"d8d3b4")
    g.write("fieldShuttle")


if __name__=="__main__":
    shuttle()
    beacon=Mesh(1)
    beacon.pole(0,0,0,.055,.16,"384342")
    beacon.pole(0,0,.055,.13,.094,"55615a")
    beacon.pole(0,0,.185,.15,.071,"dcc58d")
    beacon.pole(0,0,.335,.048,.085,"4d5951")
    for x in (-.065,.065):
        beacon.box(x,.254,0,.012,.15,.045,"747d70")
    beacon.write("fieldLamp")
    for region,settings in enumerate(DISTRICTS):
        for end,word in ((1,"North"),(-1,"South")):
            labels=settings[0 if end>0 else 1]
            g=Mesh(end)
            roof=Mesh(end)
            backstreet(g,region,settings[2])
            for side,z,label,accent in zip((1,-1),(60,77),labels,settings[2:]):
                annex(g,roof,side,z,region,end,label,accent)
            name=f"approach{region}{word}"
            g.write(name)
            roof.write(name+"Roof")
