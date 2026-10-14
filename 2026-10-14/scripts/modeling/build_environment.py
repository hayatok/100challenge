"""Reference-led v0.4 exit and office environment, in logical Godot metres.

Read 07-exit-clock.png and 08-office-modules.png before editing. Elevator front
is +Z, unlike other asset fronts; its open entrance is at Z=0, clear X +/-2.90.
Clock origin is its face centre. Wall/floor origins are at ground centre.
"""
from pathlib import Path
import math
import sys
import bpy
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (APP, PALETTE as P, reset_scene, node, rounded_box as box,
                    cylinder, ellipsoid, tube, text, export_glb, vec, paint)

MODELS = APP / 'game/assets/models'
SOURCES = APP / 'art/models'


def finish(root, name):
    export_glb(root, MODELS / (name + '.glb'), SOURCES / (name + '.blend'))


def elevator():
    reset_scene()
    r = node('Elevator')
    # The broad frame rounds outward; the aperture itself stays 5.8m wide.
    for side in (-1, 1):
        box('TealFramePost', (.35, 4.8, .60), (side*3.075, 2.40, -.18), P['teal'], r, bevel=.16, segments=3)
        box('GoldOpeningEdge', (.13, 4.25, .10), (side*2.965, 2.13, .155), P['yellow'], r, bevel=.055)
        box('ShellSide', (.28, 4.50, 5.65), (side*3.10, 2.30, -3.02), P['dark_teal'], r, bevel=.12)
        # Open doors stack against the side walls, never across the entrance.
        box('RetractedDoor', (.15, 4.10, 1.15), (side*3.005, 2.10, -.88), P['teal'], r, bevel=.07)
        box('DoorHandle', (.065, .72, .07), (side*2.905, 1.86, -.35), P['yellow'], r, bevel=.03)
        box('IvoryInteriorSide', (.06, 2.6, 4.4), (side*2.92, 1.72, -3.29), P['cream'], r, bevel=.02, segments=1)
        box('PostBoot', (.42, .18, .67), (side*3.075, .09, -.19), P['dark_teal'], r, bevel=.055)
    box('TealFrameHeader', (6.50, .65, .60), (0, 4.48, -.18), P['teal'], r, bevel=.25, segments=3)
    box('GoldLintel', (6.02, .18, .10), (0, 4.23, .16), P['yellow'], r, bevel=.07)
    box('CabRoof', (6.2, .18, 5.6), (0, 4.40, -3.00), P['orange'], r, bevel=.075)
    box('CabRear', (6.2, 4.5, .2), (0, 2.30, -5.83), P['teal'], r, bevel=.09)
    box('WarmRearWindow', (5.70, 2.65, .06), (0, 2.82, -5.70), P['orange'], r, bevel=.035, segments=1)
    box('SunsetGlow', (5.6, 1.55, .04), (0, 3.31, -5.65), '#FFB654', r, bevel=.02, segments=1)
    for i, (x, h) in enumerate([(-2.2, .82), (-1.65, 1.22), (-.90, .58), (.02, .94), (.85, 1.3), (1.55, .78), (2.18, 1.06)]):
        box('RearCity', (.54, h, .055), (x, 1.77+h/2, -5.60), '#D97640', r, bevel=.015, segments=1)
    box('RearIvoryPadding', (5.70, 1.27, .10), (0, .72, -5.60), '#E5BE8C', r, bevel=.045, segments=1)
    box('ComicallyFatHandrail', (5.5, .15, .16), (0, 1.36, -5.43), P['yellow'], r, bevel=.065)
    box('CabFloor', (6.12, .12, 5.91), (0, .06, -2.88), '#65A56B', r, bevel=.04, segments=1)
    box('GoldThreshold', (5.85, .08, .35), (0, .06, .08), P['yellow'], r, bevel=.035)
    box('ExitSignGoldBorder', (3.10, .74, .20), (0, 4.73, .18), P['yellow'], r, bevel=.11, segments=2)
    box('ExitSignGreen', (2.88, .58, .065), (0, 4.73, .305), '#268954', r, bevel=.075)
    text('EXIT', 'EXIT', .58, (-.56, 4.55, .349), P['white'], r, rotation=(math.pi, 0, 0), font_path=None, extrude=.001)
    # Simple running person and arrow, readable at gameplay scale.
    ellipsoid('ExitPersonHead', (.13, .13, .05), (.49, 4.93, .36), P['white'], r, segments=8, rings=4)
    for n, pts in enumerate([[(.47,4.84,.36),(.38,4.70,.36),(.48,4.62,.36)],[(.42,4.73,.36),(.61,4.72,.36)],[(.45,4.65,.36),(.29,4.51,.36)],[(.47,4.65,.36),(.61,4.51,.36)],[(.74,4.72,.36),(1.18,4.72,.36)],[(1.01,4.86,.36),(1.18,4.72,.36),(1.01,4.58,.36)]]):
        tube('ExitIcon'+str(n), pts, .033, P['white'], r, sides=5)
    for x in (-2.50, -1.97, 1.97, 2.50):
        ellipsoid('SmallCelebrationBulb', (.23, .23, .13), (x, 4.52, .16), P['yellow'], r, segments=8, rings=4)
    box('FatCallPanel', (.48, 1.10, .22), (3.23, 1.92, .18), P['yellow'], r, bevel=.10)
    for y, flip in ((2.15, 1), (1.70, -1)):
        cylinder('CallButton', .145, .06, (3.23, y, .325), P['ink'], r, axis=(0,0,1), vertices=12, bevel=.015)
        # No inaccessible text: big up/down arrow triangles on the two buttons.
        pts=[(3.15,y-.07*flip,.362),(3.31,y-.07*flip,.362),(3.23,y+.085*flip,.362)]
        mesh=bpy.data.meshes.new('ButtonArrowMesh'); mesh.from_pydata([vec(p) for p in pts], [], [(0,1,2) if flip==1 else (2,1,0)]);mesh.update()
        obj=bpy.data.objects.new('ButtonArrow',mesh);bpy.context.collection.objects.link(obj);obj.parent=r;paint(obj,P['cream'])
    finish(r, 'elevator')


