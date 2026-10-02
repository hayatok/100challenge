"""BLACK RELAY original low-poly asset generator. Blender 4.3.2.
Run: blender -b --python source/generate_black_relay.py
Front in Blender is -Y, exported glTF/Godot front is +Z. 1 unit = 1 metre.
All geometry and materials are original procedural work; no external assets.
"""
import bpy, math, os, json, random
from mathutils import Vector
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent
MODELS = OUT / 'models'; PREVIEWS = OUT / 'previews'
for p in (MODELS, PREVIEWS): p.mkdir(parents=True, exist_ok=True)
random.seed(812)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in list(bpy.data.materials): bpy.data.materials.remove(d)

def mat(name, rgb, metal=0., rough=.5, emission=0.):
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*rgb,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    if emission:
        p.inputs['Emission Color'].default_value=(*rgb,1)
        p.inputs['Emission Strength'].default_value=emission
    return m

M = {
 'ceramic':mat('Bone | fired ceramic',(.847,.839,.737),.16,.34),
 'edge':mat('Porcelain | chipped edges',(.93,.91,.74),.06,.48),
 'tar':mat('Carbon | wet black cables',(.015,.025,.028),.35,.26),
 'steel':mat('Iron | oxidised green steel',(.082,.125,.124),.75,.42),
 'rust':mat('Oxide | dark copper',(.24,.075,.025),.65,.53),
 'amber':mat('Signal | living amber', (1.,.43,.055),.05,.35,3.),
 'teal':mat('Emergency | phosphor teal',(.025,.65,.61),.05,.3,2.),
 'red':mat('Warning | dry vermilion',(.42,.042,.013),.25,.5),
 'yellow':mat('Safety | aged ochre',(.78,.43,.055),.2,.55),
}
ROOT=None; PART=None

def empty(name,loc=(0,0,0),parent=None):
    ob=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(ob)
    ob.location=loc
    if parent: ob.parent=parent; ob.matrix_parent_inverse=parent.matrix_world.inverted()
    bpy.context.view_layer.update()
    return ob

def begin(name):
    global ROOT,PART
    ROOT=empty(name); PART=ROOT
    return ROOT

def part(name,loc=(0,0,0)):
    global PART
    PART=empty(name,loc,ROOT)
    return PART

def finish_obj(ob,name,material,bevel=0):
    ob.name=name
    ob.data.materials.append(M[material])
    if bevel:
        mod=ob.modifiers.new('Small manufactured edge bevel','BEVEL'); mod.width=bevel; mod.segments=1
        bpy.context.view_layer.objects.active=ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new('Weighted face normals','WEIGHTED_NORMAL'); mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if PART:
        world=ob.matrix_world.copy(); ob.parent=PART; ob.matrix_world=world
    return ob

def cube(name,loc,size,material='steel',bevel=.008,rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    ob=bpy.context.object; ob.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if rot: ob.rotation_euler=rot
    return finish_obj(ob,name,material,bevel)

def ico(name,loc,scale,material='tar',sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc)
    ob=bpy.context.object; ob.scale=scale
    return finish_obj(ob,name,material)

def beam(name,a,b,r,material='tar',r2=None,verts=8):
    delta=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=r if r2 is None else r2,depth=delta.length,location=(Vector(a)+Vector(b))/2)
    ob=bpy.context.object; ob.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    return finish_obj(ob,name,material)

def cable(name,points,r=.025,material='tar'):
    cu=bpy.data.curves.new(name,'CURVE'); cu.dimensions='3D'; cu.resolution_u=1
    cu.bevel_depth=r; cu.bevel_resolution=1; cu.resolution_u=1
    spl=cu.splines.new('POLY'); spl.points.add(len(points)-1)
    for v,p in zip(spl.points,points):v.co=(*p,1)
    ob=bpy.data.objects.new(name,cu); bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active=ob; ob.select_set(True)
    bpy.ops.object.convert(target='MESH'); ob=bpy.context.object
    return finish_obj(ob,name,material)

def ring(name,loc,major,minor,material='steel',rotation=(math.pi/2,0,0),segs=20):
    bpy.ops.mesh.primitive_torus_add(major_segments=segs,minor_segments=6,location=loc,major_radius=major,minor_radius=minor,rotation=rotation)
    return finish_obj(bpy.context.object,name,material)

