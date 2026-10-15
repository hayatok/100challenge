"""Build v0.4 breakables from the generated three-view toy-office reference.

Blender 4.3.2+, Godot coordinates throughout. Preserve v0.4 silhouettes;
v0.7 adds a few named rigid groups for staged, nonphysical collapse.
Run: blender --background --python scripts/modeling/build_breakables.py
"""
from pathlib import Path
import math
import random
import sys
import bpy
import bmesh
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (APP, vec, node, paint, rounded_box, cylinder as base_cylinder, tube,
                    reset_scene, export_glb, _place, _smooth)

PAPER = '#FFF3DD'
EDGE = '#E3CDB0'
TEAL = '#138C91'
NAVY = '#253D55'
CARDBOARD = '#C98D55'
TAPE = '#DDA05B'
INK = '#292E34'
GRAY = '#919292'
RED = '#DF3E36'
YELLOW = '#FFC53E'


def mesh(name, vertices, faces, color, root, pos=(0, 0, 0), rotation=(0, 0, 0), smooth=False):
    data = bpy.data.meshes.new(name + '_Mesh')
    data.from_pydata([vec(p) for p in vertices], [], faces)
    data.update()
    bm=bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(data); bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    if smooth:
        _smooth(obj)
    paint(obj, color)
    return _place(obj, name, pos, root, rotation)


def cylinder(name,radius,depth,pos,color,root,axis=(0,1,0),vertices=12,bevel=0):
    # Cylinders for little holes/fasteners keep flat caps, avoiding redundant bevel rings.
    return base_cylinder(name,radius,depth,pos,color,root,axis=axis,vertices=vertices,bevel=0)


def wheel(name,pos,root):
    r=.19; depth=.14; verts=[]; n=12
    for x,scale in [(-depth/2,.82),(-depth*.30,1),(depth*.30,1),(depth/2,.82)]:
        for i in range(n):
            a=math.tau*i/n
            verts.append((pos[0]+x,pos[1]+r*scale*math.cos(a),pos[2]+r*scale*math.sin(a)))
    faces=[tuple(reversed(range(n))),tuple(range(3*n,4*n))]
    for j in range(3):
        for i in range(n): faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    mesh(name,verts,faces,INK,root,smooth=True)


