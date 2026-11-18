"""Blender 5.x background build. Pass the directory prepared by paint_atlas.py after --."""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector, Euler, Quaternion
from math import sin, cos, pi, sqrt, atan2, acos
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from forms import CAST, PALETTE, M, profile, EYES, station_width
args=sys.argv[sys.argv.index('--')+1:]
TEX=Path(args[0]); GAME=HERE.parent/'game'/'racers'
V=Vector
def uv(x,y):return (x/1024,1-y/1024)
def pigment(k):
    if isinstance(k,str):k=PALETTE.index(k)
    return uv(k*32+16,544)

class Surface:
    def __init__(self,name):
        self.name=name;self.verts=[];self.faces=[];self.uvs=[];self.bones=[]

    def grid(self,rows,bone,color,wrapped=True,reverse=False,tex=None,cap=True):
        base=len(self.verts); n=len(rows[0]); nr=len(rows)
        for row in rows:
            self.verts.extend([tuple(v*M for v in p) for p in row])
            self.bones.extend([bone]*n)
        def face(indices,coords=None):
            self.faces.append(tuple(base+q for q in (reversed(indices) if reverse else indices)))
            if coords is None:coords=[pigment(color)]*len(indices)
            self.uvs.append(tuple(reversed(coords)) if reverse else tuple(coords))
        for a in range(nr-1):
            for b in range(n if wrapped else n-1):
                j=(b+1)%n
                f=[a*n+b,a*n+j,(a+1)*n+j,(a+1)*n+b]
                coords=[tex(a,b),tex(a,b+1),tex(a+1,b+1),tex(a+1,b)] if tex else None
                face(f,coords)
        if cap and wrapped:
            face(list(reversed(range(n)))); face([(nr-1)*n+j for j in range(n)])
    def loft(self,rings,bone,color,n=24):
        # Each ring = z, x radius, y radius, x offset, y offset.
        rows=[]
        for z,rx,ry,x,y in rings:
            rows.append([(x+rx*sin(a*2*pi/n),y-ry*cos(a*2*pi/n),z) for a in range(n)])
        self.grid(rows,bone,color,tex=(lambda a,b:uv(871+147*b/n,581+227*a/(len(rows)-1))) if color=='hair' else None)
    def oval(self,center,radii,bone,color,n=16,h=8):
        x,y,z=center;rx,ry,rz=radii
        self.loft([(z+rz*sin(t),rx*cos(t),ry*cos(t),x,y) for t in [-1.56+i*3.12/h for i in range(h+1)]],bone,color,n)
    def tube(self,points,radii,bone,color,flat=1,n=10,steps=3,plane=None):
        pp=[V(p) for p in points]
        def cat(a,b,c,d,t):
            return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t**3)
        seq=[]
        for i in range(len(pp)-1):
            for j in range(steps):
                t=j/steps; a=max(i-1,0);d=min(i+2,len(pp)-1)
                seq.append((cat(pp[a],pp[i],pp[i+1],pp[d],t),max(.12,cat(radii[a],radii[i],radii[i+1],radii[d],t))))
        seq.append((pp[-1],radii[-1])); rows=[]
        for i,(p,r) in enumerate(seq):
            tangent=(seq[min(i+1,len(seq)-1)][0]-seq[max(i-1,0)][0]).normalized()
            guide=V(plane) if plane else V((0,-1,0))
            if abs(tangent.dot(guide))>.96:guide=V((1,0,0))
            a=(guide-tangent*guide.dot(tangent)).normalized(); b=tangent.cross(a)
            rows.append([p+b*(sin(j*2*pi/n)*r)+a*(cos(j*2*pi/n)*r*flat) for j in range(n)])
        self.grid(rows,bone,color,tex=(lambda a,b:uv(871+147*b/n,581+227*a/(len(rows)-1))) if color=='hair' else None)
    def polygon(self,pts,bone,color):
        offset=len(self.verts);self.verts.extend([tuple(x*M for x in p) for p in pts])
        self.bones.extend([bone]*len(pts));self.faces.append(tuple(range(offset,offset+len(pts))));self.uvs.append([pigment(color)]*len(pts))
    def object(self,material,rig):
        mesh=bpy.data.meshes.new(self.name);mesh.from_pydata(self.verts,[],self.faces);mesh.update()
        ob=bpy.data.objects.new(self.name,mesh);bpy.context.collection.objects.link(ob)
        ob.data.materials.append(material)
        layer=mesh.uv_layers.new(name='Albedo')
        for p,uvs in zip(mesh.polygons,self.uvs):
            p.use_smooth=True
            for l,st in zip(p.loop_indices,uvs):layer.data[l].uv=st
        bybone={}
        for i,k in enumerate(self.bones):bybone.setdefault(k,[]).append(i)
        for k,idx in bybone.items():ob.vertex_groups.new(name=k).add(idx,1,'REPLACE')
        mod=ob.modifiers.new('Competition rig','ARMATURE');mod.object=rig
        ob.parent=rig
        return ob