def bolt(loc,r=.018,material='rust'):
    return beam('Hex retaining bolt',(loc[0],loc[1]+.014,loc[2]),(loc[0],loc[1]-.014,loc[2]),r,material,verts=6)

def wedge(name,center,ra,rb,a0,a1,depth,material='ceramic'):
    # Segment of a ceramic annulus, standing in the X/Z plane, face toward -Y.
    x,y,z=center; verts=[]
    for yy in (y-depth/2,y+depth/2):
        for rr,aa in ((ra,a0),(rb,a0),(rb,a1),(ra,a1)):
            verts.append((x+rr*math.sin(aa),yy,z+rr*math.cos(aa)))
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active=ob; ob.select_set(True)
    return finish_obj(ob,name,material,.008)

def mask(center,width=.32,height=.4):
    x,y,z=center
    ico('Fired porcelain hood',(x,y+.05,z),(width*.62,.145,height*.65),'ceramic',1)
    # Recessed face, overhanging broken ceramic brow and cheek fins.
    cube('Face void',(x,y-.06,z-.015),(width*.78,.1,height*.69),'tar',.025)
    cube('Heavy ceramic brow',(x,y-.122,z+height*.27),(width,.075,.06),'edge',.014)
    for s in (-1,1):
        cube('Porcelain cheek',(x+s*width*.42,y-.10,z-.04),(.042,.075,height*.62),'ceramic',.012,rot=(0,s*.15,s*.08))
    for dz,w in ((.075,.72),(.004,.56),(-.067,.32)):
        cube('Amber diagnostic slit',(x,y-.117,z+dz),(width*w,.018,.027),'amber',.003)

def disc_mask(center,radius=.21,slits=3):
    """Original split ceramic face: asymmetric manufactured mask, not a skull."""
    x,y,z=center
    ico('Black disc-mask backing',(x,y+.03,z),(radius,.068,radius),'tar',2)
    for a,b in ((.09,1.39),(1.59,3.03),(3.22,4.56),(4.76,6.14)):
        wedge('Split ivory face',(x,y-.014,z),radius*.32,radius,a,b,.060,'ceramic')
    cube('Porcelain split brow',(x,y-.062,z+radius*.34),(radius*1.32,.055,.045),'edge',.009)
    for i in range(slits):
        cube('Amber mask slit',(x,y-.077,z+.012-i*.052),(radius*(1.08-i*.18),.018,.022),'amber',.003)
    bolt((x-radius*.73,y-.071,z+radius*.10),.014)
    bolt((x+radius*.73,y-.071,z-radius*.10),.014)

