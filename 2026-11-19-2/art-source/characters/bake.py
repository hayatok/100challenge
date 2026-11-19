"""Build articulated evacuation characters in Blender. Run blender -b -P bake.py."""
import gzip
import math
import struct
import sys
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


def reduced(part, select, triangles, source):
    base_points, base_faces = source
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
    def __init__(self, detail):
        self.detail = detail
        self.tris = []

    def surface(self, points, polygons, color, bone=0, uv=None, orient=None, material=6):
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
                self.tris.append((p.copy(), n, rgb, bone + 16*(12 if coords else material), coords or (0, 0)))
        bpy.data.meshes.remove(mesh)

    def loft(self, sections, color, bone=0, count=16, ripple=0, band=None, material=6):
        # Tubular garment sections carry unequal radii, displaced seams and folds.
        if not self.detail:
            count=max(6,round(count*.51))
            if len(sections)>5:
                sections=sections[::2]+(sections[-1:] if len(sections)%2==0 else [])
            ripple*=.7
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
        def cloth(tri):
            y=sum(verts[i][1] for i in tri.vertices)/3
            return band[1] if y<band[0] else color
        self.surface(verts,faces,cloth if band else color,bone,material=material)

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
        if not self.detail:
            return
        points=[(x-w*.96,y+h*.86,z+d),(x+w*.96,y+h*.86,z+d),
                (x+w*.94,y+h*.28,z+d*1.19),(x,y+h*.15,z+d*1.28),
                (x-w*.94,y+h*.28,z+d*1.19)]
        points += [(px,py-.0025,pz-.003) for px,py,pz in points]
        self.surface(points,[(0,1,2,3,4),(1,2,7,6),(2,3,8,7),(3,4,9,8),(4,0,5,9)],
                     flap,bone)

    def ribbon(self, trace, width, color, bone=0):
        if not self.detail and width<.008:
            return
        points = [(x+dx,y,z) for x,y,z in trace for dx in (-width,width)]
        faces = [(j,j+1,j+3,j+2) for j in range(0,len(points)-2,2)]
        self.surface(points,faces,color,bone)

    def gear(self):
        # The trigger-hand palm at rest. The shader carries both this grip and
        # the hand through the same elbow and shoulder rotations.
        start=len(self.tris)
        self.pocket(0,.017,.009,.025,.039,.034,"242b2a","3f4540",9)
        self.loft([(0,.017,.169,.026,.205),(0,.038,.178,.029,.211),
                   (0,.073,.174,.024,.200),(0,.084,.176,.018,.191)],
                  "363e3b",9,count=12)
        self.loft([(0,.039,.377,.011,.055),(0,.060,.377,.012,.055)],
                  "4a514d",9,count=10)
        self.pocket(0,.005,.158,.021,.059,.049,"272e2d","3d4541",9)
        self.bead((0,.100,.204),(.022,.026,.044),"343b38",9)
        # Orient the object in the relaxed hand's bind pose. The nominal held
        # pose counter-rotates this angle, bringing the long axis forward.
        angle=1.42
        sn,cs=math.sin(angle),math.cos(angle)
        for point,normal,_,_,_ in self.tris[start:]:
            point.y,point.z=.925+cs*point.y-sn*point.z,.079+sn*point.y+cs*point.z
            point.x+=.180
            normal.y,normal.z=cs*normal.y-sn*normal.z,sn*normal.y+cs*normal.z

    def pack(self,name):
        with (OUT/(name+".bytes")).open("wb") as dest:
            dest.write(struct.pack("<I",len(self.tris)))
            for p,n,c,b,uv in self.tris:
                dest.write(struct.pack("<3f3b3BB2H",*p,*(round(t*126) for t in n),
                                       *bytes.fromhex(c),b,*(round(max(0,min(1,t))*65535) for t in uv)))
        print(name,len(self.tris)//3,"triangles")


def market_apron(g):
    # Cut a folded half apron around the hips, with an open back and one patch pocket.
    rings=((1.046,.186,.152),(1.002,.195,.160),(.918,.215,.174),
           (.829,.213,.190),(.750,.203,.208),(.708,.197,.211))
    count=16 if g.detail else 8
    vertices=[]
    for row,(y,w,d) in enumerate(rings):
        t=row/(len(rings)-1)
        for i in range(count+1):
            a=-.20+(math.pi+.40)*i/count
            fold=(math.sin(a*7+.4)+.37*math.sin(a*12))*t
            vertices.append((math.cos(a)*w,y+.018*t*math.cos(3*a)+.006*fold,
                             math.sin(a)*d-.004+.010*fold))
    stride=count+1
    faces=[(j,j+1,j+stride+1,j+stride)
           for k in range(len(rings)-1) for j in range(k*stride,k*stride+count)]
    g.surface(vertices,faces,lambda tri: "b6a27e" if all(i>=4*stride for i in tri.vertices)
              else "c2ae88",bone=14)
    g.loft([(0,1.015,-.008,.181,.140),(0,1.045,-.007,.178,.139)],
           "d0bb95",count=20)
    g.bead((-.028,1.029,-.156),(.043,.026,.027),"bead87")
    for sign in (-1,1):
        g.ribbon([(-.03,1.034,-.166),(-.029+sign*.055,.997,-.176),
                  (-.03+sign*.069,.954-sign*.015,-.171)],.012,"cbb38c")
    g.pocket(-.075,.900,.161,.057,.060,.018,"a99470","bda783",14)


def market_florist_coat(g):
    # Broad turnover collar and split back yoke on a quilt-free work coat.
    for s in (-1,1):
        collar=[(s*.057,1.497,.040),(s*.094,1.473,.084),(s*.121,1.432,.085),
                (s*.066,1.378,.131),(s*.018,1.430,.119),(s*.027,1.484,.064)]
        thickness=[(x,y-.006,z-.007) for x,y,z in collar]
        g.surface(collar+thickness,[(0,1,2,3,4,5)]+
                  [(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)],"41625c")
        g.pocket(s*.089,1.037,.124,.064,.070,.014,"60817a","7c9a89")
        g.ribbon([(s*.132,1.405,-.110),(s*.121,1.368,-.135),
                  (s*.080,1.321,-.156),(s*.013,1.309,-.163)],.010,"83a498")
        g.ribbon([(s*.145,.983,-.123),(s*.147,.925,-.140),
                  (s*.137,.852,-.164),(s*.132,.825,-.170)],.007,"547a6f")
    g.ribbon([(0,1.37,-.163),(0,1.254,-.164),(0,1.072,-.142),
              (0,.955,-.164),(-.012,.865,-.187)],.007,"3f605b")


def market_lead_kit(g):
    # Radio, webbing shoulder guard and wraparound cloth marker.
    g.loft([(.171,1.347,-.012,.107,.127),(.176,1.389,-.014,.114,.136),
            (.174,1.434,-.014,.109,.123),(.163,1.460,-.011,.090,.105),
            (.144,1.478,-.007,.063,.073)],"545449",count=18,ripple=.032)
    g.loft([(.174,1.432,-.015,.111,.125),(.169,1.455,-.013,.096,.112),
            (.158,1.473,-.011,.079,.091)],"b3844d",count=18)
    pack=[(.140,1.244,-.181,.046,.042),(.141,1.270,-.190,.059,.057),
          (.148,1.379,-.184,.057,.064),(.154,1.406,-.172,.049,.049)]
    g.loft(pack,"363a35",count=14)
    g.loft([(.170,1.392,-.190,.014,.014),(.172,1.426,-.186,.012,.012),
            (.184,1.565,-.200,.005,.005),(.191,1.662,-.231,.003,.003)],
           "333832",count=10)
    g.ribbon([(.107,1.405,-.204),(.095,1.447,-.126),(.085,1.476,-.031),
              (.090,1.453,.063),(.104,1.389,.126),(.109,1.270,.158)],
             .016,"9a916f")
    g.pocket(.152,1.310,-.243,.029,.052,-.010,"5f5e52","747164")
    for i in range(3 if g.detail else 0):
        g.bead((.151,1.296+i*.014,-.256),(.021,.0028,.004),"353a33")


def make(kind,var,detail,head,hand):
    g=Figure(detail)
    soldier=kind==0; ill=kind==1
    lead=soldier and var==3
    grocer=kind==2 and var==4
    florist=kind==2 and var==5
    if lead: var=0
    if grocer: var=0
    if florist: var=3
    coat=(["4c594b","385650","626253"] if soldier else
          ["635059","6b7676","777059","536478"] if ill else
          ["b88a65","5c7988","a86456","718262"])[var]
    if lead: coat="485249"
    if grocer: coat="8e4c41"
    if florist: coat="668a80"
    trouser=["353d43","454541","414a52","51453e"][var]
    skin=(["c2997e","b48a6e","bb9276"] if soldier else
          ["827666","716c68","806e60","7d6f64"] if ill else ["bc947d","b99982","bc947d","ba977f"])[var]
    dark="3a403e"; trim="747e72" if soldier else "7e776a"
    if grocer: trim="532e2a"
    if florist: trim="3f645a"
    hair=["302e2b","292a29","686763","393633"][var]
    if ill and var==1: hair="282627"
    panel=([0,1,0] if soldier else [3,4,5,3] if ill else [0,2,1,2])[var]
    center=[82,253,426,82,253,426][panel]
    eyes=[101,100,104,357,355,357][panel]
    def headcoord(p):
        x,y,z=p
        jaw=max(0,1-abs(y-6.67)/.61)
        brow=max(0,1-abs(y-7.43)/.22)
        asym=(1 if x>0 else -1)*(.006 if ill else .002)
        jaw_width=([1.07,.97,1.02,.92] if not ill else [.92,.86,1.12,.94])[var]
        mouth=max(0,1-abs(y-6.72)/.31)*max(0,1-abs(x)/.52)
        neck=max(0,min(1,(6.24-y)/.46))
        cheek=math.exp(-((y-7.02)/.25)**2)*min(1,abs(x)/.49)
        temple=math.exp(-((y-7.42)/.35)**2)*min(1,abs(x)/.59)
        cheek_width=(-.12 if ill else .04 if soldier else .015)*cheek
        chin=mouth*(.012 if ill and var!=2 else .002)
        return V((x*.104*(1+(jaw_width-1)*jaw+cheek_width+(.034 if soldier else -.025)*temple),
                  1.50+(y-5.78)*.103-chin+asym*jaw-neck*.027,
                  (z-.38)*.105+(.027 if ill else .006)+brow*.004))
    hverts=[headcoord(p) for p in head[0]]
    def head_uv(p,tri):
        source=[head[0][i] for i in tri.vertices]
        if sum(q.z for q in source)/3 < .38: return None
        x=p.x/.104; y=(p.y-1.5)/.103+5.78
        return ((center+x*53)/512,1-(eyes-(y-7.28)*101)/512)
    def head_color(t):
        x,y,z=sum((head[0][i] for i in t.vertices),V((0,0,0)))/3
        return hair if z<.42 and y>6.60 else skin
    g.surface(hverts,head[1],head_color,bone=13,uv=head_uv,material=7)
    # The underlying head supplies eye sockets and eyelids. The printed eyes
    # continue over small ocular surfaces using the same frontal projection.
    for side in (-1,1):
        ox=.308*side; oy=7.29; oz=1.244
        points=[]; polys=[]
        eye_rings, eye_sides=(7,12) if detail else (4,8)
        for y in range(eye_rings):
            lat=math.pi*(y+.02)/(eye_rings-.96)-math.pi/2
            for j in range(eye_sides):
                a=j*TAU/eye_sides
                points.append(headcoord((ox+.151*math.cos(lat)*math.cos(a),oy+.130*math.sin(lat),oz+.145*math.cos(lat)*math.sin(a))))
        for y in range(eye_rings-1):
            for j in range(eye_sides):
                a=y*eye_sides+j
                b=y*eye_sides+(j+1)%eye_sides
                polys.append((a,a+eye_sides,b+eye_sides,b))
        g.surface(points,polys,skin,bone=13,material=7,uv=lambda p,t:((center+p.x/.104*53)/512,1-(eyes-((p.y-1.5)/.103+5.78-7.28)*101)/512))
    # Follow the actual asymmetrical skull so hair never floats above the brow.
    cap=[]; capfaces=[]
    skull=BVHTree.FromPolygons(hverts,head[1])
    origin=headcoord((0,7.38,.47))
    hair_rings,hair_sides=(8,36) if detail else (5,16)
    for k in range(hair_rings):
        t=k/(hair_rings-1)
        for j in range(hair_sides):
            a=j*TAU/hair_sides
            front=math.sin(a)
            edge=-.34+.64*front+.25*max(0,front)**2+.05*math.sin(3*a+var)
            edge-=.22*math.exp(-((front-.26)/.14)**2)
            if ill:
                edge+=.16*max(0,front)*abs(math.cos(a))-.10*math.cos(a+var)
            elif not soldier:
                edge-=.12*math.cos(a-.42)*max(0,front)
            elevation=edge+(1.569-edge)*t
            ray=V((math.cos(a)*math.cos(elevation),math.sin(elevation),front*math.cos(elevation)))
            hit,normal,_,_=skull.ray_cast(origin,ray)
            cap.append((hit if hit is not None else origin+ray*.102)+ray*((.0025 if detail else .006)+.004*t+
                       .0017*math.sin(8*a+k*.7)))
    for k in range(hair_rings-1):
        for j in range(hair_sides):
            a=k*hair_sides+j
            b=k*hair_sides+(j+1)%hair_sides
            capfaces.append((a,a+hair_sides,b+hair_sides,b))
    def hair_uv(p,t):
        q=p-origin
        a=math.atan2(q.z,q.x)
        front=max(0,math.sin(a))
        # The chart's crown supplies real hair direction and tonal breakup.
        u=center+max(-1,min(1,p.x/.105))*(18+11*front)
        v=eyes-91+min(24,max(0,1.78-p.y)*185)*front+4*math.sin(a)
        return u/512,1-v/512
    g.surface(cap,capfaces,hair,bone=13,uv=hair_uv)
    width=1 if soldier else ((.97,.90,1.10,.98) if ill else (1.025,.91,.97,1.04))[var]
    hem=.91 if soldier else ((.94,.825,.90,.84) if ill else (.91,.83,.948,.86))[var]
    if florist: hem=.810
    waist=1.015 if hem<.94 else 1.026
    hip_width=.204 if soldier or var==0 else .211 if var in (1,3) else .193
    torso=[(hem,.243 if florist else hip_width,.178 if florist else .148,-.002),
           ((hem+waist)*.5,.223 if florist else .198,.163 if florist else .144,-.009),(waist,.174,.133,-.008),
           (1.055,.164,.125,-.01),(1.12,.153,.112,-.008),(1.23,.185,.139,-.012),
           (1.335,.203,.145,-.01),(1.402,.212,.124,-.012),(1.449,.16,.096,-.007),
           (1.49,.081,.073,.001)]
    g.loft([(0,y,z,w*width,d) for y,w,d,z in torso],coat,count=20,ripple=.035)
    # Garment fronts follow the actual chest sections, including their waist taper.
    def cloth_front(x,y,stand=0):
        j=next((k for k in range(len(torso)-1) if torso[k+1][0]>=y),len(torso)-2)
        y0,w0,d0,z0=torso[j]; y1,w1,d1,z1=torso[j+1]
        t=max(0,min(1,(y-y0)/(y1-y0)))
        w=(w0+(w1-w0)*t)*width
        return (x,y,z0+(z1-z0)*t+(d0+(d1-d0)*t)*math.sqrt(max(0,1-(x/w)**2))+stand)
    if ill:
        # A worn worker's jacket hangs open over an undershirt. Unequal lapels,
        # a lower left hem and exposed lining read even when the cast is backlit.
        lining=["8d8175","aaa395","8d8172","80929a"][var]
        shirt=[(-.102,1.419),(-.057,1.457),(.065,1.452),(.109,1.409),
               (.074,1.287),(.044,1.161),(.028,1.049),(-.036,1.056),(-.062,1.228)]
        g.surface([cloth_front(x,y,.011) for x,y in shirt],[tuple(range(len(shirt)))],lining)
        for sign in (-1,1):
            rows=[(hem+(.042 if sign>0 else -.049),.036,.194),(1.047,.036,.168),
                  (1.195,.052,.160),(1.303,.074,.175),(1.409,.104,.172),(1.454,.060,.104)]
            points=[]
            for y,inner,outer in rows:
                for u in (0,.45,1):
                    x=sign*(inner+(outer-inner)*u)
                    point=cloth_front(x,y,.009+.014*(1-u))
                    points.append(point)
            g.surface(points,[(i,i+1,i+4,i+3) for i in range(15) if i%3!=2],coat)
            lapel=[(.059,1.459),(.142,1.409),(.112,1.351),(.125,1.336),(.052,1.202)]
            g.surface([cloth_front(sign*x,y,.029) for x,y in lapel],[(0,1,2,3,4)],trim)
        # Rolled, frayed hem on the trailing side creates a broken rather than tubular outline.
        sgn=1 if var%2 else -1
        g.surface([(sgn*.058,hem+.044,.151),(sgn*.181,hem+.031,.105),
                   (sgn*.199,hem-.073,.105),(sgn*.155,hem-.045,.135),
                   (sgn*.129,hem-.115,.145),(sgn*.099,hem-.058,.153)],
                  [(0,1,2,3),(0,3,4,5)],coat)
    if not ill and not soldier and not florist and var==0:
        g.loft([(0,1.418,.006,.139,.106),(0,1.469,.008,.117,.099),
                (0,1.513,.006,.079,.077)],"697a73",count=16,ripple=.07)
        g.ribbon([(-.059,1.474,.099),(-.075,1.402,.129),(-.076,1.309,.155),
                  (-.099,1.226,.133)],.028,"66766e")
    neckline="574a40" if var==2 and not soldier else coat
    g.loft([(0,1.444,-.005,.107,.091),(0,1.470,0,.086,.078),
            (0,1.489,.001,.075,.067),(0,1.501,.002,.074,.065)],
           neckline,count=16)
    for side in (-1,1):
        s=side
        thigh=1 if s<0 else 2
        arm=thigh+4
        shoe=thigh+10
        hip=s*.101; knee=s*.109
        # A common vertex strip crosses the knee. The runtime blends rotation
        # above and below that joint without a separate cap or intersecting tube.
        g.loft([(hip,.933,-.011,.102,.114),(hip,.857,-.013,.106,.116),
                (hip,.785,-.006,.100,.102),(hip,.718,.005,.087,.092),
                (knee,.609,.013,.079,.082),(knee,.546,.020,.073,.076),
                (knee,.502,.023,.072,.075),(knee,.470,.007,.071,.072),
                (knee,.425,-.011,.072,.074),(knee,.350,-.022,.077,.084),
                (knee,.269,-.017,.066,.072),(knee,.191,-.004,.054,.063),
                (knee,.153,.002,.061,.061),(knee,.126,-.003,.055,.054)],
               trouser,thigh,count=18,ripple=.045)
        upper_leather="514d40" if var==2 and not soldier else "353833"
        sole=[(knee,.008,.043,.066,.126),(knee,.018,.045,.076,.143),
              (knee,.033,.046,.077,.143),(knee,.043,.046,.073,.139)]
        g.loft(sole,"35332d",shoe,count=18)
        g.loft([(knee,.038,.046,.071,.139),(knee,.056,.048,.073,.138),
                (knee,.076,.045,.071,.130),(knee,.098,.020,.066,.103),
                (knee,.123,-.007,.057,.064),(knee,.162,-.010,.060,.064)],
               upper_leather,shoe,count=18)
        for j in range(3 if detail else 0):
            y=.115-j*.009
            z=.083+j*.014
            g.surface([(knee-.029,y,z),(knee-.027,y+.003,z-.002),
                       (knee+.028,y+.004,z-.002),(knee+.030,y+.001,z)],
                      [(0,1,2,3)],"686457",shoe)
        shoulder=s*.179*width
        offset=(-.009 if ill else -.004)*s
        elbow=s*(.239 if soldier else .230)
        wrist=s*(.18 if soldier else .211)
        cuff=1.066 if ill else .966
        g.loft([(shoulder*.81,1.450+offset,-.009,.042,.052),
                (shoulder,1.425+offset,-.010,.055,.069),
                (shoulder+s*.014,1.387+offset,-.012,.068,.076),
                (shoulder+s*.022,1.315+offset,-.014,.068,.075),
                (elbow,1.222,-.017,.060,.066),(elbow,1.180,-.012,.060,.066),
                (elbow,1.150,-.004,.060,.063),(elbow*.97,1.117,.009,.059,.063),
                (elbow*.91,1.077,.026,.052,.055),
                (wrist+s*.008,cuff+.041,.052,.044,.049),
                (wrist+s*.003,cuff+.024,.057,.041,.046),
                (wrist,cuff+.013,.058,.043,.047),
                (wrist,cuff,.062,.039,.041)],coat,arm,count=16,ripple=.036,
               band=(cuff+.018,neckline if ill else trim))
        if ill:
            g.loft([(wrist,1.084,.056,.038,.039),(wrist,1.039,.061,.034,.038),
                    (wrist,.996,.067,.030,.033),(wrist,.962,.070,.026,.031)],
                   skin,arm,material=7)
        handcolor=dark if soldier else skin
        # Rotate the full MakeHuman hand from the neutral A-pose toward the ground.
        origin=V((4.315,2.455,1.755)); axis=V((.30,-.52,.80)).normalized()
        rot=axis.rotation_difference(V((-.12,-.965,.23)).normalized())
        transformed=[]
        for p in hand[0]:
            q=rot@((p-origin)*.096)
            if soldier and not (lead and s<0):
                # Pull the distal finger tips into the palm for the carrying pose.
                curl=max(0,-q.y-.025)
                q.z+=curl*.54
                q.y+=curl*.36
            transformed.append((wrist+s*q.x,.965+q.y,.067+q.z))
        g.surface(transformed,hand[1] if s>0 else [tuple(reversed(f)) for f in hand[1]],handcolor,arm,material=6 if soldier else 7)
        if lead or grocer or florist:
            g.loft([(wrist,cuff+.002,.060,.040,.043),(wrist,cuff+.010,.058,.045,.049),
                    (wrist+s*.004,cuff+.024,.056,.045,.049),(wrist+s*.008,cuff+.035,.053,.043,.047)],
                   trim,arm,count=16,ripple=.045)
            if g.detail:
                g.bead((wrist+s*.032,cuff+.026,.086),(.008,.006,.004),
                       "a6a28c" if florist else "74675a",arm)
        if soldier:
            # Shoulder panels sit on the articulated sleeve and bridge onto the vest.
            g.loft([(shoulder+s*.025,1.319,-.011,.069,.078),
                    (shoulder+s*.023,1.339,-.011,.081,.087),
                    (shoulder+s*.012,1.397,-.012,.083,.082),
                    (shoulder-s*.018,1.438,-.007,.064,.068),
                    (shoulder-s*.045,1.453,-.006,.039,.044)],"62705d",arm,count=16)
            g.pocket(s*.194,1.353,.063,.031,.021,.012,["aa7855","76a09a","cbad63"][var],trim,arm)
            g.pocket(s*.098,1.183,.132,.070,.070,.039,"525e4d","626d56")
            g.bead((s*.181,.76,.006),(.045,.095,.080),"4a534c",thigh)
            g.bead((knee,.479,.065),(.058,.056,.023),"525b51",thigh)
        elif var==1 or (var==3 and ill):
            g.loft([(s*.117,1.16,.106,.017,.008),(s*.132,1.34,.101,.021,.018),
                    (s*.120,1.454,-.006,.022,.067)],"61524b",count=8)
        # The collar and front seams follow the taper of the upper chest.
        if not soldier and not florist:
            g.surface([(s*.067,1.478,.060),(s*.127,1.431,.076),(s*.096,1.389,.111),
                       (s*.027,1.439,.095)],[(0,1,2,3)],trim)
            g.pocket(s*.098,1.309,.122,.041,.042,.012,coat,trim)
    if soldier:
        # Shallow front brim, raised brow mount and fabric rear skirt give the
        # helmet distinct front, side and back profiles rather than one round ring.
        rim=[(-.125,1.708,.011),(-.106,1.710,.081),(-.067,1.717,.142),
             (0,1.718,.153),(.067,1.717,.142),(.106,1.710,.081),(.125,1.708,.011)]
        g.surface(rim+[(x*.94,y+.012,z-.018) for x,y,z in rim],
                  [(i,i+1,i+8,i+7) for i in range(6)],"69715a",13)
        for side in (-1,1):
            g.loft([(side*.103,1.594,-.032,.019,.041),
                    (side*.113,1.616,-.029,.025,.049),(side*.119,1.666,-.035,.026,.052),
                    (side*.109,1.704,-.039,.021,.046)],"444c40",13,count=12)
        g.pocket(0,1.735,.128,.029,.021,.012,"414b41","777e67",13)
        g.loft([(0,1.03,-.003,.181,.148),(0,1.12,-.006,.201,.161),
                (0,1.33,-.003,.218,.156),(0,1.402,0,.165,.137)],"49564c",count=16)
        g.loft([(0,1.691,-.008,.123,.122),(0,1.711,-.008,.138,.141),
                (0,1.738,-.011,.133,.136),(0,1.789,-.015,.099,.105),
                (0,1.81,-.015,.048,.057)],"536150",bone=13,count=24)
        g.loft([(0,1.70,-.007,.139,.142),(0,1.715,-.007,.140,.143)],"41493e",bone=13,count=24)
        g.bead((0,1.23,-.141),(.162,.179,.084),"5a604c")
        badge=["c4774e","7baaa3","e0b55b"][var]
        g.pocket(-.080,1.337,.143,.038,.013,.009,badge,badge)
        for row in range(3 if detail else 1):
            g.pocket(0,1.26+row*.019,.151,.132,.004,.004,"606957","5a6654")
        for side in (-1,1):
            g.ribbon([(side*.125,1.709,.038),(side*.116,1.685,.049),
                      (side*.101,1.626,.062),(side*.084,1.581,.078),
                      (side*.043,1.557,.100),(0,1.553,.111)],
                     .006,"4b4c3d",13)
            g.ribbon([(side*.155,1.13,.133),(side*.128,1.29,.157),
                      (side*.129,1.38,.126),(side*.135,1.466,.031),
                      (side*.142,1.413,-.116),(side*.142,1.28,-.190)],
                     .014,"686c55")
        g.pocket(.185,1.315,.099,.025,.048,.023,"373f37","555c4d")
        g.loft([(.186,1.35,.121,.007,.007),(.191,1.489,.119,.003,.004)],"3a4439",count=8)
        g.gear()
        g.loft([(0,1.03,.351,.173,.112),(0,1.124,.357,.178,.114),
                (0,1.212,.357,.177,.109),(0,1.225,.357,.164,.100)],
               "a38259",10,count=10)
        for x in (-.082,.082):
            g.ribbon([(x,1.038,.46),(x,1.203,.469),(x,1.226,.433)],
                     .013,"65543c",10)
        for z in (.320,.340):
            g.surface([(-.065,1.222,z),(-.046,1.251,z),
                       (.046,1.251,z),(.065,1.222,z),
                       (.047,1.222,z),(.035,1.239,z),
                       (-.035,1.239,z),(-.047,1.222,z)],
                      [(0,1,6,7),(1,2,5,6),(2,3,4,5)],"59473a",10)
    elif var==1 or (var==3 and ill):
        g.bead((0,1.245,-.125),(.148,.205,.087),"66564c")
    elif var==3 and not florist:
        g.pocket(.146,1.04,.118,.064,.071,.035,"6e5846","8a7159")
        g.ribbon([(.148,1.09,.163),(.074,1.21,.145),(-.017,1.33,.142),
                  (-.105,1.44,.090),(-.106,1.46,-.013)],.012,"796350")
    else:
        for y in (1.115,1.185,1.255,1.325):
            g.bead((.005,y,.130),(.008,.008,.006),"584e46")
    if not soldier and not ill:
        seam=[(0,y,z+d*1.045) for y,w,d,z in torso]
        verts=[(x+dx,y,z) for x,y,z in seam for dx in (-.004,.004)]
        g.surface(verts,[(j,j+1,j+3,j+2) for j in range(0,len(verts)-2,2)],trim)
    if grocer: market_apron(g)
    if florist: market_florist_coat(g)
    if lead: market_lead_kit(g)
    if ill:
        def front(x,y,lift):
            j=next(k for k in range(len(torso)-1) if torso[k+1][0]>=y)
            h,w,d,z=torso[j]
            h2,w2,d2,z2=torso[j+1]
            t=(y-h)/(h2-h)
            w=(w+(w2-w)*t)*width
            return (x,y,z+(z2-z)*t+(d+(d2-d)*t)*math.sqrt(max(0,1-(x/w)**2))+lift)
        for j in range(3):
            x=-.064+.022*math.sin(var*.7+j)
            y=1.089+j*.052
            jag=[(x-.038,y-.018),(x-.018,y-.003),(x+.013,y+.004),
                 (x+.055,y+.024),(x+.018,y-.004),(x-.019,y-.014)]
            g.surface([front(px,py,.003) for px,py in jag],[(0,1,2,3,4,5)],"3f3532")
            if detail:
                for k in range(3):
                    px=x-.029+k*.024
                    py=y-.017+k*.009
                    g.surface([front(px,py,.005),front(px+.004,py-.002,.005),
                               front(px+.008,py+.009,.005),front(px+.004,py+.010,.005)],
                              [(0,1,2,3)],"817467")
    # Instanced animation adds the stride. An offset stance and a tilted,
    # protracted neck also make stationary infected and civilians read differently.
    for p,n,c,b,uv in g.tris:
        height=p.y
        if height>1.49:
            p.x*=1.08
            p.y=1.49+(height-1.49)*1.055
        if ill:
            # Scapulae protract around the ribcage. One shoulder hangs lower
            # than the other, carrying its sleeve, hand and jacket panel with it.
            shoulder_band=math.exp(-((height-1.38)/.19)**2)
            handed=1 if var in (0,2) else -1
            side=max(-1,min(1,p.x/.155))*handed
            p.y+=shoulder_band*(.016-.039*side)
            p.z+=shoulder_band*(.027+.028*side)
            lean=max(0,height-1.08)
            p.z+=lean*(.29 if var!=2 else .24)
            p.x+=lean*(.12 if var%2 else -.15)
            p.y-=lean*.065
    return g


def bake():
    source=anatomy()
    wrist=V((4.315,2.455,1.755))
    for detail in (True,False):
        prefix="actor" if detail else "actorFar"
        head=reduced("head and neck",lambda p:p.y>5.77 and abs(p.x)<min(1.22,.59+max(0,p.y-6.12)*.97),
                     2350 if detail else 640,source)
        hand=reduced("hand",lambda p:p.x>3.55 and (p-wrist).dot(V((.30,-.52,.80)))>-.17,
                     510 if detail else 130,source)
        variants=((0,3),(2,4),(2,5))
        if "--market-only" not in sys.argv:
            variants=tuple((kind,var) for kind in range(3)
                           for var in range(3 if kind==0 else 4))+variants
        for kind,var in variants:
            make(kind,var,detail,head,hand).pack(f"{prefix}{kind}_{var}")


if __name__=="__main__":
    bake()
