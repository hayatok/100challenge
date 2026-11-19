"""Bake the market relief canopy, station refuge signs, and field controls in metres."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from landmarks import Building

IVORY, STEEL, RUBBER, TEAL, RED = "e3dfc9","677c78","384442","3d7268","ab5138"


def canopy():
    g=Building(0)
    for x in (-2.1,2.1):
        for z in (-1.48,1.48):
            g.pole(x,z,.045,2.42,.049,STEEL)
            g.pole(x,z,.12,1.43,.057,"9fadaa")
            g.box(x,.036,z,.31,.071,.28,RUBBER)
        g.beam((x,2.43,-1.48),(x,2.43,1.48),.070,.074,STEEL)
    for z in (-1.48,0,1.48):
        g.beam((-2.1,2.43,z),(0,3.02,z),.064,.077,STEEL)
        g.beam((0,3.02,z),(2.1,2.43,z),.064,.077,STEEL)
    # Sewn panels sag across the frame. Separate faces keep the cloth fold and hem visible from below.
    for side in (-1,1):
        for j in range(12):
            z1,z2=-1.68+j*.28,-1.68+(j+1)*.28
            for k in range(6):
                u1,u2=k/6,(k+1)/6
                def point(u,z):
                    y=3.13-.63*u-.12*math.sin(math.pi*u)-.029*math.sin((z+1.68)*math.pi/1.68)**2
                    return side*u*2.31,y,z
                shade=("537c6d","587f70","537a6a")[(j//4)%3]
                g.face([point(u1,z1),point(u2,z1),point(u2,z2),point(u1,z2)],shade,4)
            g.face([(side*2.31,2.51,z1),(side*2.31,2.51,z2),(side*2.31,2.25,z2),(side*2.31,2.25,z1)],TEAL,4)
        for z in (-1.68,1.68):
            g.face([(0,3.13,z),(side*2.31,2.51,z),(side*2.31,2.31,z),(0,2.31,z)],"527768",4)
    g.board("一時待避所",0,2.43,-1.71,2.91,.49,.287,-1,TEAL)
    g.board("一時待避所",0,2.43,1.71,2.91,.49,.287,1,TEAL)
    for x in (-1.18,1.18):
        g.beam((x-.19,.02,.97),(x+.19,.44,1.32),.041,.046,STEEL)
        g.beam((x+.19,.02,.97),(x-.19,.44,1.32),.041,.046,STEEL)
    for z in (1.04,1.18,1.32):g.box(0,.459,z,2.86,.052,.118,"987955")
    g.box(-.83,.567,1.19,.62,.14,.35,"b1a17d")
    g.box(-.83,.663,1.19,.55,.056,.31,"d1c3a2")
    g.write("columnMarketCanopy")


def refuge_board(name,text):
    g=Building(2)
    for x in (-1.32,1.32):
        g.box(x,1.42,0,.087,2.84,.14,STEEL)
        g.box(x,.045,0,.34,.09,.40,RUBBER)
        for y in (.24,.42,.60):g.box(x,y,-.077,.09,.071,.017,"d6b572")
    g.board(text,0,2.55,0,2.74,.61,.286,-1,TEAL)
    g.board(text,0,2.55,0,2.74,.61,.286,1,TEAL)
    g.box(0,2.90,0,2.84,.089,.258,STEEL)
    for x in (-1.20,1.20):g.box(x,2.385,-.105,.067,.067,.04,"d5c098")
    g.write(name)


def field_control(name,label,station):
    g=Building(2 if station else 0)
    g.box(0,.076,0,.69,.152,.57,RUBBER)
    g.box(0,.65,0,.59,1.18,.42,"6a817b")
    g.box(0,1.35,0,.80,.50,.51,IVORY)
    g.box(0,1.42,-.269,.63,.18,.032,"253e3c")
    for x in (-.23,-.12,-.01):g.box(x,1.43,-.289,.052,.052,.012,"87bb9b")
    for x in (.15,.23):g.box(x,1.43,-.292,.056,.092,.012,"d9bb71")
    for x in (-.22,0,.22):g.box(x,1.23,-.28,.106,.081,.052,RED if x<0 else RUBBER)
    g.pole(.22,0,1.61,.21,.080,"b49356")
    g.box(0,.81,-.225,.43,.29,.035,IVORY)
    for i in range(5):g.box(0,.84-i*.035,-.250,.30-.02*i,.011,.018,STEEL)
    g.board(label,0,1.96,0,1.72,.39,.224,-1,TEAL)
    g.box(0,1.70,.04,.063,.29,.088,STEEL)
    if station:
        # Staff gauge in decimetres, paired with the flood band's actual surface level.
        g.box(.62,.84,0,.17,1.66,.067,IVORY)
        for i in range(16):g.box(.65 if i%5 else .62,.058+i*.10,-.041,.073 if i%5 else .16,.017,.014,RED)
    g.write(name)


def stretcher():
    g=Building(2)
    for side in (-1,1):
        x=side*.322
        g.beam((x,.68,-.99),(x,.68,.99),.052,.052,"a0a9a1")
        g.beam((x,.71,-.98),(x,1.0,-1.07),.047,.048,STEEL)
        g.beam((x,1.0,-1.07),(x,1.0,-1.20),.054,.053,RUBBER)
        for z in (-.63,.63):
            g.beam((x*.87,.66,-z),(x*.87,.21,z),.049,.048,"aa9365")
            g.box(x,.18,z,.093,.16,.095,STEEL)
            # Wheel in the vertical plane; a separate metal hub reads in side profile.
            for width,radius,color in ((.083,.111,RUBBER),(.092,.052,STEEL)):
                rings=[]
                for edge in (-1,1):
                    rings.append([(x+edge*width/2,.112+radius*math.sin(i*math.tau/18),z+radius*math.cos(i*math.tau/18)) for i in range(18)])
                g.face(rings[0],color);g.face(rings[1][::-1],color)
                for i in range(18):
                    j=(i+1)%18;g.face([rings[0][i],rings[1][i],rings[1][j],rings[0][j]],color)
        for z in (-.29,.30):
            g.beam((x,.69,z),(x,.86,z),.034,.038,STEEL)
        g.beam((x,.86,-.31),(x,.86,.32),.047,.046,"b3b8ad")
    g.box(0,.703,0,.62,.073,1.84,"466558")
    g.box(0,.745,0,.565,.032,1.78,"768c78")
    for z in (-.63,.64):g.beam((-.30,.25,z),(.30,.25,z),.048,.048,STEEL)
    g.box(0,.78,-.67,.43,.056,.31,"bdc4ae")
    g.write("columnStretcher")


def grip_arms():
    from characters.viewmodel import glove
    class GripMesh(Building):
        def poly(self,points,color):
            self.face(points,color)
    g=GripMesh(2)
    for s in (-1,1):
        wrist=(s*.322,1.04,-1.23)
        g.beam((s*.40,1.19,-1.64),wrist,.115,.126,"586254")
        g.beam((s*.341,1.07,-1.295),wrist,.107,.102,"353e36")
        glove(g,wrist,(-s*.11,-.22,.97),(s*.05,-.98,-.20),s>0,22)
    g.write("columnStretcherArms")


stretcher()
grip_arms()
canopy()
refuge_board("columnRailLift","昇降機前")
refuge_board("columnRailService","保守通路")
field_control("columnMarketControl","市場横戸",False)
field_control("columnFloodControl","防火扉操作盤",True)