def maker_walker():
    root=begin('enemy_walker')
    part('body',(0,0,.97))
    # Segmented cable spine and floating ceramic rib plates.
    beam('Spine trunk',(0,.05,.66),(0,.03,1.34),.074,'tar')
    cube('Relay thorax',(0,.01,1.17),(.37,.27,.39),'steel',.05)
    for i in range(5):
        z=.89+i*.087
        beam('Copper vertebra',(-.11,.025,z),(.11,.025,z),.047,'rust',verts=8)
        for s in (-1,1):
            cable('Exposed rib cable',[(s*.035,-.08,z),(s*.18,-.12,z+.02),(s*.23,0,z+.065),(s*.16,.13,z+.087)],.029)
    for s in (-1,1):
        cube('Split chest ceramic',(s*.13,-.17,1.205),(.13,.075,.22),'ceramic',.02,rot=(0,s*.15,s*-.15))
    ico('Heart socket',(0,-.205,1.15),(.09,.055,.105),'tar',2)
    ico('Exposed signal heart',(0,-.25,1.15),(.05,.025,.062),'amber',2)
    cube('Pelvic connector',(0,0,.70),(.25,.21,.13),'steel',.022)
    # Deliberately asymmetrical shoulders and dangling cable loops.
    ico('Left shoulder plate',(-.285,.0,1.28),(.18,.16,.14),'ceramic',1)
    cube('Right junction block',(.29,.02,1.28),(.18,.23,.19),'steel',.03)
    for i in range(3):
        cable('Dangling left wires',[(-.27+i*.035,.09,1.24),(-.4+i*.025,.12,.92),(-.37+i*.019,.13,.79),(-.25+i*.035,.03,.97)],.013,'tar')
    part('head',(0,-.015,1.47))
    beam('Exposed neck',(0,.02,1.30),(0,-.025,1.5),.04,'rust')
    disc_mask((0,-.105,1.515),.215)
    # offset tuning antenna, distinct from normal human silhouette.
    beam('Tuning aerial',(.125,.01,1.59),(.155,.02,1.73),.011,'steel')
    ico('Aerial cap',(.155,.02,1.73),(.025,.025,.018),'amber')
    for s in (-1,1):
        part('arm_L' if s<0 else 'arm_R',(s*.30,0,1.26))
        elbow=(s*.43,-.01,.98); wrist=(s*.47,-.18,.67)
        beam('Cable upper arm',(s*.31,0,1.25),elbow,.049,'tar')
        beam('Ceramic forearm',elbow,wrist,.064,'ceramic',.042)
        ico('Elbow bearing',elbow,(.078,.074,.079),'rust',1)
        ico('Gripper palm',wrist,(.064,.046,.075),'steel',1)
        for j in range(3):
            xx=s*.47+(j-1)*.035
            cable('Three-prong wire finger',[(xx,-.18,.65),(xx+s*.01,-.2,.55),(xx+s*.004,-.27,.50)],.012,'tar')
        cable('Arm tension hose',[(s*.35,.04,1.2),(s*.51,.075,1.00),(s*.49,-.1,.73)],.019,'tar')
        part('leg_L' if s<0 else 'leg_R',(s*.10,0,.69))
        knee=(s*.14,-.11,.40); ankle=(s*.18,.05,.09)
        beam('Upper leg piston',(s*.10,0,.68),knee,.057,'tar')
        cube('Thigh plate',(s*.13,-.085,.55),(.103,.09,.22),'ceramic',.022,rot=(.25,0,s*.11))
        ico('Knee retaining joint',knee,(.075,.075,.068),'rust')
        beam('Shin cable',knee,ankle,.039,'tar')
        beam('Shin ceramic splint',(s*.16,-.12,.37),(s*.18,.01,.15),.039,'ceramic',.022)
        cube('Split industrial foot',(s*.18,-.055,.045),(.12,.23,.085),'steel',.015)
        for j in (-1,1):beam('Toe prong',(s*.18+j*.035,-.16,.03),(s*.18+j*.037,-.24,.025),.018,'tar')
    root.scale=(1.08,1.08,1.08)
    return root

def maker_crawler():
    root=begin('enemy_crawler'); part('body',(0,0,.47))
    ico('Low relay chassis',(0,.0,.47),(.35,.4,.20),'steel',1)
    ico('Broken ceramic carapace',(0,.07,.61),(.37,.35,.22),'ceramic',1)
    # Stepped ridges give a spinal, electrical-insulator silhouette.
    for i in range(4):
        cube('Carapace ridge',(0,.22-i*.13,.7-abs(i-1.5)*.016),(.40-i*.025,.067,.13),'edge',.015)
    for s in (-1,1):
        for j in range(3):
            y=.27-j*.25
            cable('Exposed abdominal wire',[(s*.15,y,.63),(s*.29,y,.5),(s*.23,y-.02,.32)],.022,'tar')
        for j in (0,2):
            part(('leg_L_' if s<0 else 'leg_R_')+str(j),(s*.24,.22-j*.22,.48))
            a=(s*.25,.24-j*.25,.48)
            b=(s*(.56+.08*(j==1)),.47-j*.44,.60 if j!=1 else .57)
            c=(s*(.78+.05*(j==1)),.57-j*.50,.06)
            beam('Radial leg root',a,b,.044,'tar')
            ico('Knee ball',b,(.067,.067,.067),'rust')
            beam('Porcelain tibia',b,(c[0]*.94,c[1],.15),.049,'ceramic',.025)
            beam('Hooked toe',(c[0]*.94,c[1],.15),c,.02,'tar',.008)
            cable('Hydraulic return',[a,(b[0],b[1]+.04,b[2]-.06),(c[0]*.95,c[1]+.03,.2)],.014,'tar')
    part('head',(0,-.31,.44))
    ico('Forward black sensor',(0,-.33,.44),(.21,.19,.17),'tar',1)
    cube('Sensor porcelain visor',(0,-.47,.50),(.34,.12,.12),'ceramic',.025)
    ico('Single amber optic',(0,-.505,.415),(.077,.035,.069),'amber',2)
    for s in (-1,1):
        cable('Jaw feeler',[(s*.13,-.42,.34),(s*.23,-.52,.24),(s*.16,-.64,.17)],.025,'rust')
    part('core',(0,.03,.45))
    ico('Exposed underbelly signal',(0,-.1,.33),(.18,.20,.07),'amber',1)
    part('spool',(0,.14,.55))
    for x in (-.27,-.09,.09,.27):
        ring('Exposed cable spool',(x,.13,.55),.235,.024,'tar',rotation=(0,math.pi/2,0),segs=16)
    part('tail',(0,.3,.47))
    for j in range(3):
        cable('Cut trailing transmission cable',[(j*.075-.075,.28,.49),(j*.08-.08,.51,.32),(j*.10-.1,.77,.21),(j*.14-.14,.89,.07)],.018,'tar')
    return root

