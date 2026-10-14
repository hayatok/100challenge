"""Seated comic employee, modeled after approved art/assets/v0.4/01-employee.png.

Build: blender --background --python scripts/modeling/build_hero.py
Preview: add -- --render; actual exported model views are saved to /tmp/employee-*.png.
Pivots use Godot local coordinates; pelvis at zero, seat height provided at runtime.
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
from mathutils import Vector
from common import *

SKIN='#FFC58F'; HAIR='#392923'; NAVY='#30374F'; SHIRT='#FFF5EB'

def mesh(name, verts, faces, color, parent):
    data=bpy.data.meshes.new(name+'Mesh'); data.from_pydata([vec(v) for v in verts], [], faces); data.update()
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj); obj.parent=parent
    for p in data.polygons: p.use_smooth=True
    paint(obj,color)
    return obj

def pear_head(parent):
    verts=[]; faces=[]; n=32; r=18
    for j in range(r+1):
        phi=math.pi*j/r; y=.60*math.cos(phi)
        width=.60*(1-.16*math.cos(phi))
        for k in range(n):
            a=math.tau*k/n
            # Pear cheeks and a broad, continuous chin rather than overlapping spheres.
            z=.47*math.sin(phi)*math.cos(a)
            if z<0: z*=1+.18*(1-math.cos(phi))/2
            verts.append((width*math.sin(phi)*math.sin(a),y,z))
    for j in range(r):
        for k in range(n):
            q=j*n+k; q1=j*n+(k+1)%n
            faces.append((q+n,q1+n,q1,q))
    return mesh('PearCheekHead',verts,faces,SKIN,parent)

def lock(name, points, width, depth, parent, color=HAIR):
    # Sculpted leaf-shaped locks with a broad center, swept pointed end and flattened section.
    p0,p1,p2=[Vector(p) for p in points]; verts=[]; faces=[]; count=11; sides=8
    for i in range(count):
        t=i/(count-1); p=(1-t)**2*p0+2*(1-t)*t*p1+t*t*p2
        tangent=(2*(1-t)*(p1-p0)+2*t*(p2-p1)).normalized()
        normal=tangent.cross(Vector((0,0,1)))
        if normal.length<.01: normal=tangent.cross(Vector((0,1,0)))
        normal.normalize(); binormal=tangent.cross(normal).normalized()
        fullness=max(.025,math.sin(math.pi*(.12+.88*t))**.65)
        for k in range(sides):
            a=math.tau*k/sides; q=p+normal*width*fullness*math.cos(a)+binormal*depth*fullness*math.sin(a)
            verts.append(tuple(q))
    for i in range(count-1):
        for k in range(sides):
            j=i*sides+k; faces.append((j,i*sides+(k+1)%sides,(i+1)*sides+(k+1)%sides,j+sides))
    faces += [tuple(reversed(range(sides))), tuple((count-1)*sides+k for k in range(sides))]
    return mesh(name,verts,faces,color,parent)

def e(name,size,pos,color,parent,segments=16,rings=8,rotation=(0,0,0)):
    return ellipsoid(name,size,pos,color,parent,segments,rings,rotation)

def b(name,size,pos,color,parent,bevel=.04,rotation=(0,0,0)):
    return rounded_box(name,size,pos,color,parent,bevel,2,rotation)

def body(root):
    e('SeatedTrouserPelvis',(1.02,.38,.75),(0,.04,.015),NAVY,root)
    e('ShirtConnectedTorso',(.94,.97,.70),(0,.54,-.01),SHIRT,root,20,10)
    e('BlousedShirtHem',(.97,.18,.66),(0,.18,-.015),'#EBDCD0',root)
    e('Neck',(.30,.31,.32),(0,1.04,0),SKIN,root)
    b('BlackBelt',(.97,.09,.065),(0,.135,-.343),'#282631',root,.025)
    b('BrassBuckle',(.17,.12,.045),(0,.135,-.39),'#A58D77',root,.025)
    b('BuckleInset',(.095,.061,.015),(.018,.14,-.42),'#332D2C',root,.009)
    for side in [-1,1]:
        b('FoldedCollar',(.23,.24,.085),(side*.145,.98,-.325),'#FFFAF5',root,.025,(0,0,side*-.50))
        b('BackTrouserPocket',(.27,.075,.035),(side*.27,.05,.391),'#242C42',root,.015)
    b('ShirtPocket',(.19,.21,.036),(.285,.65,-.322),'#EBDDD3',root,.018,(0,0,.06))
    b('PocketLip',(.20,.035,.04),(.285,.735,-.345),SHIRT,root,.013)
    # The teal neck loop continues behind the neck; visible tilted ID frame and tiny picture.
    tube('TealLanyard',[(-.23,.98,-.28),(-.19,.76,-.38),(-.09,.50,-.41),(.06,.48,-.41),(.23,.94,-.30),(.14,1.05,.15),(-.14,1.05,.15),(-.23,.98,-.28)],.022,'#008E91',root,sides=8)
    badge=node('BadgeDetails',root,(-.14,.36,-.405),(0,0,-.12))
    b('IDDarkFrame',(.26,.25,.045),(0,0,0),'#39455C',badge,.027)
    b('IDCreamCard',(.215,.195,.012),(0,0,-.03),'#FFFAEC',badge,.012)
    b('IDClip',(.047,.068,.03),(0,.15,0),'#30353C',badge,.009)
    e('IDPortrait',(.058,.061,.012),(-.063,.025,-.043),SKIN,badge,12,6)
    b('IDPortraitShirt',(.063,.042,.012),(-.062,-.021,-.043),'#3986AA',badge,.006)
    for i in range(3): b('IDPrintedLine',(.075,.013,.012),(.041,.037-i*.039,-.043),'#818698',badge,.004)
    # Fold badge geometry into torso to keep the mesh draw count low.
    for o in list(badge.children):
        world=o.matrix_world.copy(); bpy.context.view_layer.update(); world=o.matrix_world.copy(); o.parent=root; o.matrix_world=world
    bpy.data.objects.remove(badge,do_unlink=True)
    tie=node('Tie',root,(.02,.88,-.405))
    e('LooseTieKnot',(.20,.18,.12),(0,0,0),'#DC2929',tie,16,8)
    lock('LongRedTie',[(0,-.045,0),(.075,-.26,-.13),(.23,-.55,-.10)],.09,.033,tie,'#F33E38')
    for side,label in [(-1,'Left'),(1,'Right')]:
        leg=node('Leg'+label,root,(side*.29,.02,-.20))
        tube('LooseTrouserThigh',[(0,0,0),(side*.045,-.035,-.26),(side*.07,-.03,-.48)],.18,NAVY,leg,radii=[.205,.198,.18],sides=16)
        e('RoundKnee',(.39,.35,.36),(side*.07,-.04,-.48),NAVY,leg)
        tube('TrouserShin',[(side*.07,-.04,-.47),(side*.09,-.24,-.64),(side*.11,-.47,-.72)],.15,NAVY,leg,radii=[.175,.155,.17],sides=16)
        e('TrouserCuff',(.34,.12,.32),(side*.11,-.46,-.73),'#273148',leg)
        e('HugeCartoonShoe',(.47,.31,.73),(side*.12,-.55,-.90),'#302B2D',leg,20,10)
        b('ShoeThickSole',(.47,.095,.72),(side*.12,-.67,-.90),'#211F27',leg,.07)
        e('ShoeTongue',(.22,.065,.27),(side*.12,-.418,-.76),'#42363A',leg,16,8)
        arm=node('Arm'+label,root,(side*.39,.80,-.025))
        tube('ShirtUpperSleeve',[(0,0,0),(side*.13,-.105,-.04),(side*.20,-.24,-.12)],.165,SHIRT,arm,radii=[.18,.19,.18],sides=16)
        cylinder('RolledSleeve',.19,.105,(side*.19,-.21,-.10),'#E9DCD4',arm,axis=(side*.12,-.18,-.08),vertices=20,bevel=.024)
        end=(side*.19,-.27,-.48) if side<0 else (side*.21,-.15,-.48)
        tube('ConnectedBareForearm',[(side*.20,-.24,-.12),(side*.21,-.33,-.25),end],.12,SKIN,arm,radii=[.13,.135,.105],sides=14)
        e('MittenPalm',(.27,.26,.23),end,SKIN,arm)
        for f in range(3):
            e('SoftFinger',(.073,.17,.105),(end[0]+(f-1)*.07,end[1]-.10,end[2]-.065),SKIN,arm,12,6,(-.16,0,0))
        e('CurledThumb',(.11,.19,.135),(end[0]-side*.125,end[1]-.015,end[2]-.03),'#FFD1A0',arm,12,6,(0,0,side*.4))

def head(root):
    h=node('Head',root,(0,1.47,-.025)); pear_head(h)
    for side in [-1,1]:
        e('Ear',(.275,.35,.23),(side*.615,-.09,.015),SKIN,h)
        e('EarIndent',(.145,.19,.085),(side*.654,-.09,-.089),'#EDA372',h,16,8)
    # Compact continuous crown, plus front/rear layered sculpted locks.
    e('HairCrown',(1.10,.56,.88),(0,.405,.06),HAIR,h,20,10)
    e('HairBack',(1.05,.76,.49),(0,.12,.28),HAIR,h,20,10)
    for i in range(5):
        x=-.42+i*.20
        lock('SweptFrontLock',[(x+.18,.61,-.14),(x-.045,.53,-.44),(x-.20,.355+abs(x)*.22,-.42)],.125,.065,h,'#43302A' if i%2 else HAIR)
    for side in [-1,1]:
        for row in range(3):
            y=.44-row*.18
            lock('SweptSideLock',[(side*.32,y+.09,.10),(side*.60,y+.05,-.03),(side*.70,y-.085,.0)],.112,.074,h)
        lock('Sideburn',[(side*.48,.30,-.13),(side*.53,.11,-.20),(side*.52,-.04,-.19)],.083,.065,h)
    for row in range(3):
        for col in range(4):
            x=-.36+col*.24; y=.41-row*.20
            lock('LayeredBackLock',[(x,y+.13,.34),(x+.025,y-.08,.52),(x+.04,y-.28,.40)],.125,.075,h,'#3C2B26' if col%2 else HAIR)
    lock('RebelliousTopCurl',[(.08,.58,.015),(.25,.98,-.015),(-.14,.90,-.07)],.105,.075,h,'#43302A')
    eyes=node('EyesOpen',h)
    happy=node('EyesHappy',h)
    brows=node('Brows',h)
    cheeks=node('Cheeks',h)
    tears=node('Tears',h)
    for side in [-1,1]:
        e('TallEyeWhite',(.29,.365,.13),(side*.24,.135,-.422),'#FFFDEF',eyes,20,10)
        e('SmallWorriedPupil',(.071,.122,.039),(side*.24+.032,.096,-.499),'#191B20',eyes,16,8)
        e('PupilCatchlight',(.023,.031,.014),(side*.24+.020,.127,-.523),'#FFFFFF',eyes,12,6)
        tube('JoyEyeArc',[(side*.24-.11,.10,-.493),(side*.24,.16,-.51),(side*.24+.11,.10,-.493)],.021,HAIR,happy,sides=8)
        tube('ThickBentBrow',[(side*.24-.12,.365,-.376),(side*.24-.01,.335,-.397),(side*.24+.11,.405,-.374)],.034,HAIR,brows,sides=10)
        e('WarmCheekBlush',(.22,.115,.035),(side*.445,-.155,-.393),'#F49680',cheeks,16,8)
        for i in range(3):
            tube('CheekBlushHatch',[(side*(.40+i*.046),-.12,-.431),(side*(.425+i*.046),-.19,-.426)],.012,'#E9796E',cheeks,sides=6)
        lock('TearDrop',[(side*.48,.12,-.405),(side*.48,.025,-.452),(side*.48,-.025,-.435)],.039,.029,tears,'#45C8E3')
    e('RoundProtrudingNose',(.21,.15,.18),(0,-.015,-.522),'#FFB778',h,24,12)
    mouth=node('Mouth',h,(0,-.285,-.440))
    e('WarmLipRim',(.72,.575,.12),(0,0,0),SKIN,mouth,24,10)
    e('HugeShoutingMouth',(.665,.51,.035),(0,.005,-.058),'#571A1F',mouth,24,10)
    for side in [-1,1]:
        b('TwoDistinctTopTeeth',(.158,.103,.040),(side*.117,.185,-.095),'#FFF7DB',mouth,.025,(0,0,side*-.11))
    e('BroadPinkTongue',(.455,.185,.03),(0,-.151,-.10),'#F7787B',mouth,24,10)
    tube('TongueCenter',[(0,-.09,-.122),(0,-.153,-.123)],.007,'#D9566D',mouth,sides=6)
    return h

def render_views(root):
    scene=bpy.context.scene; scene.render.engine='BLENDER_EEVEE_NEXT'; scene.render.resolution_x=900; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
    scene.world.color=(.7,.7,.7); scene.view_settings.view_transform='Standard'; scene.eevee.taa_render_samples=24
    for label in ['EyesHappy','Tears']:
        for obj in bpy.data.objects[label].children_recursive: obj.hide_render=True
    bpy.ops.object.light_add(type='AREA',location=(3,4,6)); bpy.context.object.data.energy=600; bpy.context.object.data.shape='DISK'; bpy.context.object.data.size=5
    bpy.ops.object.light_add(type='AREA',location=(-4,1,3)); bpy.context.object.data.energy=350; bpy.context.object.data.size=4
    bpy.ops.object.light_add(type='AREA',location=(1,-3,4)); bpy.context.object.data.energy=450; bpy.context.object.data.size=3
    bpy.ops.object.camera_add(); camera=bpy.context.object; scene.camera=camera; camera.data.type='ORTHO'; camera.data.ortho_scale=3.65
    center=vec((0,.87,-.14))
    for label,at in [('front',(0,1,-7)),('side',(7,1,0)),('back',(0,1,7)),('threequarter',(5,2,-7))]:
        camera.location=vec(at); camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler(); scene.render.filepath='/tmp/employee-'+label+'.png'; bpy.ops.render.render(write_still=True)

reset_scene(); root=node('Employee'); body(root); head(root)
merge_rigid(root)
# Reduce only redundant bevel/UV tessellation, preserving rigid parts and vertex colors.
triangles=mesh_stats(root)['triangles']
if triangles>14500:
    ratio=14500/triangles
    for obj in descendants(root):
        if obj.type=='MESH':
            bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new('Web triangle budget','DECIMATE'); mod.ratio=ratio
            bpy.ops.object.modifier_apply(modifier=mod.name)
export_glb(root,APP/'game/assets/models/employee.glb',APP/'art/models/employee.blend')
if '--render' in sys.argv: render_views(root)