def make_material(i):
    name=CAST[i]['name']
    mat=bpy.data.materials.new(name+' – painted cloth, hair and skin')
    mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.83;bs.inputs['Specular IOR Level'].default_value=.14
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(TEX/f'{i+1:02}.png'));tex.image.pack()
    mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    return mat

def skel(i):
    bones={'Pelvis':((0,0,115),None),'Chest':((0,0,126),'Pelvis'),'Head':((0,0,194),'Chest'),
           'Ornament':((0,15,264),'Head'),'Blink':((0,15,262),'Head')}
    if i==0:bones['Ornament']=((64,-34,324),'Head')
    if i==2:bones['Ornament']=((-28,48,340),'Head')
    if i==3:bones['Ornament']=((0,7,329),'Head')
    if i==5:bones['Ornament']=((41,73,238),'Head')
    for s,sgn in [('L',1),('R',-1)]:
        for name,pos,parent in [
            ('Thigh',(sgn*24,0,116),'Pelvis'),('Shin',(sgn*28,-1,77),'Thigh.'+s),
            ('Foot',(sgn*32,0,37),'Shin.'+s),('UpperArm',(sgn*33,1,184),'Chest'),
            ('Forearm',(sgn*60,-1,153),'UpperArm.'+s),('Hand',(sgn*76,-5,130),'Forearm.'+s),
            ('Lock',(sgn*67,12,245),'Head')]:
            bones[name+'.'+s]=(pos,parent)
    arm=bpy.data.armatures.new('Skeleton_'+CAST[i]['name'])
    rig=bpy.data.objects.new(CAST[i]['name']+'_Rig',arm);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    for name,(pos,parent) in bones.items():
        b=arm.edit_bones.new(name);b.head=V(pos)*M;b.tail=b.head+V((0,0,.05))
        if parent:b.parent=arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    return rig

def head(g,i):
    c=CAST[i]; n=84; steps=48
    rows=[[profile(c,-pi+2*pi*j/n,k/steps) for j in range(n)] for k in range(steps+1)]
    g.grid(rows,'Head','hair',reverse=True,tex=lambda a,b:uv(1+(1022*b/n),1+509*a/steps))
    # Soft eyelid appliqués follow the head's actual UV surface. At rest their driving
    # bone scales them into the skull, leaving the painted open eyes fully exposed.
    for j,(ex,ey,ew,eh) in enumerate(EYES[i]):
        coords=[]
        for b in range(8):
            y=ey+(b/7-.5)*2.55*eh
            v=(y-c['stations'][0][0])/(c['stations'][-1][0]-c['stations'][0][0]);row=[]
            r=station_width(c,y)
            for a in range(13):
                x=ex+(a/12-.5)*ew*2.6
                theta=math.asin(max(-.98,min(.98,(x-c['cx'])/r)))
                p=V(profile(c,theta,v));p.y-=.46;row.append(p)
            coords.append(row)
        g.grid(coords,'Blink','skin',False,True,lambda b,a:uv(300+j*160+139*a/12,640+99*b/7),False)
    g.oval((0,0,198),(18,14,20),'Chest','skin')