def maker_beacon():
    root=begin('enemy_beacon');part('body',(0,0,1.38))
    # CHOIR: three suspended ceramic faces, no human body or legs.
    ico('Choir cable junction',(0,.03,1.5),(.27,.22,.23),'tar',1)
    beam('Triangular suspension L',(0,.11,1.86),(-.43,.07,1.56),.036,'rust')
    beam('Triangular suspension R',(0,.11,1.86),(.43,.07,1.56),.036,'rust')
    beam('Triangular suspension bottom',(-.43,.07,1.56),(.43,.07,1.56),.029,'rust')
    for i in range(11):
        a=i*math.tau/11;x=.20*math.cos(a);y=.16*math.sin(a)
        length=.82+(i%4)*.16
        cable('Cable skirt strand',[(x,y,1.52),(x*1.7,y*1.8,1.08),(x*2.1+.05*math.sin(i),y*2.1,.64),(x*1.75+.035*math.cos(i),y*1.7,1.46-length)],.026 if i%3 else .043,'tar')
        beam('Ceramic skirt ferrule',(x*1.7,y*1.8,.93),(x*1.7,y*1.8,1.06),.037,'ceramic')
    for idx,(x,z,r) in enumerate(((0,2.11,.255),(-.43,1.70,.22),(.43,1.70,.22))):
        part(('head','mask_left','mask_right')[idx],(x,-.11,z))
        cable('Face suspension hose',[(x,.02,z-.08),(x*.62,.14,1.54),(x*.4,.14,1.39)],.052,'tar')
        disc_mask((x,-.11,z),r)
        ring('Mask copper halo',(x,.015,z),r*1.14,.018,'rust',segs=16)
    part('core',(0,-.22,1.42))
    ico('Exposed choir signal',(0,-.22,1.42),(.080,.052,.12),'amber',2)
    return root

