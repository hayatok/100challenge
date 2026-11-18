"""Build articulated evacuation characters in Blender. Run blender -b -P bake.py."""
import gzip
import math
import struct
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "Game/Assets/Resources/World"
TAU = math.tau
V = Vector


def anatomy():
    points, faces = [], []
    group = ""
    for line in gzip.open(HERE / "hm08.obj.gz", "rt"):
        words = line.split()
        if not words:
            continue
        if words[0] == "v":
            points.append(V(tuple(map(float, words[1:4]))))
        elif words[0] == "g":
            group = words[1]
        elif group == "body" and words[0] == "f":
            faces.append([int(word.split("/")[0])-1 for word in words[1:]])
    return points, faces


def reduced(part, select, triangles):
    chosen = [f for f in base_faces if all(select(base_points[i]) for i in f)]
    used = sorted({i for f in chosen for i in f})
    indices = {i: j for j, i in enumerate(used)}
    mesh = bpy.data.meshes.new(part)
    mesh.from_pydata([base_points[i] for i in used], [], [[indices[i] for i in f] for f in chosen])
    obj = bpy.data.objects.new(part, mesh)
    bpy.context.collection.objects.link(obj)
    mod = obj.modifiers.new("Preserve silhouette", "DECIMATE")
    mod.ratio = min(1, triangles / sum(len(f)-2 for f in chosen))
    final = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    final.calc_loop_triangles()
    result = ([v.co.copy() for v in final.vertices], [tuple(t.vertices) for t in final.loop_triangles])
    bpy.data.objects.remove(obj, do_unlink=True)
    return result


