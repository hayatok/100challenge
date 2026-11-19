"""Bake the evacuation districts and articulated figures with Blender's mesh API.
Run blender -b -P streets.py from any directory. Coordinates below are game x, height, z.
"""
import bpy, math, random, struct
from pathlib import Path
from mathutils import Vector
from math import sin, cos, pi

OUT = Path(__file__).resolve().parents[1] / "Game/Assets/Resources/World"
OUT.mkdir(exist_ok=True, parents=True)
ASPH="454e50"; BLACK="263236"; INK="1b282c"; GRAY="657477"; STEEL="9aa5a0"
CREAM="ddd4b7"; YELLOW="e4af39"; RED="ad4a3c"; TEAL="367572"; GLASS="30505a"
LIGHT="fff0bc"; RUST="915b46"; WHITE="e0e4d7"; CONC="8c9186"; NAVY="33434f"

class Batch:
    def __init__(self):
        self.p=[]; self.faces=[]; self.styles=[]; self.uv=[]
    def poly(self, points,c,b=0,uv=None):
        offset=len(self.p)
        self.p.extend([(x,z,y) for x,y,z in points])
        self.faces.append(tuple(range(offset,offset+len(points))))
        if hasattr(self,"held_joint"): b=(b//16)*16+self.held_joint
        self.styles.append((c,b))
        self.uv.extend(uv if uv else [(0,0)]*len(points))
    def bake(self,name):
        mesh=bpy.data.meshes.new(name)
        mesh.from_pydata(self.p,[],self.faces)
        mesh.update()
        mesh.calc_loop_triangles()
        smooth={}
        if name.startswith("hands"):
            for face in mesh.polygons:
                for idx in face.vertices:
                    key=tuple(round(v,4) for v in mesh.vertices[idx].co)
                    smooth.setdefault(key,[]).append(face.normal.copy())
        with (OUT/(name+".bytes")).open("wb") as f:
            f.write(struct.pack("<I",len(mesh.loop_triangles)*3))
            for tri in mesh.loop_triangles:
                n=tri.normal; c,b=self.styles[tri.polygon_index]
                rgb=bytes.fromhex(c)
                for i in tri.vertices:
                    v=mesh.vertices[i].co
                    if smooth:
                        nearby=smooth[tuple(round(val,4) for val in v)]
                        n=sum((nn for nn in nearby if nn.dot(tri.normal)>.73),Vector((0,0,0))).normalized()
                    f.write(struct.pack("<3f3b3BB2H",v.x,v.z,v.y,
                        round(n.x*126),round(n.z*126),round(n.y*126),*rgb,b,
                        *[round(max(0,min(1,t))*65535) for t in self.uv[i]]))
        bpy.data.meshes.remove(mesh)

def box(x,y,z,w,h,d,c,b=0):
    a=[(x+sx*w/2,y+sy*h/2,z+sz*d/2) for sy in (-1,1) for sz in (-1,1) for sx in (-1,1)]
    for face in [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]:
        g.poly([a[i] for i in face],c,b)

def rings(x,z,levels,c,b=0,n=10):
    loops=[[(x+cos(2*pi*j/n)*rx,y,z+sin(2*pi*j/n)*rz+dz) for j in range(n)] for y,rx,rz,dz in levels]
    g.poly(loops[0],c,b);g.poly(loops[-1][::-1],c,b)
    for a,e in zip(loops,loops[1:]):
        for j in range(n):g.poly([a[j],e[j],e[j-1],a[j-1]],c,b)

def rod(p,q,r,c,b=0,n=6):
    p=Vector(p);q=Vector(q);v=(q-p).normalized()
    other=Vector((1,0,0)) if abs(v.x)<.85 else Vector((0,0,1))
    a=v.cross(other).normalized()*r;t=v.cross(a)
    o=[a*cos(2*pi*i/n)+t*sin(2*pi*i/n) for i in range(n)]
    for i in range(n):g.poly([p+o[i],q+o[i],q+o[i-1],p+o[i-1]],c,b)

def shade(c,f):
    return "".join("%02x"%int(max(0,min(255,int(c[i:i+2],16)*f))) for i in (0,2,4))

def stripes(x,z,along=1):
    for i in range(6):box(x+i*.68-1.7,.031,z,.34,.016,along*2.8,CREAM)
def wheel(x,y,z):
    rod((x-.13,y,z),(x+.13,y,z),.48,INK,n=12)
    rod((x-.141,y,z),(x+.141,y,z),.21,GRAY,n=10)
def vehicle(x,z,train=False):
    length=13 if train else 8.7
    box(x,.68,z,2.64,.54,length-.35,BLACK)
    box(x,1.76,z,2.94,1.86,length,"c9c9b4" if train else "aabcb1")
    box(x,1.39,z,2.98,.23,length+.02,RED if train else TEAL)
    box(x,2.76,z,2.92,.2,length-.09,STEEL)
    if train:
        for s in (-1,1):
            box(x+s*1.30,2.869,z,.28,.045,length-.12,RED)
            box(x+s*1.39,2.705,z,.205,.14,length-.10,RED)
        box(x,2.89,z,.51,.11,length-.28,"8e9894")
    box(x,2.94,z+.6,1.55,.26,2.1,GRAY)
    for s in (-1,1):
        for j in range(8 if train else 5):
            zz=z-length/2+.88+j*1.52
            box(x+s*1.479,2.13,zz,.04,.74,1.24,GLASS)
            box(x+s*1.506,2.42,zz,.012,.029,1.2,STEEL)
            if train:
                box(x+s*1.508,2.12,zz,.016,.64,1.14,"887e61")
                box(x+s*1.519,1.90,zz,.013,.18,1.14,"665f4d")
                box(x+s*1.52,2.365,zz,.016,.045,1.12,LIGHT)
                for handle in (-.30,.31):
                    rod((x+s*1.525,2.35,zz+handle),(x+s*1.525,2.23,zz+handle),.012,CREAM)
                    rod((x+s*1.525,2.23,zz+handle-.041),(x+s*1.525,2.23,zz+handle+.041),.012,CREAM)
                    rod((x+s*1.525,2.23,zz+handle+.041),(x+s*1.525,2.17,zz+handle),.009,CREAM)
                    rod((x+s*1.525,2.17,zz+handle),(x+s*1.525,2.23,zz+handle-.041),.009,CREAM)
        for dz in [-length*.32,length*.32]:wheel(x+s*1.33,.53,z+dz)
        for zz in (z-length*.24,z+length*.25):
            box(x+s*1.50,1.64,zz,.08,2.00,1.21,INK)
            box(x+s*1.55,1.71,zz,.035,1.57,.92,"726547")
            box(x+s*1.575,1.08,zz,.012,.43,.76,"8f7755")
            box(x+s*1.575,2.45,zz,.023,.10,1.03,LIGHT)
            if train and zz>z:
                panel(x+s*1.575,zz,1.68,1.18,1.93,0,-s,11,(.529,.256,.724,.805))
            for side in (-1,1):
                box(x+s*1.58,1.65,zz+side*.65,.06,1.96,.27,STEEL)
                box(x+s*1.62,2.01,zz+side*.65,.032,.68,.20,GLASS)
                rod((x+s*1.596,1.14,zz+side*.40),(x+s*1.596,2.37,zz+side*.40),.026,YELLOW)
            box(x+s*1.62,.67,zz,.33,.085,1.29,BLACK)
            box(x+s*1.79,.717,zz,.04,.025,1.27,YELLOW)
        box(x+s*.94,1.4,z-length/2-.02,.38,.19,.05,LIGHT)
    for s in (-1,1):
        box(x,2.13,z+s*(length/2+.012),2.4,.74,.046,GLASS)
        box(x,2.13,z+s*(length/2+.053),.058,.74,.024,STEEL)
        box(x,2.61,z+s*(length/2+.018),1.52,.21,.057,INK)
        for j in range(5):box(x-.48+j*.22,2.61,z+s*(length/2+.053),.13,.078,.022,YELLOW)
    for j in range(6):box(x,3.094,z+.05+j*.22,1.24,.037,.07,BLACK)

def lamp(x,z,s):
    box(x,.22,z,.54,.44,.53,CONC)
    rod((x,0,z),(x,5.7,z),.105,GRAY)
    rod((x,5.1,z),(x-s*1.4,5.62,z),.068,GRAY)
    box(x-s*.83,5.73,z,1.85,.105,.13,BLACK)
    box(x-s*1.6,5.67,z,.91,.13,.38,STEEL)
    box(x-s*1.6,5.59,z,.8,.023,.32,LIGHT)
def boards(x,z,s,r):
    box(x,1.55,z,.85,3.1,2.2,"b1ad98")
    for j in range(2):
        zz=z-.5+j
        box(x-s*.44,1.58,zz,.04,2.62,.87,["a9c8bc","c6a48b"][j])
        for k in range(5):
            box(x-s*.475,2.28-k*.18,zz,.03,.055,.59 if k%2 else .43,["5b7878","955d4f"][j])
def panel(x,z,y,width,height,dx,dz,tag,uv):
    # Draw an artwork panel along a façade. UVs address the source print without mirroring glyphs.
    a=(x-dx*width/2,y-height/2,z-dz*width/2);b=(x+dx*width/2,y-height/2,z+dz*width/2)
    c=(b[0],b[1]+height,b[2]);d=(a[0],a[1]+height,a[2])
    u1,v1,u2,v2=uv
    g.poly([a,b,c,d],"e0dbca",tag*16,[(u1,v1),(u2,v1),(u2,v2),(u1,v2)])
def roof_detail(x,h,z):
    box(x,h+.35,z,1.4,.7,2.1,STEEL)
    for j in range(5):box(x,h+.72,z-.72+j*.32,1.05,.028,.075,GRAY)

def market():
    for s in (-1,1):
        for j in range(9):
            z=-35+j*8.8; h=[6,8.4,5.5,7.2][(j+(s+1))%4];x=s*22.6
            wall=["b59e83","889997","a69887","b4ae95","89989c"][j%5]
            box(x,h*.5,z,6.4,h,8.4,wall)
            box(x,h+.1,z,6.65,.22,8.65,shade(wall,.8))
            roof_detail(x,h,z+1.1)
            for zz in (-2.75,-1.35,.05,1.45,2.85):
                box(x-s*3.21,h-1.42,z+zz,.06,1.48,1.09,GLASS)
                box(x-s*3.27,h-2.15,z+zz,.15,.10,1.21,STEEL)
            face=x-s*3.23;accent=[TEAL,RED,"c49c60","788879","768897"][j%5]
            for k in range(3):
                zz=z-2.52+k*2.52
                box(face,1.47,zz,.075,2.85,2.38,GLASS if j%3 else GRAY)
                if j%3==0:
                    for t in range(9):box(face-s*.06,.28+t*.27,zz,.039,.038,2.3,STEEL)
                else:
                    box(face-s*.06,1.45,zz,.05,2.75,.052,STEEL)
                    box(face-s*.07,.55,zz,.04,.79,2.28,shade(wall,.72))
            box(face-s*.17,3.94,z,.37,.79,8.12,accent)
            for bay in range(3):
                zz=z-2.61+bay*2.61
                style=(j+(1 if s>0 else 2)+(1 if bay==2 else 0))%4
                if bay==0:
                    panel(face-s*.14,zz,1.63,2.53,2.95,0,-s,10,(style*.25+.012,.081,style*.25+.187,.755))
                elif bay==1:
                    panel(face-s*.14,zz,1.63,2.53,2.95,0,-s,10,(style*.25+.062,.072,(style+1)*.25-.011,.75))
                else:
                    panel(face-s*.14,zz,1.63,2.53,2.95,0,-s,10,(style*.25+.009,.080,(style+1)*.25-.008,.77))
                for side in (-1,1):box(face-s*.181,1.65,zz+side*1.27,.15,3.04,.085,shade(wall,.68))
                box(face-s*.24,.13,zz,.48,.22,2.54,GRAY)
            aw=face-s*.82
            for k in range(12):
                zz=z-3.8+k*.69
                g.poly([(face,3.59,zz),(aw-s*.58,3.25,zz),(aw-s*.58,3.25,zz+.69),(face,3.59,zz+.69)],accent if k%2 else CREAM)
                box(aw-s*.58,3.18,zz+.345,.06,.16,.69,accent if k%2 else CREAM)
            for k in range(4):box(face-s*.385,3.98,z-2.1+k*1.38,.04,.22,.86,CREAM)
            if j%2==0: boards(face-s*.6,z+3.4,s,j)
        for z in (-29,-8,13,32):lamp(s*16.9,z,s)
    for z in (-28,25):
        for s in (-1,1):
            rod((s*17.9,0,z),(s*17.9,6.49,z),.11,TEAL)
            rod((s*17.9,5.30,z),(s*14.5,6.66,z),.08,TEAL)
        for y in (6.56,7.07):rod((-17.9,y,z),(17.9,y,z),.08,TEAL)
        for j in range(12):
            rod((-17.9+j*2.98,6.56,z),(-16.41+j*2.98,7.07,z),.042,TEAL)
            rod((-16.41+j*2.98,7.07,z),(-14.92+j*2.98,6.56,z),.042,TEAL)
        box(0,6.86,z,5.4,.95,.18,TEAL)
    for z in (-25,4,28):stripes(0,z)

    for z in range(-34,35,6):box(0,.027,z,.105,.015,2.75,CREAM)

def container(x,z,c):
    box(x,1.31,z,2.8,2.62,6.3,c)
    for s in (-1,1):
        for j in range(18):box(x+s*1.42,1.32,z-2.96+j*.35,.09,2.46,.075,shade(c,.85))
        for j in range(3):box(x+s*(.42+j*.36),1.34,z-3.17,.045,2.42,.05,STEEL)
    box(x,2.65,z,2.9,.12,6.4,shade(c,1.13))
def warehouse():
    for s in (-1,1):
        for j in range(4):
            x=s*24.4;z=-29+j*18
            box(x,4.4,z,8,8.8,16.5,"919b92")
            for a in range(21):box(x-s*4.02,4.6,z-7.9+a*.78,.11,8.62,.09,GRAY)
            for dz in [-3.6,3.6]:
                box(x-s*4.15,2.25,z+dz,.22,4.5,5.8,NAVY)
                for k in range(12):box(x-s*4.30,.27+k*.32,z+dz,.06,.09,5.55,GRAY)
                box(x-s*4.36,4.9,z+dz,.35,.23,2.1,LIGHT)
            for dz in (-3.6,3.6):
                panel(x-s*4.37,z+dz,2.20,5.40,4.27,0,-s,11,(.008,.09,.242,.80))
            box(x,9,z,8.8,.55,17.4,GRAY);roof_detail(x,9.3,z+2)
            for dz in [-7.5,7.5]:box(x-s*4.16,2.6,z+dz,.4,5.2,.34,YELLOW)
        for z in [-21,7,33]:lamp(s*16.7,z,s)
    for j in range(4):container(-17.4,-26+j*14,[TEAL,RUST,NAVY,GRAY][j])
    for z in range(-28,34,6):
        box(8,.035,z,.19,.02,3,YELLOW);box(-8,.035,z,.19,.02,3,YELLOW)

def station():
    for s in (-1,1):
        for z in range(-36,39,8):
            x=s*17
            box(x,2.7,z,.44,5.4,.52,TEAL)
            box(x,.39,z,.61,.78,.68,CREAM)
            for dz in [-1.7,1.7]:rod((x,4.12,z),(x,5.55,z+dz),.11,TEAL)
            box(x,5.64,z,.34,.36,8.15,BLACK)
            box(x,5.91,z,1.2 if s>0 else 2.15,.21,8.05,"8a9a94")
            box(x,5.44,z,1.72,.07,.25,LIGHT)
        for z in range(-36,39,3):
            stripeX=12.52 if s>0 else -14.9
            box(stripeX,.032,z,.58,.025,2.96,YELLOW)
            for dz in [-.9,0,.9]:box(stripeX,.052,z+dz,.43,.014,.05,"b68a36")

    for z in (-28,-9,10,29):
        box(-19.5,2.1,z,4.2,4.2,12.2,CONC)
        for dz in (-4,0,4):box(-17.37,2.05,z+dz,.1,2.35,3.0,GLASS)
        panel(-17.28,z,2.11,7.0,3.42,0,1,11,(.263,.10,.487,.86))
        boards(-16.75,z+4.8,-1,0)
    for x in [-11,-8]:
        box(x,1.7,20,.24,3.4,2.5,YELLOW)
        box(x,3.44,20,.3,.17,2.58,BLACK)
    box(-9.5,3.45,20,3.3,.22,.32,YELLOW)
def yard():
    for s in (-1,1):
        for z in range(-36,39,4):
            x=s*20.5
            rod((x,0,z),(x,1.75,z),.057,STEEL)
            for yy in (.52,1.38):rod((x,yy,z),(x,yy,z+4),.036,GRAY)
        for z in [-28,-4,20]:lamp(s*16.8,z,s)
    g.poly([(-48,.026,-46),(-19.7,.026,-46),(-19.7,.026,46),(-48,.026,46)],"466d70",14*16)
    box(-19.55,.08,0,.34,.16,89,CONC)
    for j in range(68):
        x=random.uniform(-34,-23);z=random.uniform(-42,42)
        box(x,.003,z,random.uniform(.3,1.8),.017,.06,"779794")
    for z in [-29,-12,5,22]:
        vehicle(18,z,True)
        if z in (-29,22):container(-21.9,z,["566e67","8b694f"][int(z)%2])
    for z in (-24,-7,10,27):
        box(25.7,2.63,z,5.2,5.26,12.2,"86928a")
        panel(23.08,z,2.64,11.85,4.84,0,-1,11,(.762,.08,.99,.84))
    for z in (-23,0,23):
        for x in (-20,20):
            rod((x,0,z),(x,9,z),.21,GRAY)
        rod((-20,9,z),(20,9,z),.16,GRAY)
        for j in range(10):
            rod((-20+4*j,9,z),(-18+4*j,9.9,z),.065,GRAY)
            rod((-18+4*j,9.9,z),(-16+4*j,9,z),.065,GRAY)
        rod((-20,9.9,z),(20,9.9,z),.09,GRAY)

def pavement(d):
    box(0,-.32,0,150,.6,146,["656664","596164","737a74","616963"][d])
    for i in range(26):
        x=random.uniform(-16,16);z=random.uniform(-34,34)
        rx=random.uniform(.15,1.25);rz=random.uniform(.25,2.1)
        g.poly([(x+cos(k*pi/5)*rx*random.uniform(.7,1.1),.003,z+sin(k*pi/5)*rz*random.uniform(.8,1.2)) for k in range(10)],["515f60","606b69","626c6a"][i%3])
    for x in (-15.6,15.6):
        box(x,.012,0,.11,.025,80,CREAM)
        for z in range(-35,36,7):
            box(x,.03,z,.42,.02,1.1,BLACK)
            for j in range(6):box(x,.045,z-.45+j*.18,.38,.015,.044,GRAY)
    if d==2:
        for z in range(-35,36,4):box(0,.009,z,30,.012,.021,"7b8179")
        for x in range(-15,16,4):box(x,.01,0,.019,.012,78,"7b8179")
    for s in (-1,1):
        for j in range(9):
            h=random.uniform(8,17);x=s*random.uniform(34,51);z=-42+j*10
            width=random.uniform(6,12)
            skyline(x,z,width,9,h,j)
        for j in range(6):
            x=-33+j*13;z=s*51;h=random.uniform(7,16)
            skyline(x,z,9,7,h,j+3)

def skyline(x,z,w,d,h,j):
    wall=["91968e","969991","9f9d90","8e9997","9c958b"][j%5]
    box(x,h/2,z,w,h,d,wall)
    box(x,h+.10,z,w+.23,.20,d+.23,shade(wall,.81))
    box(x+w*.19,h+.62,z,2.15,1.19,1.84,shade(wall,.87))
    if j%3==0:
        rod((x,h,z),(x,h+3.5,z),.077,GRAY)
        for i in range(3):rod((x-.71,h+3.0-i*.33,z),(x+.71,h+3.0-i*.33,z),.035,GRAY)
    if j%3==1:
        rings(x,z,[(h+.45,.63,.63,0),(h+1.7,.63,.63,0),(h+1.94,.39,.39,0)],"797f73")
    for y in range(2,int(h),3):
        if y+1.0>h: continue
        for s in (-1,1):
            for off in (-.29,0,.29):
                xx=x+off*w;zz=z+s*(d*.5+.035)
                box(xx,y,zz,1.65,1.15,.08,"4e6267")
                box(xx,y-.61,zz,1.85,.11,.30,shade(wall,.83))
                box(xx,y,zz+s*.054,.065,1.14,.03,STEEL)
                if (j+y)%3==0:box(xx,y-.29,zz+s*.095,1.65,.43,.04,"7e8b87")
                sx=x+s*(w*.5+.03);sz=z+off*d
                box(sx,y,sz,.08,1.15,1.55,"536668")
                box(sx,y-.61,sz,.23,.11,1.74,shade(wall,.78))

def market_details():
    for s in (-1,1):
        for j in range(9):
            z=-35+j*8.8; x=s*19.15;h=[6,8.4,5.5,7.2][(j+(s+1))%4]
            for dz in (-2.6,2.75):
                box(x-s*.06,h-1.51,z+dz,.25,1.07,.96,"9ba297")
                for k in range(5):box(x-s*.205,h-1.85+k*.15,z+dz,.04,.054,.76,GRAY)
            for dz in (-3.98,):
                rod((x-s*.05,.3,z+dz),(x-s*.05,h-.28,z+dz),.065,shade(CONC,.74))
                for y in (1.6,3.4,5.0):box(x-s*.05,y,z+dz,.20,.07,.19,STEEL)
            if j%2==0:
                for z2 in (-2.7,0,2.7):
                    xx=s*17.68;zz=z+z2
                    box(xx,.38,zz,1.08,.74,1.60,"82674d")
                    for k in range(4):box(xx-s*.55,.16+k*.16,zz,.055,.082,1.53,"9b8261")
                    for dz in (-.73,.73):box(xx-s*.57,.4,zz+dz,.07,.71,.085,"715c49")
                    for n in range(9):
                        rx=xx+random.uniform(-.3,.3);rz=zz+random.uniform(-.62,.62)
                        rings(rx,rz,[(.75,.064,.067,0),(.82,.105,.10,0),(.89,.065,.064,0)],
                              ["bc7741","b29c52","687443","9f5546"][(j+n)%4],n=6)
            else:
                xx=s*17.91
                box(xx,.89,z,1.01,1.78,.72,"a65249")
                box(xx-s*.521,1.09,z,.047,1.14,.59,"738a89")
                for ky in range(3):
                    box(xx-s*.56,.79+ky*.29,z,.045,.035,.55,CREAM)
                    for kz in range(3):box(xx-s*.57,.91+ky*.29,z-.18+kz*.18,.05,.15,.065,
                                         [RED,YELLOW,TEAL][(kz+ky)%3])
                box(xx-s*.537,.31,z,.038,.20,.38,BLACK)
            x=s*17.22; zz=z+3.85
            box(x,2.41,zz,.11,1.22,.75,["a95745","567c73","b79b64"][j%3])
            rod((s*18.94,3.11,zz),(x,3.11,zz),.05,GRAY)
        for z in range(-36,36,3):
            box(s*17.32,.035,z,3.37,.07,2.97,"85887b")
            box(s*15.67,.077,z,.16,.12,2.96,CONC)

def road_furniture(d):
    sites=[((-7.8,-24),(8.2,22)),((-8.2,24),(6.8,-23)),((-5.6,-22),(6.7,21)),((-7,24),(7.6,-24))][d]
    for j,(x,z) in enumerate(sites):
        if d==0 or d==2:
            # A luggage dolly with a telescoping handle and rubber wheels.
            for dx in (-.49,.49):
                for dz in (-.72,.72):
                    rod((x+dx-.07,.15,z+dz),(x+dx+.07,.15,z+dz),.15,BLACK,n=10)
                rod((x+dx,.28,z+.76),(x+dx,1.36,z+.96),.037,STEEL)
            rod((x-.49,1.36,z+.96),(x+.49,1.36,z+.96),.043,BLACK)
            box(x,.30,z,1.18,.18,1.83,["607978","8a775a"][j])
            box(x-.17,.69,z-.15,.61,.68,.94,["65554b","645662"][j])
            for dz in (-.48,.18):box(x-.17,.70,z+dz,.625,.70,.06,BLACK)
            box(x+.31,.66,z+.22,.30,.63,.85,TEAL)
            for k in range(5):box(x+.47,.69,z-.08+k*.15,.03,.48,.035,GRAY)
        else:
            box(x,.15,z,1.4,.16,1.85,"827258")
            for k in range(3):box(x-.52+k*.52,.07,z,.23,.14,1.9,"705d45")
            for dx in (-.32,.32):
                for dz in (-.41,.41):box(x+dx,.59,z+dz,.62,.75,.77,["98774e","907a59"][(j+int(dx>0))%2])
                box(x+dx,.97,z,.11,.033,1.62,BLACK)
            box(x,.98,z,1.32,.044,.065,BLACK)
        for n in range(2):
            xx=x+1.0+n*.55; zz=z+.72
            box(xx,.043,zz,.27,.086,.27,BLACK)
            rings(xx,zz,[(.08,.125,.125,0),(.42,.044,.044,0)],RED,n=8)
            rings(xx,zz,[(.22,.093,.093,0),(.29,.076,.076,0)],CREAM,n=8)
    for z in range(-31,35,11):
        x=(-1 if z%2 else 1)*(4.8+abs(z)%5)
        rings(x,z,[(.032,.49,.49,0),(.044,.48,.48,0)],"424d4b",n=16)
        for k in range(5):
            w=.59 if k in (0,4) else .78
            box(x,.051,z-.25+k*.12,w,.012,.028,GRAY)
    if d!=2:
        for side in (-1,1):
            for k in range(8):
                x=side*(9.1+(k%2)*2.5);z=-30+k*8.3
                box(x,.028,z,1.3,.012,.083,shade(CREAM,.78))
                box(x+side*.61,.028,z+.63,.083,.012,1.34,shade(CREAM,.78))

def tapered(p,q,levels,c,n=10,b=0):
    p=Vector(p);q=Vector(q);axis=(q-p).normalized()
    a=axis.cross(Vector((0,1,0))).normalized();t=axis.cross(a)
    loops=[]
    for factor,w,h in levels:
        center=p+(q-p)*factor
        loops.append([center+a*cos(j*2*pi/n)*w+t*sin(j*2*pi/n)*h for j in range(n)])
    for u,v in zip(loops,loops[1:]):
        for j in range(n):g.poly([u[j],v[j],v[j-1],u[j-1]],c,b)
    g.poly(loops[0],c,b);g.poly(loops[-1],c,b)
def alloy(x,y,start,end,w,h,bevel,col):
    shape=[(-w+bevel,-h),(-w,-h+bevel),(-w,h-bevel),(-w+bevel,h),
           (w-bevel,h),(w,h-bevel),(w,-h+bevel),(w-bevel,-h)]
    a=[(x+u,y+v,start) for u,v in shape];b=[(x+u,y+v,end) for u,v in shape]
    g.poly(a,col,13*16);g.poly(b,col,13*16)
    for j in range(8):g.poly([a[j],b[j],b[j-1],a[j-1]],col,13*16)
def hands():
    for s in (-1,1):
        g.held_joint=11 if s<0 else 12
        x=.139 if s>0 else .045;z=.314 if s>0 else .536
        p=(s*.32,-.39,-.008);q=(x,-.166,z)
        tapered(p,q,[(0,.098,.094),(.19,.094,.090),(.43,.078,.075),(.51,.083,.079),
                     (.76,.064,.061),(.81,.069,.068),(.95,.056,.053),(1,.052,.05)],"46514a",14)
        tapered(p,q,[(.87,.063,.058),(.91,.065,.060),(.95,.059,.056)],"303c37",14)
        tapered(p,q,[(.56,.081,.077),(.58,.079,.075)],"71785c",14)
        end=(x-.016*s,-.116,z+.06)
        tapered(q,end,[(0,.052,.051),(.25,.056,.05),(.7,.051,.046),(1,.044,.037)],"3a403a",12)
        for j in range(4):
            xx=x+(j-1.5)*.018
            finger=(xx,-.105,z+.06); tip=(xx-.016*s,-.088,z+.089-j*.005)
            rod(finger,tip,.011,"81745f",n=8)
            rod(tip,(tip[0]-.012*s,tip[1]-.011,tip[2]+.011),.010,"393d35",n=8)
        rod((x-.042*s,-.122,z+.025),(x-.079*s,-.105,z+.073),.017,"5e6051",n=9)
    g.held_joint=0
    alloy(.122,-.118,.16,.36,.047,.042,.018,"363c39")
    alloy(.122,-.109,.295,.544,.047,.055,.010,"4a514b")
    alloy(.122,-.107,.49,.674,.039,.039,.011,"505a52")
    for j in range(7):
        alloy(.122,-.065,.35+j*.035,.36+j*.035,.039,.010,.004,"313936")
    for s in (-1,1):
        for j in range(4):
            box(.122+s*.042,-.097,.516+j*.038,.005,.016,.021,"2d3533")
        for z in (.34,.46):
            rod((.122+s*.047,-.114,z),(.122+s*.052,-.114,z),.0078,STEEL,n=8)
    for j in range(4):
        rod((.08,-.128,.23+j*.025),(.155,-.128,.23+j*.025),.005,"555e52",n=6)
    alloy(.122,-.112,.664,.738,.024,.025,.008,BLACK)
    rod((.122,-.111,.73),(.122,-.111,.793),.017,"515851",n=12)
    rod((.122,-.111,.773),(.122,-.111,.805),.020,"363d37",n=12)
    g.held_joint=14
    box(.122,-.196,.383,.059,.12,.061,"333b39")
    for jj in range(4):box(.122,-.16-jj*.023,.383,.062,.006,.065,BLACK)
    g.held_joint=0
    for side in (-1,1):
        xx=.122+side*.048
        for j in range(5):
            z=.204+j*.021
            g.poly([(xx,-.129,z),(xx,-.113,z+.015),(xx,-.102,z+.010),(xx,-.118,z-.004)],"646c62")
        box(.122+side*.048,-.112,.392,.006,.025,.079,"758277")
        for j in range(3):box(.122+side*.052,-.111,.367+j*.019,.005,.009,.009,"c3baa0")
    alloy(.122,-.113,.128,.177,.052,.047,.021,"545e55")
    for delta in (-.022,.022):
        rod((.122+delta,-.153,.185),(.122+delta,-.153,.246),.004,STEEL)
    # A thin chamfered optic housing leaves the sight picture open.
    center=(.122,-.007); outer=[(-.030,-.030),(-.035,-.019),(-.034,.012),(-.020,.028),
                                (.019,.028),(.034,.012),(.035,-.019),(.030,-.030)]
    for j in range(8):
        a=outer[j];b=outer[j-1]
        aa=(a[0]*.78,a[1]*.75);bb=(b[0]*.78,b[1]*.75)
        def pp(pair,z):return (center[0]+pair[0],center[1]+pair[1],z)
        g.poly([pp(a,.388),pp(b,.388),pp(bb,.388),pp(aa,.388)],"657066")
        g.poly([pp(a,.388),pp(b,.388),pp(b,.445),pp(a,.445)],"404a45")
        g.poly([pp(aa,.388),pp(bb,.388),pp(bb,.445),pp(aa,.445)],"303a37")
    alloy(.122,-.042,.379,.453,.038,.012,.006,"657365")
    rod((.154,-.012,.413),(.170,-.012,.413),.013,"4d5850",n=12)
    rod((.168,-.012,.413),(.173,-.012,.413),.014,"758073",n=12)

g=Batch();hands();g.bake("hands")

g=Batch();vehicle(0,0);g.bake("bus")
g=Batch();vehicle(0,0,True);g.bake("train")
# Set type in Blender so the signs have the same horizon and lighting as the street.
# An installed Noto font can be supplied when rebuilding on another OS.
import os
font_path = os.environ.get("EVAC_SIGN_FONT", str(OUT.parent / "UI/NotoSansJP.ttf"))
font = bpy.data.fonts.load(font_path)
def sign(text,x,y,z,height,dx,dz,col=CREAM):
    curve=bpy.data.curves.new("Sign letters","FONT")
    curve.font=font;curve.body=text;curve.align_x="CENTER";curve.align_y="CENTER";curve.size=height
    curve.resolution_u=2
    obj=bpy.data.objects.new("Lettering",curve)
    bpy.context.scene.collection.objects.link(obj)
    mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    mesh.calc_loop_triangles()
    for tri in mesh.loop_triangles:
        points=[]
        for idx in tri.vertices:
            p=mesh.vertices[idx].co
            points.append((x+p.x*dx,y+p.y,z+p.x*dz))
        g.poly(points,col)
    bpy.data.meshes.remove(mesh);bpy.data.objects.remove(obj,do_unlink=True);bpy.data.curves.remove(curve)
def streetsigns(d):
    if d==0:
        for z in (-28,25):sign("商 店 街",0,6.87,z-.108,.79,1,0)
        names=["青 果","CAFE","書 店","薬 局","COFFEE","食 堂","生 花","文 具","茶 屋"]
        for s in (-1,1):
            for j in range(9):
                z=-35+j*8.8;face=s*18.91
                box(face,3.94,z,.10,.76,7.75,[TEAL,RED,"8a694d","596f62"][j%4])
                sign(names[(j+s)%9],face-s*.072,3.94,z,.73,0,-s)
    if d==1:
        for s in (-1,1):
            for j in range(4):
                z=-29+j*18
                box(s*20.09,6.1,z,.15,1.4,5.1,NAVY)
                sign("BAY  0"+str(j+1),s*19.99,6.1,z,1.02,0,-s)
    if d==2:
        for z in (-25,-1,25):
            x=-16.5
            box(x,3.3,z,.18,1.07,4.1,INK)
            sign("環 状 線",x+.11,3.34,z,.69,0,1)
            box(x+.1,2.85,z,.04,.10,4.08,TEAL)
        for z in (-30,-6,18,30):
            for x in (-16,16):
                box(x,4.1,z,2.1,.8,.12,NAVY)
                sign("2   /   3",x,4.1,z-.083,.57,1,0,LIGHT)
    if d==3:
        for z in (-23,0,23):
            box(0,8.55,z,5.2,.87,.15,TEAL)
            sign("DEPOT   /   04",0,8.56,z-.092,.61,1,0)
def stationprops():
    for x in (-11,-8):
        for z in (18.76,21.24):box(x,2.36,z,.20,4.72,.20,YELLOW)
        for y in (.26,1.35,2.7,4.4):box(x,y,20,.20,.19,2.64,YELLOW)
        for z in (19.34,20.65):
            box(x,2.07,z,.07,1.05,1.12,"657a78")
            box(x,.81,z,.10,.81,1.10,"526a67")
        box(x,4.65,20,.42,.32,2.87,"b79542")
    box(-9.5,4.65,18.76,3.27,.35,.27,YELLOW)
    box(-9.5,4.65,21.24,3.27,.35,.27,YELLOW)
    box(-9.5,4.87,20,3.39,.18,2.95,"a78c46")
    for x in (-10.22,-8.78):
        box(x,1.17,21.26,1.43,2.34,.11,"657a78")
        box(x,2.59,21.26,1.44,.17,.16,YELLOW)
    box(-8.19,1.35,18.62,.25,.50,.14,BLACK)
    box(-8.19,1.46,18.539,.14,.12,.032,"95bd9a")
    box(-9.5,.10,20,3.02,.20,2.59,STEEL)
    box(-9.5,3.56,18.73,3.07,.42,.2,BLACK)
    sign("LIFT    02",-9.5,3.56,18.608,.32,1,0,LIGHT)
    for j in range(10):
        box(-11.13,.4+j*.18,18.75,.04,.032,.18,RED if j>6 else CREAM)
    for z in (-20,0,19):
        for x in (-15.7,):
            for dz in (-1.1,1.1):
                rod((x,.06,z+dz),(x,.5,z+dz),.068,GRAY)
            for t in range(4):box(x+t*.12,.52,z,.104,.09,2.65,RUST)
            for t in range(3):box(x-.1,.72+t*.13,z,.09,.103,2.65,RUST)
    for z in (-32,31):
        for x in (-8,-5,-2,1,4,7):
            box(x,.57,z,.54,1.14,1.98,STEEL);box(x,1.16,z,.56,.12,1.99,TEAL)
            box(x,1.25,z-.7,.34,.08,.34,INK);box(x,1.298,z-.7,.20,.012,.16,"94d7bc")
def facilities(which):
    if which=="cache":
        for x,z,y in [(-.55,0,0),(.55,0,0),(-.48,0,.8)]:
            box(x,.12+y,z,1.07,.14,.83,RUST)
            box(x,.51+y,z,.99,.66,.77,"9a7850")
            for sx in (-.32,.32):box(x+sx,.51+y,z,.066,.68,.79,"5f5d4d")
            box(x,.5+y,z-.397,.29,.22,.015,CREAM)
    elif which=="works":
        box(0,.16,0,1.65,.32,1.09,BLACK);box(0,.82,0,1.46,1.16,.95,"b28b46")
        box(0,1.44,0,1.54,.12,1.01,STEEL)
        for j in range(9):box(.37,.44+j*.087,-.482,.51,.035,.03,BLACK)
        box(-.28,1.02,-.49,.55,.49,.04,GRAY)
        for j in range(3):
            box(-.47+j*.18,1.1,-.526,.095,.086,.035,["85b29e",YELLOW,RED][j])
        rod((-.61,1.49,.24),(-.61,1.91,.24),.065,BLACK)
    elif which=="depot":
        for x in (-1,1):
            for z in (-.65,.65):rod((x,0,z),(x,1.08,z),.053,GRAY)
        box(0,1.1,0,2.23,.11,1.49,"79664c")
        box(-.52,1.34,0,.74,.37,.52,"697b5d")
        box(.52,1.32,0,.67,.32,.49,CREAM)
        box(.52,1.49,0,.11,.025,.32,RED);box(.52,1.50,0,.34,.025,.10,RED)
    elif which=="tent":
        for x in (-1.38,1.38):
            for z in (-1.02,1.02):rod((x,0,z),(x,2.04,z),.052,STEEL)
            g.poly([(0,2.58,-1.25),(0,2.58,1.25),(x*1.1,2.04,1.25),(x*1.1,2.04,-1.25)],"768f76")
            box(x*1.1,1.97,0,.057,.16,2.5,"637b67")
    elif which=="workshop":
        box(0,.85,0,2.28,1.70,.65,"64766f")
        for j in range(5):box(0,.26+j*.27,-.339,2.03,.05,.047,STEEL)
        box(0,1.75,0,2.57,.12,.89,CREAM)
        box(-.71,2,0,.29,.38,.44,GRAY)
    elif which=="passenger":
        rings(0,0,[(0,.16,.12,0),(.29,.20,.14,0),(.40,.13,.085,0)],"566a67")
        rings(0,0,[(.37,.079,.079,0),(.46,.101,.10,0),(.57,.092,.086,0),(.60,.064,.06,0)],"b3997c")
    elif which=="threat":
        for x in (-1.38,1.38):
            box(x,.42,0,.28,.84,1.25,STEEL)
            box(x,1.04,0,.25,.42,1.06,RED)
            for dz in (-.3,.3):box(x,1.08,dz,.27,.16,.19,CREAM)
def cable(p,q,sag,r,c):
    last=Vector(p)
    for k in range(1,9):
        t=k/8
        curr=Vector(p).lerp(Vector(q),t)
        curr.y-=4*t*(1-t)*sag
        rod(last,curr,r,c,n=5)
        last=curr
def pylons(d):
    for s in (-1,1):
        if s>0 and d==2:continue
        for j,z in enumerate((-36,-15,6,27,48)):
            x=s*(17.6 if d==0 else 19.2)
            rod((x,0,z),(x,8.9,z),.126 if d==0 else .16,CONC,n=10)
            rod((x-1.1,8.19,z),(x+1.1,8.19,z),.058,BLACK)
            for dx in (-.84,0,.84):
                rod((x+dx,8.2,z),(x+dx,8.48,z),.065,STEEL)
                if j<4:cable((x+dx,8.49,z),(x+dx,8.49,z+21),.62,.022,BLACK)
            if j<4:cable((x,7.65,z),(x,7.65,z+21),1.02,.043,BLACK)
            if j%2==0:
                rings(x+.31,z,[(6.5,.23,.22,0),(7.18,.23,.22,0)],"7e8780",n=10)
                if d==0:cable((x,7.68,z),(-x,7.68,z+6),1.03,.025,BLACK)
def bridge(d,z):
    color=[TEAL,"6c786a","597b70","6b7970"][d]
    for x in (-21,-12,12,21):
        box(x,2.65,z,.57,5.3,2.5,CONC)
        box(x,5.21,z,1.19,.48,3.2,GRAY)
    box(0,5.63,z,48,.50,3.68,shade(color,.85))
    for s in (-1,1):
        zz=z+s*1.75
        for h in (5.83,7.65):box(0,h,zz,48,.20,.20,color)
        for i in range(16):
            a=-24+i*3
            rod((a,5.90,zz),(a+1.5,7.58,zz),.091,color)
            rod((a+1.5,7.58,zz),(a+3,5.90,zz),.091,color)
            box(a,6.74,zz,.11,1.84,.21,color)
    for i in range(6):box(-20+i*8,5.32,z,2.1,.1,.37,LIGHT)
    if d==2:
        box(0,7.88,z,48,.27,4.4,"798d83")
    for n in range(15):
        x=14+n*.34;y=5.19-n*.34
        box(x,y,z,1.25,.29,2.32,GRAY)
def bicycle(x,z,direction):
    for zz in (-.58,.58):
        for k in range(12):
            a=k*pi/6;b=(k+1)*pi/6
            p=(x,.43+.34*cos(a),z+direction*(zz+.34*sin(a)))
            q=(x,.43+.34*cos(b),z+direction*(zz+.34*sin(b)))
            rod(p,q,.031,BLACK)
            if k%2==0:rod((x,.43,z+direction*zz),p,.0085,STEEL,n=4)
    def line(p,q,r,col=TEAL):
        rod((x,p[0],z+direction*p[1]),(x,q[0],z+direction*q[1]),r,col)
    for p,q in [((.43,-.58),(.37,0)),((.43,-.58),(.84,-.18)),((.84,-.18),(.37,0)),
                ((.37,0),(.94,.44)),((.84,-.18),(.94,.44)),((.43,.58),(.94,.44))]:
        line(p,q,.030)
    line((.84,-.18),(.98,-.20),.025,STEEL);box(x,.99,z-.2*direction,.19,.066,.23,BLACK)
    line((.94,.44),(1.11,.40),.024,STEEL)
    rod((x-.20,1.10,z+.4*direction),(x+.20,1.10,z+.4*direction),.025,BLACK)
    for dx in (-.17,.17):
        box(x+dx,.965,z+.68*direction,.028,.21,.31,GRAY)
    box(x,.86,z+.68*direction,.37,.037,.32,GRAY)
def canopy_tree(x,z,scale):
    rod((x,0,z),(x,2.8*scale,z),.13*scale,"6b6353")
    for i in range(5):
        a=i*1.92;h=(2.65+.35*(i%3))*scale;r=(.82+.12*(i%2))*scale
        xx=x+cos(a)*scale*.64;zz=z+sin(a)*scale*.67
        rod((x,1.65*scale,z),(xx,h,zz),.07*scale,"625e4e")
        rings(xx,zz,[(h-r*.67,r*.64,r*.60,0),(h-r*.23,r,r*.89,0),(h+.27*r,r*.91,r,0),
                     (h+.70*r,r*.54,r*.48,0),(h+.81*r,r*.16,r*.14,0)],
              ["586b52","63755a","737d60","506550","69785b"][i],n=9)
def tracks(x,stop):
    box(x,.041,0,3.24,.071,79,"5e625c")
    for z in range(-38,39):
        box(x,.108,z,2.39,.128,.21,"625c50")
    for dx in (-.74,.74):
        box(x+dx,.20,0,.104,.14,79,"6b7069")
        box(x+dx,.281,0,.126,.029,79,STEEL)
    if stop:
        for dx in (-.83,.83):
            rod((x+dx,.27,36),(x+dx,1.05,37),.11,"9c7858")
            rod((x+dx,1.05,37),(x+dx,.27,38),.11,"9c7858")
        box(x,1.11,37,2.10,.25,.22,RED)
def riverside():
    for z in range(-35,38,6):
        for j in range(3):
            xx=-20.0-j*.15;zz=z+sin(j)*1.97
            for k in range(3):
                p=(xx+.12*k,.06,zz+.14*k);q=(xx-.19+.1*k,.6+.16*cos(k+z),zz+.08*k)
                rod(p,q,.017,"778365",n=4)
    for j in range(8):
        canopy_tree(-39+j%2,-35+j*10,1.15+(j%3)*.30)
    for x in (-20,20):
        box(x,1.6,31,.91,3.2,.85,"66736e")
        box(x,3.72,31,.67,1.24,.37,BLACK)
        rings(x,30.78,[(3.73,.20,.11,0),(4.0,.20,.11,0)],"9aad74",n=8)
def ranges(z,base,col):
    for i in range(18):
        x=-99+i*11
        h=lambda px:base+4.2*sin(px*.07)+2.9*sin(px*.18)+1.7*cos(px*.32)
        a=h(x);b=h(x+11)
        g.poly([(x,-1,z),(x+11,-1,z),(x+11,b,z),(x,a,z)],shade(col,.98+.026*sin(i*2.64)))
def alley_details(d):
    ranges(71,10,"899b8c");ranges(83,16,"94a39a")
    for j in range(7):
        x=-29+j*10;z=46+(j%3)*.8
        if j in (1,4):
            for k in range(3):
                y=2.3+k*2.4
                box(x,y,z,6.2,.18,1.48,GRAY)
                box(x,y+.54,z-.73,6.31,.72,.11,"7d877c")
                for n in range(6):box(x-2.70+n*1.08,y+1.10,z-.74,.054,.45,.05,STEEL)
            box(x,3.90,z+1.21,6.35,7.8,2.1,"9a9e91")
        elif j in (0,3,5):
            for n in range(3):canopy_tree(x+n*1.8,z+(n%2)*1.25,1.28+.28*(n%2))
    pylons(d)
    bridge(d,39 if d!=2 else 34.5)
    if d in (0,3):
        for s in (-1,1):
            for j,z in enumerate((-32,-21,-3,15,31)):
                x=s*(17.0 if d==0 else 19.45)
                if d==0 and j%2==0:bicycle(x,z,-s)
                else:canopy_tree(x,z,.84+j*.055)
    for s in (-1,1):
        for j in range(5):
            x=s*(28+j*3);z=35.9+j*1.76;h=6.12+.72*(j%3)
            box(x,h/2,z,3.5,h,3.4,["a69e8d","83918b","a8a18a"][j%3])
            for face in (-1,1):
                pts=[(x-1.96,h-.08,z+face*2),(x+1.96,h-.08,z+face*2),
                     (x+1.96,h+1.07,z),(x-1.96,h+1.07,z)]
                g.poly(pts,["686c64","795e53","657a77"][j%3])
            for dx in (-.84,.84):box(x+dx,h-1.4,z-1.72,.92,.96,.08,GLASS)

def tactile(x,z,length_x,length_z):
    box(x,.054,z,length_x,.055,length_z,"c99e46")
    if length_z>length_x:
        for dx in (-.12,0,.12):box(x+dx,.091,z,.035,.022,length_z,"dfb854")
    else:
        for dz in (-.12,0,.12):box(x,.091,z+dz,length_x,.022,.035,"dfb854")
def station_bench(x,z):
    for dz in (-1.06,1.06):
        box(x,.26,z+dz,.44,.5,.11,"485c59")
        box(x,.06,z+dz,.56,.12,.26,CONC)
    for k in range(4):
        box(x-.20+k*.13,.52,z,.115,.085,2.55,"a98460")
        box(x-.26,.68+k*.10,z,.082,.082,2.55,"927052")
    for dz in (-.42,.42):
        rod((x-.2,.77,z+dz),(x+.16,.77,z+dz),.033,GRAY)
        rod((x+.16,.77,z+dz),(x+.16,.54,z+dz),.030,GRAY)
def platform_detail():
    for x,z in ((-10.4,-20.8),(6.7,10.5),(-9.8,5)):station_bench(x,z)
    tactile(-4.1,3.4,.45,35)
    tactile(4.1,-14,16.7,.46)
    tactile(-6.65,17.4,5.4,.45)
    for z in range(-32,35,7):
        for row in (-.59,.59):
            box(11.55,.045,z+row,1.78,.018,.09,CREAM)
            box(10.69,.046,z+row*.76,.08,.02,.34,TEAL)
            # End-of-queue arrows point from the lane to the boarding sill.
            pts=[(12.28,.068,z+row-.19),(12.61,.068,z+row),(12.28,.068,z+row+.19)]
            g.poly(pts,"e8c66d")
        for i in range(3):
            box(10.01-i*.42,.047,z,.23,.022,.055,"9da99d")
    for z in (-26,-9,8,25):
        # Service recesses and wall-mounted station posters face the central hall.
        box(-16.72,1.65,z,.2,2.68,1.54,NAVY)
        panel(-16.60,z,1.7,1.37,2.31,0,1,11,(.431,.255,.478,.63))
    for z in (-16,1,18):
        for j in range(4):
            box(-15.1,1.62,z+j*.45,.18,3.24,.12,TEAL)
        box(-15.1,3.15,z+.65,.22,.25,1.59,TEAL)
def station_roof():
    # This ceiling is an FPS cutaway. Tactical view retains the platforms, lamps and traffic lanes.
    for z in range(-36,37,8):
        for x in (-12,-4,4,12):
            box(x,5.64,z,7.82,.17,7.93,["5c6965","64716a"][(z//8+x//8)%2])
            for offset in (-2.65,-.91,.91,2.65):
                box(x+offset,5.48,z,.105,.15,7.96,"455651")
        box(0,5.28,z,32.2,.34,.22,TEAL)
        box(0,5.02,z,32.4,.11,.52,"536a61")
        for xx in (-13,-5.2,2.7,10.5):
            rod((xx,5.07,z-.81),(xx,4.63,z-.81),.025,BLACK)
            rod((xx,5.07,z+.81),(xx,4.63,z+.81),.025,BLACK)
            box(xx,4.59,z,.43,.14,2.74,"667570")
            for dx in (-.095,.095):
                g.poly([(xx+dx-.035,4.50,z-1.27),(xx+dx+.035,4.50,z-1.27),
                        (xx+dx+.035,4.50,z+1.27),(xx+dx-.035,4.50,z+1.27)],"fff1c2",15*16)
        for xx in (-11.1,7.35):
            rod((xx,5.32,z-4),(xx,5.32,z+4),.12,"596760",n=8)
            rod((xx+.37,5.35,z-4),(xx+.37,5.35,z+4),.06,GRAY,n=8)
    for j,z in enumerate((-26,-12,3,19,32)):
        x=-3.8 if j%2 else 4.3
        for dx in (-1.48,1.48):rod((x+dx,5.52,z),(x+dx,3.94,z),.043,BLACK)
        box(x,3.87,z,4.90,1.04,.18,INK)
        box(x,3.40,z,4.91,.105,.22,TEAL)
        for s in (-1,1):
            zz=z+s*.12
            box(x-1.93,3.88,zz,.81,.79,.036,CREAM)
            sign("2",x-1.93,3.89,zz+s*.026,1.10,-s,0,NAVY)
            sign("PLATFORM",x+.01,3.68,zz+s*.025,.33,-s,0,LIGHT)
            sign("環 状 線",x+.01,4.03,zz+s*.027,.76,-s,0,CREAM)
            g.poly([(x+1.64,3.68,zz+s*.03),(x+2.16,3.90,zz+s*.03),(x+1.64,4.13,zz+s*.03)],YELLOW)
    for s in (-1,1):
        x=s*15.25
        for z in range(-32,38,8):
            # The angled beam meets the side wall above head height.
            rod((x,3.17,z),(x-s*2.05,5.23,z),.105,TEAL)
    g.bake("stationRoof")

def bake_street_light(district):
    # Store sky visibility on the walking surface for flags, awnings and buildings.
    # The R8 lighting data is sampled only on upward-facing street surfaces.
    from mathutils.bvhtree import BVHTree
    tree=BVHTree.FromPolygons(g.p,g.faces,all_triangles=False)
    rays=[(Vector((-.67,-.35,.70)).normalized(),33,.36),
          (Vector((-.77,-.30,.68)).normalized(),33,.12),
          (Vector((.65,.23,.74)).normalized(),4,.11),
          (Vector((-.13,.61,.78)).normalized(),4,.10)]
    width,height=192,320
    light=bytearray(width*height)
    for iy in range(height):
        z=(iy+.5)*80/height-40
        for ix in range(width):
            start=Vector(((ix+.5)*48/width-24,z,.09)); visibility=1.
            for direction,distance,strength in rays:
                hit=tree.ray_cast(start,direction,distance)
                if hit[0] is not None:
                    visibility-=strength*(1-.34*hit[3]/distance)
            light[iy*width+ix]=round(255*visibility)
    (OUT/("light%d.bytes"%district)).write_bytes(light)
for d,fn in enumerate((market,warehouse,station,yard)):
    random.seed(181+d);g=Batch();pavement(d);fn();streetsigns(d)
    alley_details(d);road_furniture(d)
    if d==0: market_details()
    if d==2: tracks(15.02,False)
    if d==3: tracks(18,True);riverside()
    if d==2: stationprops();platform_detail()
    bake_street_light(d);g.bake("district"+str(d))
for prop in ("depot","cache","works","tent","workshop","passenger","threat"):
    g=Batch(); facilities(prop);g.bake(prop)

g=Batch()
g.poly([(cos(k*pi/15)*(1+.06*sin(k*1.9)),.047,sin(k*pi/15)*(1+.11*cos(k))) for k in range(30)],"4e7275")
for k in range(28):
    x=.83*cos(k*.92)*sin(k*6.78);z=.84*sin(k*1.43)
    box(x,.05,z,.07+.046*cos(k),.003,.011,"8ca7a6")
g.bake("water")

g=Batch()
box(0,.09,0,2.95,.18,2.24,"676c62")
for x in (-1.35,1.35):
    for z in (-.98,.98):
        rod((x,0,z),(x,.84,z),.05,YELLOW)
for z in (-1.03,1.03):
    box(0,.61,z,2.76,.12,.065,YELLOW)
    for j in range(6):box(-1.08+j*.42,.61,z,.18,.124,.07,BLACK)
g.bake("foundation")

for cargo in (False,True):
    g=Batch()
    for s in (-1,1):
        # Reach to the upper arm on the casualty's near side. The other hand steadies the forearm.
        x=s*.205 if cargo else (.208 if s>0 else -.062)
        z=.38 if cargo else (.405 if s>0 else .26)
        y=-.16 if cargo else (-.073 if s>0 else -.219)
        elbow=(s*.34,-.39,.01);wrist=(x,y,z)
        tapered(elbow,wrist,[(0,.099,.093),(.16,.096,.091),(.44,.083,.076),(.52,.085,.079),
                            (.73,.069,.067),(.81,.072,.068),(.91,.058,.057),(1,.053,.050)],"46534a",15)
        tapered(elbow,wrist,[(.82,.071,.066),(.90,.065,.061),(.94,.060,.058)],"34433c",14)
        palm=(x-.012*s,y+.048,z+.060)
        tapered(wrist,palm,[(0,.049,.044),(.32,.054,.046),(.66,.053,.043),(1,.043,.035)],"353d37",12)
        for finger in range(4):
            xx=x+s*(finger-1.5)*.020
            knuckle=(xx,y+.042,z+.064)
            mid=(xx-.004*s,y+.069,z+.102-(finger%3)*.005)
            tip=(xx-.013*s,y+.066,z+.124-abs(1-finger)*.005)
            rod(knuckle,mid,.012,"9b8269",n=9)
            rod(mid,tip,.0105,"a88b70",n=9)
        rod((x-.036*s,y+.01,z+.031),(x-.072*s,y+.05,z+.072),.016,"7f705d",n=10)
    if cargo:
        box(0,-.17,.48,.38,.28,.24,"b18d60")
        for x in (-.12,.12):box(x,-.168,.48,.027,.29,.25,"626956")
        box(0,-.171,.352,.12,.07,.012,CREAM)
    g.bake("handsCargo" if cargo else "handsHelping")












for active in (False,True):
    g=Batch()
    rings(0,0,[(0,.12,.12,0),(.09,.13,.13,0),(.14,.09,.09,0)],BLACK,n=12)
    rings(0,0,[(.14,.075,.075,0),(.30,.091,.091,0),(.34,.048,.048,0)],
          "8ed9ac" if active else "aa5340",n=12)
    for y in (.175,.23,.28):rings(0,0,[(y,.091,.091,0),(y+.009,.091,.091,0)],"b4c3aa" if active else "8c6658",n=12)
    if active: rings(0,0,[(.255,.093,.093,0),(.277,.093,.093,0)],"fff0bf",15*16,n=12)
    g.bake("signalOn" if active else "signalOff")




g=Batch();station_roof()

def alarm_station(kind):
    # Common slim base leaves the adjacent service position clear for interaction.
    box(0,.055,0,.47,.11,.40,GRAY)
    for x in (-.16,.16):
        for z in (-.13,.13):rod((x,.10,z),(x,.135,z),.023,BLACK,n=6)
    h=(1.85,1.5,2.65,2.05)[kind]
    rod((0,.11,0),(0,h,0),.075,"52665f",n=10)
    if kind==0:
        box(0,1.43,0,.54,.79,.12,"8f7561")
        box(0,1.47,-.073,.43,.62,.041,CREAM)
        for side in (-1,1):
            face=side*.105
            tapered((0,1.60,face),(0,1.60,face+side*.10),[(0,.19,.19),(.48,.21,.21),(1,.16,.16)],RED,16)
            rod((.16,1.36,face),(.224,1.50,face),.025,"a58963")
            box(0,1.25,face,.16,.095,.048,RED)
    if kind==1:
        box(0,1.22,0,.62,.65,.29,"a98d51")
        box(0,1.27,-.16,.48,.45,.045,GRAY)
        box(-.12,1.33,-.193,.15,.085,.03,"afc5ad")
        for j in range(4):box(.13,1.23+j*.063,-.195,.132,.029,.028,INK)
        rod((-.10,1.14,-.18),(-.10,1.23,-.28),.038,BLACK)
        for side in (-1,1):
            tapered((side*.12,1.56,0),(side*.39,1.69,0),[(0,.056,.056),(.4,.08,.08),(1,.15,.15)],"787f70",10)
    if kind==2:
        box(0,1.37,0,.25,.42,.20,STEEL)
        for j in range(3):box(0,1.29+j*.065,-.109,.15,.031,.02,BLACK)
        rod((-.43,2.67,0),(.43,2.67,0),.057,GRAY)
        for s in (-1,1):
            base=Vector((s*.12,2.80,0));direction=Vector((s*.88,-.24,s*.39)).normalized()
            end=base+direction*.56
            tapered(base,end,[(0,.082,.080),(.4,.106,.1),(.75,.213,.17),(1,.30,.22)],"a6aca1",14)
            tapered(end,end+direction*.012,[(0,.254,.186),(1,.250,.183)],"3a4849",14)
            tapered(end+direction*.014,end+direction*.024,[(0,.105,.075),(1,.089,.056)],"6f7971",12)
    if kind==3:
        box(0,1.26,0,.29,.46,.20,"657369")
        for j in range(3):box(0,1.12+j*.13,-.11,.24,.057,.025,YELLOW)
        box(0,1.74,0,.66,.14,.24,BLACK)
        rings(0,0,[(1.81,.32,.27,0),(1.9,.29,.24,0),(2.02,.20,.17,0),
                   (2.09,.13,.11,0),(2.13,.055,.055,0)],"b28a51",n=16)
        rod((.31,1.71,-.035),(.37,1.97,-.035),.027,STEEL)
        rings(.37,-.035,[(1.94,.060,.057,0),(2.01,.066,.060,0),(2.03,.043,.045,0)],BLACK)
    anchor=[1.92,1.58,2.97,2.17][kind]
    box(0,anchor-.04,0,.22,.095,.22,BLACK)
for alarm_kind in range(4):
    g=Batch();alarm_station(alarm_kind);g.bake("alarm"+str(alarm_kind))