def maker_boss():
    root=begin('boss_relay'); part('body',(0,0,2.))
    # A suspended signal heart inside a severed shrine-like switching assembly.
    for s in (-1,1):
        cube('Vertical relay tower',(s*.93,.29,1.93),(.24,.40,2.72),'steel',.045)
        for z in (1.0,1.5,2.,2.5,3.):
            cube('Tower porcelain isolator',(s*.93,.29,z),(.38,.52,.14),'ceramic',.02)
            cube('Tower amber marker',(s*.945,.005,z),(.12,.032,.07),'amber',.006)
        # Heavy planted insectoid legs.
        for y in (-.35,.52):
            knee=(s*1.28,y*1.2,1.2); foot=(s*1.46,y*1.8,.07)
            beam('Supporting black thigh',(s*.9,.29,1.8),knee,.125,'tar')
            ico('Root knee',knee,(.20,.17,.18),'rust')
            beam('Porcelain supporting shin',knee,(s*1.4,y*1.7,.24),.16,'ceramic',.075)
            beam('Root foot',(s*1.4,y*1.7,.24),foot,.095,'steel',.12)
            cube('Anchor sole',foot,(.36,.40,.12),'steel',.025)
    beam('Upper crossbeam',(-1.04,.29,3.20),(1.04,.29,3.20),.16,'steel',verts=4)
    for i in range(5):
        x=(i-2)*.36; h=3.55+.44*(1-abs(i-2)/2)
        beam('Crown insulator stem',(x,.30,3.20),(x,.30,h),.044,'rust')
        for z in (h-.15,h):
            beam('Porcelain crown disc',(x,.3,z-.028),(x,.3,z+.028),.099,'ceramic',verts=10)
        ico('Crown amber terminus',(x,.30,h+.04),(.047,.047,.04),'amber',1)
    # Thick cables suspended around the open heart.
    for s in (-1,1):
        for j in range(4):
            cable('Catenary side transmission',[(s*(.17+j*.14),.36,3.18),(s*(.32+j*.18),.5,2.85),(s*(.52+j*.13),.53,2.0),(s*(.31+j*.16),.30,.93),(s*.85,.28,.7)],.043 if j%2 else .031,'tar')
    part('halo',(0,-.12,2.))
    ring('Iron containment hoop',(0,.0,2.06),.91,.085,'tar',segs=20)
    ring('Copper conductor hoop',(0,-.09,2.06),.77,.023,'rust',segs=20)
    for i in range(14):
        if i in (3,10):continue
        a0=i*2*math.pi/14+.037;a1=(i+1)*2*math.pi/14-.037
        wedge('Floating porcelain containment petal',(0,-.14,2.06),.74,1.0,a0,a1,.19,'ceramic' if i%3 else 'edge')
        a=(a0+a1)/2
        ico('Amber petal lock',(.875*math.sin(a),-.265,2.06+.875*math.cos(a)),(.044,.025,.044),'amber',1)
    part('core',(0,-.13,2.06))
    ico('Obsidian rear core socket',(0,.24,2.06),(.40,.12,.49),'tar',1)
    ico('Live amber core',(0,-.21,2.06),(.37,.30,.44),'amber',2)
    # Five vertical guards reveal slices of the glowing volume.
    for i in range(5):
        x=(i-2)*.143; ext=math.sqrt(max(.0,.24-x*x))
        beam('Core front black cage',(x,-.49,2.06-ext),(x,-.49,2.06+ext),.029,'tar')
    for z in (1.65,2.47):cube('Core porcelain cap',(0,-.10,z),(.57,.56,.09),'ceramic',.025)
    for idx,a in enumerate((0,math.tau/3,2*math.tau/3)):
        x=.90*math.sin(a);z=2.06+.90*math.cos(a)
        part(('head','mask_left','mask_right')[idx],(x,-.30,z))
        disc_mask((x,-.33,z),.215)
    return root

def maker_cabinet():
    root=begin('relay_cabinet');part('body')
    cube('Cabinet plinth',(0,0,.075),(.84,.59,.15),'tar',.025)
    cube('Sheet steel enclosure',(0,0,1.0),(.76,.52,1.85),'steel',.045)
    cube('Ivory maintenance door',(0,-.277,1.04),(.67,.045,1.70),'ceramic',.025)
    cube('Top power indicator socket',(0,-.311,1.70),(.42,.035,.15),'tar',.008)
    for i in range(4):cube('Status lamp',(-.135+i*.09,-.335,1.70),(.043,.012,.043),'amber' if i<3 else 'teal',.007)
    for j in range(3):
        cube('Voltage meter surround',(-.145+j*.145,-.320,1.44),(.116,.025,.15),'steel',.008)
        cube('Voltage meter glass',(-.145+j*.145,-.339,1.45),(.08,.012,.084),'tar',.003)
        beam('Voltage meter needle',(-.17+j*.145,-.348,1.424),(-.134+j*.145,-.348,1.479),.005,'edge',verts=4)
    cube('Copper serial plaque',(0,-.315,1.22),(.39,.018,.055),'rust',.004)
    for j in range(8):cube('Louver shadow',(0,-.315,.50+j*.066),(.45,.024,.022),'tar',.004)
    for x in (-.292,.292):
        for z in (.28,1.81):bolt((x,-.313,z),.016)
    cube('Service door handle',(.235,-.36,1.06),(.027,.055,.15),'tar',.008)
    for x in (-.25,-.09,.12,.26):
        cable('Cabinet top wire',[(x,.11,1.90),(x,.11,2.05),(x+.10,.11,2.14),(x+.10,.25,2.15)],.022,'tar')
    return root