def decoration(g,i):
    lock=lambda points,r,b='Ornament',c='hair',flat=.7:g.tube(points,r,b,c,flat,12,3)
    if i==0:
        # The left-temple bow is asymmetrical. One loop points upward, one extends out;
        # two folded swallow tails trail lower on the side of the bob.
        def bow_surface(outline,center,depth):
            # Coordinates in the calibrated front view. Convex folded cross-sections
            # give the loops volume and carry the original designer's crease painting.
            rings=[]
            for t in [.035,.36,.72,1,.72,.36,.035]:
                front=len(rings)<4; row=[]
                for px,py in outline:
                    qx=center[0]+(px-center[0])*t;qy=center[1]+(py-center[1])*t
                    x=qx-273+8
                    r=station_width(CAST[0],qy)
                    theta=math.asin(clamp(x/max(r,.01),-.997,.997))
                    face_y=profile(CAST[0],theta,clamp((qy-21)/177,0,1))[1]
                    yy=min(-22+.80*(qx-343)+.13*(qy-74),face_y-4)
                    yy-=max(0,min(1,(qy-77)/16))*15
                    yy+=(1 if not front else -1)*depth*(1-t*t)
                    row.append((x,yy,398-qy))
                rings.append(row)
            def bow_uv(a,b):
                px,yy,z=rings[a][b%len(outline)]
                return uv(710+(px+273-8-311)*154/75,561+(398-z-12)*250/125)
            g.grid(rings,'Ornament',15,tex=bow_uv)
        bow_surface([(343,72),(331,68),(321,62),(316,53),(315,41),(316,31),(321,21),(327,15),(332,17),(340,25),(349,35),(352,43),(351,52),(347,62)],(333,45),8)
        bow_surface([(343,72),(349,66),(357,61),(366,60),(374,62),(378,68),(378,79),(375,91),(371,98),(364,98),(354,90),(348,83)],(363,78),7)
        bow_surface([(343,76),(350,79),(359,88),(370,103),(381,118),(377,122),(357,132),(352,130),(348,116),(344,95)],(358,104),4)
        g.oval((77,-36,325),(8.5,8,10),'Ornament',15,20)
    if i==1:
        for s,sign in [('L',1),('R',-1)]:
            b='Lock.'+s
            center=V((sign*68,20,334))
            g.oval(center,(32,29,31),b,'hair',24,12)
            # Coiled bun sections wind around a diagonal axis, creating the scalloped edge.
            for t in range(6):
                a=t*2*pi/6
                coil=[center+V(((35-4*u)*cos(a+u*1.85),(32-5*u)*sin(a+u*1.85),-18+45*u)) for u in [0,.22,.47,.70,1]]
                lock(coil,[9,12,12,11,4],b,'hair',.84)
            for t in range(7):
                a=(t-3)*.34
                g.oval((sign*(46+27*sin(a)), -11,323-17*sin(a)),(5.5,6,6),b,12,12,6)
            lock([(sign*82,-18,284),(sign*95,-19,267),(sign*82,-27,246),(sign*89,-30,229),(sign*99,-25,237)],[7,9,7,4,.4],b)
    if i==2:
        g.oval((-33,49,335),(27,25,16),'Ornament',20)
        # High fountain ponytail arcs over its tie, behind the left shoulder in front view.
        for q in [-1,-.5,0,.5,1]:
            path=[(-30+q*13,54+q*7,338),(-46+q*13,68,365),(-72+q*13,75,363),(-94+q*10,72,337),(-108+q*8,64,289),(-96+q*9,62,236),(-105+q*10,52,188),(-113+q*10,45,149),(-98+q*13,46+q*8,121+q*13),(-72+q*14,50+q*10,146+q*16)]
            lock(path,[9,13,15,16,16,16,14,12,7,.5],flat=.82)
        for j in range(4):g.oval((-51+j*13,27,343+j*2),(10,10,10),'Ornament',20)
    if i==3:
        # Woven visor band wraps around the skull, and the crescent bill projects forward.
        z=289
        # Tilt the brim on the same diagonal as the illustrated visor.
        band=[]
        for dz,rx,ry in [(0,86,76),(4,88,77),(15,85,75),(19,82,71)]:
            band.append([(rx*sin(a*2*pi/64),12-ry*cos(a*2*pi/64),z+dz+15*sin(a*2*pi/64)) for a in range(64)])
        g.grid(band,'Head',12)
        br=[]
        for q in range(7):
            t=q/6;row=[]
            for j in range(37):
                a=-1.38+j*2.76/36
                row.append(((86+t*14)*sin(a),12-(76+t*38*max(.1,cos(a)))*cos(a),z+4+15*sin(a)+t*(4+7*cos(a))-5*sin(a)**2))
            br.append(row)
        g.grid(br,'Head',12,False,True,cap=False)
        g.tube(br[-1], [2]*len(br[-1]),'Head',29,n=7,steps=1)
        lock([(-2,9,350),(-10,13,370),(-27,17,382),(-47,19,383),(-56,21,378)],[8,10,8,4,.5],c='hair')
        for s,sign in [('L',1),('R',-1)]:
            lock([(sign*69,18,300),(sign*87,17,287),(sign*100,10,279),(sign*111,7,284)],[11,11,7,.6],'Lock.'+s)
    if i==4:
        for s,sign in [('L',1),('R',-1)]:
            b='Lock.'+s
            for j in range(5):
                cx=sign*(65+2*j)
                z=211-j*12
                for cross in [-1,1]:
                    lock([(cx+cross*9,12,z+11),(cx+cross*9,8+cross*3,z+5),(cx+cross*3,4,z-2),(cx-cross*6,9,z-8)],[6,9-j*.45,8-j*.4,4],b,'hair',.85)
            lock([(sign*74,12,156),(sign*78,11,143),(sign*81,8,126),(sign*71,7,111),(sign*65,6,111)],[7,12,12,7,.4],b)
            for p in [-1,1]:
                lock([(sign*76,0,156),(sign*76+p*11,-1,159),(sign*76+p*16,2,164)],[3,7,5],b,14,.6)
            g.oval((sign*76,-2,156),(5,5,6),b,14)
        # Thin acetate temples extend back to the ears; the original painted rims own the front.
        for sign in [-1,1]:lock([(sign*64,-39,237),(sign*78,-18,238),(sign*88,4,241)],[1.8,2.3,2],'Head',17)
    if i==5:
        center=V((75,52,220))
        g.oval(center,(26,25,25),'Ornament','hair',24,12)
        for t in range(5):
            a=t*1.256
            lock([center+V((25*cos(a),20*sin(a),10)),center+V((31*cos(a+.9),23*sin(a+.9),4)),center+V((20*cos(a+1.8),18*sin(a+1.8),-16)),center+V((4,2,-18))],[8,11,8,3])