def clock():
    reset_scene(); r=node('Clock')
    cylinder('ThickTealClockRim', .75, .24, (0,0,0), P['teal'], r, axis=(0,0,1), vertices=40, bevel=.05)
    cylinder('CreamClockFace', .635, .055, (0,0,-.142), P['cream'], r, axis=(0,0,1), vertices=32, bevel=.012)
    for i in range(12):
        a=i*math.tau/12
        box('BoldGoldHourTick', (.065,.135,.03), (.535*math.sin(a),.535*math.cos(a),-.183), P['yellow'], r, bevel=.025, segments=1, rotation=(0,0,-a))
    box('MinuteHandAtTwelve', (.082,.43,.035), (0,.204,-.214), P['ink'], r, bevel=.035, segments=2)
    # Five o'clock, measured clockwise on the front face.
    box('HourHandAtFive', (.105,.31,.035), (-.0775,-.1342,-.224), P['ink'], r, bevel=.042, segments=2, rotation=(0,0,math.pi*5/6))
    cylinder('GoldenHandHub', .073, .044, (0,0,-.252), P['yellow'], r, axis=(0,0,1), vertices=16, bevel=.008)
    box('SeventeenHundredPlate', (.38,.16,.045), (0,-.365,-.22), P['red'], r, bevel=.035)
    text('ClockTime', '17:00', .128, (0,-.402,-.249), P['white'], r, rotation=(0,0,math.pi), font_path=None, extrude=.0007)
    # A small embossed rear hanger keeps the back view intentionally authored.
    box('BackHanger', (.24,.30,.045), (0,0,.143), P['dark_teal'], r, bevel=.05, segments=1)
    cylinder('HangerHole', .034, .012, (0,.04,.17), P['ink'], r, axis=(0,0,1), vertices=8, bevel=0)
    finish(r,'clock')


