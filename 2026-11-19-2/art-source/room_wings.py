"""Bake the four walkable northern buildings and matching collision footprints."""
import json
import math
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from landmarks import Building, OUT

WALL = 0
FLOOR = 1
METAL = 2
CLOTH = 3
WOOD = 4
GLASS = 5
LIGHT = 6
MARK = 7
CEILING = 8
EXTERIOR = 9

Z_START, Z_END, CUT = 93.0, 151.0, 1.14
ROWS = (101.,120.,139.)
STATIONS = [(x,z) for z in ROWS for x in (-8.,8.)]
REGIONS = (
    ("北街診療所", ("夜間受付","配電室","観察病室","薬品庫","救護室","地域診療所"),
     "dedbc9","7d9b91","4f756b","c2c8b9","cad1c3",3.61),
    ("北物流センター", ("検量窓口","搬送盤","検品室","荷さばき場","作業員出口","積載口"),
     "b5aa91","7b8378","bd884a","969184","aab1a8",5.72),
    ("環状線北口", ("改札窓口","放送室","駅務室","連絡通路","北改札","北ホーム"),
     "d8d3ac","5f7f78","3d6a64","969d89","b7b8aa",5.96),
    ("河岸車両基地", ("整備受付","動力室","点検ピット","部品庫","運転班詰所","配車室"),
     "afb9b6","788c88","c18d45","898f87","849893",5.55),
)