def outer_hair(g,i):
    c=CAST[i]
    # Individual layered locks flare free of the main head at the bob's cut edge.
    styles=[(12,.28,1.03),(8,.26,1.02),(7,.18,1.02),(9,.30,1.03),(9,.24,1.02),(8,.20,1.03)]
    count,sweep,end=styles[i]
    for j in range(count):
        ang=.96+j*(2*pi-1.92)/(count-1)
        if abs(ang-pi)<.32:continue
        start=.21+.09*sin(j*3.1);rows=[];nt=14;nr=10
        for a in range(nt+1):
            t=a/nt
            vc=start+(end-start)*t
            theta=ang+sweep*sin(t*pi*.90+j*.24)-.16*(1-t)
            if vc<=1:p=V(profile(c,theta,vc))
            else:
                p=V(profile(c,theta,1))
                p.z-=(vc-1)*130
                p-=V((sin(theta),-cos(theta),0))*(vc-1)*290
            norm=V((sin(theta),-cos(theta),.30*(1-t))).normalized();tan=V((cos(theta),sin(theta),0))
            strength=max(.015,sin(pi*(.02+.98*t))**.58)
            width=(10+3*sin(j*2.4))*strength
            depth=(4.6+1.8*sin(j+.4))*strength
            p+=norm*(.4+1.0*sin(pi*t))
            rows.append([p+tan*(width*sin(b*2*pi/nr))+norm*(depth*cos(b*2*pi/nr)) for b in range(nr)])
        def lookup(a,b):
            t=a/nt;theta=ang+sweep*sin(t*pi*.90+j*.24)-.16*(1-t)
            theta+=(width if a==nt else 8)*sin(b*2*pi/nr)/94
            theta=(theta+pi)%(2*pi)-pi
            return uv(1+1022*(theta+pi)/(2*pi),1+min(1,start+(end-start)*t)*509)
        g.grid(rows,'Head','hair',tex=lookup)

