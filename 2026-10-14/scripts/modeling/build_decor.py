"""Reference-built v0.4 colleague and desk toys, logical Godot coordinates.

Reference sheets: art/assets/v0.4/{01-employee,05-colleague,06-desk-toys}.png.
The colleague pelvis is at Y=0 for the shared runtime chair; no chair is baked in.
"""
import math
import bmesh
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *

P = PALETTE
HAIR = '#613226'
HAIR_LIGHT = '#7C4230'
SHOE = '#282930'
NAVY = '#343F59'


def mesh(name, verts, faces, color, parent, smooth=True):
    data = bpy.data.meshes.new(name + '_Mesh')
    data.from_pydata([vec(v) for v in verts], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for face in data.polygons:
        face.use_smooth = smooth
    paint(obj, color)
    obj.parent = parent
    return obj


def lathe(name, profile, color, parent, pos=(0,0,0), sides=20):
    """Closed or open, explicitly wound revolved profile; hollow rims are real."""
    verts=[]; faces=[]
    for radius,y in profile:
        for j in range(sides):
            angle=math.tau*j/sides
            verts.append((pos[0]+radius*math.cos(angle),pos[1]+y,pos[2]+radius*math.sin(angle)))
    for i in range(len(profile)-1):
        for j in range(sides):
            k=(j+1)%sides
            faces.append((i*sides+j,(i+1)*sides+j,(i+1)*sides+k,i*sides+k))
    return mesh(name,verts,faces,color,parent)


def triangle_prism(name, coords, depth, color, parent, bevel=.01):
    verts=[(x,y,z) for z in [-depth/2,depth/2] for x,y in coords]
    obj=mesh(name,verts,[(2,1,0),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],color,parent)
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    if bevel:
        bpy.context.view_layer.objects.active=obj
        obj.select_set(True)
        mod=obj.modifiers.new('Rounded ear','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        # New bevel loops need the shared color re-filled.
        paint(obj,color)
    return obj


def smooth_path(points, subdivisions=4):
    result=[]
    for i in range(len(points)-1):
        a=Vector(points[max(i-1,0)]);b=Vector(points[i]);c=Vector(points[i+1]);d=Vector(points[min(i+2,len(points)-1)])
        for j in range(subdivisions):
            t=j/subdivisions
            result.append(tuple(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)))
    result.append(points[-1])
    return result


def cat_mug(parent, pos=(0,0,0), scale=1, handle_side=1):
    holder=node('CatMug',parent,pos)
    holder.scale=(scale,scale,scale)
    lathe('Plump open porcelain',[(0,0),(.125,0),(.165,.035),(.195,.11),(.204,.24),(.19,.365),(.18,.405),(.163,.41),(.149,.397),(.155,.36),(.167,.25),(.15,.085),(0,.07)],P['cream'],holder)
    cylinder('Coffee',.164,.008,(0,.352,0),'#694025',holder,vertices=20,bevel=0)
    # Small coffee ripples are geometry and remain readable from above.
    tube('Coffee ripple',[(.057*math.cos(t),.358,.057*math.sin(t)) for t in [i*math.tau/16 for i in range(17)]],.003,'#A86B38',holder,sides=5,capped=False)
    for side in [-1,1]:
        ear=triangle_prism('Cat ear',[(side*.094,.377),(side*.179,.382),(side*.157,.481)],.064,P['cream'],holder,.012)
        ear.location=vec((0,0,-.083))
        inner=triangle_prism('Pink inner ear',[(side*.112,.391),(side*.161,.397),(side*.151,.454)],.009,P['pink'],holder,.004)
        inner.location=vec((0,0,-.121))
        ellipsoid('Cat pupil',(.031,.064,.018),(side*.077,.256,-.194),SHOE,holder,segments=10,rings=6)
        ellipsoid('Little paw',(.097,.088,.053),(side*.10,.055,-.17),P['white'],holder,segments=12,rings=6)
        for offset in [-.019,.019]:
            tube('Paw crease',[(side*.10+offset,.033,-.194),(side*.10+offset,.056,-.2)],.0025,'#BDA582',holder,sides=4)
        for offset in [-.021,0,.021]:
            tube('Blush',[(side*.123+offset,.203,-.168),(side*.128+offset,.224,-.17)],.005,P['pink'],holder,sides=5)
    ellipsoid('Cat nose',(.045,.027,.019),(0,.229,-.201),P['pink'],holder,segments=12,rings=6)
    tube('Cat philtrum',[(0,.207,-.205),(0,.223,-.205)],.006,HAIR,holder,sides=5)
    tube('Cat smile',[(-.035,.211,-.198),(-.023,.194,-.202),(0,.205,-.205),(.023,.194,-.202),(.035,.211,-.198)],.006,HAIR,holder,sides=5)
    tube('Fat curled tail handle',smooth_path([(handle_side*x,y,z) for x,y,z in [(.156,.085,.015),(.263,.117,.015),(.356,.18,.015),(.398,.269,.015),(.382,.347,.015),(.316,.379,.015),(.277,.364,.015),(.262,.326,.015),(.284,.312,.015)]],subdivisions=3),.044,P['teal'],holder,sides=8)
    return holder


def mug():
    reset_scene();root=node('CatMugRoot')
    holder=cat_mug(root)
    # Fold the assembly into the root for one rigid mesh/surface.
    for obj in list(holder.children):
        obj.parent=root
    bpy.data.objects.remove(holder,do_unlink=True)
    return root


def stapler():
    reset_scene(); root=node('CrocodileStapler')
    rounded_box('Heavy blue base',(.70,.12,1.60),(0,.07,0),NAVY,root,bevel=.055,segments=3)
    rounded_box('Base upper step',(.62,.055,1.48),(0,.105,0),'#45627B',root,bevel=.035)
    rounded_box('Anvil plate',(.44,.018,.48),(0,.145,-.46),'#AAB0AC',root,bevel=.01)
    for x in [-.12,.12]:
        rounded_box('Anvil groove',(.095,.003,.045),(x,.156,-.52),P['ink'],root,bevel=.006)
    outline=[(-.75,.385),(-.72,.48),(-.65,.54),(-.40,.55),(-.07,.525),(.24,.455),(.50,.35),(.66,.235),(.68,.17),(.56,.15),(.46,.19),(.37,.30),(.14,.335),(-.20,.355),(-.55,.36)]
    verts=[(x,y,z) for x in [-.278,.278] for z,y in outline]
    n=len(outline)
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    jaw=mesh('Swept red crocodile jaw',verts,faces,P['red'],root)
    bpy.context.view_layer.objects.active=jaw; bpy.ops.object.select_all(action='DESELECT');jaw.select_set(True)
    mod=jaw.modifiers.new('Soft moulded shell','BEVEL');mod.width=.035;mod.segments=3
    bpy.ops.object.modifier_apply(modifier=mod.name);paint(jaw,P['red'])
    for x in [-.105,.105]:
        rounded_box('Ivory buck tooth',(.175,.13,.135),(x,.316,-.609),P['cream'],root,bevel=.027,segments=3,rotation=(.08,0,0))
    for side in [-1,1]:
        for z,y in [(-.53,.447),(.52,.226)]:
            cylinder('Gold screw eye',.070,.022,(side*.292,y,z),P['yellow'],root,axis=(side,0,0),vertices=16,bevel=.01)
            # Diagonal screw slot on both broad sides.
            tube('Screw slot',[(side*.307,y-.038,z-.033),(side*.307,y+.038,z+.033)],.007,HAIR,root,sides=5)
    coil=[]
    for i in range(49):
        a=i*math.tau*2.6/48
        coil.append((.086*math.cos(a),.191+.101*i/48,.35+.086*math.sin(a)))
    tube('Visible steel spring',coil,.018,SHOE,root,sides=6)
    for x in [-.24,.24]:
        for z in [-.6,.59]:
            rounded_box('Rubber foot',(.15,.027,.20),(x,.0135,z),SHOE,root,bevel=.014)
    return root


def leaf(name,start,end,width,color,root):
    # A broad pointed, bent blade with a substantial lentil cross section.
    a=Vector(start);b=Vector(end);axis=(b-a).normalized()
    normal=Vector((0,0,1)); side=axis.cross(normal).normalized();normal=side.cross(axis).normalized()
    verts=[];faces=[]
    for i in range(7):
        t=i/6; center=a.lerp(b,t)+normal*(math.sin(math.pi*t)*.10)
        radius=max(.012,math.sin(math.pi*t)**.65)*width
        for j in range(8):
            theta=math.tau*j/8
            point=center+side*(radius*math.cos(theta))+normal*(radius*.42*math.sin(theta))
            verts.append(tuple(point))
    for i in range(6):
        for j in range(8): faces.append((i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j))
    faces += [tuple(reversed(range(8))),tuple(48+i for i in range(8))]
    mesh(name,verts,faces,color,root)
    tube('Raised leaf vein',[tuple(a.lerp(b,t)+normal*(math.sin(math.pi*t)*.10+math.sin(math.pi*t)*width*.425)) for t in [.05,.25,.5,.75,.94]],.007,'#2E8D5B',root,sides=4)


def plant():
    reset_scene();root=node('BentOfficePlant')
    lathe('Squat ivory pot',[(0,.04),(.31,.04),(.42,.085),(.46,.20),(.455,.44),(.405,.67),(.38,.69),(.353,.68),(.35,.64),(.36,.56),(0,.54)],P['cream'],root,sides=20)
    cylinder('Visible soil',.353,.02,(0,.596,0),'#6B462A',root,vertices=20,bevel=0)
    for x in [-.25,.25]:
        for z in [-.22,.22]: ellipsoid('Small pot foot',(.13,.09,.13),(x,.045,z),P['cream'],root,segments=8,rings=4)
    trunk=[(0,.59,0),(-.08,.83,.01),(.07,1.07,0),(.13,1.24,.025),(-.09,1.46,.02),(-.14,1.66,0),(-.04,1.87,0),(.13,2.06,.015),(.20,2.30,.04)]
    widths=[.12,.115,.10,.09,.085,.08,.072,.058,.025]
    radii=[widths[i]*(1-j/2)+widths[i+1]*(j/2) for i in range(8) for j in range(2)]+[widths[-1]]
    tube('Crooked thick trunk',smooth_path(trunk,subdivisions=2),.085,HAIR,root,radii=radii,sides=8)
    branches=[((.08,1.15,0),(.43,1.33,.02)),((-.10,1.48,0),(-.43,1.68,-.04)),((-.10,1.72,0),(.33,1.96,.01)),((.05,2.02,0),(-.27,2.24,.02)),((.13,1.22,.01),(-.20,1.29,-.14)),((-.08,1.61,0),(.13,1.74,.28)),((.15,2.12,0),(.35,2.32,.015))]
    for a,b in branches: tube('Crooked branch',[a,tuple(Vector(a).lerp(Vector(b),.55)+Vector((.02,.055,0))),b],.043,HAIR,root,radii=[.05,.037,.016],sides=7)
    leaves=[((.36,1.34,.02),(.66,1.02,-.03),.21),((-.39,1.68,-.04),(-.65,1.37,-.05),.22),((.31,1.96,.01),(.64,1.75,0),.21),((-.25,2.24,.02),(-.52,2.12,.04),.22),((.19,2.30,.04),(.47,2.48,.02),.20),((-.19,1.30,-.14),(-.31,1.09,-.20),.16),((.12,1.75,.25),(.37,1.56,.35),.18),((-.14,1.75,0),(-.29,1.97,.25),.16)]
    for i,(a,b,w) in enumerate(leaves):leaf('Broad rounded leaf',a,b,w,['#3CA965','#4AB473','#339559'][i%3],root)
    for a,b in [((-.38,1.68,-.04),(-.53,1.84,0)),((.34,1.96,.01),(.5,2.13,0)),((.05,2.04,0),(-.05,2.43,-.04))]:
        tube('Voxel tip twig',[a,b],.021,HAIR,root,sides=6)
        rounded_box('Stepped voxel leaf',(.15,.18,.145),b,'#98CC3D',root,bevel=.015,segments=1,rotation=(0,.2,.15))
        rounded_box('Voxel leaf step',(.085,.12,.13),(b[0]+.06,b[1]-.035,b[2]),'#81B62A',root,bevel=.008,segments=1)
    # Front teal holiday seal, curved ring and readable Japanese character.
    tube('Pot seal ring',[(.158*math.cos(t),.34+.158*math.sin(t),-.451) for t in [i*math.tau/24 for i in range(25)]],.012,P['teal'],root,sides=6,capped=False)
    stamp=text('Holiday stamp','休',.64,(0,.26,-.464),P['teal'],root,extrude=.002)
    # Local compensation for the shared helper's text-up orientation.
    for vertex in stamp.data.vertices:
        vertex.co.x *= -1
        vertex.co.z *= -1
    bm=bmesh.new();bm.from_mesh(stamp.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(stamp.data);bm.free()
    rounded_box('Small red seal',(.074,.082,.009),(.27,.205,-.403),P['red'],root,bevel=.01)
    for i in range(5):
        ang=i*math.tau/5
        ellipsoid('Soil pebble',(.15,.075,.12),(.22*math.cos(ang),.627,.22*math.sin(ang)),'#9B6742',root,segments=8,rings=4)
    return root


def hair_shell(root):
    # One connected bob shell with a raised opening over the face. The perimeter
    # drops behind the ears and around the neck; large locks accent the shell.
    verts=[];faces=[];segs=28;rings=10
    for i in range(rings+1):
        t=i/rings
        for j in range(segs):
            theta=math.tau*j/segs
            front=max(0,math.cos(theta))
            maxphi=2.24-1.02*front**3
            phi=.03+t*maxphi
            x=.554*math.sin(phi)*math.sin(theta)
            y=1.27+.555*math.cos(phi)
            z=-.477*math.sin(phi)*math.cos(theta)+.04
            # Flared lower bob ends broaden one continuous silhouette.
            if t>.7: x*=1+.09*(t-.7)/.3
            verts.append((x,y,z))
    for i in range(rings):
        for j in range(segs): faces.append((i*segs+j,i*segs+(j+1)%segs,(i+1)*segs+(j+1)%segs,(i+1)*segs+j))
    shell=mesh('Continuous bob hair shell',verts,faces,HAIR,root)
    # Shell's face winding points outwards; give bottom opening a tiny thickness.
    bpy.context.view_layer.objects.active=shell;bpy.ops.object.select_all(action='DESELECT');shell.select_set(True)
    mod=shell.modifiers.new('Thick bob edge','SOLIDIFY');mod.thickness=.045
    bpy.ops.object.modifier_apply(modifier=mod.name);paint(shell,HAIR)
    def lock(name,points,widths,col):
        # Cubic interpolation keeps broad swept locks curved at toy scale.
        smooth_points=[];smooth_widths=[]
        for i in range(len(points)-1):
            a=Vector(points[max(0,i-1)]);b=Vector(points[i]);c=Vector(points[i+1]);d=Vector(points[min(i+2,len(points)-1)])
            for k in range(3):
                t=k/3
                smooth_points.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
                smooth_widths.append(widths[i]*(1-t)+widths[i+1]*t)
        smooth_points.append(Vector(points[-1]));smooth_widths.append(widths[-1])
        vs=[];fs=[]
        for i,(point,w) in enumerate(zip(smooth_points,smooth_widths)):
            tangent=smooth_points[min(i+1,len(smooth_points)-1)]-smooth_points[max(0,i-1)]
            across=Vector((-tangent.y,tangent.x,0)).normalized()
            for j in range(8):
                a=math.tau*j/8
                vs.append(tuple(point+across*(w*math.cos(a))+Vector((0,0,.049*math.sin(a)))))
        for i in range(len(smooth_points)-1):
            for j in range(8):fs.append((i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j))
        fs.extend([tuple(reversed(range(8))),tuple((len(smooth_points)-1)*8+j for j in range(8))])
        mesh(name,vs,fs,col,root)
    lock('Swept broad fringe',[(-.01,1.77,-.22),(-.16,1.72,-.33),(-.31,1.62,-.39),(-.41,1.48,-.41),(-.51,1.43,-.36)],[.035,.12,.145,.13,.015],HAIR_LIGHT)
    lock('Right parted fringe',[(.04,1.77,-.20),(.24,1.70,-.32),(.40,1.52,-.35),(.49,1.31,-.28),(.53,1.23,-.17)],[.035,.12,.13,.10,.012],HAIR_LIGHT)
    # Side locks follow the bob rather than forming loose balls.
    for side in [-1,1]:
        lock('Bob side lock',[(side*.39,1.52,-.26),(side*.49,1.33,-.18),(side*.51,1.09,-.14),(side*.46,.91,-.09)],[.045,.095,.09,.012],HAIR_LIGHT)
    for x in [-.42,-.28,-.14,0,.14,.28,.42]:
        spread=math.sqrt(1-(x/.57)**2)
        lock('Sculpted back bob lock',[(x*.3,1.72,.31),(x*.65,1.54,.455),(x,1.28,.505*spread+.04),(x*.95,1.05,.455*spread+.04),(x*.9,.937,.335*spread+.04)],[.025,.078,.094,.075,.009],HAIR_LIGHT)
    tube('Quiet cowlick',[(.05,1.79,.03),(.11,1.865,.03),(.04,1.9,.03),(-.09,1.883,.03),(-.13,1.856,.03)],.06,HAIR,root,radii=[.045,.065,.067,.037,.005],sides=8)


def colleague():
    reset_scene();root=node('SeatedColleague')
    # The only hierarchy is this rigid root; the shared chair belongs to runtime.
    rounded_box('Trouser pelvis',(.73,.27,.61),(0,.035,.04),NAVY,root,bevel=.13,segments=3)
    rounded_box('White blouse',(.83,.71,.55),(0,.46,0),P['white'],root,bevel=.18,segments=3)
    rounded_box('Teal vest',(.75,.69,.64),(0,.43,.025),'#247C85',root,bevel=.16,segments=3)
    # Inset V collar constructed as a flat thick triangle in front of the vest.
    patch=triangle_prism('Blouse V neck',[(-.28,.795),(.28,.795),(0,.44)],.021,P['white'],root,bevel=.009);patch.location=vec((0,0,-.315))
    inner=triangle_prism('Pink inner collar',[(-.15,.76),(.15,.76),(0,.565)],.009,'#FFC3CF',root,bevel=.006);inner.location=vec((0,0,-.33))
    for side in [-1,1]:
        rounded_box('Pointed folded collar',(.23,.13,.05),(side*.197,.766,-.332),P['white'],root,bevel=.045,segments=2,rotation=(0,0,side*.40))
    cylinder('Neck',.15,.21,(0,.885,0),P['skin'],root,vertices=16,bevel=.025)
    ellipsoid('Connected round adult head',(1.025,.985,.865),(0,1.30,-.025),P['skin'],root,segments=24,rings=16)
    for side in [-1,1]:
        ellipsoid('Ear',(.18,.25,.15),(side*.49,1.23,-.01),P['skin'],root,segments=12,rings=8)
        ellipsoid('Ear inset',(.086,.133,.025),(side*.509,1.24,-.087),'#E79A6C',root,segments=10,rings=6)
    hair_shell(root)
    for side in [-1,1]:
        x=side*.198
        ellipsoid('Sleepy ivory eye',(.31,.235,.10),(x,1.323,-.43),P['white'],root,segments=16,rings=8)
        ellipsoid('Half closed upper lid',(.323,.153,.106),(x,1.407,-.443),P['skin'],root,segments=16,rings=8)
        ellipsoid('Small indifferent pupil',(.063,.079,.020),(x-side*.022,1.313,-.481),SHOE,root,segments=12,rings=6)
        ellipsoid('Pupil glint',(.015,.015,.006),(x-side*.029,1.336,-.493),P['white'],root,segments=8,rings=4)
        tube('Heavy eyelid line',[(x-.155,1.362,-.474),(x,1.35,-.495),(x+.153,1.335,-.474)],.012,SHOE,root,sides=6)
        tube('Patient eyebrow',[(x-.087,1.516,-.403),(x-.03,1.53,-.435),(x+.055,1.512,-.435)],.032,HAIR,root,radii=[.02,.034,.022],sides=7)
        for dx in [-.028,.003,.034]:
            tube('Rosy cheek stripe',[(side*.329+dx,1.205,-.40),(side*.341+dx,1.235,-.408)],.008,P['pink'],root,sides=5)
    ellipsoid('Soft little nose',(.145,.103,.132),(0,1.245,-.468),'#F4A56F',root,segments=16,rings=8)
    tube('Small content smile',[(-.111,1.145,-.435),(-.066,1.115,-.457),(0,1.107,-.465),(.066,1.115,-.457),(.105,1.141,-.442)],.009,'#BD654E',root,sides=6)
    # Crossed trousers bend forward from the pelvis and down towards the floor.
    tube('Lower relaxed leg',[(.21,.00,-.01),(.23,-.03,-.40),(.20,-.25,-.61),(.19,-.735,-.66)],.15,NAVY,root,radii=[.20,.19,.17,.145],sides=12)
    tube('Crossed upper leg',[(-.23,.05,-.04),(-.20,.15,-.34),(.04,.15,-.56),(.30,-.06,-.68),(.40,-.29,-.79)],.16,NAVY,root,radii=[.20,.20,.195,.17,.145],sides=12)
    for x,y,z in [(.19,-.865,-.81),(.42,-.38,-.92)]:
        ellipsoid('Oversized shiny loafer',(.39,.27,.60),(x,y,z),SHOE,root,segments=16,rings=8)
        rounded_box('Thick loafer sole',(.40,.055,.62),(x,y-.105,z-.012),'#1E252C',root,bevel=.028,segments=2)
        rounded_box('Loafer strap',(.34,.05,.15),(x,y+.085,z+.01),'#393438',root,bevel=.025)
    # One arm rests at chair-arm height; the other lifts a little cat mug.
    tube('Right white sleeve',[(.35,.67,0),(.49,.50,-.01),(.54,.38,-.06)],.12,P['white'],root,radii=[.15,.14,.135],sides=12)
    tube('Pink rolled right cuff',[(.54,.405,-.055),(.56,.33,-.08)],.14,'#F6A6B9',root,sides=12)
    tube('Resting right forearm',[(.56,.33,-.08),(.61,.24,-.23),(.60,.20,-.37)],.10,P['skin'],root,radii=[.11,.10,.10],sides=12)
    ellipsoid('Relaxed right palm',(.21,.18,.18),(.59,.17,-.41),P['skin'],root,segments=12,rings=8)
    for i in range(4):
        tube('Relaxed hand finger',[(.515+i*.047,.16,-.421),(.53+i*.047,.09,-.455),(.535+i*.047,.065,-.432)],.022,P['skin'],root,sides=6)
    tube('Left white sleeve',[(-.35,.67,0),(-.49,.53,-.07),(-.54,.40,-.12)],.13,P['white'],root,radii=[.15,.14,.125],sides=12)
    tube('Pink rolled left cuff',[(-.535,.433,-.115),(-.56,.366,-.15)],.137,'#F6A6B9',root,sides=12)
    tube('Lifted left forearm',[(-.57,.39,-.16),(-.64,.52,-.29),(-.66,.78,-.37)],.10,P['skin'],root,radii=[.11,.10,.09],sides=12)
    ellipsoid('Mug holding palm',(.19,.21,.17),(-.64,.82,-.395),P['skin'],root,segments=12,rings=8)
    held=cat_mug(root,(-.56,.72,-.55),.64,handle_side=-1)
    for i in range(3):
        tube('Mug curled finger',[(-.693,.875-i*.041,-.43),(-.73,.859-i*.041,-.492),(-.69,.841-i*.041,-.52)],.021,P['skin'],root,sides=6)
    tube('Teal lanyard left',[(-.24,.756,-.33),(-.17,.61,-.35),(0,.43,-.345)],.014,P['teal'],root,sides=6)
    tube('Teal lanyard right',[(.24,.756,-.33),(.17,.61,-.35),(0,.43,-.345)],.014,P['teal'],root,sides=6)
    rounded_box('ID clip',(.068,.105,.028),(0,.431,-.36),SHOE,root,bevel=.008)
    badge=node('BadgeAssembly',root,(.04,.312,-.369),rotation=(0,0,.13))
    rounded_box('ID dark frame',(.252,.204,.03),(0,0,0),P['ink'],badge,bevel=.025)
    rounded_box('ID cream card',(.218,.171,.01),(0,0,-.022),P['paper'],badge,bevel=.015)
    ellipsoid('ID portrait head',(.036,.046,.004),(-.064,.029,-.03),P['skin'],badge,segments=8,rings=4)
    rounded_box('ID portrait vest',(.057,.044,.005),(-.064,-.018,-.03),P['teal'],badge,bevel=.013)
    for y in [-.041,.001,.043]:rounded_box('ID text line',(.082,.011,.004),(.043,y,-.031),'#8A9092',badge,bevel=.002)
    # Collapse all static child assemblies before merging: one rigid mesh.
    bpy.context.view_layer.update()
    for obj in list(root.children_recursive):
        if obj.type=='MESH' and obj.parent!=root:
            matrix=obj.matrix_world.copy();obj.parent=root;obj.matrix_world=matrix
    for obj in list(root.children_recursive):
        if obj.type=='EMPTY':bpy.data.objects.remove(obj,do_unlink=True)
    return root


if __name__=='__main__':
    bpy.context.preferences.filepaths.save_version=0
    for asset,builder in [('colleague',colleague),('cat_mug',mug),('stapler',stapler),('plant',plant)]:
        root=builder()
        if asset=='plant':
            root.scale.x=.94
        merge_rigid(root)
        # Preserve the sculpted outline while collapsing redundant coplanar /
        # short interior edges. Each disconnected colored component stays separate.
        budget=9000 if asset=='colleague' else 2500
        count=mesh_stats(root)['triangles']
        if count>budget:
            obj=next(o for o in root.children_recursive if o.type=='MESH')
            bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new('Game silhouette budget','DECIMATE')
            mod.ratio=(budget-200)/count
            bpy.ops.object.modifier_apply(modifier=mod.name)
        export_glb(root, APP/'game/assets/models'/f'{asset}.glb', APP/'art/models'/f'{asset}.blend',merge=False)