class Wing(Building):
    def box(self,x,y,z,w,h,d,color,tag=WALL):
        points=[(x+a*w/2,y+b*h/2,z+c*d/2)
                for b in (-1,1) for c in (-1,1) for a in (-1,1)]
        cells=((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3))
        for cell in cells:
            self.face([points[i] for i in cell],color,tag)

    def measured(self,x,z,w,d,h):
        self.footprint(x,z,w,d,h)

    def pane(self,x,y,z,width,height,color,along_x):
        w,d=(width,.03) if along_x else (.03,width)
        self.box(x,y,z,w,height,d,color,GLASS)
        for t in (-1,1):
            if along_x:
                self.box(x+t*width/2,y,z,.065,height+.065,.084,"50605b",METAL)
            else:
                self.box(x,y,z+t*width/2,.084,height+.065,.065,"50605b",METAL)

    def prop_sign(self,text,x,y,z,w,accent):
        self.board(text,x,y,z,w,.47,.27,-1,accent)

    def partition(self,upper,x,z,w,d,high,tone,dado):
        # The lower structure stays in the command view and owns collision.
        self.measured(x,z,w,d,high)
        self.box(x,CUT/2,z,w,CUT,d,dado)
        self.box(x,.095,z,w+.049,.19,d+.049,"6e7770",METAL)
        self.box(x,CUT+.014,z,w+.038,.055,d+.038,"afb8ac")
        upper.box(x,(CUT+high)/2,z,w,high-CUT,d,tone)

    def room_frame(self,upper,x,z,along_x,accent):
        clearance=1.55 if along_x else 1.49
        width,height=(2*clearance+.13,2.68)
        for d in (-clearance,clearance):
            xx=x+d if along_x else x
            zz=z if along_x else z+d
            self.box(xx,CUT*.5,zz,.14,CUT,.14,accent,METAL)
            upper.box(xx,(height+CUT)*.5,zz,.14,height-CUT,.14,accent,METAL)
        w,d=(width,.16) if along_x else (.16,width)
        upper.box(x,height,z,w,.16,d,accent,METAL)

    def cabinet(self,x,z,w,d,h,c,metal=False):
        finish=METAL if metal else WOOD
        self.box(x,h*.53,z,w,h*.87,d,c,finish)
        self.box(x,.072,z,w*.91,.143,d*.9,"3b4946",METAL)
        self.box(x,h,z,w+.058,.083,d+.09,"a9ad9c" if not metal else "878e86",finish)
        sections=max(2,round(w/.63))
        for i in range(sections):
            q=x+w*((i+.5)/sections-.5)
            self.box(q,h*.56,z-d*.505,w/sections-.029,h*.72,.018,c,finish)
            self.box(q,h*.72,z-d*.524,.147,.029,.043,"4b5b55",METAL)

    def stool(self,x,z,seat="788579",back=False):
        self.box(x,.44,z,.40,.082,.39,seat,CLOTH)
        for dx in (-.145,.145):
            for dz in (-.136,.136):
                self.box(x+dx,.211,z+dz,.031,.421,.031,"5b6b62",METAL)
        if back:
            self.box(x,.73,z+.17,.38,.34,.089,seat,CLOTH)

    def monitor(self,x,z,y=1.13):
        self.box(x,y+.19,z,.49,.30,.092,"303e3c",METAL)
        self.box(x,y+.194,z-.049,.421,.23,.017,"65887a",GLASS)
        for i in range(3):
            self.box(x-.108+i*.107,y+.193,z-.061,.052,.021,.012,"9dc198",MARK)
        self.box(x,y-.037,z,.081,.17,.082,"424f48",METAL)
        self.box(x,y-.121,z,.234,.034,.18,"313e38",METAL)

    def cartons(self,x,z,y,seed,count=2):
        rng=random.Random(seed)
        for i in range(count):
            w,d,h=rng.uniform(.34,.60),rng.uniform(.36,.59),rng.uniform(.27,.49)
            dx=(i-(count-1)*.5)*.65
            self.box(x+dx,y+h*.5,z,w,h,d,("9c7a53","ad8b60","9f895e")[i%3],WOOD)
            self.box(x+dx,y+h*.54,z-d*.505,w*.33,.13,.013,"d8cfb1",MARK)
            self.box(x+dx,y+h+.006,z,.037,.012,d,"bda97f",WOOD)

    def bed(self,x,z,accent,covered):
        self.box(x,.486,z,1.05,.13,2.34,"637d77",METAL)
        self.box(x,.616,z,.98,.17,2.26,"d4d5c0",CLOTH)
        self.box(x,.72,z+.73,.80,.13,.45,"e5dfc8",CLOTH)
        self.box(x,.72,z-.38,.989,.076,1.44,covered,CLOTH)
        self.box(x,.883,z+1.14,1.06,.56,.10,accent,METAL)
        self.box(x,.745,z-1.13,1.06,.26,.09,accent,METAL)
        for dx in (-.40,.40):
            for dz in (-.88,.88):
                self.box(x+dx,.23,z+dz,.061,.453,.069,"75847b",METAL)
                self.box(x+dx,.104,z+dz,.12,.15,.10,"424f49",METAL)

    def rack(self,x,z,w,color,seed,levels=4):
        self.box(x,.10,z,w,.18,.68,"64736c",METAL)
        for dx in (-w/2+.041,w/2-.041):
            for dz in (-.29,.29):
                self.box(x+dx,levels*.268,z+dz,.071,levels*.536,.077,color,METAL)
        for i in range(levels):
            y=.28+i*.492
            self.box(x,y,z,w,.066,.65,color,METAL)
            self.cartons(x,z,y+.035,seed+i,max(2,round(w/.72)))

    def workbench(self,x,z,w,color,screen=True):
        self.cabinet(x,z,w,.87,1.02,color,True)
        if screen:
            self.monitor(x+.31,z+.17,1.17)
        self.box(x-.32,1.07,z-.12,.40,.034,.25,"c6c8b7",MARK)