def bib(g,rear=False):
    sign=1 if rear else -1
    rings=[]
    for a in range(7):
        t=a/6;row=[]
        for b in range(11):
            u=b/10-.5; x=u*43*(-1 if rear else 1)
            y=sign*(27.6+2*(1-(u*2)**2)+.7*sin(t*pi))
            row.append((x,y,145+29*t))
        rings.append(row)
    g.grid(rings,'Chest',9,False,rear,lambda a,b:uv(1+254*b/10,600+158*(1-a/6)),False)

def clothes(g,i):
    torso=[(125,37,24,0,2),(129,39,26,0,2),(138,41,27,0,1),(153,39,28,0,0),(170,36,25.5,0,0),(181,34,23,0,0),(190,29,20,0,1),(197,18,14,0,2)]
    n=48
    rings=[[(x+rx*sin(-pi+j*2*pi/n),y-ry*cos(-pi+j*2*pi/n),z) for j in range(n)] for z,rx,ry,x,y in torso]
    g.grid(rings,'Chest','jacket',tex=lambda a,b:uv(1+1022*b/n,819+204*(torso[a][0]-125)/72))
    for z0,z1,c in [(126,130,'sleeve'),(130,134,9)]:
        g.loft([(z0,38,25,0,2),(z1,39,26,0,2)],'Chest',c)
    g.tube([(0,-24,127),(0,-28,144),(0,-28.4,157),(0,-24.8,174),(0,-18,189),(0,-13,198)],[2,2,2,1.8,1.7,1.6],'Chest',10,n=8)
    for s in [-1,1]:
        g.polygon([(s*3,-15,194),(s*15,-13,200),(s*26,-12,192),(s*15,-20,182)],'Chest',10 if i in [0,5] else 'sleeve')
    if i in [1,2,4]:
        g.tube([(-24,0,189),(-29,12,188),(-21,23,184),(0,29,181),(21,23,184),(29,12,188),(24,0,189)],[6,9,10,11,10,9,6],'Chest','sleeve',n=12)
    if i in [1,5]:
        for sg in [-1,1]:g.tube([(sg*7,-18,193),(sg*9,-24,184),(sg*8,-26,178)],[1.2,1.3,1.4],'Chest',9,n=6)
    for sg in [-1,1]:
        g.tube([(sg*23,-20,144),(sg*28,-18,138),(sg*32,-15,137)],[1.3,1.5,.8],'Chest',11,n=6)
    for rear in [False,True]:bib(g,rear)
    g.polygon([(9,-22.5,178),(22,-19,178),(17,-18,189)],'Chest',10 if i in [0,1] else 9)
    g.polygon([(15,-20.8,179),(20,-20,179),(17,-19,186)],'Chest',9 if i in [0,1] else 'jacket')
    g.loft([(109,29,24,0,1),(120,35,25,0,1),(128,35,24,0,1)],'Pelvis','pants')
    for s,k in [('L',1),('R',-1)]:
        up='UpperArm.'+s;lo='Forearm.'+s;hand='Hand.'+s
        thigh='Thigh.'+s;shin='Shin.'+s;foot='Foot.'+s
        def P(x,y,z):return (k*x,y,z)
        # Raglan jacket sleeves ease out at the elbow, then gather into a striped cuff.
        def A(x,y,z):
            return P(x+max(0,x-33)*.30,y,z-max(0,131-z)*.57)
        g.tube([A(33,1,184),A(39,0,178),A(48,0,164),A(54,-1,153)],[13.5,14.5,13.2,12.5],up,'sleeve',n=16)
        g.oval(A(54,-1,153),(12.6,12.6,12.6),lo,'sleeve',16)
        fore_color='skin' if i==3 else 'sleeve'
        g.tube([A(53,-1,155),A(58,-2,147),A(63,-4,139),A(66,-5,131)],[12.4,12.5,12,10.5],lo,fore_color,n=16)
        for z,xx,cc in [(137,64,'sock'),(134,65,9),(131,66,'sleeve')]:
            g.tube([A(xx,-4,z+1.4),A(xx+.8,-5,z-1.4)],[11.2,10.8],lo,cc,n=16,steps=1)
        if i in [1,2,5]:
            g.tube([A(40,-7,180),A(46,-9,172),A(51,-10,164),A(54,-9,158)],[1.9,2.2,2.2,1.9],up,9,n=7)
        g.polygon([A(40,-11,180),A(47,-11,177),A(50,-12,170),A(42,-13,172)],up,9)
        g.polygon([A(41,-11.4,178.5),A(47,-11.6,176),A(48,-12.5,172)],up,10)
        # Relaxed hands with a separate thumb and four tapered, curved fingers.
        g.oval(A(69,-6,124),(8,6.9,11),hand,'skin',16,9)
        for f in range(4):
            xx=65+f*3; zz=118+abs(f-1.5)*1.4
            g.tube([A(xx,-7,zz+5),A(xx+2.2,-8,zz),A(xx+2.7,-9,zz-4+abs(f-1))],[2.5,2.3,1.2],hand,'skin',n=8)
        g.tube([A(65,-8,126),A(62,-11,122),A(61,-11,117)],[3.4,3,1.5],hand,'skin',n=8)
        long=i in [2,5]
        # Shorts or tracksuit trousers with a side stripe and ribbed ankle.
        g.oval(P(26,0,98),(16,15,27),thigh,'skin')
        if long:
            g.tube([P(23,0,121),P(24,1,107),P(27,0,91),P(28,-1,77)],[20,21,20,17],thigh,'pants',n=18)
            g.tube([P(28,-1,79),P(29,0,65),P(31,2,48),P(32,1,38)],[17,19 if i==5 else 17,19 if i==5 else 14,13],shin,'pants',n=18)
            for spacing in ([0,3.5] if i==2 else [0]):
                g.tube([P(41+spacing,-7,120),P(43+spacing,-6,105),P(45+spacing,-6,89),P(44+spacing,-6,77)],[1.2,1.6,1.6,1.3],thigh,9,n=6)
                g.tube([P(44+spacing,-6,79),P(46+spacing,-5,67),P(47+spacing,-5,51),P(43+spacing,-4,39)],[1.3,1.7,1.6,.9],shin,9,n=6)
        else:
            g.tube([P(23,0,121),P(24,0,113),P(25,0,102)],[20,21,20],thigh,'pants',n=20)
            g.tube([P(25,0,103),P(25.5,0,99)],[20.4,20],thigh,9,n=20,steps=1)
            g.tube([P(41,-4,120),P(43,-4,113),P(44,-4,104)],[1.8,2,1.8],thigh,9,n=7)
            g.tube([P(27,-1,82),P(28,-1,75),P(30,1,61),P(32,0,40)],[15.4,15.3,14,12.5],shin,'skin',n=20)
            g.tube([P(29,0,74),P(30,1,65),P(32,0,43),P(32,0,34)],[16.1,16,13.7,13],shin,9,n=20)
            g.tube([P(29.5,.5,69),P(30,1,63)],[16.2,16.1],shin,'sock',n=20,steps=1)
        # Shoes are lasted over an asymmetric toe box; rubber sole has its own rounded lip.
        x=k*33
        for rings,cc in [
            ([(0,25,36,x,-8),(1.6,29,40,x,-8),(4.2,30,41,x,-8)],14),
            ([(3.1,29.7,41,x,-8),(5,31,42,x,-8),(13,31.5,42.5,x,-8),(16,30.3,41,x,-8)],9),
            ([(13,29,40,x,-8),(18,30,40.5,x,-8),(24,28.5,36,x,-6),(33,24,30,x,-2),(39,19,20,x,4)],'shoe'),
            ([(33,19,18,x,5),(39,20,19,x,5),(42,17,16,x,5)],'shoe')]:
            n=36
            rows=[[(cx+rx*sin(-pi+j*2*pi/n),cy-ry*cos(-pi+j*2*pi/n),z) for j in range(n)] for z,rx,ry,cx,cy in rings]
            g.grid(rows,foot,cc,tex=lambda a,b:uv(1+685*b/n,761+55*(rings[a][0])/42))
        g.oval((x,-13,36),(12,15,9),foot,'shoe',16)
        for q in range(3):
            y=-17-q*6;z=36-q*3
            g.tube([(x-14,y+2,z-2),(x-9,y-1,z+.9),(x,y-2,z+2.2),(x+9,y-1,z+1),(x+14,y+1,z-2)],[2,2.6,2.8,2.6,2],foot,9,n=8)
        g.tube([(x-18,-37,20),(x-13,-43,19),(x,-47,18),(x+13,-43,19),(x+18,-37,20)],[1,1.6,1.7,1.6,1],foot,9,n=7)
        g.tube([(x+k*16,17,33),(x+k*22,12,29),(x+k*26,4,23),(x+k*29,-3,20)],[2,3,3,1.1],foot,9,n=7)
        # Raised tread pods are visible during toe-off and jumping.
        for yy in [-30,-12,7,17]:
            g.oval((x,yy,.9),(18 if yy<10 else 12,3.8,.9),foot,14,12,4)

