"""Reference-led chunky furniture and CRT kit, in logical Godot coordinates.

Run: blender --background --python scripts/modeling/build_furniture.py
Add -- --render to produce inspectable front/side/back renders in /tmp.
Desk/cabinet origins are on the floor; computer origin is on the desktop.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (APP, PALETTE as P, node, rounded_box, ellipsoid, cylinder,
                    tube, text, paint, vec, export_glb, reset_scene, descendants)

GRAY = '#939899'
NAVY = '#303746'
TEAL = '#258C91'
GOLD = '#FFBF3E'


def loop_handle(name, parent, x, y, z, width=.43, height=.17, radius=.035):
    """A real open capsule loop; the two end fixings recess into the panel."""
    points = []
    straight = (width-height)/2
    for center, first in ((straight, -math.pi/2), (-straight, math.pi/2)):
        for k in range(9):
            angle = first + math.pi*k/8
            points.append((x+center+height/2*math.cos(angle),
                           y+height/2*math.sin(angle), z))
    points.append(points[0])
    tube(name, points, radius, GOLD, parent, sides=6, capped=False)
    for dx in (-straight, straight):
        cylinder(name+'_Mount', radius*.85, .07, (x+dx, y, z+.035),
                 GOLD, parent, axis=(0,0,1), vertices=8, bevel=0)


def stamp(parent, x, y, z, size=.28):
    rounded_box('StampBorder', (size,.19,.015), (x,y,z), P['red'], parent,
                bevel=.012, segments=1, rotation=(0,0,-.09))
    rounded_box('StampPaper', (size-.035,.155,.016), (x,y,z-.009), P['white'], parent,
                bevel=.005, segments=1, rotation=(0,0,-.09))
    # Facing -Z requires the glyph's local horizontal axis to reverse as well.
    glyphs=text('FullPowerStamp', '全力', min(size*1.15,.30), (x,y,z-.020),
                P['red'], parent, rotation=(0,0,math.pi-.09), extrude=0)
    bpy.context.view_layer.update()
    vertices=[glyphs.matrix_world@vertex.co for vertex in glyphs.data.vertices]
    center_x=(min(point.x for point in vertices)+max(point.x for point in vertices))/2
    center_y=(min(point.z for point in vertices)+max(point.z for point in vertices))/2
    glyphs.location+=vec((x-center_x,y-center_y,0))


def build_desk():
    reset_scene()
    root = node('Desk')
    rounded_box('CreamThickTop', (3.6,.18,2.8), (0,1.71,0), P['cream'], root,
                bevel=.085, segments=3)
    rounded_box('TealThickRim', (3.58,.16,2.78), (0,1.565,0), TEAL, root,
                bevel=.07, segments=3)
    rounded_box('AsymmetricDrawerPedestal', (1.08,1.38,2.32), (-1.14,.80,.05),
                '#217F85', root, bevel=.105, segments=3)
    for i,y in enumerate((.36,.80,1.24)):
        rounded_box(f'BulgingDrawer{i}', (1.01,.411,.15), (-1.14,y,-1.145),
                    TEAL, root, bevel=.065, segments=2)
        loop_handle(f'GoldDrawerLoop{i}', root, -1.19,y,-1.255)
    stamp(root,-.84,1.24,-1.230,.24)
    for x in (-1.53,-.75):
        for z in (-.86,.95):
            cylinder('PedestalFoot', .115,.10,(x,.05,z),NAVY,root,vertices=10)
    for z in (-1.02,1.02):
        tube('SturdySplayedGrayLeg', [(1.40,.10,z*1.09),(1.28,.78,z*1.035),
                                    (1.18,1.54,z)], .105,GRAY,root,
             radii=[.105,.11,.105], sides=10)
        cylinder('DarkLegBoot', .145,.13,(1.40,.065,z*1.09),NAVY,root,vertices=12)
    return root


def build_cabinet():
    reset_scene()
    root = node('Cabinet')
    # Wide island stays within the original 6 x 3.4 x 1.7 collider footprint.
    rounded_box('LowNavyPlinth', (5.62,.16,2.83), (0,.16,0),NAVY,root,
                bevel=.07,segments=2)
    rounded_box('TealIslandBody', (5.75,1.26,2.90), (0,.89,0), '#227C83',root,
                bevel=.09,segments=2)
    rounded_box('ThickCreamIslandTop', (5.9,.22,3.04), (0,1.59,0),P['cream'],root,
                bevel=.10,segments=3)
    for i,x in enumerate((-1.86,0,1.86)):
        rounded_box(f'ChunkyFrontPanel{i}', (1.82,1.24,.13), (x,.88,-1.468),
                    TEAL,root,bevel=.075,segments=2)
        loop_handle(f'GoldDoorLoop{i}',root,x,1.13,-1.575,.66,.20,.045)
        rounded_box(f'ChunkyBackPanel{i}', (1.82,1.24,.075), (x,.88,1.456),
                    TEAL,root,bevel=.055,segments=2)
    stamp(root,2.12,.59,-1.542,.39)
    for x in (-2.53,2.53):
        for z in (-1.18,1.18):
            cylinder('NavyIslandFoot',.18,.15,(x,.075,z),NAVY,root,vertices=12)
    return root


def rounded_perimeter(width, height, radius, samples=6):
    points=[]
    for cx,cy,angle in ((width/2-radius,height/2-radius,0),
                         (-width/2+radius,height/2-radius,90),
                         (-width/2+radius,-height/2+radius,180),
                         (width/2-radius,-height/2+radius,270)):
        for k in range(samples):
            a=math.radians(angle+k*90/(samples-1))
            points.append((cx+radius*math.cos(a),cy+radius*math.sin(a)))
    return points


def monitor_frame(root):
    """Connected rounded ring, including beveled outer and inner lips."""
    # Every outline is in the front XY plane and faces toward logical -Z.
    outlines=[(1.40,.90,.15,-.015),(1.46,.96,.17,.025),
              (1.46,.96,.17,.112),(1.10,.67,.12,.112),
              (1.06,.63,.105,.025),(1.10,.67,.12,-.015)]
    verts=[]
    for w,h,r,z in outlines:
        verts.extend(vec((x-.13,y+.69,z)) for x,y in rounded_perimeter(w,h,r))
    count=len(verts)//len(outlines)
    faces=[]
    for ring in range(len(outlines)):
        next_ring=(ring+1)%len(outlines)
        for k in range(count):
            j=(k+1)%count
            faces.append((ring*count+k,ring*count+j,next_ring*count+j,next_ring*count+k))
    mesh=bpy.data.meshes.new('ConnectedCreamCRTFrameMesh')
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new('ConnectedCreamCRTFrame',mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent=root
    for polygon in mesh.polygons:
        polygon.use_smooth=True
    # Surface winding is reversed because the ring traverses inward on its back.
    import bmesh
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free()
    paint(obj,P['cream'])


def vented_back(root):
    rear=rounded_box('BulkyVentedCRTBack', (1.12,.69,.22),(-.13,.69,.475),
                     NAVY,root,bevel=.12,segments=3)
    # The openings are cut in the casing; recessed ink geometry gives their depth.
    for x in (-.53,.27):
        for y in (.55,.635,.72,.805):
            cutter=rounded_box('VentCutter',(.18,.038,.35),(x,y,.49),
                               P['ink'],bevel=.015,segments=2)
            bpy.context.view_layer.objects.active=rear
            mod=rear.modifiers.new('ActualVentOpening','BOOLEAN')
            mod.operation='DIFFERENCE'; mod.solver='EXACT'; mod.object=cutter
            bpy.ops.object.modifier_apply(modifier=mod.name)
            bpy.data.objects.remove(cutter,do_unlink=True)
    rounded_box('DarkRecessInsideVents',(1.03,.59,.02),(-.13,.69,.40),
                '#151F2B',root,bevel=.05,segments=1)
    paint(rear,NAVY)


def chart_sector(root,start,end,color):
    verts=[vec((.19,.67,-.035))]
    steps=max(2,round((end-start)/math.tau*24))
    for k in range(steps+1):
        a=start+(end-start)*k/steps
        verts.append(vec((.19+.146*math.cos(a),.67+.146*math.sin(a),-.035)))
    faces=[(0,k+1,k) for k in range(1,len(verts)-1)]
    mesh=bpy.data.meshes.new('ChartPieSectorMesh');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('ChartPieSector',mesh);bpy.context.collection.objects.link(obj)
    obj.parent=root;paint(obj,color)


def build_computer():
    reset_scene()
    root=node('Computer')
    rounded_box('RoundedCRTStandFoot',(.77,.14,.53),(-.13,.07,.20),NAVY,root,
                bevel=.065,segments=2)
    rounded_box('StoutCRTNeck',(.38,.22,.31),(-.13,.215,.23),NAVY,root,
                bevel=.075,segments=1)
    rounded_box('BulgingNavyCRTShell',(1.44,.94,.48),(-.13,.69,.25),NAVY,root,
                bevel=.18,segments=3)
    monitor_frame(root)
    rounded_box('CyanWorkChartScreen',(1.08,.64,.065),(-.13,.69,.002),
                '#20C2E7',root,bevel=.09,segments=3)
    for i,height in enumerate((.12,.19,.27,.35)):
        rounded_box(f'ChartBar{i}',(.072,height,.012),(-.51+i*.105,.535+height/2,-.038),
                    GOLD,root,bevel=.008,segments=1)
    for start,end,color in ((0,1.5,P['yellow']),(1.5,3.05,P['teal']),
                            (3.05,5.5,P['cream']),(5.5,math.tau,P['red'])):
        chart_sector(root,start,end,color)
    for dx,angle in ((0,0),(.10,-.35),(.18,-.75)):
        rounded_box('ChartExcitementMark',(.028,.09,.012),(.17+dx,.935,-.037),
                    P['pink'],root,bevel=.013,segments=2,rotation=(0,0,angle))
    cylinder('HugeGoldPowerButton',.042,.022,(.47,.318,-.037),GOLD,root,
             axis=(0,0,1),vertices=12)
    vented_back(root)
    rounded_box('DeepTealKeyboard', (1.39,.17,.48),(-.18,.085,-.51),TEAL,root,
                bevel=.078,segments=2)
    for row in range(3):
        for col in range(8):
            if col==7 and row<2: continue
            x=-.775+col*.151
            z=-.65+row*.118
            rounded_box(f'LargeCreamKey{row}_{col}',(.132,.062,.102),(x,.197+row*.006,z),
                        P['cream'],root,bevel=.021,segments=1)
    rounded_box('HugeRedEnterVertical',(.151,.079,.23),(.292,.202,-.58),P['red'],root,
                bevel=.024,segments=2)
    rounded_box('HugeRedEnterToe',(.28,.079,.103),(.229,.203,-.644),P['red'],root,
                bevel=.025,segments=2)
    rounded_box('BigCreamSpacebar',(.68,.066,.104),(-.245,.2,-.771),P['cream'],root,
                bevel=.025,segments=2)
    rounded_box('KeyboardFrontLip',(1.35,.09,.16),(-.18,.08,-.729),TEAL,root,
                bevel=.045,segments=1)
    ellipsoid('PlumpTealMouse',(.34,.24,.42),(.736,.12,-.535),TEAL,root,
              segments=16,rings=8)
    rounded_box('OversizedMouseWheel',(.055,.042,.14),(.736,.242,-.58),NAVY,root,
                bevel=.020,segments=2)
    return root


def render_views(root,name,views=None):
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False
    scene.render.resolution_x=760;scene.render.resolution_y=540
    scene.render.resolution_percentage=100
    scene.world.color=(.35,.32,.27)
    scene.view_settings.view_transform='Standard'
    scene.view_settings.exposure=-.65
    ground=rounded_box('PreviewGround',(200,.08,200),(0,-.047,0),'#EFE6D4',bevel=0)
    vertices=[obj.matrix_world@v.co for obj in descendants(root) if obj.type=='MESH' for v in obj.data.vertices]
    low=Vector([min(v[i] for v in vertices) for i in range(3)])
    high=Vector([max(v[i] for v in vertices) for i in range(3)])
    center=(low+high)/2
    dim=high-low
    distance=max(dim)*2.8
    camera=bpy.data.objects.new('PreviewCamera',bpy.data.cameras.new('PreviewCamera'))
    bpy.context.collection.objects.link(camera);scene.camera=camera
    camera.data.type='ORTHO';camera.data.ortho_scale=max(dim.x,dim.y,dim.z)*1.33
    for label,location in (('Key',(-3,-4,7)),('Fill',(5,2,4))):
        lamp=bpy.data.objects.new(label,bpy.data.lights.new(label,'AREA'))
        bpy.context.collection.objects.link(lamp);lamp.location=location
        lamp.data.energy=700 if label=='Key' else 350;lamp.data.shape='DISK';lamp.data.size=5
    for label,offset in (('front',(0,1,.16)),('side',(1,0,.16)),('back',(0,-1,.16))):
        if views and label not in views: continue
        camera.location=center+Vector(offset)*distance
        camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=f'/tmp/{name}-{label}.png'
        bpy.ops.render.render(write_still=True)


if __name__=='__main__':
    bpy.context.preferences.filepaths.save_version=0
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    selected=next((arg.split('=',1)[1] for arg in args if arg.startswith('--asset=')),None)
    views=next((arg.split('=',1)[1].split(',') for arg in args if arg.startswith('--views=')),None)
    for name,builder in (('desk',build_desk),('cabinet',build_cabinet),('computer',build_computer)):
        if selected and selected!=name: continue
        root=builder()
        export_glb(root, APP/f'game/assets/models/{name}.glb',APP/f'art/models/{name}.blend')
        bounds=[obj.matrix_world@vertex.co for obj in descendants(root)
                if obj.type=='MESH' for vertex in obj.data.vertices]
        logical=[(point.x,point.z,-point.y) for point in bounds]
        low=[min(point[i] for point in logical) for i in range(3)]
        high=[max(point[i] for point in logical) for i in range(3)]
        print(f'ASSET_BOUNDS {name}: min={low} max={high} dimensions={[high[i]-low[i] for i in range(3)]}')
        if '--render' in args: render_views(root,name,views)