def shell(region):
    _,_,tone,dado,accent,floor,plafond,h=REGIONS[region]
    lower,upper=Wing(region),Wing(region)
    def section(x,z,w,d):
        lower.partition(upper,x,z,w,d,h,tone,dado)

    wall=.27
    middle=(Z_START+Z_END)/2
    length=Z_END-Z_START
    lower.box(0,-.19,125.08,82.0,.28,74.0,"7d8378",EXTERIOR)
    for side in (-1,1):
        x=side*18.8
        lower.box(x,-.029,124.2,4.85,.060,66.5,"959689",EXTERIOR)
        lower.box(x+side*2.39,.049,124.2,.13,.099,66.5,"a4a093",EXTERIOR)
        for j in range(9):
            z=99+j*6.2
            lower.box(side*23.64,.005,z,4.29,.009,.09,"b9b49d",MARK)
            lower.box(side*25.76,.003,z+2.16,.078,.008,4.31,"b9b49d",MARK)
    lower.box(0,-.061,122,29.28,.124,length+.32,floor,FLOOR)
    lower.box(0,-.028,92.16,34.22,.036,2.42,"a3a598",FLOOR)
    for side in (-1,1):
        section(side*14.5,middle,wall,length)
        section(side*8.64,Z_START,11.72,wall)
        for z0,z1 in zip((Z_START,102.55,121.55,140.55),
                         (99.45,118.45,137.45,Z_END)):
            section(side*3.5,(z0+z1)/2,.25,z1-z0)
        for z in ROWS:
            lower.room_frame(upper,side*3.5,z,False,accent)
        for z in (110.,130.):
            section(side*7.085,z,7.18,.23)
            section(side*13.96,z,1.08,.23)
            lower.room_frame(upper,side*11.77,z,True,accent)
    section(0,Z_END,29.27,wall)

    # The junction connects the existing asphalt to the actual entrance.
    lower.box(0,.027,92.0,5.35,.026,.28,"d6ceab",MARK)
    for side in (-1,1):
        lower.box(side*2.78,CUT*.52,Z_START,.31,CUT,.45,accent,METAL)
        upper.box(side*2.78,(2.97+CUT)*.5,Z_START,.31,2.97-CUT,.45,accent,METAL)
        upper.pane(side*1.45,3.18,Z_START-.055,2.60,.40,"738d83",True)
        lower.box(side*4.34,.49,92.58,.05,.98,.092,accent,METAL)
        lower.box(side*5.27,.49,92.58,.05,.98,.092,accent,METAL)
        lower.box(side*4.81,.75,92.58,.97,.16,.099,accent,METAL)
    upper.box(0,3.18,Z_START,5.69,.20,.41,accent,METAL)
    upper.box(0,3.67,92.30,12.1,.27,2.47,accent,METAL)
    upper.lens(0,3.47,91.98,6.5,.30)
    entrance_name,room_names,*_=REGIONS[region]
    upper.board(entrance_name,0,3.82,91.02,8.96,.76,.54,-1,accent)
    for side in (-1,1):
        if region in (0,2):
            for x in (side*6.64,side*10.95):
                y=2.26 if region==0 else 2.83
                wh=1.72 if region==0 else 2.78
                upper.box(x,y,Z_START-.165,3.28,wh+.16,.12,accent,METAL)
                upper.pane(x,y,Z_START-.232,3.03,wh,"739389" if region==0 else "6e877f",True)
                for dx in (-.98,0,.99):
                    upper.box(x+dx,y,Z_START-.252,.075,wh,.075,accent,METAL)
                upper.box(x,y-.25,Z_START-.255,3.03,.059,.078,accent,METAL)
                upper.box(x,y-wh*.5-.05,Z_START-.234,3.43,.093,.23,accent,METAL)
            if region==0:
                x=side*4.34
                upper.box(x,2.86,Z_START-.282,.58,.58,.083,"6d9688",METAL)
                upper.box(x,2.86,Z_START-.330,.14,.383,.022,"e6e2d0",MARK)
                upper.box(x,2.86,Z_START-.335,.383,.14,.022,"e6e2d0",MARK)
        else:
            x=side*9.53
            ymax=h-.66
            upper.box(x,(ymax+CUT)*.5,Z_START-.174,6.7,ymax-CUT,.109,"576b63",METAL)
            for y in range(11):
                yy=1.29+y*.318
                upper.box(x,yy,Z_START-.244,6.50,.046,.067,"8c9380",METAL)
            for dx in (-3.47,3.47):
                upper.box(x+dx,(ymax+CUT)*.5,Z_START-.246,.27,ymax-CUT,.245,accent,METAL)
                lower.box(x+dx,CUT*.53,Z_START-.246,.27,CUT,.245,accent,METAL)
            upper.box(x,ymax+.07,Z_START-.24,7.04,.27,.27,accent,METAL)
        for i in range(3):
            lower.box(side*(4+i*1.15),.030,91.40,.53,.016,1.62,accent,MARK)

    # Interior direction changes read from the road, the corridor and the cutaway.
    for idx,(x,z) in enumerate(STATIONS):
        room_top=min(h-.26,3.15 if region==0 else 3.37)
        upper.prop_sign(room_names[idx],x,room_top,z+2.64,3.80,accent)
        for face in (-1,1):
            tx=math.copysign(2.74,x)
            tz=z+face*1.71
            lower.box(tx,.027,tz,.97,.032,.069,accent,MARK)
        lower.box(x,.020,z,1.85,.023,.055,accent,MARK)

    # All bays have independently shaped light sources and overhead structure.
    upper.box(0,h+.16,middle,29.05,.28,length+.33,plafond,CEILING)
    for i in range(10):
        z=94.68+i*5.60
        beam_y=h-(.20 if region==0 else .49)
        for x in (-10.4,0,10.4):
            w=1.95 if region==0 else 3.30
            upper.lens(x,beam_y-.075,z,w,.29 if region==0 else .32)
        upper.box(0,beam_y+.051,z,28.65,.19,.22,accent,METAL)
        if region!=0:
            for sign in (-1,1):
                upper.beam((sign*3.47,h-.43,z),(sign*2.08,h-.09,z),.096,.18,accent)
    for side in (-1,1):
        lower.box(side*3.08,.023,122,.044,.019,54.7,accent,MARK)
        for z in (95,113,131,147):
            lower.box(side*2.75,.024,z,.51,.022,.11,accent,MARK)
        for i in range(5):
            z=98+11.1*i
            upper.pane(side*14.335,2.57 if region==0 else 3.56,z,3.4,.89 if region==0 else 1.34,"6d8b80",False)
    return lower,upper


