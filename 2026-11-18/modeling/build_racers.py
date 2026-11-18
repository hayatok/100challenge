"""Blender 5.x background build. Pass the directory prepared by paint_atlas.py after --."""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector, Euler, Quaternion
from math import sin, cos, pi, sqrt, atan2, acos
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from forms import CAST, PALETTE, M, profile, hair_profile, station_width
from hair_sculpt import cap_and_locks
from face_rig import build_face
from athletic_kit import sleeve, hand, legs, sneaker
from performance_poses import PERFORMANCE_CLIPS, performance_pose
from sport_poses import sport_pose, support_geometry
args=sys.argv[sys.argv.index('--')+1:]
TEX=Path(args[0]); GAME=HERE.parent/'game'/'racers'
V=Vector
def uv(x,y):return (x/1024,1-y/1024)
def pigment(k):
    if isinstance(k,str):k=PALETTE.index(k)
    return uv(k*32+16,544)

class Surface:
    def __init__(self,name):
        self.name=name;self.verts=[];self.faces=[];self.uvs=[];self.bones=[];self.blends=[]

    def grid(self,rows,bone,color,wrapped=True,reverse=False,tex=None,cap=True,face_tex=None):
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
                if face_tex: coords=face_tex(a,b)
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
    def feather(self, first, end, rows, bone, strength):
        per_row = (end-first)//rows
        for index in range(first, end):
            along = ((index-first)//per_row)/(rows-1)
            t = clamp((along-.37)/.56,0,1)
            if t:
                self.blends.append((index,bone,strength*t*t*(3-2*t)))

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
        for vertex,bone,weight in self.blends:
            group=ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
            group.add([vertex],weight,'REPLACE')
            ob.vertex_groups[self.bones[vertex]].add([vertex],1-weight,'REPLACE')
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
    if i==0:bones['Ornament']=((87,-46,324),'Head')
    if i==2:bones['Ornament']=((-28,48,340),'Head')
    if i==3:bones['Ornament']=((0,7,329),'Head')
    if i==5:bones['Ornament']=((41,73,238),'Head')
    for s,sgn in [('L',1),('R',-1)]:
        for name,pos,parent in [
            ('Thigh',(sgn*24,0,116),'Pelvis'),('Shin',(sgn*28,-1,77),'Thigh.'+s),
            ('Foot',(sgn*32,0,37),'Shin.'+s),('UpperArm',(sgn*33,1,184),'Chest'),
            ('Forearm',(sgn*60,-1,153),'UpperArm.'+s),('Hand',(sgn*76,-5,130),'Forearm.'+s),
            ('Lock',(sgn*67,12,245),'Head')]:
            if i==4 and name=='Lock':
                pos=(sgn*65,12,217)
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
    g.grid(rows,'Head','hair',reverse=True,tex=lambda a,b:uv(1+(1022*b/n),325+185*a/steps))
    # Warm ear cups sit behind the free temple locks. The small nose follows
    # the same curved skin as the eyes and protrudes only near its rounded tip.
    for sign in (-1,1):
        xx,yy,zz=profile(c,sign*1.28,.78)
        g.oval((xx,yy+(9 if i==0 else -2),zz+2),(8.5,6.8,12.8),'Head','skin',18,10)
        g.oval((xx+sign*4.7,yy+(6 if i==0 else -5.4),zz+1.3),(4.4,3.4,7.4),'Head',23,14,8)
    nose_row=[157,184,186,181,189,178][i]
    v=(nose_row-c['stations'][0][0])/(c['stations'][-1][0]-c['stations'][0][0])
    p=V(profile(c,0,v))
    g.oval(p+V((0,.45,.8)),(2.85,2.8,2.15),'Head','skin',14,8)
    g.oval((0,0,198),(17,14,20),'Chest','skin')

def decoration(g,i):
    lock=lambda points,r,b='Ornament',c='hair',flat=.7:g.tube(points,r,b,c,flat,12,3)
    if i==0:
        # The left-temple bow is asymmetrical. One loop points upward, one extends out;
        # two folded swallow tails trail lower on the side of the bob.
        def bow_surface(outline,center,depth):
            # Coordinates in the calibrated front view. Convex folded cross-sections
            # give the loops volume and carry the original designer's crease painting.
            rings=[]
            # Sideways bow centre and folds are taken from the profile, where
            # the upper loop reaches back and the swallow tail hangs over the ear.
            for t in [.035,.36,.72,1,.72,.36,.035]:
                front=len(rings)<4; row=[]
                for px,py in outline:
                    qx=center[0]+(px-center[0])*t;qy=center[1]+(py-center[1])*t
                    # All panels meet at the same temple knot. Project
                    # them onto the side of the hair, then roll the silk
                    # away from the scalp around the fold.
                    sy=clamp((qy-21)/177,0,1)
                    yy=-46+(qx-343)*.96-(qy-75)*.22
                    _,mid,_=hair_profile(CAST[0],pi/2,sy)
                    _,edge,_=hair_profile(CAST[0],0 if yy<mid else pi,sy)
                    r=station_width(CAST[0],qy)
                    shell=.975*r*sqrt(max(0,1-((yy-mid)/max(1,abs(edge-mid)))**2))
                    x=max(qx-273+13,shell+7.4)+(1 if front else -1)*depth*(1-t*t)
                    yy-=(1 if front else -1)*depth*.55*(1-t*t)
                    row.append((x,yy,398-qy))
                rings.append(row)
            def bow_uv(a,b):
                t=(.035,.36,.72,1,.72,.36,.035)[a]
                px,py=outline[b%len(outline)]
                return uv(710+(center[0]+(px-center[0])*t-311)*154/75,
                          561+(center[1]+(py-center[1])*t-12)*250/125)
            g.grid(rings,'Ornament',15,tex=bow_uv)
        bow_surface([(343,72),(331,68),(321,62),(316,53),(315,41),(316,31),(321,21),(327,15),(332,17),(340,25),(349,35),(352,43),(351,52),(347,62)],(333,45),8)
        bow_surface([(343,72),(349,66),(357,61),(366,60),(374,62),(378,68),(378,79),(375,91),(371,98),(364,98),(354,90),(348,83)],(363,78),7)
        bow_surface([(343,76),(350,79),(359,88),(370,103),(381,118),(377,122),(357,132),(352,130),(348,116),(344,95)],(358,104),4)
        g.oval((87,-46,325),(10,10,10),'Ornament',15,20)
    if i==1:
        for s,sign in [('L',1),('R',-1)]:
            b='Lock.'+s
            center=V((sign*70,12,339))
            g.oval(center,(32.5,28,30),b,'hair',24,12)
            for lobe in range(6):
                angle=lobe*2*pi/6
                coil=[center+V((sign*(25-7*u)*cos(angle+1.26*u),
                                (22-5*u)*sin(angle+1.26*u),-15+39*u)) for u in (0,.21,.49,.76,1)]
                lock(coil,[8,12,14,12,3],b,'hair',.89)
            for t in range(6):
                phase=t/5
                g.oval((sign*(49+38*phase),-17.5-8*sin(pi*phase),337-26*phase),
                       (5.3,6,5.8),b,12,14,7)
            for j in (0,1):
                x=sign*(84+7*j)
                lock([(x,-14+4*j,292-7*j),(x+sign*9,-25,270),
                      (x-sign*4,-40,252-9*j),(x+sign*6,-38,237-10*j),
                      (x+sign*13,-30,242-11*j)], [8,11,9,5,.4],b,'hair',.78)
    if i==2:
        # Separate overlapping waves unfurl from the high tie. Vary the
        # bend and free end of each lock, including the hollow return loop.
        for offset in (-1,0,1):
            q=offset
            path=[(-30+9*q,47+6*q,338),(-47+9*q,57+7*q,358+5*q),
                  (-71+11*q,64+8*q,354+6*q),(-86+12*q,68+9*q,322),
                  (-93+11*q,68+9*q,283),(-85+9*q,63+11*q,249),
                  (-86+11*q,53+11*q,218),(-106+8*q,42+11*q,186+4*q),
                  (-111+9*q,34+10*q,154+6*q),(-98+12*q,31+11*q,136+8*q),
                  (-79+12*q,33+11*q,143+11*q),(-75+12*q,37+11*q,154+11*q)]
            lock(path,[9,16,19,19,18,16,16,15,13,11,6,.4],flat=.66)
        g.oval((-33,39,337),(26,19,14),'Ornament',20)
        for j in range(4):g.oval((-51+j*13,25,343+j*2),(10,10,10),'Ornament',20)
    if i==3:
        # Woven visor band wraps around the skull, and the crescent bill projects forward.
        n=68
        def visor_band(a,level):
            z=287+level+15*sin(a)
            v=clamp((CAST[i]['floor']-z/CAST[i]['k']-50)/166,0,1)
            p=V(hair_profile(CAST[i],a,v))
            normal=V((sin(a),-cos(a),0))
            p+=normal*(9+3.5*max(0,cos(a))+.7*sin(pi*level/39))
            p.z=z
            return p
        band=[[visor_band(-pi+j*2*pi/n,dz) for j in range(n)] for dz in (0,2,11,27,37,39)]
        g.grid(band,'Head',12)
        brim=[]
        for j in range(8):
            t=j/7;row=[]
            for k in range(37):
                a=-1.43+k*2.86/36
                p=visor_band(a,3)
                p+=V((sin(a)*10*t,-(7+15*cos(a))*t,
                      -3.1*t+3.6*sin(pi*t)))
                row.append(p)
            brim.append(row)
        g.grid(brim,'Head',12,False,True,cap=False)
        g.tube(brim[-1],[1.85]*len(brim[-1]),'Head',29,n=8,steps=1)
        def mark(a,z,offset=0):
            return visor_band(a,z)+V((sin(a),-cos(a),0))*(1.1+offset)
        g.polygon([mark(-.12,13),mark(.12,13),mark(0,29)],'Head',9)
        g.polygon([mark(-.028,16,.3),mark(.074,16,.3),mark(-.01,24,.3)],'Head',12)
        lock([(-2,9,350),(-10,13,370),(-27,17,382),(-47,19,383),(-56,21,378)],[8,10,8,4,.5],c='hair')
        for s,sign in [('L',1),('R',-1)]:
            lock([(sign*69,18,300),(sign*87,17,287),(sign*100,10,279),(sign*111,7,284)],[11,11,7,.6],'Lock.'+s)
    if i==4:
        for s,sign in [('L',1),('R',-1)]:
            b='Lock.'+s
            for strand in range(3):
                path=[];radii=[]
                for step in range(24):
                    t=step/23
                    phase=t*4.7*pi+strand*2*pi/3
                    path.append((sign*(65+12*t+(9-3*t)*sin(phase)),
                                 -5-(6.8-2*t)*cos(phase),224-68*t))
                    radii.append(8.1-2.8*t)
                g.tube(path,radii,b,'hair',.81,10,2)
            for offset in (-1,1):
                lock([(sign*77,-6+3*offset,156),(sign*(78+4*offset),-7,145),
                      (sign*(81+4*offset),-9,131),(sign*(74+5*offset),-8,116),
                      (sign*(68+4*offset),-3+3*offset,114+2*offset)],
                     [5.4,9.1,9,5,.4],b)
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
    torso=[(124,35,22.8,0,1.4),(128,37.7,24.8,0,1.7),(132,41,26.2,0,1.6),(138,42.8,27.4,0,1.5),(146,41.6,28.1,0,.9),(155,37.8,27.4,0,.4),(170,36.7,26,0,.2),(181,34.7,23,0,.1),(190,29,20,0,1),(197,18,14,0,2)]
    n=48
    rings=[]
    for z,rx,ry,x,y in torso:
        radius=max(0,1-abs(z-138)/18)
        row=[]
        for j in range(n):
            a=-pi+j*2*pi/n
            side=abs(sin(a))
            fold=1.6*sin(5*a+.13*z)*side*radius
            row.append((x+(rx+fold)*sin(a),y-(ry+fold)*cos(a),z+1.3*side*sin(2*a+.7)*radius))
        rings.append(row)
    g.grid(rings,'Chest','jacket',tex=lambda a,b:uv(1+1022*b/n,819+204*(torso[a][0]-125)/72))
    for z0,z1,c in [(124,126,10),(126,128,'sleeve'),(128,130,9)]:
        g.loft([(z0,37.7,25.4,0,1.7),(z1,38.9,26.2,0,1.7)],'Chest',c)
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
        foot='Foot.'+s
        sleeve(g,i,s,k)
        hand(g,s,k)
        legs(g,i,s,k)
        sneaker(g,s,k)

def clamp(x,a,b):return max(a,min(b,x))

def make_pose(rig,i,state,t,support):
    for b in rig.pose.bones:
        b.rotation_mode='QUATERNION'
        b.rotation_quaternion=Quaternion()
        b.location=(0,0,0)
        b.scale=(1,1,1)
    performance_pose(rig,i,state,t,support)

def actions(rig,i,support):
    anim=rig.animation_data_create()
    for state,frames in PERFORMANCE_CLIPS.items():
        act=bpy.data.actions.new(f'{CAST[i]["name"]}_{state}');anim.action=act
        for frame in range(frames+1):
            make_pose(rig,i,state,frame/frames,support)
            for b in rig.pose.bones:
                b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
                if b.name=='Pelvis':b.keyframe_insert('location',frame=frame,group=b.name)
                if b.name=='Blink':b.keyframe_insert('scale',frame=frame,group=b.name)
        track=anim.nla_tracks.new();track.name=state
        track.strips.new(state,0,act);track.mute=True
        anim.action=None
    make_pose(rig,i,'idle',0,support)
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc=bpy.context.scene;sc.render.fps=30
    rigs=[]
    for i,c in enumerate(CAST):
        rig=skel(i);g=Surface(c['name']+'_painted_mesh')
        head(g,i);cap_and_locks(g,i);decoration(g,i);clothes(g,i)
        material=make_material(i)
        ob=g.object(material,rig);face=build_face(i,rig,material)
        # Contact solvers sample the owner of the deformed surface. The
        # sleeve cuff, knee and hair tips may be driven by the following bone.
        for vertex,bone,weight in g.blends:
            if weight>=.5:g.bones[vertex]=bone
        actions(rig,i,support_geometry(g))
        rig.rotation_euler.z=pi
        bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);ob.select_set(True);face.select_set(True)
        bpy.context.view_layer.objects.active=rig;bpy.context.view_layer.update()
        bpy.ops.export_scene.gltf(filepath=str(GAME/f'{i+1:02}.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_step=1,export_optimize_animation_size=True,export_yup=True,export_apply=False,export_cameras=False,export_lights=False)
        rigs.append(rig)
        if '--single' in args:break
    for i,rig in enumerate(rigs):rig.location.x=-(i-(len(rigs)-1)/2)*1.05
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'ribbon-rally.blend'),compress=True)
if __name__=='__main__':main()