class Figure:
    def __init__(self):
        self.tris = []

    def surface(self, points, polygons, color, bone=0, uv=None, orient=None):
        mesh = bpy.data.meshes.new("tailoring")
        mesh.from_pydata(points, [], polygons)
        mesh.update()
        mesh.calc_loop_triangles()
        for tri in mesh.loop_triangles:
            rgb = color if isinstance(color, str) else color(tri)
            for i in tri.vertices:
                p = mesh.vertices[i].co
                n = mesh.vertices[i].normal.copy()
                if orient is not None and n.dot(p - orient) < 0:
                    n.negate()
                coords = uv(p, tri) if uv else None
                self.tris.append((p.copy(), n, rgb, bone + (192 if coords else 0), coords or (0, 0)))
        bpy.data.meshes.remove(mesh)

    def loft(self, sections, color, bone=0, count=12, ripple=0):
        # Tubular garment sections carry unequal radii, displaced seams and folds.
        verts, faces = [], []
        for k,(x,y,z,w,d) in enumerate(sections):
            for j in range(count):
                a = TAU*j/count
                fold = 1+ripple*(math.sin(a*5+k*.72)+.45*math.sin(a*3-k*.39))
                verts.append((x+w*math.cos(a)*fold,y,z+d*math.sin(a)*fold))
        for k in range(len(sections)-1):
            for j in range(count):
                a=k*count+j; b=k*count+(j+1)%count
                faces.append((a,a+count,b+count,b))
        faces += [tuple(range(count)), tuple(reversed(range(len(verts)-count,len(verts))))]
        if sections[0][1] > sections[-1][1]:
            faces = [f[::-1] for f in faces]
        self.surface(verts, faces, color, bone)

    def bead(self, center, dims, color, bone=0):
        x,y,z=center; w,h,d=dims
        sections=[]
        for t in (-.98,-.72,0,.72,.98):
            r=math.sqrt(1-t*t)
            sections.append((x,y+h*t,z,w*r,d*r))
        self.loft(sections,color,bone,10)

    def pocket(self,x,y,z,w,h,d,color,flap,bone=0):
        # An eight-sided sewn pouch with boxed corners and an overlapping flap.
        ring=[(-.8,-1),(.8,-1),(1,-.72),(1,.74),(.78,1),(-.78,1),(-1,.74),(-1,-.72)]
        verts=[]
        for depth,scale in ((0,.95),(d,.99),(d*1.15,.87)):
            verts.extend((x+u*w*scale,y+v*h*scale,z+depth) for u,v in ring)
        polys=[(k*8+j,k*8+(j+1)%8,(k+1)*8+(j+1)%8,(k+1)*8+j) for k in range(2) for j in range(8)]
        polys.append(tuple(range(16,24)))
        self.surface(verts,polys,color,bone,orient=V((x,y,z-d)))
        self.surface([(x-w*.96,y+h*.86,z+d),(x+w*.96,y+h*.86,z+d),
                      (x+w*.94,y+h*.28,z+d*1.24),(x,y+h*.11,z+d*1.26),
                      (x-w*.94,y+h*.28,z+d*1.24)],[(0,1,2,3,4)],flap,bone)

    def pack(self,name):
        with (OUT/(name+".bytes")).open("wb") as dest:
            dest.write(struct.pack("<I",len(self.tris)))
            for p,n,c,b,uv in self.tris:
                dest.write(struct.pack("<3f3b3BB2H",*p,*(round(t*126) for t in n),
                                       *bytes.fromhex(c),b,*(round(max(0,min(1,t))*65535) for t in uv)))
        print(name,len(self.tris)//3,"triangles")


def make(kind,var):
    g=Figure()
    soldier=kind==0; ill=kind==1
    coat=(["4c594b","385650","626253"] if soldier else
          ["635059","6b7676","777059","536478"] if ill else
          ["b88a65","5c7988","a86456","718262"])[var]
    trouser=["353d43","454541","414a52","51453e"][var]
    skin=(["c2997e","b48a6e","bb9276"] if soldier else
          ["a29786","94908c","97867b","a29786"] if ill else ["bc947d","b99982","bc947d","ba977f"])[var]
    dark="3a403e"; trim="747e72" if soldier else "7e776a"
    hair=["302e2b","292a29","686763","393633"][var]
    if ill and var==1: hair="282627"
    panel=([0,1,0] if soldier else [3,4,5,3] if ill else [0,2,1,2])[var]
    center=[82,253,426,82,253,426][panel]
    eyes=[101,100,104,357,355,357][panel]
    def headcoord(p):
        x,y,z=p
        return V((x*.104,1.50+(y-5.78)*.103,(z-.38)*.105+(.027 if ill else .006)))
    hverts=[headcoord(p) for p in head[0]]
    def head_uv(p,tri):
        source=[head[0][i] for i in tri.vertices]
        if sum(q.z for q in source)/3 < .38: return None
        x=p.x/.104; y=(p.y-1.5)/.103+5.78
        return ((center+x*53)/512,1-(eyes-(y-7.28)*101)/512)
    def head_color(t):
        x,y,z=sum((head[0][i] for i in t.vertices),V((0,0,0)))/3
        return hair if z<.42 and y>6.60 else skin
    g.surface(hverts,head[1],head_color,uv=head_uv)
    # The underlying head supplies eye sockets and eyelids. The printed eyes
    # continue over small ocular surfaces using the same frontal projection.
    for side in (-1,1):
        ox=.308*side; oy=7.29; oz=1.244
        points=[]; polys=[]
        for y in range(7):
            lat=math.pi*(y+.02)/6.04-math.pi/2
            for j in range(12):
                a=j*TAU/12
                points.append(headcoord((ox+.151*math.cos(lat)*math.cos(a),oy+.130*math.sin(lat),oz+.145*math.cos(lat)*math.sin(a))))
        for y in range(6):
            for j in range(12):
                a=y*12+j;b=y*12+(j+1)%12;polys.append((a,a+12,b+12,b))
        g.surface(points,polys,skin,uv=lambda p,t:((center+p.x/.104*53)/512,1-(eyes-((p.y-1.5)/.103+5.78-7.28)*101)/512))
    # Follow the actual asymmetrical skull so hair never floats above the brow.
    cap=[]; capfaces=[]
    skull=BVHTree.FromPolygons(hverts,head[1])
    origin=headcoord((0,7.38,.47))
    for k in range(8):
        for j in range(36):
            a=j*TAU/36
            front=math.sin(a)
            edge=-.34+.64*front+.25*max(0,front)**2+.05*math.sin(3*a+var)
            edge-=.22*math.exp(-((front-.26)/.14)**2)
            elevation=edge+(1.569-edge)*k/7
            ray=V((math.cos(a)*math.cos(elevation),math.sin(elevation),front*math.cos(elevation)))
            hit,normal,_,_=skull.ray_cast(origin,ray)
            cap.append((hit if hit is not None else origin+ray*.102)+ray*(.0025+.004*k/7+
                       .0017*math.sin(8*a+k*.7)))
    for k in range(7):
        for j in range(36):
            a=k*36+j;b=k*36+(j+1)%36
            capfaces.append((a,a+36,b+36,b))
    def hair_uv(p,t):
        q=p-origin
        a=math.atan2(q.z,q.x)
        front=max(0,math.sin(a))
        # The chart's crown supplies real hair direction and tonal breakup.
        u=center+max(-1,min(1,p.x/.105))*(18+11*front)
        v=eyes-91+min(24,max(0,1.78-p.y)*185)*front+4*math.sin(a)
        return u/512,1-v/512
    g.surface(cap,capfaces,hair,uv=hair_uv)
    width=1.10 if ill and var==2 else (.93 if var==1 and not soldier else 1)
    hem=.80 if (not soldier and var in (1,3)) else .91
    torso=[(hem,.204,.148,-.002),(.94,.198,.144,-.009),(1.015,.174,.133,-.008),
           (1.055,.164,.125,-.01),(1.12,.153,.112,-.008),(1.23,.185,.139,-.012),
           (1.335,.203,.145,-.01),(1.402,.212,.124,-.012),(1.449,.16,.096,-.007),
           (1.49,.081,.073,.001)]
    g.loft([(0,y,z,w*width,d) for y,w,d,z in torso],coat,count=20,ripple=.035)
    g.loft([(0,1.445,0,.115,.102),(0,1.484,0,.084,.081),(0,1.505,0,.077,.07)],coat,count=14)
    for side in (-1,1):
        s=side
        thigh=1 if s<0 else 2; shin=thigh+2; arm=thigh+4; fore=arm+2
        hip=s*.101; knee=s*.109
        g.loft([(hip,.938,-.007,.104,.116),(hip,.856,-.014,.111,.124),
                (hip,.778,-.005,.096,.109),(knee,.648,.014,.085,.091),
                (knee,.552,.016,.074,.079),(knee,.520,.022,.073,.077),
                (knee,.487,.013,.069,.071)],trouser,thigh,ripple=.045)
        g.loft([(knee,.514,.013,.070,.075),(knee,.467,.002,.079,.077),
                (knee,.429,-.007,.069,.074),(knee,.347,-.021,.081,.087),
                (knee,.258,-.016,.067,.07),(knee,.177,-.004,.058,.063),
                (knee,.148,.002,.067,.067),(knee,.124,-.003,.059,.060)],trouser,shin,ripple=.054)
        g.loft([(knee,.012,.041,.075,.141),(knee,.035,.044,.077,.142),
                (knee,.07,.041,.076,.139),(knee,.095,.018,.070,.102),
                (knee,.129,-.004,.060,.071),(knee,.159,-.009,.059,.065)],"383831",11 if s<0 else 12)
        shoulder=s*.181*width; elbow=s*(.249 if soldier else .238)
        wrist=s*(.18 if soldier else .211)
        g.loft([(shoulder*.84,1.453,-.005,.053,.057),(shoulder,1.424,-.007,.084,.087),
                (shoulder+s*.018,1.37,-.004,.087,.092),(shoulder+s*.029,1.29,-.012,.072,.073),
                (elbow,1.207,-.016,.061,.064),(elbow,1.172,-.012,.067,.069),
                (elbow,1.145,-.004,.055,.06)],coat,arm,ripple=.053)
        cuff=1.065 if ill else .966
        g.loft([(elbow,1.168,-.003,.054,.059),(elbow,1.133,.002,.064,.065),
                (elbow*.96,1.096,.021,.061,.063),(wrist+s*.014,cuff+.018,.058,.048,.049),
                (wrist,cuff,.062,.049,.050)],coat,fore,ripple=.047)
        if ill:
            g.loft([(wrist,1.08,.057,.044,.048),(wrist,1.035,.062,.039,.043),
                    (wrist,.963,.071,.028,.035)],skin,fore)
        handcolor=dark if soldier else skin
        # Rotate the full MakeHuman hand from the neutral A-pose toward the ground.
        origin=V((4.315,2.455,1.755)); axis=V((.30,-.52,.80)).normalized()
        rot=axis.rotation_difference(V((-.12,-.965,.23)).normalized())
        transformed=[]
        for p in hand[0]:
            q=rot@((p-origin)*.096)
            transformed.append((wrist+s*q.x,.965+q.y,.067+q.z))
        g.surface(transformed,hand[1] if s>0 else [tuple(reversed(f)) for f in hand[1]],handcolor,fore)
        if soldier:
            g.pocket(s*.098,1.183,.132,.070,.070,.039,"525e4d","626d56")
            g.bead((s*.181,.76,.006),(.045,.095,.080),"4a534c",thigh)
            g.bead((knee,.479,.065),(.058,.056,.023),"525b51",shin)
        elif var%2:
            g.loft([(s*.117,1.16,.106,.017,.008),(s*.132,1.34,.101,.021,.018),
                    (s*.120,1.454,-.006,.022,.067)],"61524b",count=8)
        # The collar and front seams follow the taper of the upper chest.
        if not soldier:
            g.surface([(s*.067,1.478,.060),(s*.127,1.431,.076),(s*.096,1.389,.111),
                       (s*.027,1.439,.095)],[(0,1,2,3)],trim)
            g.pocket(s*.091,1.312,.109,.048,.043,.011,coat,trim)
    if soldier:
        g.loft([(0,1.03,-.003,.181,.148),(0,1.12,-.006,.201,.161),
                (0,1.33,-.003,.218,.156),(0,1.402,0,.165,.137)],"49564c",count=16)
        g.loft([(0,1.691,-.008,.123,.122),(0,1.711,-.008,.138,.141),
                (0,1.738,-.011,.133,.136),(0,1.789,-.015,.099,.105),
                (0,1.81,-.015,.048,.057)],"536150",count=20)
        g.loft([(0,1.70,-.007,.139,.142),(0,1.715,-.007,.140,.143)],"41493e",count=20)
        g.bead((0,1.23,-.141),(.162,.179,.084),"5a604c")
        badge=["c4774e","7baaa3","e0b55b"][var]
        g.pocket(-.080,1.337,.143,.038,.013,.009,badge,badge)
        for row in range(3):
            g.pocket(0,1.26+row*.019,.151,.132,.004,.004,"606957","5a6654")
        g.loft([(.13,1.02,.248,.047,.190),(.13,1.086,.251,.044,.185)],"363c39",9,count=8)
        g.bead((.13,1.065,.471),(.017,.018,.110),"414845",9)
        g.loft([(0,.94,.3,.215,.14),(0,1.22,.3,.215,.14)],"ad855b",10,count=8)
    elif var%2:
        g.bead((0,1.245,-.125),(.148,.205,.087),"66564c")
    else:
        for y in (1.115,1.185,1.255,1.325):
            g.bead((.005,y,.130),(.008,.008,.006),"584e46")
    if not soldier:
        seam=[(0,y,z+d*1.045) for y,w,d,z in torso]
        verts=[(x+dx,y,z) for x,y,z in seam for dx in (-.004,.004)]
        g.surface(verts,[(j,j+1,j+3,j+2) for j in range(0,len(verts)-2,2)],trim)
    if ill:
        # Irregular diagonal tears expose the darker lining of each coat.
        for j in range(7):
            y=1.09+j*.035
            x=.028*math.sin(var*2+j*.8)-.075
            z=.116+(y-1.09)*.096
            g.surface([(x-.025,y+.018,z-.005),(x+.04,y-.009,z+.010),
                       (x+.063,y-.031,z+.013),(x+.009,y-.009,z+.006)],
                      [(0,1,2,3)],"694e48")
    # Instanced animation adds the stride. An offset stance and a tilted,
    # protracted neck also make stationary infected and civilians read differently.
    for p,n,c,b,uv in g.tris:
        height=p.y
        if height>1.49:
            p.x*=1.08
            p.y=1.49+(height-1.49)*1.055
        if ill:
            lean=max(0,height-1.08)
            p.z+=lean*.19
            p.x+=lean*(.10 if var%2 else -.09)
            p.y-=lean*.065
    return g


base_points,base_faces=anatomy()
head=reduced("head and neck",lambda p:p.y>5.77 and abs(p.x)<(.64 if p.y<6.14 else 1.22),1650)
wrist=V((4.315,2.455,1.755))
hand=reduced("hand",lambda p:p.x>3.55 and (p-wrist).dot(V((.30,-.52,.80)))>-.17,410)
for kind in range(3):
    for var in range(3 if kind==0 else 4):
        make(kind,var).pack("actor%d_%d"%(kind,var))