def maker_gate():
    root=begin('hazard_gate');part('frame')
    for s in (-1,1):
        cube('Gate upright',(s*1.63,0,1.60),(.19,.25,3.2),'steel',.025)
        cube('Gate post ceramic guard',(s*1.63,-.15,1.40),(.23,.08,1.34),'ceramic',.017)
        for z in (.98,1.32,1.66):cube('Amber post bars',(s*1.63,-.198,z),(.13,.025,.04),'amber',.005)
        cube('Base bracket',(s*1.63,.02,.10),(.42,.47,.20),'tar',.025)
    cube('Gate lintel',(0,0,3.10),(3.5,.29,.25),'steel',.024)
    cube('Warning panel',(0,-.17,3.10),(.64,.06,.20),'yellow',.010)
    for i in range(5):cube('Warning hatching',(-.26+i*.13,-.207,3.10),(.051,.018,.17),'tar',.004,rot=(0,.3,0))
    part('gate_panel')
    for z in (.23,2.7):cube('Barrier horizontal',(0,.03,z),(3.14,.1,.12),'rust',.010)
    for i in range(13):cube('Vertical gate bar',(-1.44+i*.24,.03,1.46),(.032,.035,2.50),'steel',.005)
    for s in (-1,1):beam('Diagonal gate brace',(s*1.5,.018,.31),(s*.06,.018,2.66),.030,'steel',verts=4)
    cube('Central lock',(0,-.055,1.5),(.25,.15,.33),'steel',.02)
    cube('Central lock status',(0,-.14,1.5),(.035,.018,.17),'amber',.006)
    return root

def maker_conduit():
    root=begin('conduit_bundle');part('body')
    for i in range(3):
        x=(i-1)*.14
        cable('Bent armoured conduit',[(x,0,.05),(x,0,1.30),(x,.03,1.53),(x,.2,1.70),(x,1.30,1.70)],.052,'steel')
        for z in (.20,.65,1.12):beam('Pipe coupler',(x,0,z-.045),(x,0,z+.045),.068,'rust')
    for z in (.38,1.0):cube('Wall retaining bracket',(0,.042,z),(.58,.11,.06),'tar',.011)
    return root

def descendants(root):
    return [root]+list(root.children_recursive)

def optimise(root):
    # Join geometry within named components; retain all pivot nodes.
    for par in [root]+[o for o in root.children_recursive if o.type=='EMPTY']:
        meshes=[o for o in par.children if o.type=='MESH']
        if not meshes:continue
        bpy.ops.object.select_all(action='DESELECT')
        for ob in meshes:ob.select_set(True)
        bpy.context.view_layer.objects.active=meshes[0]
        bpy.ops.object.join()
        ob=bpy.context.object; ob.name=par.name+'_mesh'
        # Eliminate duplicate slots introduced by joining, reducing GLB primitives.
        used=[]; remap={}
        for i,m in enumerate(ob.data.materials):
            if m not in used:used.append(m)
            remap[i]=used.index(m)
        indices=[remap[p.material_index] for p in ob.data.polygons]
        ob.data.materials.clear()
        for m in used:ob.data.materials.append(m)
        for p,i in zip(ob.data.polygons,indices):p.material_index=i

