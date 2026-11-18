"""Nagi's bob. Cross sections, fringe corners and ear window use the 1250 px turnaround."""
from math import cos, pi, sin
from mathutils import Vector

from forms import CAST, side_edges, station_width

# Each sector has a shared root edge and two independently placed cut corners.
# Measurements are angles about the skull and rows in the front/profile artwork.
# The short sector over the ear makes room for the pinna between the two long locks.
SECTIONS = (
    (0.00, .18,  .00, .14, 126, 124),
    (.18, .35,   .16, .26, 126, 119),
    (.35, .75,   .38, .69, 98, 151),
    (.75, 1.17,  .62, 1.03, 166, 197),
    (1.17, 1.76, 1.17, 1.70, 184, 137),
    (1.76, 2.01, 1.69, 2.12, 187, 196),
    (2.01, 2.38, 1.97, 2.42, 194, 198),
    (2.38, 2.72, 2.32, 2.77, 190, 197),
    (2.72, pi,   2.68, pi, 193, 195),
)


def smooth(t):
    t = max(0., min(1., t))
    return t*t*(3-2*t)


def shell(angle, row):
    c = CAST[0]
    front, rear = side_edges(row)
    # The profile silhouette at eye height is the face. Follow the brow's
    # uninterrupted arc behind that silhouette to the two cropped temples.
    if row > 119:
        front = 526 + 11*smooth((row-123)/73)
    radius = station_width(c, row)
    if row > 185:
        # The back and side locks curl under at the collar. Individual free
        # ends remain round where the original station is the chin opening.
        radius = 102 - 18*smooth((row-185)/15)
    co = cos(angle)
    depth = .5*(rear-front)
    return Vector((radius*sin(angle), .5*(front+rear)-603-depth*co, 398-row))


def projected_uv(angle, row):
    return .002+.996*(angle+pi)/(2*pi), 1-(1+317*(row-18)/185)/1024


