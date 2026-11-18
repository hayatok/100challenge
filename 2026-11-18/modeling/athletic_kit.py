"""Tailored athletic clothing and contact surfaces for the shared race skeleton."""
from math import cos, sin, pi
from mathutils import Vector

TAU=2*pi


def joint_weights(g, first, columns, weights, following):
    for row,weight in enumerate(weights):
        if weight:
            for vertex in range(first+row*columns,first+(row+1)*columns):
                g.blends.append((vertex,following,weight))


def sleeve(g, i, side, sign):
    upper='UpperArm.'+side
    forearm='Forearm.'+side
    # Panel radius is measured perpendicular to the upper arm. The sleeve
    # crowns over the shoulder, relaxes into the elbow and gathers at the wrist.
    stations=[(27,2,189,7,8),(32,1,186,13,14),(38,0,181,17.3,17),
              (44,-.5,174,16.7,16),(50,.6,166,15.0,14.2),(55,1,159,14.2,14.4),
              (60,0,153,14.1,14),(64,-1,148,14.8,14.7),(68,-2,144,14.0,13.7),
              (72,-3,139,13,13.3),(74,-4.3,135,12.7,12.9),(76,-5,131,10.9,11.4)]
    stop=7 if i==3 else len(stations)
    cols=24
    def surface(j,angle,extra=0):
        x,y,z,rad,depth=stations[j]
        # Soft bias folds near the elbow and wrist. They pinch the underside
        # and cross the sleeve on a slant, leaving the upper shoulder smooth.
        pinch=(1.1*cos(2*angle+.53*j)+.7*cos(3*angle-.6*j))*(.26 if j<3 else 1)
        r=rad+pinch+extra
        return Vector((sign*(x+.77*r*sin(angle)),y-(depth+extra)*cos(angle),z+.64*r*sin(angle)))
    def band(j0,j1,bone,color,raise_by):
        rows=[[surface(j,k*TAU/cols,raise_by) for k in range(cols)] for j in (j0,j1)]
        g.grid(rows,bone,color,reverse=sign==1,cap=False)
    rows=[[surface(j,k*TAU/cols) for k in range(cols)] for j in range(stop)]
    first=len(g.verts)
    g.grid(rows,upper,'sleeve',reverse=sign==1)
    joint_weights(g,first,cols,[0,0,0,0,.03,.21,.50,.77,.91,.99,1,1][:stop],forearm)
    if i==3:
        band(5,6,forearm,9,.75)
        rows=[[surface(j,k*TAU/cols,-2.3) for k in range(cols)] for j in range(6,len(stations))]
        g.grid(rows,forearm,'skin',reverse=sign==1)
    else:
        band(9,10,forearm,9,1.25)
        band(10,11,forearm,'sock',1.15)
    # Front/lateral shoulder patch wraps the compound curve, like a real
    # sewn-in competition crest, also visible on the profile shoulder.
    def diamond(a,b,tone):
        pts=[surface(row,col,1.2+b) for row,col in a]
        g.polygon(pts if sign>0 else list(reversed(pts)),upper,tone)
    diamond([(2,.67),(2,1.59),(4,1.61),(4,.68)],0,9)
    diamond([(2,.73),(2,1.53),(3,1.09)],.4,10 if i in (0,1,5) else 'jacket')
    diamond([(4,.75),(3,1.09),(4,1.52)],.4,'shoe')
    if i in (1,2,5):
        for angle in ([1.8,2.03] if i==2 else [1.8]):
            pp=[surface(j,angle,1.1) for j in (2,3,4,5)]
            g.tube(pp,[1.3,1.6,1.55,.9],upper,9,n=7,steps=2)


def hand(g,side,sign):
    bone='Hand.'+side
    def p(x,y,z):return (sign*x,y,z)
    g.loft([(107,4.8,4.7,sign*85,-8.7),(111,9.7,7.4,sign*84,-7.6),
            (117,10.7,8.8,sign*82,-6.4),(123,9.5,8,sign*79,-5.4),
            (129,7.9,6.6,sign*77,-5),(133,6.7,5.6,sign*75,-4)],bone,'skin',20)
    for finger,(dx,dy,length) in enumerate(((-6.1,-3,8.4),(-2.3,-2,9.2),(2.2,.1,8.2),(6,1.5,6.4))):
        x=84+dx
        g.tube([p(x,-7+dy,116.5),p(x+1.7,-8+dy,113),p(x+2.9,-9.4+dy,110),
                p(x+2.4,-10.5+dy,116.5-length-2)],[3.8,3.7,3.3,1.55],bone,'skin',n=9,steps=2)
    g.tube([p(76,-9,123),p(72,-11.2,120.5),p(69.9,-13,117),p(69.4,-14,113.8)],
           [4.7,4.4,3.6,1.6],bone,'skin',n=10,steps=3)