def perimeter(w, d, radius=.055):
    # Three samples per corner, one midway along each side: 16 vertices.
    points = []
    for cx, cz, start in [(w/2-radius, d/2-radius, 0),
                           (-w/2+radius, d/2-radius, math.pi/2),
                           (-w/2+radius, -d/2+radius, math.pi),
                           (w/2-radius, -d/2+radius, 3*math.pi/2)]:
        for j in range(3):
            angle = start + j*math.pi/4
            points.append((cx+radius*math.cos(angle), cz+radius*math.sin(angle)))
        # midpoint to the following corner to support bowed faces.
        following = [(0, d/2), (-w/2, 0), (0, -d/2), (w/2, 0)][len(points)//4]
        points.append(following)
    return points


def loaf(name, size, pos, color, root, lean=0, yaw=0, bulge=.025, hollow=False):
    w, h, d = size
    vertices = []
    for y, scale in [(-h/2, .92), (-h/2+.04, 1), (0, 1+bulge), (h/2-.04, 1), (h/2, .93)]:
        for x,z in perimeter(w*scale,d*scale,min(.07,w*.1,d*.1)):
            vertices.append((x+lean*(y/h),y,z))
    n = 16
    faces = [tuple(reversed(range(n)))]
    for j in range(4):
        for i in range(n):
            faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    if hollow:
        # Preserve the bulging outside; a real cardboard rim and warm inner
        # floor remain visible when the papers spill and the carton crushes.
        for y in [h/2, -h/2+.065]:
            for x,z in perimeter(w*.86,d*.84,min(.06,w*.08,d*.08)):
                vertices.append((x,y,z))
        for i in range(n):
            j=(i+1)%n
            faces.append((4*n+i,4*n+j,5*n+j,5*n+i))
            faces.append((5*n+i,5*n+j,6*n+j,6*n+i))
        faces.append(tuple(range(6*n,7*n)))
    else:
        faces.append(tuple(range(4*n,5*n)))
    return mesh(name,vertices,faces,color,root,pos,(0,yaw,0),True)


def sheet(name, w, d, h, pos, root, color=PAPER, bend=.015, yaw=0, roll=0):
    # A whole curved paper packet/sheet, with rounded outlines and raised ends.
    vertices=[]
    for y in [-h/2,h/2]:
        for index,(x,z) in enumerate(perimeter(w,d,min(.03,d*.06))):
            if index%4==1: continue
            arch = bend * ((2*x/w)**2-.5) + .003*math.sin(z*9+x*8)
            vertices.append((x,y+arch,z))
    n=len(vertices)//2
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    for i in range(n):
        faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
    return mesh(name,vertices,faces,color,root,pos,(0,yaw,roll))


def papers(name, pos, size, count, root, seed=1, yaw=0, tilt=0):
    rng=random.Random(seed)
    w,h,d=size
    step=h/count
    for i in range(count):
        col = PAPER if i%3 else '#F6E5CD'
        sheet(name+f'_Layer{i:02}',w+rng.uniform(-.012,.012),d+rng.uniform(-.008,.008),
              step*.89,(pos[0]-(i+.5)*step*math.sin(tilt)+rng.uniform(-.012,.012), pos[1]+(i+.5)*step*math.cos(tilt),
                          pos[2]+rng.uniform(-.008,.008)),root,col,
              bend=.014+rng.uniform(-.006,.007),yaw=yaw,roll=tilt)


def ring(name,pos,radius,root,axis='front',color='#B7B1A1'):
    points=[]
    for i in range(9):
        a=math.tau*i/8
        if axis=='front': points.append((pos[0]+radius*math.cos(a),pos[1]+radius*math.sin(a),pos[2]))
        else: points.append((pos[0],pos[1]+radius*math.cos(a),pos[2]+radius*math.sin(a)))
    tube(name,points,.009,color,root,sides=4,capped=False)


def label(name,pos,w,h,root,yaw=0):
    rounded_box(name,(w,h,.008),pos,'#FFF2D6',root,bevel=0,segments=1,rotation=(0,yaw,0))
    for i, length in enumerate([.7,.48]):
        rounded_box(name+f'_Ink{i}',(w*length,h*.14,.009),
                    (pos[0]-w*.05,pos[1]+h*(.16-i*.32),pos[2]-.006),'#BAB6A8',root,
                    bevel=0,segments=1,rotation=(0,yaw,0))


def stamp(name,pos,w,h,root):
    # Bold stamp pictogram: four outer ink bars and two compact document glyphs.
    for x,y,ww,hh in [(0,h/2,w,.013),(0,-h/2,w,.013),(-w/2,0,.013,h),(w/2,0,.013,h)]:
        rounded_box(name+'_Frame',(ww,hh,.006),(pos[0]+x,pos[1]+y,pos[2]),RED,root,bevel=0,segments=1)
    for x in [-w*.22,w*.22]:
        for y in [-h*.23,0,h*.23]:
            rounded_box(name+'_Glyph', (w*.3,.012,.007),(pos[0]+x,pos[1]+y,pos[2]-.001),RED,root,bevel=0)
        rounded_box(name+'_GlyphStem',(.012,h*.75,.007),(pos[0]+x,pos[1],pos[2]-.002),RED,root,bevel=0)


def binder(name,pos,size,color,root,yaw=0,tilt=0,tab=RED,upright=False,details=True):
    w,h,d=size
    # Separate broad covers around visible cream page-block, thick curved spine.
    if upright:
        rounded_box(name+'_Pages',(w*.65,h*.9,d*.9),pos,PAPER,root,bevel=.016,segments=1,rotation=(0,yaw,tilt))
        for x in [-w*.42,w*.42]:
            rounded_box(name+'_Cover',(w*.18,h,d), (pos[0]+x,pos[1],pos[2]),color,root,
                        bevel=.022,segments=1,rotation=(0,yaw,tilt))
        rounded_box(name+'_Spine',(w,h,d*.13),(pos[0],pos[1],pos[2]-d*.44),color,root,
                    bevel=.025,segments=1,rotation=(0,yaw,tilt))
        if details:
            label(name+'_Label',(pos[0],pos[1]+h*.13,pos[2]-d/2-.003),w*.64,h*.47,root)
            cylinder(name+'_FingerHole',w*.22,.01,(pos[0],pos[1]-h*.32,pos[2]-d/2-.008),INK,root,axis=(0,0,1),vertices=12,bevel=0)
            ring(name+'_HoleRim',(pos[0],pos[1]-h*.32,pos[2]-d/2-.015),w*.22,root)
        rounded_box(name+'_Tab',(w*.55,.08,.12),(pos[0]+w*.07,pos[1]+h/2+.025,pos[2]-.13),tab,root,bevel=0,segments=1)
    else:
        # Local parent pivot allows all spine details to rotate with crooked binder.
        pivot=node(name+'_Temporary',root,pos,rotation=(0,yaw,tilt))
        rounded_box(name+'_PageBlock',(w*.94,h*.7,d*.9),(0,0,.015),PAPER,pivot,bevel=.015,segments=1)
        for y in [-h*.43,h*.43]:
            rounded_box(name+'_Cover',(w,h*.16,d),(0,y,0),color,pivot,bevel=.022,segments=1)
        rounded_box(name+'_Spine',(w,h,d*.15),(0,0,-d*.425),color,pivot,bevel=.03,segments=1)
        if details:
            label(name+'_Label',(-w*.12,0,-d/2-.003),w*.42,h*.58,pivot)
            cylinder(name+'_FingerHole',h*.23,.01,(w*.34,0,-d/2-.008),INK,pivot,axis=(0,0,1),vertices=12,bevel=0)
            ring(name+'_HoleRim',(w*.34,0,-d/2-.015),h*.24,pivot)
        rounded_box(name+'_Tab',(.075,h*.52,.12),(w/2+.025,0,-d*.1),tab,pivot,bevel=0,segments=1)
        # Bake construction pivot into meshes so final prop has one rigid surface.
        bpy.context.view_layer.update()
        for obj in list(pivot.children):
            world=obj.matrix_world.copy(); obj.parent=root; obj.matrix_world=world
        bpy.data.objects.remove(pivot,do_unlink=True)


def box(name='PaperBox',scale=1,pos=(0,0,0),root=None,loaded=True,details=True):
    own=root is None
    if own: root=node(name)
    # Build in local pivot, then bake placement for cart cargo reuse.
    pivot=node(name+'_Local',root,pos)
    loaf(name+'_BulgingCarton',(1,.86,.79),(0,.43,0),CARDBOARD,pivot,bulge=.025,hollow=own and loaded)
    for side in ([-1,1] if loaded else []):
        # folded side flaps hang visibly outward; top is open around the paper.
        rounded_box(name+'_FoldedSide',(.19,.035,.78),(side*.49,.82,0),'#CB925C',pivot,
                    bevel=.015,segments=1,rotation=(0,0,side*.65))
    for z,angle in ([(-.365,-.48),(.365,.48)] if loaded else []):
        rounded_box(name+'_FoldedLip',(.93,.033,.19),(0,.835,z),'#D3995F',pivot,
                    bevel=.014,segments=1,rotation=(angle,0,0))
    # Thick shiny-looking packing bands follow the bulging front, back and sides.
    for z in [-.408,.408]:
        rounded_box(name+'_CrossTape',(.16,.78,.012),(.01,.43,z),TAPE,pivot,bevel=0,segments=1)
        rounded_box(name+'_BellyTape',(.975,.13,.014),(0,.47,z),TAPE,pivot,bevel=0,segments=1)
    for x in [-.514,.514]:
        rounded_box(name+'_SideTape',(.012,.13,.77),(x,.47,0),TAPE,pivot,bevel=0,segments=1)
    if not loaded:
        rounded_box(name+'_LidTape',(.16,.014,.74),(.01,.865,0),TAPE,pivot,bevel=0)
    if details:
        rounded_box(name+'_TealSticker',(.285,.215,.012),(-.28,.235,-.414),TEAL,pivot,bevel=.013,segments=1)
        label(name+'_Label',(-.28,.235,-.423),.232,.16,pivot)
        stamp(name+'_Stamp',(.28,.215,-.418),.235,.16,pivot)
        # folded corner creases on rear too.
        for x in [-.445,.445]:
            tube(name+'_CornerCrease',[(x,.1,.39),(x*.97,.045,.386),(x*.92,.1,.391)],.005,'#99643D',pivot,sides=4)
    if loaded: papers(name+'_LoosePapers',(0,.84,0),(.77,.3,.67),12,pivot,7)
    bpy.context.view_layer.update()
    for obj in list(pivot.children):
        world=obj.matrix_world.copy(); obj.parent=root; obj.matrix_world=world
        obj.location = vec(pos)+scale*(obj.location-vec(pos)); obj.scale*=scale
    bpy.data.objects.remove(pivot,do_unlink=True)
    return root


def tower():
    root=node('PaperTower')
    rounded_box('LowTealPlatform',(1.02,.13,.89),(0,.105,0),TEAL,root,bevel=.04,segments=1)
    for x in [-.38,.38]:
        for z in [-.32,.32]:
            rounded_box('RubberFoot',(.1,.07,.1),(x,.035,z),'#176168',root,bevel=.024,segments=1)
    blocks=[(.17,.36,-.015,.025),(.76,.38,.05,-.07),(1.37,.4,-.025,.075),(1.98,.4,.055,-.055)]
    for i,(y,h,x,tilt) in enumerate(blocks):
        papers('WobblyPaper'+str(i),(x,y,0),(.88,h,.77),8,root,10+i,yaw=(i-1.5)*.024,tilt=tilt)
    for i,(y,x,tilt,c) in enumerate([(.64,.035,-.075,TEAL),(1.26,-.025,.055,NAVY),(1.86,.015,-.095,TEAL)]):
        binder('FatBinder'+str(i),(x,y,0),(.96,.23,.82),c,root,tilt=tilt,tab=YELLOW if i==0 else RED)
    return root


def shelf(name,y,root):
    # Thick curved platform sags below its load, all four rounded corners.
    vertices=[]
    for dy in [-.045,.045]:
        for x,z in perimeter(1.23,.86,.09):
            vertices.append((x,y+dy-.045*(1-(x/.615)**2),z))
    faces=[tuple(reversed(range(16))),tuple(range(16,32))]
    for i in range(16): faces.append((i,(i+1)%16,(i+1)%16+16,i+16))
    mesh(name+'_BowedTray',vertices,faces,TEAL,root,smooth=True)
    for z in [-.445,.445]:
        pts=[(-.59+j*(1.18/6),y+.06-.043*math.sin(math.pi*j/6),z) for j in range(7)]
        tube(name+'_CurvedRim',pts,.038,TEAL,root,sides=6)


def cart():
    root=node('PaperCart')
    for x in [-.535,.535]:
        for z in [-.365,.365]:
            wheel('RubberCaster',(x,.19,z),root)
            cylinder('WheelInset',.115,.147,(x,.19,z),'#555454',root,axis=(1,0,0),vertices=8,bevel=.008)
            cylinder('AxleCap',.045,.164,(x,.19,z),'#B4B1A6',root,axis=(1,0,0),vertices=8,bevel=.006)
            # One gray tapered fork on outside face, rounded broad shoulders.
            xx=x+(.081 if x>0 else -.081)
            verts=[(xx-.016,.18,z-.04),(xx-.016,.4,z-.10),(xx-.016,.4,z+.1),(xx-.016,.18,z+.04),
                   (xx+.016,.18,z-.04),(xx+.016,.4,z-.10),(xx+.016,.4,z+.1),(xx+.016,.18,z+.04)]
            faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
            mesh('CasterFork',verts,faces,GRAY,root)
    shelf('LowerShelf',.46,root)
    shelf('UpperShelf',1.12,root)
    for x in [-.59,.59]:
        # Front lower posts and curled back handle are curved continuous rails.
        tube('FrontPost',[(x,.42,-.4),(x,.8,-.4),(x,1.2,-.4),(x,1.4,-.38),(x,1.45,-.32)],.041,TEAL,root,sides=6)
        tube('HandleUpright',[(x,.43,.4),(x,1.05,.4),(x,1.52,.4),(x,1.68,.44),
                              (x,1.80,.46),(x,1.87,.4),(x,1.88,.3)],.043,TEAL,root,sides=6)
        tube('RubberHandGrip',[(x,1.875,.31),(x,1.88,.4),(x,1.83,.46)],.061,INK,root,sides=6)
        for y in [.49,1.16]:
            cylinder('VisibleRailBolt',.032,.015,(x,y,-.448),'#C8C3B5',root,axis=(0,0,1),vertices=8,bevel=.005)
    papers('TopPaperCargo',(-.36,1.18,-.005),(.45,.46,.70),8,root,30)
    stamp('TopStackStamp',(-.36,1.36,-.373),.18,.115,root)
    papers('BottomPaperCargo',(-.39,.52,.02),(.4,.47,.68),7,root,45)
    binder('TopNavyFile',(.015,1.425,.03),(.145,.54,.64),NAVY,root,upright=True,tab=RED)
    binder('TopTealFile',(.18,1.40,.01),(.145,.49,.63),TEAL,root,upright=True,tab=YELLOW)
    box('TopCarton',.36,(.425,1.175,.025),root,loaded=False,details=False)
    box('BottomCarton',.38,(-.035,.525,.025),root,loaded=False,details=False)
    binder('LowerNavyFile',(.30,.78,.02),(.15,.51,.65),NAVY,root,upright=True,tab=RED)
    binder('LowerTealFile',(.47,.755,.035),(.11,.46,.62),TEAL,root,upright=True,tab=YELLOW,details=False)
    return root


def motion_groups(root, filename):
    """Keep original world geometry, but author meaningful destruction pivots.

    export_glb merges geometry by parent, so every group is still one shared
    vertex-colored surface. The runtime batches intact and settled poses.
    """
    bpy.context.view_layer.update()
    original = [obj for obj in root.children_recursive if obj.type == 'MESH']
    if filename == 'paper_box':
        origins = {'CartonBody': (0, 0, 0), 'FlapLeft': (-.49, .82, 0),
                   'FlapRight': (.49, .82, 0), 'FlapFront': (0, .835, -.365),
                   'FlapBack': (0, .835, .365),
                   'PaperLow': (0, .89, 0), 'PaperMiddle': (0, .99, 0),
                   'PaperTop': (0, 1.09, 0)}
        def classify(obj):
            logical = Vector((obj.location.x, obj.location.z, -obj.location.y))
            if 'FoldedSide' in obj.name:
                return 'FlapLeft' if logical.x < 0 else 'FlapRight'
            if 'FoldedLip' in obj.name:
                return 'FlapFront' if logical.z < 0 else 'FlapBack'
            if 'LoosePapers_Layer' in obj.name:
                layer = int(obj.name.split('Layer')[1][:2])
                return ['PaperLow', 'PaperMiddle', 'PaperTop'][min(2, layer // 4)]
            return 'CartonBody'
    elif filename == 'paper_tower':
        origins = {'TowerBase': (0, 0, 0), 'TowerLow': (0, .17, 0),
                   'TowerMiddle': (0, .76, 0), 'TowerUpper': (0, 1.37, 0),
                   'TowerCrown': (0, 1.98, 0)}
        def classify(obj):
            if obj.name.startswith('WobblyPaper'):
                return ['TowerLow', 'TowerMiddle', 'TowerUpper', 'TowerCrown'][int(obj.name[11])]
            if obj.name.startswith('FatBinder'):
                return ['TowerLow', 'TowerMiddle', 'TowerUpper'][int(obj.name[9])]
            return 'TowerBase'
    else:
        origins = {'CartFrame': (0, 0, 0), 'CasterLoose': (.535, .19, -.365),
                   'CastersFixed': (0, .19, 0), 'CargoPaper': (0, .8, 0),
                   'CargoBinders': (0, .8, 0), 'CargoCartons': (0, .8, 0)}
        def classify(obj):
            if any(obj.name.startswith(prefix) for prefix in ['RubberCaster', 'WheelInset', 'AxleCap', 'CasterFork']):
                logical = Vector((obj.location.x, obj.location.z, -obj.location.y))
                # wheel/fork meshes are baked around authored positions.
                center = sum((v.co for v in obj.data.vertices), Vector()) / len(obj.data.vertices)
                logical = Vector((center.x + obj.location.x, center.z + obj.location.z,
                                  -center.y - obj.location.y))
                return 'CasterLoose' if logical.x > 0 and logical.z < 0 else 'CastersFixed'
            if 'PaperCargo' in obj.name or obj.name.startswith('TopStackStamp'):
                return 'CargoPaper'
            if any(key in obj.name for key in ['NavyFile', 'TealFile']):
                return 'CargoBinders'
            if 'Carton' in obj.name:
                return 'CargoCartons'
            return 'CartFrame'
    groups = {name: node(name, root, origin) for name, origin in origins.items()}
    bpy.context.view_layer.update()
    for obj in original:
        world = obj.matrix_world.copy()
        obj.parent = groups[classify(obj)]
        obj.matrix_world = world
    return root


def main():
    bpy.context.preferences.filepaths.save_version=0
    for filename,builder in [('paper_box',box),('paper_tower',tower),('paper_cart',cart)]:
        reset_scene()
        root=motion_groups(builder(), filename)
        export_glb(root,APP/'game/assets/models'/f'{filename}.glb',APP/'art/models'/f'{filename}.blend')
        # Report world-space Godot extents, including every detail.
        bpy.context.view_layer.update()
        verts=[obj.matrix_world@v.co for obj in root.children_recursive if obj.type=='MESH' for v in obj.data.vertices]
        logical=[Vector((v.x,v.z,-v.y)) for v in verts]
        lo=[min(v[i] for v in logical) for i in range(3)]
        hi=[max(v[i] for v in logical) for i in range(3)]
        print('ASSET_EXTENTS',filename,'min',lo,'max',hi,'size',[hi[i]-lo[i] for i in range(3)])

if __name__=='__main__': main()