def clinic(g,upper):
    mint,pale="869f90","d4d4b9"
    for x,z,w,d,h in ((-9.1,104.35,4.48,1.03,1.17),(9.83,104.30,4.71,1.10,1.15),
                      (-9.4,124.01,6.42,3.06,1.60),(9.80,124.34,6.65,1.0,2.23),
                      (-9.75,143.32,5.5,1.15,1.64),(10.6,144.02,4.12,2.67,1.55)):
        g.measured(x,z,w,d,h)
    g.cabinet(-9.18,104.35,4.42,.99,1.13,"a6a994")
    for x in (-10.58,-8.86):
        g.monitor(x,104.47,1.25)
        g.box(x+.55,1.193,104.10,.32,.026,.31,"dedbc7",MARK)
    g.workbench(9.82,104.40,4.53,mint)
    g.box(10.78,1.18,104.20,.64,.117,.38,"bbbcb0",METAL)
    g.box(9.85,1.54,104.75,3.54,.64,.20,"7c9590",METAL)
    for i in range(8):
        g.box(8.50+i*.38,1.60,104.635,.128,.074,.019,
              "a5b7a2" if i%3 else "d9bf81",LIGHT)
    for j,x in enumerate((-11.61,-9.62,-7.60)):
        z=124.00
        g.bed(x,z,mint,("b5c5ac","9dab9b","bfbea1")[j])
        g.cabinet(x+.60,z+.89,.48,.40,.63,pale)
        if j<2:
            for j2 in range(12):
                dz=z-1.24+j2*.23
                g.box(x+.97,1.29,dz,.034,1.83,.231,"bbcabb" if j2%2 else "8ea99d",CLOTH)
            upper.box(x+.98,2.49,z+.035,.049,.064,2.89,mint,METAL)
    for x in (7.70,9.82,11.87):
        g.rack(x,124.33,1.79,"7e9d8b",int(x*9),4)
    g.cabinet(-9.75,143.32,5.08,1.02,1.07,pale)
    for x in (-11.43,-9.63,-7.71):
        g.monitor(x,143.41,1.25)
    for x in (9.58,11.45):
        g.bed(x,144.06,mint,"afc0ae")
    for x in (-2.57,2.57):
        for z in (97.0,113.5,132.0):
            g.box(x,.96,z,.40,.086,1.18,"76968d",METAL)
            g.box(x,.43,z,.44,.063,1.19,"9ba99a",CLOTH)
            g.box(x,.20,z,.16,.40,.095,"6c8074",METAL)
            g.measured(x,z,.57,1.22,1.03)
    for z in (96.3,116.0,136.0):
        upper.board("診療区画",0,2.88,z,3.40,.39,.24,-1,"6e9185")
        upper.box(0,3.31,z,2.30,.079,.24,"688981",METAL)
        upper.lens(0,3.24,z,2.10,.18)
    # Wall protection, utility outlets and a treatment privacy track.
    for x in (-3.33,3.33):
        for a,b in ((102.58,118.39),(121.61,137.39)):
            g.box(x,.82,(a+b)/2,.114,.118,b-a,"a9b4a3",WOOD)
    for j in range(3):
        x=-11.43+j*1.91
        upper.box(x,1.47,125.57,1.66,.43,.087,"b9b5a1",METAL)
        for dx in (-.56,0,.56):
            upper.box(x+dx,1.45,125.514,.095,.093,.034,"638e7f",METAL)
        upper.box(x,2.22,125.60,1.60,.31,.066,"7c9e90",METAL)
    for j in range(4):
        x=-11.68+j*1.34
        g.box(x,.019,124.06,1.22,.024,2.94,"a2ad9c",FLOOR)
    for side in (-1,1):
        # Ceiling channels are visible beyond the door but out of reach.
        for z in (103.0,120.0,140.5):
            for dx in (-1.34,1.34):
                upper.beam((side*9.82+dx,3.52,z-4.11),(side*9.82+dx,3.52,z+4.21),.074,.090,"84968b")