CLIPS={'idle':60,'run':20,'jump':24,'land':10,'stumble':24,'fall':24,'finish':48}
def clamp(x,a,b):return max(a,min(b,x))
def make_pose(rig,i,state,t):
    pbs=rig.pose.bones
    swing=2*pi*t
    for b in pbs:
        b.rotation_mode='QUATERNION'
        b.rotation_quaternion=Quaternion(); b.location=(0,0,0);b.scale=(1,1,1)
    def rotate(name,x=0,y=0,z=0):
        b=pbs[name];basis=b.bone.matrix_local.to_quaternion()
        b.rotation_quaternion=basis.inverted()@Euler((x,y,z)).to_quaternion()@basis
    def translate(name,x,y,z):
        b=pbs[name];b.location=b.bone.matrix_local.to_quaternion().inverted()@(V((x,y,z))*M)
    bb=.5-.5*cos(swing)
    shift=0;lean=0;turn=0;roll=0;head_nod=0;hair=0
    if state=='idle':
        shift=1.1*bb;head_nod=.012*cos(swing);hair=.035*sin(swing)
    if state=='run':
        shift=-25+11*sin(2*swing);lean=.13; turn=.065*sin(swing);head_nod=.034*cos(2*swing);hair=.10*sin(2*swing-.85)
    if state=='jump':
        shift=-4-12*math.exp(-((t-.06)/.11)**2);lean=.14+.12*sin(pi*t);head_nod=-.045*sin(pi*t);hair=.21*sin(2*pi*t-.5)
    if state=='land':
        shift=-17*max(0,sin(pi*(.15+.85*t)))**1.5;lean=.24*(1-t);head_nod=.08*sin(pi*t);hair=.23*sin(2*pi*t-.45)*(1-t)
    if state=='stumble':
        shift=-8*sin(pi*t);lean=.35*sin(pi*t);roll=.16*sin(4*pi*t)*(1-t);hair=.27*sin(4*pi*t-.4)*(1-t)
    if state=='fall':
        shift=-7*sin(pi*t);lean=.18*sin(pi*t);roll=.18*sin(2*pi*t);hair=.25*sin(pi*t)
    if state=='finish':
        shift=1.6*bb;head_nod=-.06*bb;hair=.065*sin(swing)
    translate('Pelvis',0,0,shift)
    rotate('Chest',lean,roll,turn)
    rotate('Head',-.66*lean+head_nod,-roll*.42,-turn*.45)
    rotate('Ornament',hair,.055*sin(swing-.5) if state!='idle' else 0,hair*.48)
    for side,k in [('L',1),('R',-1)]:
        phase=(t+(.5 if k<0 else 0))%1
        th=0;kn=0;ankle=0; arm=0;el=0;sidearm=0;hand=0
        if state=='idle':
            arm=-.045*bb;el=-.10-.05*bb
            if i==3 and k>0:
                arm=-1.75*bb;el=-1.4*bb;sidearm=.94*bb
        if state=='run':
            # Two-link leg IK anchors soles throughout the support half of the cycle.
            if phase<.28:
                q=phase/.28;ay=-57+117*q
                rise=15*max(0,(q-.72)/.28)**2
                toe=.30*max(0,(q-.72)/.28)**2
            else:
                q=(phase-.28)/.72;ay=1.5+58.5*cos(q*pi);rise=15*(1-q)+35*sin(q*pi);toe=.3*(1-q)-.22*sin(q*pi)
            length=clamp(sqrt(ay*ay+(116+shift-37-rise)**2),12,78.7)
            kn=acos(clamp((length*length-39*39-40*40)/(2*39*40),-1,1))
            th=atan2(ay,(116+shift-37-rise))-atan2(40*sin(kn),39+40*cos(kn))
            ankle=-th-kn+toe
            arm=.68*cos(phase*2*pi-.08);el=-.85+.25*sin(phase*2*pi);sidearm=.06
        if state=='jump':
            apex=sin(pi*t);early=math.exp(-((t-.07)/.14)**2)
            th=(-1.19 if k>0 else .17)*apex-.42*early
            kn=(.55 if k>0 else 1.35)*apex+.86*early
            ankle=-.48*(th+kn)
            arm=(-.94 if k<0 else .52)*apex;el=-.34-.33*early
            sidearm=.48*apex+.14;hand=-.2*apex
        if state=='land':
            compression=max(0,sin(pi*(.15+.85*t)))
            th=(-.70 if k>0 else -.39)*compression
            kn=(1.31 if k>0 else 1.04)*compression
            ankle=-th-kn;arm=-.92*compression;el=-.32*compression
            sidearm=(.59 if i==1 else .25)*compression
        if state in ['fall','stumble']:
            th=(-.52 if k>0 else .45)*sin(pi*t);kn=.47*sin(pi*t)
            ankle=-th*.6;arm=-.25+(.74 if k>0 else -.88)*sin(swing)
            el=-.43;sidearm=.92*sin(pi*t)+.1
        if state=='finish':
            if i==4:
                arm=-1.79 if k>0 else -.05;el=-1.16 if k>0 else -.1; sidearm=.52 if k>0 else .03
            elif i==5:
                sidearm=(.99+.24*sin(swing*2)) if k>0 else .05;el=(-1.14-.2*bb) if k>0 else -.1
            else:
                arm=-.48-.22*bb;el=-1.05-.13*bb;sidearm=.94+.12*bb
        rotate('Thigh.'+side,th)
        rotate('Shin.'+side,kn)
        rotate('Foot.'+side,ankle)
        rotate('UpperArm.'+side,arm,-k*sidearm)
        rotate('Forearm.'+side,el)
        rotate('Hand.'+side,hand,0,k*sidearm*.15)
        rotate('Lock.'+side,hair*(1 if i==4 else .7),k*hair*.45)
    blink=1. if ((state=='idle' and .80<t<.88) or (state=='land' and .14<t<.43) or (state=='stumble' and t<.24) or (state=='finish' and .80<t<.89)) else .01
    pbs['Blink'].scale=(blink,blink,blink)