def legs(g,i,side,sign):
    thigh='Thigh.'+side;shin='Shin.'+side
    cols=24
    long=i in (2,5)
    # The hip shell extends inside the waistband. One skin/pants surface
    # passes through the patella and into the sock so there are no open cuts
    # when the rear leg folds tightly during a jump or a sprint.
    stations=[(23,1,126,18.4,19),(23,-.3,119,21,21),(24,-.1,111,20.8,20),
              (25,-.5,100,19.1,17.9),(27,-.5,88,17,16.4),(27.8,-.3,82,16.6,16),
              (28,-1,77,16.3,16.2),(28.6,-.4,71,16.5,16.8),
              (30,1.1,61,16,16),(31.1,1.4,51,14,14),(32,.2,40,12.7,12.9),(32,0,34,12,12)]
    if not long:
        stations=[(x,y,z,.80*w if z>104 else w,.8*d if z>104 else d) for x,y,z,w,d in stations]
    if long:
        stations=[(x,y,z,w+(3.3 if i==5 else 2.1),d+(3.1 if i==5 else 2.0)) for x,y,z,w,d in stations]
    def at(j,a,rise=0):
        x,y,z,w,d=stations[j]
        wrinkle=(.7*sin(3*a+.6*j)+.7*sin(2*a-.89*j)) if long else 0
        return (sign*(x+(w+wrinkle+rise)*sin(a)),y-(d+wrinkle+rise)*cos(a),z+.7*cos(a+j*.36))
    rows=[[at(j,k*TAU/cols) for k in range(cols)] for j in range(len(stations))]
    first=len(g.verts);g.grid(rows,thigh,'pants' if long else 'skin',reverse=sign==1)
    joint_weights(g,first,cols,[0,0,0,0,.07,.22,.50,.77,.97,1,1,1],shin)
    if long:
        for a in ((1.25,1.49) if i==2 else (1.39,)):
            rows=[[at(j,a+u,.69) for u in (-.041,.041)] for j in range(len(stations))]
            first=len(g.verts);g.grid(rows,thigh,9,False,sign==1,cap=False)
            joint_weights(g,first,2,[0,0,0,0,.07,.22,.50,.77,.97,1,1,1],shin)
    else:
        # The shorts flare at the turned-up white binding. The outer side is
        # lifted and scooped at its seam; inner leg openings dip lower.
        cuts=[(122,20,21),(119,21,21.5),(112,21.6,21.1),(105,21.9,20.5),(99,22.2,20.4)]
        def opening(j,a,rise):
            z,w,d=cuts[j]
            return (sign*(24+(w+rise)*sin(a)),-(d+rise)*cos(a),
                    z+2.4*max(0,sin(a))**2-.9*cos(a+.6))
        rows=[[opening(j,k*TAU/cols,0) for k in range(cols)] for j in range(len(cuts))]
        g.grid(rows,thigh,'pants',reverse=sign==1)
        tape=[[opening(j,k*TAU/cols,.8) for k in range(cols)] for j in (3,4)]
        g.grid(tape,thigh,9,reverse=sign==1,cap=False)
        stripe=[[opening(j,a,.85) for a in (1.23,1.41)] for j in range(len(cuts))]
        g.grid(stripe,thigh,9,False,sign==1,cap=False)
        for j0,j1,color,offset0,offset1 in ((7,11,9,1.1,1.35),(7,8,'sock',1.25,1.35)):
            rows=[[at(j,k*TAU/cols,offset0 if j==j0 else offset1) for k in range(cols)] for j in range(j0,j1+1)]
            g.grid(rows,shin,color,reverse=sign==1)