def freight(g,upper):
    amber="a98b53"
    for x,z,w,d,h in ((-10.25,104.06,5.62,1.18,1.18),(9.4,104.56,6.35,2.17,1.16),
                      (-10.29,124.15,5.24,1.18,1.16),(9.9,125.17,6.12,2.13,2.97),
                      (-9.16,143.40,6.81,3.18,4.25),(10.43,143.92,5.14,2.42,2.09)):
        g.measured(x,z,w,d,h)
    g.workbench(-10.24,104.24,5.42,"727d6e")
    g.cartons(-9.41,104.22,1.11,8,3)
    for i in range(9):
        x=6.63+i*.65
        g.box(x,.45,104.41,.56,.81,1.94,"637267",METAL)
        g.box(x,.89,104.42,.60,.082,1.98,"343d3c",METAL)
        for dz in (-.81,-.38,.04,.46,.82):
            g.box(x,.949,104.42+dz,.59,.051,.11,"898e82",METAL)
    g.cartons(10.3,104.40,.98,32,3)
    g.workbench(-10.22,124.34,5.14,"687d72")
    g.monitor(-9.98,124.44,1.20)
    for z in (124.71,125.60):
        for x in (7.98,10.16,12.13):
            g.rack(x,z,1.81,amber,int(x*10),5)
    for side in (-1,1):
        x=-9.15+side*3.11
        g.box(x,.70,143.40,.31,1.38,2.55,amber,METAL)
        upper.box(x,2.93,143.40,.32,3.23,2.56,amber,METAL)
    g.box(-9.14,.17,143.42,5.8,.28,2.99,"5c655b",METAL)
    g.box(-9.14,.91,144.82,5.8,1.82,.14,"6a7164",METAL)
    for i in range(13):
        upper.box(-9.15,1.33+i*.22,144.82,5.85,.147,.13,"717e72",METAL)
    upper.beam((-12.17,4.01,142.31),(-6.11,4.01,142.31),.17,.22,amber)
    upper.lens(-9.15,3.80,142.31,1.75,.24)
    for x in (8.66,10.45,12.23):
        g.rack(x,144.10,1.57,"7c876c",int(x*3),4)
    for x in (-2.64,2.64):
        for z in range(95,150,3):
            g.box(x,.029,z,.09,.027,1.33,"c4a165",MARK)
    for z in (99,119,138):
        upper.board("荷役通路",0,3.94,z,4.05,.52,.31,-1,"7e6d49")
    # The induction line has guarding, mail cubbies, exit shelves and powered rail.
    for dx in (-2.96,2.96):
        g.box(9.4+dx,1.07,104.48,.067,.47,2.04,amber,METAL)
        g.box(9.4+dx,.658,104.48,.091,.082,1.98,"a79b72",METAL)
    for i in (0,3,6):
        g.box(6.94+i*.74,.73,105.20,.068,1.44,.071,"687a6d",METAL)
    g.box(9.17,1.404,105.10,4.98,.071,.17,"6c786d",METAL)
    for i in range(7):
        x=6.94+i*.74
        g.box(x,1.68,105.08,.69,.49,.13,"596b61",METAL)
        g.box(x,1.63,105.003,.41,.103,.027,"b3b5a4",MARK)
    for x in (-11.9,11.9):
        for z in (103.4,123.4,143.4):
            upper.box(x,4.70,z,.88,.62,5.92,"747c70",METAL)
            for dz in (-2.95,0,2.95):
                upper.box(x,4.71,z+dz,.94,.68,.124,"5a6b62",METAL)
    for z in range(96,151,5):
        upper.beam((-3.35,4.71,z),(-1.32,5.38,z),.13,.19,"697066")
        upper.beam((3.35,4.71,z),(1.32,5.38,z),.13,.19,"697066")