def export(root):
    optimise(root)
    if root.name=='boss_relay':
        # Only supporting structure is simplified; preserve masks and heart.
        for ob in root.children_recursive:
            if ob.type=='MESH' and ob.name.startswith('body'):
                bpy.context.view_layer.objects.active=ob
                mod=ob.modifiers.new('Browser support-frame LOD','DECIMATE');mod.ratio=.63
                bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for o in descendants(root):o.select_set(True)
    bpy.context.view_layer.objects.active=root
    dest=MODELS/(root.name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_animations=False,export_materials='EXPORT',export_cameras=False,export_lights=False)
    objects=[o for o in descendants(root) if o.type=='MESH']
    vs=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
    lo=[min(v[a] for v in vs) for a in range(3)]; hi=[max(v[a] for v in vs) for a in range(3)]
    return dict(file=str(dest.relative_to(OUT)),bytes=dest.stat().st_size,vertices=sum(len(o.data.vertices) for o in objects),triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects),components=[o.name for o in root.children if o.type=='EMPTY'],dimensions_blender=[round(hi[i]-lo[i],3) for i in range(3)],front_godot='+Z',up_godot='+Y',origin='Ground centre',textures='None; original PBR materials')

assets=[];roots=[]
for fn in (maker_walker,maker_crawler,maker_beacon,maker_boss,maker_cabinet,maker_gate,maker_conduit):
    root=fn();root['original_design']='BLACK RELAY | original procedural modelling';root['front_godot']='+Z'
    assets.append(export(root));roots.append(root)
    # An isolated source scene preserves this asset at its authored origin/scale.
    asset_scene=bpy.data.scenes.new(root.name+'_source')
    for ob in descendants(root):asset_scene.collection.objects.link(ob)
    bpy.data.libraries.write(str(OUT/'source'/(root.name+'_final.blend')),{asset_scene},fake_user=True,compress=True)
    bpy.data.scenes.remove(asset_scene)
    print('ASSET_READY',root.name,flush=True)
    for ob in descendants(root):ob.hide_render=True

manifest={'project':'BLACK RELAY / 黒の中継局','generator':'Blender 4.3.2, source/generate_black_relay.py','license':'CC0-1.0; original geometry and materials dedicated to the public domain','third_party_assets':[],'coordinates':'Godot +Y up, front +Z, 1 unit = 1m, ground at y=0','animation':'Named separated component pivots; no baked animation. Runtime transforms are safe.','assets':assets}
(OUT/'asset_manifest.json').write_text(json.dumps(manifest,indent=2))

# A single carefully lit contact sheet is the visual QA deliverable.
ROOT=None;PART=None
for root,x in zip(roots[:4],(-3.05,-1.28,.43,2.62)):
    root.location.x=x
    if root.name=='boss_relay':root.scale=(.61,.61,.61)
    for ob in descendants(root):ob.hide_render=False
cube('Preview studio floor',(0,0,-.09),(15,15,.16),'tar',.0)
for idx,(root,x) in enumerate(zip(roots[:4],(-3.05,-1.28,.43,2.62))):
    bpy.ops.object.text_add(location=(x,-.83,-.004),rotation=(0,0,0))
    txt=bpy.context.object;txt.name='Preview identification'
    txt.data.body=['01  HUSH','02  SKIP','03  CHOIR','04  THE CARRIER'][idx]
    txt.data.align_x='CENTER';txt.data.size=.13;txt.data.extrude=.0005;txt.data.materials.append(M['edge'])
world=bpy.data.worlds.new('Dark studio') if not bpy.data.worlds else bpy.data.worlds[0]
bpy.context.scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.085,.10,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.38

def area(name,loc,energy,color,size,target=(0,0,1)):
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name
    o.data.energy=energy;o.data.color=color;o.data.shape='DISK';o.data.size=size
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
area('Large warm key',(-3,-4.5,6),1500,(1.,.83,.62),5)
area('Cold rim',(2,3,5),1900,(.16,.72,.83),4)
area('Soft front fill',(2,-5,3.1),800,(.65,.8,1),5)
bpy.ops.object.camera_add(location=(5.6,-13,7.1));cam=bpy.context.object
cam.rotation_euler=(Vector((-.2,0,1.02))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=9.0
scene=bpy.context.scene;scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=32;scene.cycles.use_denoising=False
scene.render.resolution_x=1800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(PREVIEWS/'black_relay_creatures.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source'/'black_relay_asset_showroom.blend'),compress=True)
bpy.ops.render.render(write_still=True)
print('BLACK_RELAY_ASSETS_COMPLETE',flush=True)
