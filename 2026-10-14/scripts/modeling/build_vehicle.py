"""Reference-led v0.4 chair and extinguisher. Logical coordinates are Godot XYZ.

Run: blender --background --python scripts/modeling/build_vehicle.py
Optional --preview renders the real exported geometry to /tmp/vehicle-*.png.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import APP, PALETTE as P, vec, node, paint, tube, cylinder, rounded_box, export_glb, reset_scene

TAU = math.tau


def mesh(name, vertices, faces, color, parent):
    data = bpy.data.meshes.new(name + '_Mesh')
    data.from_pydata([vec(v) for v in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    for polygon in data.polygons:
        polygon.use_smooth = True
    return paint(obj, color)


def signed_power(x, power):
    return math.copysign(abs(x) ** power, x)


def cushion(name, size, center, parent, color=P['teal'], back=False, seams=True):
    """Closed, bowed upholstery with recessed seams, never intersecting pillows."""
    nx, ny = 6, 4
    vertices=[]
    for side in (-1,1):
        for j in range(ny+1):
            v=-1+2*j/ny
            for i in range(nx+1):
                u=-1+2*i/nx
                # Rounded rectangular domain with densely sampled center panels.
                xx=signed_power(u*math.sqrt(1-v*v*.5),.60)
                vv=signed_power(v*math.sqrt(1-u*u*.5),.60)
                edge=max(abs(u),abs(v))
                puff=.25+.75*max(0,1-edge**3)**.48
                if back:
                    x=xx*size[0]/2*(1+.035*vv-.070*math.exp(-((vv+.1)/.4)**2))
                    y=vv*size[1]/2
                    z=side*size[2]/2*puff
                    if seams and side < 0:
                        z+=.035*math.exp(-((abs(xx)-.52)/.15)**2)
                        z+=.022*math.exp(-((vv+.20)/.14)**2)*math.exp(-(xx/.70)**8)
                        # The single upholstery shell swells at both side bolsters.
                        z-=.075*math.exp(-((abs(xx)-.78)/.20)**2)
                else:
                    x=xx*size[0]/2
                    y=side*size[1]/2*puff
                    z=vv*size[2]/2
                    if seams and side>0:
                        y-=.026*math.exp(-((abs(xx)-.58)/.14)**2)
                vertices.append((center[0]+x,center[1]+y,center[2]+z))
    per=(nx+1)*(ny+1)
    faces=[]
    for side in range(2):
        offset=side*per
        for j in range(ny):
            for i in range(nx):
                a=offset+j*(nx+1)+i
                face=(a,a+1,a+nx+2,a+nx+1)
                faces.append(tuple(reversed(face)) if side==0 else face)
    edge=[i for i in range(nx+1)]
    edge += [j*(nx+1)+nx for j in range(1,ny+1)]
    edge += [ny*(nx+1)+i for i in range(nx-1,-1,-1)]
    edge += [j*(nx+1) for j in range(ny-1,0,-1)]
    for i,a in enumerate(edge):
        b=edge[(i+1)%len(edge)]
        faces.append((a,b,b+per,a+per))
    if not back:
        faces=[tuple(reversed(face)) for face in faces]
    obj=mesh(name,vertices,faces,color,parent)
    # Subdivision rounds the continuously connected shell; the controlled
    # reduction keeps this toy in the same budget as the office furniture.
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Rounded upholstery mold','SUBSURF')
    mod.levels=1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=obj.modifiers.new('Upholstery triangle budget','DECIMATE')
    mod.ratio=.5
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def outline(w, h, center, plane, back=False, count=32):
    result = []
    for i in range(count + 1):
        a = TAU * i / count
        x = w / 2 * signed_power(math.cos(a), .32)
        second = h / 2 * signed_power(math.sin(a), .32)
        result.append((center[0] + x, center[1] + second, plane) if back else (center[0] + x, plane, center[2] + second))
    return result


def upholstery_seam(obj, path, back=False):
    """Fit stitch traces to the final sculpt instead of floating straight chords."""
    points=[]
    for step in range(8):
        t=step*(len(path)-1)/7
        i=min(int(t),len(path)-2)
        f=t-i
        p=tuple(path[i][k]*(1-f)+path[i+1][k]*f for k in range(3))
        origin=(p[0],p[1],-2) if back else (p[0],2,p[2])
        direction=(0,0,1) if back else (0,-1,0)
        hit,point,normal,_=obj.ray_cast(vec(origin),vec(direction))
        if hit:
            p=(point.x,point.z,-point.y)
            p=(p[0],p[1],p[2]+.003) if back else (p[0],p[1]-.003,p[2])
        points.append(p)
    return points


def build_chair():
    reset_scene()
    root = node('Chair')
    seat = node('SeatPivot', root, (0, .87, 0))
    # Reference: broad puffy seat, a waisted upholstered back and a small headrest.
    seat_skin=cushion('SeatUpholstery', (1.45, .30, 1.20), (0, 0, 0), seat)
    tube('SeatDarkPiping', outline(1.40, 1.15, (0, 0, 0), -.115), .022, P['dark_teal'], seat, sides=5)
    cushion('SeatPan', (1.43, .14, 1.14), (0, -.15, .03), seat, P['ink'], seams=False)
    cushion('BackShell', (1.25, .93, .20), (0, .46, .49), seat, P['ink'], back=True, seams=False)
    back_skin=cushion('BackUpholstery', (1.27, .90, .36), (0, .49, .35), seat, back=True)
    for sign in (-1,1):
        cylinder('RecessedUpholsteryButton',.017,.004,(sign*.315,.49,.179),P['dark_teal'],seat,axis=(0,0,1),vertices=8,bevel=0)
    for sign in (-1,1):
        back_path=[(sign*x,y,z) for x,y,z in [(.43,.86,.251),(.37,.71,.186),(.32,.52,.175),(.34,.36,.183),(.43,.14,.25)]]
        seat_path=[(sign*x,y,z) for x,y,z in [(.44,.06,-.54),(.43,.135,-.35),(.42,.143,-.03),(.43,.126,.32),(.45,.07,.52)]]
        tube('BackIndentedSeam',upholstery_seam(back_skin,back_path,back=True),.009,P['dark_teal'],seat,sides=4)
        tube('SeatIndentedSeam',upholstery_seam(seat_skin,seat_path),.008,P['dark_teal'],seat,sides=4)
    tube('BackDarkPiping', outline(1.14, .79, (0, .49, 0), .31, back=True), .022, P['dark_teal'], seat, sides=5)
    cushion('Headrest', (.94, .30, .37), (0, .87, .37), seat, back=True, seams=False)
    for sign in (-1, 1):
        # Thick closed loop arms: no unsupported floating arm pads.
        points = [(sign * .66, -.07, -.34), (sign * .79, .02, -.44),
                  (sign * .81, .23, -.48), (sign * .80, .31, -.32),
                  (sign * .78, .32, -.06), (sign * .76, .31, .20),
                  (sign * .71, .25, .34), (sign * .67, .06, .31),
                  (sign * .66, -.07, .14), (sign * .66, -.07, -.34)]
        tube('LoopArm', points, .078, P['ink'], seat, sides=8)
        cushion('ArmPad', (.34, .20, .75), (sign * .78, .29, -.13), seat, P['ink'], seams=False)
        cylinder('ArmAdjustmentDisc', .12, .045, (sign * .72, -.02, .15), P['ink'], seat, axis=(1,0,0), vertices=12, bevel=0)
    tube('AdjustmentPaddleStem', [(-.37,-.19,-.18),(-.65,-.24,-.20),(-.77,-.26,-.22)], .037, P['ink'], seat, sides=6)
    rounded_box('HugeOrangePaddle', (.36,.105,.20), (-.80,-.27,-.23), P['orange'], seat, bevel=.045, segments=2, rotation=(0,0,-.14))
    cylinder('GasLift', .12, .38, (0,.52,.035), P['ink'], root, vertices=16, bevel=.01)
    cylinder('GasLiftCollar', .18, .14, (0,.35,.035), '#394450', root, vertices=16, bevel=.012)
    for i in range(5):
        angle = -math.pi / 2 + TAU * i / 5
        x, z = math.cos(angle), math.sin(angle)
        points = [(x*r, y, .035+z*r) for r,y in [(0,.34),(.20,.32),(.42,.28),(.63,.24),(.77,.22)]]
        tube('BowedStarSupport', points, .09, P['ink'], root, radii=[.13,.13,.105,.075,.07], sides=6)
        cylinder('CasterStem', .055, .13, (x*.76,.18,.035+z*.76), '#394450', root, vertices=8, bevel=0)
        # Wheel axles tangent to the star, with two visibly separate fat tyres.
        tangent = (-z,0,x)
        for sign in (-1,1):
            pos=(x*.76+tangent[0]*sign*.070,.105,.035+z*.76+tangent[2]*sign*.070)
            cylinder('TwinCasterTyre', .105, .10, pos, '#2B303D', root, axis=tangent, vertices=12, bevel=0)
            hub=tuple(pos[k]+tangent[k]*sign*.054 for k in range(3))
            cylinder('CasterHub', .062, .012, hub, '#424854', root, axis=tangent, vertices=10, bevel=0)
    return root


def lathe(name, profile, parent, color, sides=24):
    vertices=[(r*math.cos(TAU*i/sides), y, r*math.sin(TAU*i/sides)) for y,r in profile for i in range(sides)]
    faces=[]
    for j in range(len(profile)-1):
        for i in range(sides):
            n=(i+1)%sides
            faces.append((j*sides+i,j*sides+n,(j+1)*sides+n,(j+1)*sides+i))
    faces += [tuple(reversed(range(sides))),tuple((len(profile)-1)*sides+i for i in range(sides))]
    return mesh(name,vertices,[tuple(reversed(face)) for face in faces],color,parent)


def build_extinguisher():
    reset_scene()
    root=node('Extinguisher')
    lathe('RoundedRedTank',[(-.49,.19),(-.47,.229),(-.43,.24),(.20,.24),(.26,.23),(.31,.20),(.345,.135),(.35,.085)],root,P['red'])
    lathe('RubberBoot',[(-.53,.20),(-.525,.245),(-.49,.255),(-.43,.255),(-.405,.24)],root,P['ink'])
    cylinder('RedNeck',.075,.07,(0,.37,0),P['red'],root,vertices=20,bevel=.008)
    rounded_box('BrassValve',(.19,.13,.17),(0,.445,0),'#DDA446',root,bevel=.025,segments=2)
    cylinder('ValveCollar',.073,.035,(0,.52,0),P['yellow'],root,vertices=16,bevel=.006)
    # Exaggerated rounded pair of levers follows the reference's curved silhouette.
    tube('TopRedLever',[(0,.535,0),(.08,.56,0),(.18,.575,0),(.27,.568,0),(.31,.55,0)],.043,P['red'],root,radii=[.045,.043,.047,.045,.031],sides=10)
    tube('LowerRedLever',[(0,.43,.045),(.08,.42,.045),(.19,.38,.045),(.28,.32,.045),(.32,.29,.045)],.039,P['red'],root,sides=10)
    cylinder('HoseBrassCollar',.071,.09,(-.115,.455,.025),'#DDA446',root,axis=(1,0,0),vertices=16,bevel=.008)
    points=[(-.15,.455,.025),(-.24,.43,.025),(-.31,.35,.018),(-.36,.24,.018),(-.40,.10,.035),(-.425,-.06,.07),(-.43,-.19,.11)]
    tube('CurvedHeavyHose',points,.045,P['ink'],root,sides=12)
    cylinder('NozzleBrassBand',.061,.07,(-.43,-.19,.115),'#DDA446',root,axis=(0,0,1),vertices=16,bevel=.008)
    # Open flared horn points along +Z: the game fires backwards at identity.
    centerx,centery=-.43,-.19
    vertices=[]
    profile=[(.14,.058),(.19,.077),(.31,.13),(.355,.142),(.36,.116),(.32,.104),(.195,.053)]
    sides=24
    for z,r in profile:
        vertices.extend((centerx+r*math.cos(TAU*i/sides),centery+r*math.sin(TAU*i/sides),z) for i in range(sides))
    faces=[]
    for j in range(len(profile)-1):
        for i in range(sides):
            n=(i+1)%sides
            faces.append((j*sides+i,j*sides+n,(j+1)*sides+n,(j+1)*sides+i))
    mesh('WideOpenNozzle',vertices,faces,P['ink'],root)
    cylinder('NozzleInterior',.052,.015,(-.43,-.19,.185),'#121C26',root,axis=(0,0,1),vertices=16,bevel=0)
    node('NozzleTip',root,(-.43,-.19,.36))
    # Gauge faces front -Z, with cream face, colored pressure arcs and pointer.
    cylinder('GaugeBrassRim',.098,.043,(.045,.447,-.125),'#DDA446',root,axis=(0,0,1),vertices=24,bevel=.005)
    cylinder('GaugeFace',.079,.007,(.045,.447,-.151),P['cream'],root,axis=(0,0,1),vertices=24,bevel=0)
    for begin,end,color in [(20,60,P['red']),(65,120,P['green']),(125,160,P['yellow'])]:
        points=[(.045+.062*math.cos(math.radians(a)),.447+.062*math.sin(math.radians(a)),-.158) for a in range(begin,end+1,8)]
        tube('GaugePressureMark',points,.008,color,root,sides=4)
    tube('GaugeNeedle',[(.026,.427,-.160),(.045,.447,-.160),(.083,.481,-.160)],.006,P['ink'],root,sides=6)
    cylinder('GaugePin',.014,.008,(.045,.447,-.164),P['ink'],root,axis=(0,0,1),vertices=12,bevel=0)
    rounded_box('CreamInstructionLabel',(.35,.36,.022),(0,-.13,-.242),P['cream'],root,bevel=.029,segments=3)
    # Raised pictogram and three bold instruction stripes remain legible in-game.
    rounded_box('LabelMiniTank',(.071,.159,.014),(-.101,-.154,-.263),P['red'],root,bevel=.019,segments=2)
    rounded_box('LabelMiniValve',(.036,.025,.015),(-.100,-.058,-.264),P['red'],root,bevel=.006,segments=1)
    tube('LabelMiniLever',[(-.102,-.040,-.265),(-.077,-.033,-.265),(-.052,-.039,-.265)],.008,P['red'],root,sides=6)
    tube('LabelMiniHose',[(-.12,-.052,-.265),(-.146,-.069,-.265),(-.154,-.106,-.265)],.008,P['ink'],root,sides=6)
    for y in (-.074,-.137,-.20):
        rounded_box('InstructionStripe',(.12,.025,.01),(.059,y,-.263),P['ink'],root,bevel=.01,segments=2)
    return root


def bounds(root):
    bpy.context.view_layer.update()
    points=[obj.matrix_world @ Vector(c) for obj in root.children_recursive if obj.type=='MESH' for c in obj.bound_box]
    lo=[min(p[i] for p in points) for i in range(3)]
    hi=[max(p[i] for p in points) for i in range(3)]
    return {'godot_min':(lo[0],lo[2],-hi[1]),'godot_max':(hi[0],hi[2],-lo[1])}


def preview(root, name):
    scene=bpy.context.scene
    scene.render.engine='BLENDER_EEVEE_NEXT'
    scene.render.resolution_x=640
    scene.render.resolution_y=640
    scene.render.resolution_percentage=100
    scene.eevee.taa_render_samples=16
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.72,.67,.57,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
    scene.view_settings.view_transform='AgX'
    scene.render.image_settings.file_format='PNG'
    b=bounds(root)
    target=vec((0,(b['godot_min'][1]+b['godot_max'][1])/2,0))
    for suffix,pos in [('front',(2.6,2.0,-4.5)),('side',(4.5,1.8,.9)),('back',(-2.8,2.0,4.5))]:
        bpy.ops.object.camera_add(location=vec(pos))
        cam=bpy.context.object
        cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.type='ORTHO'
        cam.data.ortho_scale=2.6 if name=='chair' else 1.55
        scene.camera=cam
        lights=[]
        for location,power,size in [((-3,4,-4),500,5),((3,2,-1),250,3),((0,4,3),350,3)]:
            bpy.ops.object.light_add(type='AREA',location=vec(location))
            light=bpy.context.object
            light.data.energy=power
            light.data.shape='DISK'
            light.data.size=size
            light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
            lights.append(light)
        scene.render.filepath=f'/tmp/vehicle-{name}-{suffix}.png'
        bpy.ops.render.render(write_still=True)
        for obj in [cam,*lights]: bpy.data.objects.remove(obj,do_unlink=True)


if __name__=='__main__':
    bpy.context.preferences.filepaths.save_version=0
    for name,builder in [('chair',build_chair),('extinguisher',build_extinguisher)]:
        if any(arg.startswith('--asset=') and arg != f'--asset={name}' for arg in sys.argv):
            continue
        root=builder()
        export_glb(root,APP/f'game/assets/models/{name}.glb',APP/f'art/models/{name}.blend')
        print('ASSET_BOUNDS',name,bounds(root))
        if '--preview' in sys.argv: preview(root,name)
