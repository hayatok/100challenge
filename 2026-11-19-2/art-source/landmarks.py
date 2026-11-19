"""Bake the four central landmarks and their walkable-world footprints."""
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from approaches import FONT, OUT, Mesh

STEEL = "365453"
TEAL = "39706b"
INK = "263938"
IVORY = "e6dbc0"
AMBER = "d9a351"
RED = "984d39"
TIMBER = "826349"
CONCRETE = "7c827a"
GOLD = "f2ce88"


class Building(Mesh):
    def __init__(self, region):
        super().__init__(1)
        self.region = region
        self.footprints = []

    def footprint(self,x,z,width,depth,height):
        self.footprints.append(dict(region=self.region,x=x,z=z,width=width,depth=depth,height=height))

    def beam(self,start,end,width,depth,color):
        origin,tip=Vector(start),Vector(end)
        axis=(tip-origin).normalized()
        cross=axis.cross(Vector((0,0,1)))
        if cross.length<.01:
            cross=axis.cross(Vector((0,1,0)))
        side=cross.normalized()*width*.5
        across=axis.cross(side.normalized())*depth*.5
        loop=[-side-across,side-across,side+across,-side+across]
        rings=[[center+offset for offset in loop] for center in (origin,tip)]
        self.face(rings[0][::-1],color)
        self.face(rings[1],color)
        for j in range(4):
            k=(j+1)%4
            self.face([rings[0][j],rings[0][k],rings[1][k],rings[1][j]],color)

    def board(self,text,x,y,z,width,height,size,face,color=INK):
        self.box(x,y,z,width,height,.14,color)
        for side in (-1,1):
            self.box(x+side*(width*.5-.037),y,z,.073,height+.026,.174,AMBER)
            self.box(x,y+side*(height*.5-.023),z,width,.045,.167,STEEL)
        self.letter(text,x,y,z,face,size,IVORY)

    def letter(self,text,x,y,z,face,size,color):
        curve=bpy.data.curves.new("Lettering","FONT")
        curve.font=FONT
        curve.body=text
        curve.align_x="CENTER"
        curve.align_y="CENTER"
        curve.size=size*2.12
        curve.resolution_u=2
        obj=bpy.data.objects.new("Lettering",curve)
        bpy.context.collection.objects.link(obj)
        mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        mesh.calc_loop_triangles()
        for tri in mesh.loop_triangles:
            points=[mesh.vertices[i].co for i in tri.vertices]
            self.face([(x-face*p.x,y+p.y,z+face*.091) for p in points],color)
        bpy.data.meshes.remove(mesh)
        bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.curves.remove(curve)

    def lens(self,x,y,z,width,depth):
        self.box(x,y,z,width,.085,depth,INK)
        self.face([(x-width*.46,y-.048,z-depth*.43),(x+width*.46,y-.048,z-depth*.43),
                   (x+width*.46,y-.048,z+depth*.43),(x-width*.46,y-.048,z+depth*.43)],GOLD,tag=15)

    def fruit(self,x,y,z,radius,color):
        points=[]
        for j in range(3):
            v=(j-.99)*.76
            rr=math.sqrt(1-v*v)*radius
            points.append([(x+rr*math.cos(k*math.tau/6),y+v*radius,
                            z+rr*math.sin(k*math.tau/6)) for k in range(6)])
        self.face(points[2],color)
        for first,second in zip(points,points[1:]):
            for k in range(6):
                j=(k+1)%6
                self.face([first[k],first[j],second[j],second[k]],color)

    def packed_crate(self,x,y,z,width,depth,accent):
        b=self.box
        b(x,y+.05,z,width,.092,depth,"6c5540")
        for side in (-1,1):
            zz=z+side*(depth*.5-.026)
            xx=x+side*(width*.5-.027)
            for level in (.09,.167,.245):
                b(x,y+level,zz,width,.064,.043,accent)
                b(xx,y+level,z,.043,.064,depth-.07,accent)
            for zz in (z-depth*.5+.055,z+depth*.5-.055):
                b(xx,y+.161,zz,.071,.277,.071,"91735a")

    def pallet(self,x,z,color):
        b=self.box
        for dx in (-.49,0,.49):
            b(x+dx,.086,z,.117,.127,1.07,TIMBER)
        for dz in (-.45,-.22,0,.22,.45):
            b(x,.17,z+dz,1.14,.077,.145,"9c7f60")
        for n,(dx,dz) in enumerate(((-.26,-.26),(.26,-.26),(-.26,.24),(.26,.24),(.0,.0))):
            y=.204+(.37 if n==4 else 0)
            self.packed_crate(x+dx,y,z+dz,.49,.475,color)
            self.box(x+dx,y+.211,z+dz,.41,.19,.40,color)