def sneaker(g,side,sign):
    foot='Foot.'+side
    cx=sign*33
    n=36
    # Each horizontal section has its own last. The asymmetric toe points
    # a little outward, and the heel stays upright rather than tapering.
    levels=[(1.4,26.8,36,-8),(1.9,29.5,39.4,-8.8),(4.2,31,41.1,-8.3),
            (7.7,31.8,42.5,-8),(12.5,31.8,41.7,-7),(15,30.9,41,-6.9),
            (18,30.9,39.4,-6.6),(22.5,29.1,37.7,-5.6),(28,27,34.2,-4),
            (33,24.5,29.6,-1.8),(37,21.7,23,2.3),(41,18.5,18.1,4.4)]
    def at(j,a,lift=0):
        z,rx,ry,offset=levels[j]
        toe=max(0,cos(a))
        heel=max(0,-cos(a))
        sn=sin(a)
        # Generous ball at the front and a narrower sculpted heel cup.
        x=cx+sign*((rx+lift)*sn*(1-.14*heel+.065*toe)+2.9*toe)
        y=offset-(ry+lift)*cos(a)-6.5*toe*max(0,(43-z)/43)
        arch=4.7*max(0,1-abs(y-7.5)/17)*max(0,(15-z)/15)
        return Vector((x,y,z+2.55*toe**3+arch+max(0,(z-14)/26)*1.3*heel))
    for start,end,col in ((0,2,14),(2,5,9),(5,11,'shoe')):
        rows=[[at(j,k*TAU/n) for k in range(n)] for j in range(start,end+1)]
        g.grid(rows,foot,col,reverse=sign<0)
    # The toe guard is the broad dark nose of the illustrated outsole. Keep
    # its return below the padded straps and shade its upper edge in rubber.
    rows=[]
    for row in range(4):
        points=[]
        for k in range(13):
            u=-1+k/6
            a=.48*u
            zrise=row/3*(7.4-4.3*abs(u)**1.7)
            pt=at(1,a,1.0)
            pt.z+=zrise
            pt.y-=.55
            points.append(pt)
        rows.append(points)
    g.grid(rows,foot,14,False,sign<0,cap=False)
    # Reinforcing quarters run up the side of the vamp and turn the heel.
    for side_angle in (-1,1):
        def quarter(j,ang,extra):
            return at(j,ang*side_angle,extra)
        rows=[]
        for step in range(4):
            t=step/3
            points=[]
            for k in range(13):
                u=k/12
                # A bone-white leather chevron across each red quarter.
                a=.82+1.67*u
                j=6.0+2.0*sin(pi*u*.9)+.55*t
                lo=int(j)
                points.append(quarter(lo,a,.95).lerp(quarter(lo+1,a,.95),j-lo))
            rows.append(points)
        g.grid(rows,foot,9,False,sign*side_angle<0,cap=False)
    # High tongue, folded ankle padding and two substantial instep straps.
    g.oval((cx,-12.8,35),(13.9,15.4,10.7),foot,'shoe',18,9)
    for level,span in ((7.52,.81),(9.12,.77)):
        points=[]
        for k in range(11):
            u=-1+k/5
            a=span*u
            j=level-.44*u*u
            lo=int(j)
            pt=at(lo,a,1.55).lerp(at(lo+1,a,1.55),j-lo)
            pt.z+=1.55*(1-u*u)
            pt.y-=.55*(1-u*u)
            points.append(pt)
        radii=[2.4+1.45*(1-(k/5-1)**2) for k in range(11)]
        g.tube(points,radii,foot,9,flat=.68,n=10,steps=1,plane=(0,-.7,.72))
    # Narrow piping immediately above the white foxing outlines the toe
    # panels all the way back to the red heel.
    pts=[at(5,-pi+k*TAU/36,.75) for k in range(37)]
    g.tube(pts,[1.05]*len(pts),foot,'shoe',n=6,steps=1,plane=(0,0,1))
    # The folded heel collar is visible from the chase camera, as is the
    # vertical strip that anchors the sides of the padded shoe opening.
    rim=[[at(j,k*TAU/n,1.1) for k in range(n)] for j in (10,11)]
    g.grid(rim,foot,'shoe',reverse=sign<0,cap=False)
    heel=[[at(j,pi+.18*u,1.1) for u in (-1,-.5,0,.5,1)] for j in (6,7,8,9,10)]
    g.grid(heel,foot,9,False,sign<0,cap=False)
    for y,width in ((-33,18),(-19,22),(-5,22),(12,17),(22,13)):
        g.oval((cx,y,.95),(width,4.6,.95),foot,16,12,4)