def station(g,upper):
    brass,green="a48b58","68877c"
    for x,z,w,d,h in ((-9.13,104.48,5.75,1.42,1.22),(9.74,104.72,5.96,1.48,1.30),
                      (-9.42,124.78,6.2,2.20,1.12),(9.74,124.67,5.32,1.16,1.61),
                      (-9.76,142.62,6.18,1.56,2.07),(9.80,143.06,5.72,1.72,1.68)):
        g.measured(x,z,w,d,h)
    g.cabinet(-9.35,104.62,5.14,1.13,1.14,"879486")
    for x in (-10.8,-7.6):
        g.monitor(x,104.69,1.31)
        upper.pane(x,2.23,105.05,1.89,1.26,"819789",True)
    g.workbench(9.74,104.72,5.77,"6a8679")
    for i in range(8):
        x=7.80+i*.51
        g.box(x,1.16,104.52,.38,.053,.37,"525f55",METAL)
        g.box(x,1.185,104.50,.078,.031,.065,"bfcaa0" if i%2 else "d5c285",LIGHT)
    for x in (-11.9,-10.45,-9.,-7.55):
        g.box(x,.60,142.62,.55,1.22,1.32,"8a9e8b",METAL)
        g.box(x,1.258,142.62,.56,.09,1.34,"556861",METAL)
        g.box(x,1.31,142.25,.29,.022,.26,"bbd097",LIGHT)
    for z in (124.30,125.34):
        for x in (-11.58,-9.60,-7.65):
            g.stool(x,z,green,True)
            g.stool(x+.48,z,green,True)
    g.workbench(9.81,124.69,5.09,"7b8a72")
    for x in (7.93,9.70,11.47):
        g.monitor(x,124.90,1.25)
    g.workbench(9.80,143.06,5.56,"536e65")
    for x in (7.70,9.72,11.73):
        g.monitor(x,143.33,1.26)
    for x in (-2.75,2.75):
        for z in range(95,150):
            g.box(x,.028,z,.16,.025,.984,brass,MARK)
    for z in (98.7,118.5,138.2):
        upper.board("環状線",0,4.11,z,5.18,.66,.39,-1,green)
        upper.lens(0,3.71,z,2.89,.22)
    for i in range(11):
        z=94.5+5.5*i
        points=[(x,5.83-.126*x*x,z) for x in (-3.45,-2.7,-1.75,-.75,.75,1.75,2.7,3.45)]
        for a,b in zip(points,points[1:]):
            upper.beam(a,b,.16,.22,green)
        for x in (-2.75,2.75):
            upper.beam((x,4.84,z-.17),(x,4.84,z+5.5),.089,.092,green)
    # A route strip and clock above the turnstile side wall.
    upper.box(8.09,2.19,109.77,4.69,1.66,.16,"425c58",METAL)
    upper.box(8.09,2.20,109.665,4.42,1.40,.048,"b7b79c",MARK)
    for y,c in ((1.91,"a48257"),(2.18,"6e8b7d"),(2.50,"778c7a")):
        upper.box(8.08,y,109.634,3.71,.055,.012,c,MARK)
        for j in range(6):
            x=6.37+j*.67
            upper.box(x,y,109.622,.112,.113,.013,"e3d7ae",MARK)
            upper.box(x,y+.12,109.626,.32,.025,.013,"697973",MARK)
    upper.box(8.09,3.09,109.79,1.4,.11,.21,"5a7269",METAL)
    for i in range(14):
        x=6.1+i*.43
        g.box(x,.027,103.90,.36,.023,.057,brass,MARK)