def lock_sector(g, sign, index, spec):
    a, b, end_a, end_b, low_a, low_b = spec
    rows = []
    maps = []
    columns = 10
    intervals = 28
    for j in range(intervals+1):
        t = (j/intervals)**1.36
        cross_section = []
        coordinates = []
        for k in range(columns+1):
            u = k/columns
            # Both sides of the centre lock belong to one broad, blunt fringe.
            ridge = cos(.5*pi*u)**.85 if index == 0 else sin(pi*u)**.86
            corner = low_a+(low_b-low_a)*u
            if index >= 3 and index != 4:
                corner += (8.2 if index > 4 else 3.5)*sin(pi*u)
                if index > 4:
                    corner -= 7.1
            # Rows start together all round the crown. At the free edge the
            # locks turn and separate progressively, leaving triangular parts.
            row = 21 + (corner-21)*t + 5.2*sin(pi*t)*cos(a)
            flow = smooth((t-.27)/.73)
            start = a+(b-a)*u
            ending = end_a+(end_b-end_a)*u
            angle = start+(ending-start)*flow
            if index <= 3:
                angle += .075*sin(pi*t)*sin(angle*2)
            else:
                angle += .07*sin(pi*t)*sin(angle)
            if index == 4:
                # Concave lower edge of the short layer over the visible ear.
                row -= 27*sin(pi*u)**.85*flow
            angle *= sign
            p = shell(angle, row)
            if j == 0:
                p.x, p.y = 0, 16
            # The ear-side lock follows the jaw in front projection, while in
            # profile it sweeps back to leave the nose, eye and cheek exposed.
            side = abs(angle)
            p.y += 31*smooth((row-107)/51)*smooth((side-.27)/.32)*smooth((1.65-side)/.52)
            radial = Vector((sin(angle),-cos(angle),.25*(1-t))).normalized()
            volume = 3.2*ridge*sin(pi*.86*t)**.58
            if index >= 3:
                # A curl retreats under the rim instead of ending as a blade.
                volume -= 8*smooth((t-.87)/.13)
            if index >= 5:
                volume -= 3.3*smooth((t-.75)/.25)*abs(2*u-1)**1.4
            p += radial*volume
            p.z += 2.6*ridge*sin(pi*min(1.,t/.46))**2
            cross_section.append(p)
            coordinates.append(projected_uv(angle,row))
        rows.append(cross_section)
        maps.append(coordinates)
    # Fold the rim towards the scalp; it stays visible from below and in stride.
    # The fringe projects well ahead of the eye in the side drawing. Its
    # underside must meet the forehead, particularly at the centre part.
    return_depth = 29.0 if index < 3 else 15.0
    for depth, down in ((2.5,.8),(.5*return_depth,-1.4),(return_depth,-5.5)):
        lip = []
        for k,p in enumerate(rows[intervals]):
            u = k/columns
            theta = sign*(end_a+(end_b-end_a)*u)
            radial_depth=depth*(1-.72*smooth((abs(theta)-.28)/.32)) if index<3 else depth
            lip.append(p-Vector((sin(theta)*radial_depth,-cos(theta)*radial_depth,-down)))
        rows.append(lip)
        maps.append(maps[intervals][:])
    base = len(g.verts)
    g.grid(rows,'Head','hair',wrapped=False,reverse=(sign>0),
           tex=lambda r,k: maps[r][k],cap=False)
    if index >= 2:
        side = 'Lock.L' if sign > 0 else 'Lock.R'
        for j in range(len(rows)):
            t = min(1.,j/intervals)
            for k in range(columns+1):
                angle = a+(b-a)*k/columns
                weight = .42*smooth((t-.61)/.39)*smooth((angle-.45)/.55)*smooth((2.55-angle)/.70)
                if weight:
                    g.blends.append((base+j*(columns+1)+k,side,weight))
    if index <= 4:
        for k in (0,columns):
            if index==0 and k==0:
                continue
            theta = sign*(end_a if k==0 else end_b)
            rail = Vector((sin(theta),-cos(theta),0))
            sidewall = []
            for j in range(intervals+1):
                t = (j/intervals)**1.36
                thickness = 1+(24 if index < 3 else 8)*smooth((t-.38)/.62)
                p=rows[j][k]
                sidewall.append((p,p-rail*thickness+Vector((0,0,2.2*t))))
            start=len(g.verts)
            g.grid(sidewall,'Head',0,wrapped=False,cap=False,reverse=((k==0)==(sign>0)))
            if index>=2:
                for j in range(intervals+1):
                    t=j/intervals
                    angle=a if k==0 else b
                    w=.42*smooth((t-.61)/.39)*smooth((angle-.45)/.55)*smooth((2.55-angle)/.70)
                    if w:
                        for v in (start+2*j,start+2*j+1):
                            g.blends.append((v,'Lock.L' if sign>0 else 'Lock.R',w))



def backing(g):
    # A continuous inner cap supports all loose tips. The opening is cut
    # around the ears, and between the central fringe and its diagonal wings.
    edge = ((0,116),(.23,114),(.36,86),(.53,105),(.70,130),(.89,160),
            (1.08,185),(1.20,170),(1.44,133),(1.69,130),(1.86,154),
            (2.04,183),(2.38,188),(pi,188))
    rows=[]
    maps=[]
    for j in range(18):
        t=j/17
        ring=[]
        strokes=[]
        for k in range(97):
            a=-pi+2*pi*k/96
            for (a0,r0),(a1,r1) in zip(edge,edge[1:]):
                if abs(a)<=a1:
                    rim=r0+(r1-r0)*smooth((abs(a)-a0)/(a1-a0))
                    break
            row=21+(rim-21)*t
            p=shell(a,row)
            p-=Vector((sin(a),-cos(a),.36*(1-t)))*(3+8*t)
            ring.append(p)
            strokes.append(projected_uv(a,row))
        rows.append(ring)
        maps.append(strokes)
    g.grid(rows,'Head','hair',wrapped=False,reverse=True,
           tex=lambda j,k:maps[j][k],cap=False)


def build_bob(g):
    backing(g)
    # Inner nape wraps behind the jaw and beneath the pinna. In an open
    # two-sided preview the far side of the bob can mask this missing volume.
    g.oval((0,37,264),(80,72,59),'Head',0,48,20)
    for sign in (-1,1):
        for i,spec in enumerate(SECTIONS):
            lock_sector(g,sign,i,spec)