def arcade():
    ground,roof,glass=Building(0),Building(0),Building(0)
    b=ground.box
    profile=[(-17,5.34),(-13.6,6.45),(-10.2,7.47),(-6.8,8.16),(-3.4,8.64),
             (0,8.81),(3.4,8.64),(6.8,8.16),(10.2,7.47),(13.6,6.45),(17,5.34)]
    bays=(-31,-24.8,-18.6,-12.4,-6.2,0,6.2,12.4,18.6,24.8,31)
    for i,z in enumerate(bays):
        for side in (-1,1):
            x=side*16.45
            b(x,.49,z,.61,.98,.74,CONCRETE)
            b(x,2.96,z,.30,4.42,.32,STEEL)
            b(x,4.77,z,.56,.24,.55,TEAL)
            ground.beam((x,4.42,z),(side*14.78,5.78,z),.11,.14,TEAL)
            roof.beam((side*17,5.36,z),(side*19.4,4.64,z),.13,.16,STEEL)
            roof.lens(side*12.15,5.53,z,1.65,.21)
        for j,((x,h),(x2,h2)) in enumerate(zip(profile,profile[1:])):
            roof.beam((x,h,z),(x2,h2,z),.18,.19,STEEL)
            roof.beam((x,h+.54,z),(x2,h2+.54,z),.12,.16,TEAL)
            roof.beam((x,h,z),(x2,h2+.54,z),.076,.10,STEEL)
            roof.beam((x2,h2,z),(x2,h2+.54,z),.069,.092,STEEL)
            if i==len(bays)-1:
                continue
            next_z=bays[i+1]
            roof.beam((x,h+.57,z),(x,h+.57,next_z),.082,.089,TEAL)
            for k in (1,2,3):
                zz=z+(next_z-z)*k/4
                roof.beam((x,h+.57,zz),(x2,h2+.57,zz),.058,.068,STEEL)
            # Leave the central crest open. The sawtooth gaps expose the sky
            # between cloudy wire glass and the lower shop-side metal panels.
            if j not in (4,5) or i%3==1:
                for k in range(4):
                    a=z+(next_z-z)*k/4+.035
                    h1=h+.605
                    h2a=h2+.605
                    c=z+(next_z-z)*(k+1)/4-.035
                    shade="b1c0b5" if (i+k+j)%4 else "879f98"
                    glass.face([(x,h1,a),(x2,h2a,a),(x2,h2a,c),(x,h1,c)],shade,tag=9)
    for z,face in ((-23,-1),(6.8,-1),(28,1)):
        for x in (-2.9,2.9):
            roof.beam((x,6.06,z),(x,8.74,z),.071,.082,STEEL)
        roof.board("商店街",0,5.68,z,5.84,1.03,.68,face,TEAL)
        roof.lens(0,5.11,z,4.2,.20)
    for side in (-1,1):
        for z in (-22,-15,-8,-1,6,13,20):
            x=side*13.7
            b(x,.034,z,1.28,.018,3.68,"77847a")
            b(x-side*.70,.040,z,.057,.023,3.68,IVORY)

    rng=random.Random(417)
    locations=[
        (-8.9,-4.9,-1,RED,"青果",("ae4e3a","a77e39","e5a347")),
        (-13.1,4.4,-1,TEAL,"野菜",("6f8549","898842","a3a252")),
        (6.7,.4,1,"b48048","朝市",("b17445","9b6847","ccab6d")),
        (10.6,10,1,"58766c","商店会",("8e6947","b98a51","767750"))]
    for x,z,side,accent,label,fruit_colors in locations:
        ground.footprint(x,z,2.44,3.08,2.52)
        for dx in (-.86,.86):
            for dz in (-1.26,1.26):
                b(x+dx,1.19,z+dz,.084,2.38,.085,TEAL)
                b(x+dx,.08,z+dz,.16,.16,.15,"797d71")
        b(x,.817,z,1.62,.16,2.55,"795942")
        b(x,.54,z,1.53,.047,2.38,"7c614a")
        for i in range(8):
            zz=z-1.39+i*.377
            hue=accent if i%2==0 else IVORY
            front=x-side*1.10
            back=x+side*.98
            ground.face([(front,2.14,zz),(back,2.53,zz),(back,2.53,zz+.377),
                         (front,2.14,zz+.377)],hue)
            b(front,2.09,zz+.188,.077,.133,.376,hue)
        for i,(dz,color) in enumerate(zip((-.81,0,.81),fruit_colors)):
            xx=x-side*.28
            ground.packed_crate(xx,.90,z+dz,.78,.69,"997357")
            for j in range(14):
                dx=(j%4-1.5)*.143+rng.uniform(-.023,.023)
                zz=(j//4-1.5)*.139+rng.uniform(-.025,.025)
                r=rng.uniform(.059,.085)
                ground.fruit(xx+dx,1.114+rng.uniform(0,.039),z+dz+zz,r,color)
        ground.board(label,x,1.87,z-1.30,1.45,.35,.244,-1,accent)
        ground.packed_crate(x+side*.76,.028,z-.94,.54,.63,TIMBER)
        ground.packed_crate(x+side*.76,.028,z+.86,.54,.63,"665d43")

    for x,z,face in ((-7.7,8.7,-1),(12.4,-14.0,-1)):
        ground.footprint(x,z,3.31,1.62,2.44)
        for side in (-1,1):
            b(x+side*1.51,1.14,z+.58,.125,2.28,.13,TEAL)
        b(x,2.38,z,3.35,.13,1.59,RED)
        b(x-.72,.94,z-.35,1.81,.16,.69,TIMBER)
        b(x-.72,.43,z-.35,1.70,.76,.51,IVORY)
        b(x+.84,.59,z+.36,.97,.09,.51,TIMBER)
        b(x+1.06,1.40,z+.45,.66,.38,.045,"40493b")
        b(x+.84,.49,z-.36,.53,.061,.49,TIMBER)
        for dx in (-.19,.19):
            b(x+.84+dx,.24,z-.35,.06,.42,.39,TEAL)
        b(x+.84,.73,z+.18,.45,.50,.10,"6d765f")
        b(x+.41,.057,z+.12,.49,.108,.56,"565e4d")
        for dx,dz in ((-.93,-.41),(-.44,-.30),(-.77,-.51)):
            b(x+dx,1.029,z+dz,.21,.018,.30,IVORY)
        ground.board("避難受付",x,2.20,z-.76,3.29,.53,.34,face,RED)
        ground.lens(x,2.29,z-.24,1.15,.15)
    return ground,roof,glass


def freight():
    g,trolley=Building(1),Building(1)
    b=g.box
    for x in (-14.2,14.15):
        for z in (-10.8,1.9):
            g.footprint(x,z,1.2,1.2,6.75)
            b(x,.28,z,1.15,.56,1.15,CONCRETE)
            b(x,3.3,z,.54,6.14,.51,"8b794f")
            b(x,.81,z,.61,.34,.58,INK)
            for dz in (-2,2):
                g.beam((x,4.52,z+dz),(x,6.55,z),.16,.24,STEEL)
            b(x,6.47,z,.84,.67,.89,INK)
        b(x,6.71,-4.45,.80,.53,14.4,"7e765a")
        b(x,7.06,-4.45,.13,.16,14.6,INK)
    for z in (-6.6,-4.4,-2.22):
        b(0,6.64,z,28.78,.61,.50,"9a844f")
        b(0,7.03,z,28.78,.13,.24,STEEL)
        for j in range(15):
            x=-13.75+j*1.96
            g.beam((x,7.0,z-.21),(x+1.01,7.75,z-.21),.076,.077,INK)
            g.beam((x+1.01,7.75,z-.21),(x+1.96,7.0,z-.21),.076,.077,INK)
        b(0,7.76,z,28.9,.11,.21,INK)
    g.board("荷役場",0,6.33,-6.95,4.61,.74,.49,-1,"746343")
    for x,z in ((-12.6,10.1),(11.7,9.2),(-11.9,-13.9)):
        g.footprint(x,z,2.53,3.08,1.83)
        for dx in (-.60,.62):
            for dz in (-.80,.78):
                g.pallet(x+dx,z+dz,TIMBER)
        b(x,1.04,z,.94,.26,1.56,"718479")
        b(x,1.23,z,.88,.12,1.45,INK)
        for dx in (-1.12,1.12):
            g.pole(x+dx,z-1.31,.04,1.10,.08,AMBER)
    for x in (-6.8,6.8):
        for z in (-16,-14,-12,-10,-8,-6,-4,-2,0,2,4,6,8,10):
            b(x,.034,z,.087,.025,.86,AMBER)
    for x in (-.78,.78):
        for z in (-.47,.47):
            trolley.box(x,.14,z,.26,.50,.26,INK)
            trolley.beam((x,.04,z),(x,-2.63,z),.047,.046,INK)
    trolley.box(0,.04,0,2.4,.64,1.55,"846b42")
    trolley.box(0,-2.52,0,2.23,.27,1.27,AMBER)
    trolley.box(0,-2.81,0,1.92,.38,1.00,STEEL)
    for j in range(6):
        x=-.95+j*.37
        trolley.face([(x,-2.67,-.51),(x+.14,-2.67,-.51),
                      (x+.27,-2.94,-.51),(x+.13,-2.94,-.51)],INK)
    return g,trolley


def station_hall():
    g=Building(2)
    b=g.box
    for x in (-4.7,-2.9,2.75,4.6):
        g.footprint(x,13.1,.51,1.47,1.25)
        b(x,.64,13.1,.48,1.23,1.43,"6a827e")
        b(x,1.244,13.1,.50,.09,1.41,INK)
        g.face([(x-.16,1.294,12.78),(x+.16,1.294,12.78),
                (x+.16,1.294,13.01),(x-.16,1.294,13.01)],"d5ceb0",tag=15)
        b(x,.79,12.37,.20,.18,.061,"ab5c4a")
        b(x,.79,13.83,.20,.18,.063,"81a293")
    for x in (-6.05,5.94):
        g.footprint(x,13.6,.55,.58,4.6)
        b(x,1.82,13.6,.45,3.6,.46,TEAL)
        b(x,.27,13.6,.62,.52,.62,CONCRETE)
        g.beam((x,2.6,13.6),(x*.75,3.88,13.6),.12,.14,STEEL)
    b(0,3.89,13.6,12.38,.38,.38,TEAL)
    g.board("発車案内",-.05,3.17,13.32,6.26,.82,.48,-1,INK)
    g.board("環状線",-.05,3.17,13.87,5.24,.66,.41,1,TEAL)
    g.lens(0,2.64,13.48,4.89,.15)
    for x in (-3.45,3.45):
        for z in (-.08,.08):
            b(x,2.94,13.26+z,1.59,.45,.08,"534a3b")
        g.letter("2   →" if x>0 else "←   1",x,2.93,13.18,-1,.32,IVORY)
    # Two dial faces and a cold cast-iron bezel hang above the open central lane.
    x,y,z=0,4.72,13.6
    g.beam((x,y-.64,z),(x,3.81,z),.12,.14,INK)
    for face in (-1,1):
        rows=[]
        for rad,dz in ((.71,.13),(.70,.176),(.61,.20)):
            rows.append([(x+rad*math.sin(i*math.tau/32),
                          y+rad*math.cos(i*math.tau/32),z+face*dz) for i in range(32)])
        for a,c in zip(rows,rows[1:]):
            for j in range(32):
                k=(j+1)%32
                g.face([a[j],a[k],c[k],c[j]],STEEL)
        g.face(rows[-1],IVORY)
        for j in range(12):
            a=j*math.tau/12
            xx=math.sin(a)
            yy=math.cos(a)
            g.beam((x+.49*xx,y+.49*yy,z+face*.206),
                   (x+.57*xx,y+.57*yy,z+face*.206),.036,.019,INK)
        for a,length,w in ((.42,.34,.052),(-1.3,.46,.028)):
            zz=z+face*.218
            g.beam((x,y,zz),(x+math.sin(a)*length,y+math.cos(a)*length,zz),w,.021,INK)
    for x,z in ((-13.1,12),(-13.1,15.4),(11.5,15.1)):
        g.footprint(x,z,1.03,2.45,1.21)
        for dz in (-.86,.86):
            b(x,.21,z+dz,.72,.42,.13,"526a65")
        b(x,.48,z,.71,.14,2.31,"68786d")
        b(x-.30,.88,z,.14,.43,2.34,"718078")
        b(x+.33,.72,z-1.06,.15,.51,.075,INK)
        if x<0:
            b(x-.63,.23,z+.69,.36,.42,.44,"766758")
    for x in (-3.09,-1.54,0,1.54,3.09):
        b(x,.035,7.06,.077,.019,1.50,AMBER)
    return g


def terminal():
    g,roof=Building(3),Building(3)
    b=g.box
    for side in (-1,1):
        x,z=side*12.94,-11.85
        g.footprint(x+side*.58,z,1.39,5.97,2.55)
        for dz in (-2.72,2.72):
            b(x+side*.88,.28,z+dz,.42,.56,.44,CONCRETE)
            b(x+side*.88,1.46,z+dz,.26,2.94,.25,TEAL)
            roof.beam((x+side*.88,2.48,z+dz),(x-side*1.23,3.17,z+dz),.14,.21,STEEL)
        b(x+side*.88,1.61,z,.10,1.77,5.42,"86a39c")
        for j in range(4):
            b(x+side*.82,1.61,z-2.35+j*1.56,.08,1.82,.055,TEAL)
        for dz in (-1.45,0,1.45):
            b(x,.39,z+dz,.61,.14,1.27,"68736a")
            b(x+side*.28,.74,z+dz,.095,.33,1.30,STEEL)
            b(x,.21,z+dz,.35,.36,.10,INK)
        roof.face([(x-side*1.20,3.18,z-3.00),(x+side*1.09,3.54,z-3.00),
                   (x+side*1.09,3.54,z+3.00),(x-side*1.20,3.18,z+3.00)],"667c75")
        for xx,yy in ((x-side*1.2,3.17),(x+side*1.08,3.52)):
            roof.box(xx,yy,z,.16,.29,6.12,TEAL)
        roof.lens(x-side*.40,3.16,z,.19,2.65)
        # The wide lane-facing wing stays high and open so bus queues retain
        # visibility under it. Its underslung fixtures define the boarding side.
        x1,x2 = side*15.4,side*8.2
        for k in range(4):
            edge=z-4.9+k*2.45
            roof.face([(x1,3.97,edge),(x2,4.78,edge),(x2,4.78,edge+2.43),
                       (x1,3.97,edge+2.43)],("617973" if k%2 else "789189"))
            roof.beam((x1,3.94,edge),(x2,4.75,edge),.13,.19,STEEL)
            roof.lens(side*10.31,4.43,edge+1.05,.19,1.59)
        for xx,yy in ((x1,3.95),(x2,4.76)):
            roof.box(xx,yy,z,.16,.19,9.85,TEAL)
        for dz in (-3.65,3.65):
            roof.beam((side*13.8,2.68,z+dz),(side*13.8,4.15,z+dz),.17,.21,STEEL)
            roof.beam((side*13.8,3.14,z+dz),(side*11.9,4.35,z+dz),.10,.14,STEEL)
        g.board("バス待合",x,2.53,z-2.93,2.30,.56,.32,-1,TEAL)
        for j in range(5):
            b(x-side*1.32,.035,z-2.37+j*.95,.16,.023,.54,AMBER)
        g.packed_crate(x+side*.21,.033,z+2.16,.41,.48,TIMBER)

    for side in (-1,1):
        x=side*14.4
        g.footprint(x,5.2,.63,1.19,5.74)
        b(x,.36,5.2,.67,.71,1.21,CONCRETE)
        b(x,2.63,5.2,.27,4.58,.44,STEEL)
        g.beam((x,3.75,5.2),(x-side*2.51,5.92,5.2),.17,.18,TEAL)
    for y in (5.82,6.57):
        b(0,y,5.2,29.04,.16,.29,STEEL)
    for j in range(12):
        x=-14.20+j*2.37
        g.beam((x,5.8,5.2),(x+1.14,6.58,5.2),.073,.113,TEAL)
        g.beam((x+1.14,6.58,5.2),(x+2.37,5.80,5.2),.076,.112,TEAL)
    g.board("バス乗り場",-4.7,5.39,5.15,5.11,.80,.48,-1,TEAL)
    g.lens(-4.7,4.91,5.15,3.50,.20)
    for x,z in ((-12.9,10.1),(11.9,13.5)):
        g.footprint(x,z,2.04,2.3,1.42)
        for dx,dz in ((-.58,-.56),(.54,.52),(.55,-.56)):
            g.pallet(x+dx,z+dz,"a58b64")
    return g,roof


if __name__=="__main__":
    market,arc,panes=arcade()
    warehouse,lift=freight()
    station=station_hall()
    terminal,shelters=terminal()
    ground=(market,warehouse,station,terminal)
    for region,asset in enumerate(ground):
        asset.write(f"landmark{region}")
    for name,asset in (("landmark0Roof",arc),("landmark0Glazing",panes),
                       ("landmark1Gantry",lift),("landmark3Roof",shelters)):
        asset.write(name)
    solids=[box for scene in ground for box in scene.footprints]
    (OUT/"DistrictLandmarks.json").write_text(json.dumps({"solids":solids},indent=2)+"\n",encoding="ascii")
    print(f"Central landmarks exported with {len(solids)} physical footprints.")