def window_module():
    reset_scene(); r=node('WindowModule')
    box('IvoryWallBack', (8.8,6,.14), (0,3,.10), P['cream'], r, bevel=.055)
    box('MintLowerPanel', (8.18,1.40,.22), (0,1.0,-.065), '#57B6A7', r, bevel=.085)
    for x in (-1.38,1.38):
        box('LowerPanelSeam', (.025,1.3,.014), (x,1.0,-.183), P['dark_teal'], r, bevel=.008, segments=1)
    box('ThickIvorySkirting', (8.8,.35,.35), (0,.175,0), P['cream'], r, bevel=.11)
    for x in (-4.15,4.15):
        box('IvoryRoundUpright', (.50,5.82,.35), (x,3.0,0), P['cream'], r, bevel=.15, segments=3)
    box('SunsetWindow', (7.78,3.94,.05), (0,3.73,-.015), '#FF9C60', r, bevel=.02, segments=1)
    box('RosySunsetTop', (7.76,1.02,.02), (0,5.19,-.05), '#F58B91', r, bevel=.008, segments=1)
    cylinder('SettingSun', .81, .015, (1.15,2.72,-.07), P['yellow'], r, axis=(0,0,1), vertices=28, bevel=0)
    for i,(x,w,h) in enumerate([(-3.35,.50,1.28),(-2.76,.63,1.68),(-2.10,.38,.78),(-1.58,.48,1.01),(-.93,.61,.52),(-.18,.52,.87),(.53,.50,.65),(1.18,.43,1.24),(1.79,.50,.83),(2.37,.60,1.57),(3.08,.60,2.37)]):
        box('SteppedNavyCity', (w,h,.025), (x,1.90+h/2,-.087), '#3C4B6B', r, bevel=.004, segments=1)
        if h>1.15:
            for k in range(2):
                box('CityWindowGlow', (.085,.12,.008), (x,2.4+k*.38,-.106), '#FFC071', r, bevel=0)
    box('CityAntenna', (.06,.36,.025), (3.08,4.41,-.087), '#3C4B6B', r, bevel=.004, segments=1)
    for y in (1.77,5.75):
        box('BroadGoldenWindowRail', (8.12,.25,.20), (0,y,-.07), P['yellow'], r, bevel=.10, segments=2)
    for x in (-3.91,-1.31,1.31,3.91):
        box('GoldWindowMullion', (.16,3.92,.17), (x,3.75,-.10), P['yellow'], r, bevel=.055)
    box('RearMintLowerPanel', (7.78,1.40,.025), (0,1.0,.177), '#57B6A7', r, bevel=.01, segments=1)
    for x in (-1.31,1.31):
        box('RearLowerSeam', (.022,1.32,.009), (x,1.0,.195), P['dark_teal'], r, bevel=0)
        box('RearIvoryMullion', (.065,3.94,.026), (x,3.74,.178), P['cream'], r, bevel=.012, segments=1)
    finish(r,'window_module')


def chevron(root, z):
    # Thick flat rounded-looking wayfinding shape points down the course (-Z).
    coords=[(-.78,z+.37),(-.84,z+.18),(0,z-.38),(.84,z+.18),(.78,z+.37),(0,z-.11)]
    verts=[vec((x,y,zz)) for y in (.151,.170) for x,zz in coords]
    faces=[tuple(reversed(range(6))),tuple(range(6,12))]
    faces += [(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
    mesh=bpy.data.meshes.new('ChevronMesh');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('RaisedGreenChevron',mesh);bpy.context.collection.objects.link(obj);obj.parent=root;paint(obj,'#AFDD60')
    bevel=obj.modifiers.new('Soft arrow edge','BEVEL');bevel.width=.045;bevel.segments=2
    bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.modifier_apply(modifier=bevel.name);obj.select_set(False)


def floor_module():
    reset_scene(); r=node('FloorModule')
    base=node('BaseTiles',r); way=node('Wayfinding',r)
    box('ThinTealTileEdge',(8,.10,8),(0,.05,0),P['teal'],base,bevel=.045)
    # The base is complete without Wayfinding, so background tiles stay neutral.
    box('WarmSeamBed',(7.94,.025,7.94),(0,.1025,0),'#DDC3A2',base,bevel=.01,segments=1)
    for x in (-3.33,-2,-.67,.67,2,3.33):
        for z in (-3,-1,1,3):
            # The 8mm bevel was subpixel in gameplay but repeated over 45 modules.
            # Keep the broad molded module edge; tile seams are colored geometry.
            box('CreamTile',(1.28,.016,1.94),(x,.123,z),P['cream'],base,bevel=0)
    box('CentralTealGuidanceStrip',(2.60,.016,7.9),(0,.142,0),P['teal'],way,bevel=.008,segments=1)
    for z in (-3,-1,1,3):
        box('GuidanceStripSeam',(2.60,.006,.025),(0,.153,z-.98),P['dark_teal'],way,bevel=0)
    for z in (-1.8,.05): chevron(way,z)
    box('FloorTimePlate',(1.64,.015,.56),(0,.17,2.4),P['red'],way,bevel=.007,segments=1)
    text('FloorTime','17:00',.40,(0,.18,2.57),P['white'],way,rotation=(math.pi/2,0,0),font_path=None,extrude=.0005)
    finish(r,'floor_module')


if __name__ == '__main__':
    for build in (elevator,clock,window_module,floor_module): build()