def bus(g,upper):
    gray,amber="647c74","af8c52"
    for x,z,w,d,h in ((-9.40,104.32,5.45,1.13,1.30),(9.45,104.41,4.82,1.04,1.13),
                      (-9.84,124.24,4.99,1.47,1.10),(9.45,124.82,5.70,3.12,1.40),
                      (-9.26,143.46,6.56,2.64,3.23),(9.64,143.53,5.40,4.18,3.14)):
        g.measured(x,z,w,d,h)
    g.workbench(-9.38,104.49,5.30,gray)
    for x in (-11.01,-9.12,-7.63):
        g.monitor(x,104.59,1.22)
    g.cabinet(9.48,104.44,4.64,.88,1.04,"a7a990")
    g.cartons(10.18,104.58,1.09,3,3)
    g.cabinet(-9.86,124.47,4.84,.90,1.0,"7a8a77")
    for x in (-10.99,-10.05,-9.17,-8.28):
        g.stool(x,123.90,gray,True)
    for x in (7.30,11.61):
        g.box(x,.41,124.96,1.01,.83,2.68,amber,METAL)
        g.box(x,.91,124.96,1.08,.17,2.54,"879180",METAL)
        g.box(x,1.03,124.96,.96,.078,2.16,"4b5c53",METAL)
        g.box(x,1.13,125.71,.34,.21,.48,amber,METAL)
    for x in (-11.62,-7.12):
        g.box(x,.66,143.40,.47,1.28,2.01,amber,METAL)
        upper.box(x,2.50,143.40,.42,2.72,2.01,amber,METAL)
    g.box(-9.37,.42,143.46,4.01,.83,2.19,"718270",METAL)
    g.box(-9.37,.89,143.46,4.19,.15,2.23,"48574e",METAL)
    upper.beam((-11.59,3.88,143.3),(-7.14,3.88,143.3),.15,.25,gray)
    upper.lens(-9.35,3.74,143.26,2.38,.23)
    # Strip lights and rear tool boards frame the parked service shuttle.
    for x in (6.52,12.62):
        g.box(x,.031,143.5,.135,.022,4.90,amber,MARK)
        upper.lens(x,4.84,143.47,.20,3.87)
    upper.box(9.53,2.44,147.08,6.73,1.55,.18,"4f625a",METAL)
    for x in (7.06,8.65,10.28,11.88):
        upper.box(x,2.24,146.96,1.35,1.02,.11,"657d72",METAL)
        for i in range(4):
            upper.box(x-.42+i*.26,2.34,146.885,.061,.47,.07,"b1ac8d",METAL)
    for z in (103.9,120.,142.9):
        upper.box(0,4.96,z,.62,.38,8.08,"647c71",METAL)
        upper.box(0,4.72,z,.23,.11,7.74,amber,METAL)
    for x in (-2.53,2.53):
        for z in range(95,150,4):
            g.box(x,.026,z,.136,.025,1.66,amber,MARK)
            g.box(x*.88,.025,z,.049,.017,1.66,amber,MARK)
    for x,z in ((-1.36,98.3),(1.34,119.2),(-1.33,138.8)):
        upper.board("車両通路",x,3.99,z,4.02,.56,.31,-1,"677e73")