def actions(rig,i):
    anim=rig.animation_data_create()
    for state,frames in CLIPS.items():
        act=bpy.data.actions.new(f'{CAST[i]["name"]}_{state}');anim.action=act
        for frame in range(frames+1):
            if state!='run' and frame%2 and frame!=frames:continue
            make_pose(rig,i,state,frame/frames)
            for b in rig.pose.bones:
                b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
                if b.name=='Pelvis':b.keyframe_insert('location',frame=frame,group=b.name)
                if b.name=='Blink':b.keyframe_insert('scale',frame=frame,group=b.name)
        track=anim.nla_tracks.new();track.name=state
        track.strips.new(state,0,act);track.mute=True
        anim.action=None
    make_pose(rig,i,'idle',0)
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc=bpy.context.scene;sc.render.fps=30
    rigs=[]
    for i,c in enumerate(CAST):
        rig=skel(i);g=Surface(c['name']+'_painted_mesh')
        head(g,i);outer_hair(g,i);decoration(g,i);clothes(g,i)
        ob=g.object(make_material(i),rig);actions(rig,i)
        rig.rotation_euler.z=pi
        bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True)
        bpy.context.view_layer.objects.active=rig;bpy.context.view_layer.update()
        bpy.ops.export_scene.gltf(filepath=str(GAME/f'{i+1:02}.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_step=1,export_optimize_animation_size=True,export_yup=True,export_apply=False,export_cameras=False,export_lights=False)
        rigs.append(rig)
        if '--single' in args:break
    for i,rig in enumerate(rigs):rig.location.x=-(i-(len(rigs)-1)/2)*1.05
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'ribbon-rally.blend'),compress=True)
if __name__=='__main__':main()