def gate_and_payloads():
    gate=Wing(0)
    gate.box(0,1.28,0,.17,2.56,2.84,"788880",METAL)
    for side in (-1,1):
        gate.box(side*.091,1.57,0,.019,.21,2.58,"aaa690",MARK)
        gate.box(side*.094,1.80,0,.019,.19,2.57,"6f8f85",MARK)
        for z in (-1.28,1.28):
            gate.box(side*.095,1.28,z,.024,2.45,.082,"435850",METAL)
        for z in (-.97,.97):
            gate.box(side*.112,1.10,z,.040,.24,.13,"4d5e55",METAL)
    gate.write("roomWingGate")
    lamp=Wing(0)
    lamp.box(0,0,0,.16,.25,.19,"435550",METAL)
    for side in (-1,1):
        lamp.box(side*.083,0,0,.014,.142,.122,"b0b5a1",10)
    lamp.write("roomWingGateLamp")

    clinic=Wing(0)
    clinic.box(0,.20,0,.54,.12,.50,"617f73",METAL)
    for x in (-.16,.16):
        clinic.pole(x,.04,.25,.94,.13,"a0b4a2",count=10)
        clinic.pole(x,.04,1.11,.13,.037,"647f74",count=8)
        clinic.box(x,.84,-.09,.16,.21,.038,"dedacf",MARK)
        clinic.box(x,.116,.15,.062,.17,.17,"42514b",METAL)
    clinic.box(0,.68,.19,.45,.075,.048,"678271",METAL)
    clinic.box(0,1.13,.22,.398,.045,.048,"658274",METAL)
    for x in (-.19,.19):clinic.box(x,.75,.22,.037,.74,.051,"688579",METAL)
    clinic.write("roomWingOxygen")

    freight=Wing(1)
    freight.box(0,.13,0,.64,.059,.61,"947343",METAL)
    for x in (-.31,.31):
        freight.box(x,.142,.23,.087,.28,.27,"343f3a",METAL)
        freight.beam((x,.15,.23),(x*.80,1.22,.38),.036,.034,"af925e")
    freight.box(0,1.20,.38,.53,.048,.047,"625c46",METAL)
    freight.cartons(0,-.061,.175,991,1)
    freight.cartons(0,-.035,.43,623,1)
    freight.write("roomWingHandTruck")

    tow=Wing(3)
    tow.box(0,.26,.01,.96,.41,1.33,"71887b",METAL)
    tow.box(0,.51,.18,.83,.14,.79,"8f926d",METAL)
    tow.box(0,.61,.35,.49,.16,.26,"414e44",CLOTH)
    tow.box(0,.64,-.32,.46,.26,.18,"89927d",METAL)
    tow.beam((0,.53,-.31),(0,.99,-.14),.091,.085,"556960")
    tow.box(0,1.01,-.16,.35,.061,.07,"3f5549",METAL)
    for x in (-.43,.43):
        for z in (-.45,.43):
            tow.box(x,.168,z,.138,.30,.31,"404941",METAL)
        tow.box(x*.62,.40,-.672,.143,.082,.029,"dfd7a1",LIGHT)
    tow.write("roomWingTow")


if __name__=="__main__":
    gate_and_payloads()
    solids=[]
    for region,style in enumerate((clinic,freight,station,bus)):
        lower,upper=shell(region)
        style(lower,upper)
        lower.write(f"roomWing{region}")
        upper.write(f"roomWing{region}Roof")
        solids.extend(lower.footprints)
    anchors=[dict(x=x,z=z) for x,z in STATIONS]
    layout={"stations":anchors,"solids":solids}
    (OUT/"RoomWingLayout.json").write_text(json.dumps(layout,indent=2)+"\n",encoding="ascii")
    print("Northern buildings:",len(anchors),"shared stations and",len(solids),"measured solids")
