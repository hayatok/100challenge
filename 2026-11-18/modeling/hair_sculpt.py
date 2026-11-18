"""Ribbon-shaped hair built over the calibrated crown in design-sheet pixels."""
from math import asin, cos, pi, sin, sqrt
from mathutils import Vector
from forms import CAST, hair_profile, station_width


def tile(u, v):
    return ((871 + 147 * u) / 1024, 1 - (581 + 227 * v) / 1024)


def panel(i, x, sy, rear=False):
    c=CAST[i]
    top,bottom=c['stations'][0][0],c['stations'][-1][0]
    if rear:
        # Back painting comes from Nagi's rear silhouette; preserve its
        # centre part when projecting it on to each inferred haircut.
        x=-x*112/max(r for _,r in c['stations'])
    u=max(.003,min(.996,(x+122)/244))
    t=max(.004,min(.996,(sy-top+2)/(bottom-top+5)))
    return ((.5 if rear else 0)+.5*u,1-(1+317*t)/1024)


def cubic(path, t):
    a, b, c, d = path
    return (1-t)**3*a + 3*(1-t)**2*t*b + 3*(1-t)*t*t*c + t**3*d


# The two outlines of each forelock are cubic curves in frontal design-sheet
# space. X is relative to the face centre; Y is the row in the original art.
# Left/right contours meet at a common root and at a tip or blunt cut.
FRINGE = [
    [((-2,39),(-37,30),(-66,85),(-60,151), (-27,46),(-49,85),(-54,121)),
     ((-5,38),(-22,43),(-28,90),(-24,110), (-11,52),(-13,96),(-15,120)),
     ((-2,39),(-17,40),(-15,98),(-10,124), (11,36),(12,99),(7,124)),
     ((5,39),(7,54),(12,100),(10,119), (24,44),(24,87),(23,108)),
     ((6,39),(24,47),(43,85),(58,117), (54,45),(70,105),(70,151))],
    [((-3,83),(-28,72),(-66,122),(-69,179),(-24,107),(-46,165),(-38,185)),
     ((-4,83),(-16,93),(-32,133),(-19,145),(-8,147),(0,147),(23,149)),
     ((1,83),(8,89),(12,119),(21,135),(31,130),(25,104),(17,94)),
     ((6,83),(27,86),(34,113),(50,129),(62,148),(69,161),(68,172))],
    [((36,84),(1,64),(-55,105),(-68,131),(-26,151),(0,103),(35,88)),
     ((33,85),(4,101),(-8,145),(-27,163),(18,142),(33,112),(36,88)),
     ((35,88),(24,112),(15,145),(-5,171),(33,153),(43,119),(38,88)),
     ((41,88),(55,96),(68,137),(57,183),(76,101),(87,146),(60,180))],
    [((-10,78),(-47,73),(-66,116),(-88,145),(-62,173),(-48,146),(-32,136)),
     ((-2,82),(-33,96),(-35,143),(-62,156),(-23,167),(-9,143),(1,122)),
     ((9,93),(16,113),(20,133),(5,161),(39,147),(49,120),(37,100)),
     ((28,87),(52,112),(56,143),(83,153),(102,153),(87,137),(74,119))],
    [((0,80),(-33,65),(-65,110),(-68,164),(-33,153),(-17,104),(-2,82)),
     ((4,80),(-22,83),(-23,136),(-35,153),(-6,147),(3,122),(6,92)),
     ((4,80),(-4,96),(-4,135),(-12,157),(8,153),(16,118),(8,86)),
     ((7,80),(26,91),(39,116),(59,144),(62,113),(47,83),(14,79))],
    [((-21,73),(-47,64),(-79,123),(-71,167),(-72,184),(-57,191),(-47,188)),
     ((-20,73),(-34,91),(-12,144),(11,164),(1,142),(-6,105),(-15,77)),
     ((-17,72),(0,91),(29,135),(52,139),(57,99),(6,63),(-14,68)),
     ((-13,69),(19,78),(65,114),(65,160),(83,149),(67,84),(17,62))],
]


def plate(g, rows, bone, coordinates=None, length=1):
    # Strip order is along the lock, then left edge to right edge. Duplicate the
    # rolled leading edge on its underside so that separated tips catch light.
    sections = []
    span = len(rows[0])
    for row in rows:
        top = [p for p, out in row]
        bottom = [p - out for p, out in row[1:-1]][::-1]
        sections.append(top + bottom)
    edges = len(sections[0])
    def lookup(a,b):
        b %= edges
        if coordinates:
            return coordinates[a][b if b<span else edges-b]
        u = b/(span-1) if b < span else 1-(b-span+1)/(span-1)
        if b >= span:
            u = .04+.18*u
        return tile(u, min(.99, .04+length*.9*a/(len(rows)-1)))
    g.grid(sections, bone, 'hair', reverse=True, tex=lookup)


def frontal_point(c, x, sy):
    v = max(.006,min(1,(sy-c['stations'][0][0])/(c['stations'][-1][0]-c['stations'][0][0])))
    radius = station_width(c,sy) * (.96 if c is CAST[0] else 1)
    angle = asin(max(-.988,min(.988,x/max(1,radius))))
    xx,y,z = hair_profile(c,angle,v)
    # The scalp's calibrated profile nose and cheek do not belong to a forelock.
    # Continue the curve of the fringe near the eye instead of plunging into it.
    if c is CAST[0]:
        from forms import side_edges
        a,b=side_edges(sy)
        mx=(a+b)/2-603
        y=mx-(b-a)/2*cos(angle)
    return Vector((x*c['k'],y,(c['floor']-sy)*c['k'])), Vector((sin(angle)*.64,-cos(angle),.14)).normalized()


def bangs(g, i):
    c=CAST[i]
    for index, strand in enumerate(FRINGE[i]):
        root,l1,l2,tip1,r1,r2,tip2 = (Vector(p) for p in strand)
        rows=[];maps=[]
        for j in range(17):
            t=j/16
            left=cubic((root,l1,l2,tip1),t)
            right=cubic((root,r1,r2,tip2),t)
            # Converge the two edges after rounding the terminal corners. Broad
            # blunt ends on the middle Nagi bangs follow the source illustration.
            row=[]; coords=[]
            for k in range(9):
                u=k/8
                point=left.lerp(right,u)
                if i==0:
                    # Roll the cut into an offset point. The centre lock dips
                    # furthest; adjacent ends turn diagonally toward the part.
                    end=max(0,(t-.76)/.24)**2
                    point=point.lerp(left.lerp(right,.46 if index==2 else .69),end*.96)
                    point.y+=end*(4.2 if index==2 else 1.0)
                p,n=frontal_point(c,*point)
                coords.append(panel(i,*point))
                crown=sin(pi*u)**.8 * sin(pi*(.015+.97*t))**.51
                # Drawn left/right contours sometimes run around the end. Ridge
                # stays a few millimetres proud of each overlapping neighbour.
                relief=(4.5+1.25*index)*sin(pi*t)**.6+(.85+9*crown)
                p+=n*relief
                if i==0:p.y+=10.5*t**2.5
                row.append((p, n*(1+7.5*crown)))
            rows.append(row);maps.append(coords)
        plate(g,rows,'Head',None if i==3 or (i==2 and index==3) else maps,.83+.04*(index%3))
    if i==0:
        # Two short, curved flyaways break the rim of the triangular parts.
        # Both stop above the brow line even from the elevated race camera.
        for sign in (-1,1):
            for main in (True,False):
                path=(Vector((3,38)),Vector((22,43)),Vector((32,79)),Vector((36,102))) if main else (
                      Vector((23,54)),Vector((38,61)),Vector((51,83)),Vector((47,106)))
                rows=[]
                for j in range(17):
                    t=j/16
                    point=cubic(path,t)
                    width=(7.4 if main else 3.2)*max(.012,sin(pi*t)**.72)
                    row=[]
                    for k in range(7):
                        u=k/6
                        p,normal=frontal_point(c,sign*(point.x+(2*u-1)*width),point.y)
                        crest=sin(pi*u)*sin(pi*t)**.62
                        p+=normal*(2.0+4.5*crest)
                        p.y+=7.0*t*t
                        row.append((p,normal*(.65+4*crest)))
                    rows.append(row)
                plate(g,rows,'Head',length=.79)



def cap_and_locks(g, i):
    c=CAST[i]
    n=72
    def cap_end(a):
        side=min(1,abs(a)/1.47)
        if i==0:
            # Behind each angled brow, the scalp terminates above the
            # illustrated triangular part, including from the raised race camera.
            side=max(0,min(1,(abs(a)-.67)/.86))
            # The hairline rises inside the two brow windows. Its
            # curved boundary stays under the shorter overlapping flyaways.
            front=.353-.080*max(0,1-((abs(a)-.42)/.26)**2)
            return front+(.994-front+.014*cos(7*a+.6))*side*side*(3-2*side)
        low=.487
        return .42+(low+.013*cos(7*a+.6))*side*side*(3-2*side)
    rows=[]
    for j in range(24):
        t=j/23;row=[]
        for k in range(n):
            a=-pi+2*pi*k/n
            p=Vector(hair_profile(c,a,t*cap_end(a)))
            nrm=Vector((sin(a),-cos(a),.58*(1-t)))
            p-=nrm*(1.3+4.5*t)
            if i==0:p.z-=8.5*t**5*min(1,abs(a)/1.38)
            p.z+=2.6*(1-t)**2
            if j==0:
                p.x*=.11
                p.y=15+(p.y-15)*.11
                p.z+=.8
            row.append(p)
        rows.append(row)
    def scalp_quad(a,b):
        # Assign the front or back panel to the whole quad. Interpolating one
        # atlas island into the next would paint a streak along the temple.
        angle=abs(-pi+2*pi*(b+.5)/n)
        rear=angle>2.20
        corners=[]
        for row,col in ((a,b),(a,b+1),(a+1,b+1),(a+1,b)):
            x,_,z=rows[row][col%n]
            if rear or (angle<.73 and i!=3):
                corners.append(panel(i,x/c['k'],c['floor']-z/c['k'],rear))
            else:
                local=(-pi+2*pi*(col%n)/n)
                corners.append(tile(.26+.23*cos(6*local),.07+.84*row/23))
        return corners
    # The front and rear edges end at different heights. Capping that
    # nonplanar opening spans the forehead with a dark polygon across
    # both parts. Roll the edge back into the hair at each angle instead.
    g.grid(rows,'Head','hair',reverse=True,face_tex=scalp_quad,cap=False)
    g.polygon(list(reversed(rows[0])),'Head','hair')
    inner=[]
    for k,p in enumerate(rows[-1]):
        a=-pi+2*pi*k/n
        inner.append(p-Vector((sin(a)*2.2,-cos(a)*2.2,-2.5)))
    g.grid([rows[-1],inner],'Head','hair',reverse=True,cap=False)
    # Broad layered panels grow around the crown and free themselves at the cut
    # edge; front temple pieces frame the face and longer back locks overlap.
    count,twist,tip,flare = [(14,.26,1,5),(10,.44,.95,6),(10,-.48,.92,3),
                             (12,.47,.96,7),(12,.32,.965,4),(11,-.41,.96,4)][i]
    minimum=[1.00,1.04,1.03,1.02,1.02,1.01][i]
    arc=2*pi-minimum*2
    step=arc/(count-1)
    for j in range(count):
        anchor=minimum+j*step
        side=1 if sin(anchor)>0 else -1
        temple=min(j,count-j-1)==0
        back=(1-cos(anchor))*.5
        end=tip-.022+.029*sin(2.7*j+i)+(.015 if temple else 0)
        if i in (1,2,4,5):end-=.05 if temple else .095*back
        start=.008+.023*((j*3)%5)
        rows=[]; maps=[]
        for a in range(18):
            t=a/17
            centre=anchor+twist*sin(pi*t)*(.5+back*.55)+side*(.13*sin(pi*t)-(.11 if temple else .08)*t*t)
            width=step*(.74+.11*cos(j*1.8)) * (.56+.44*sin(pi*t)**.45)
            # Pull one edge into the next tip so the lower boundary forms large,
            # varied scallops instead of an evenly corrugated cap.
            if t>.70:width*=max(.014,1-((t-.70)/.30)**1.8)
            row=[];coords=[]
            for k in range(9):
                u=k/8; cross=2*u-1
                v=start+(end-start)*t-.026*abs(cross)**2*sin(pi*t)
                angle=centre+cross*width
                # Preserve width at the cut instead of squeezing all tips
                # into the narrow bottom ring of the head envelope.
                sample_v=v if v<.88 else .88+.56*(v-.88)
                p=Vector(hair_profile(c,angle,min(sample_v,1)))
                p.z-=(v-sample_v)*(c['stations'][-1][0]-c['stations'][0][0])*c['k']
                radial=Vector((sin(angle),-cos(angle),.22*(1-t))).normalized()
                p.z-=max(0,v-1)*190
                if i==0:p.z-=9*t**4*(.63+.37*back)
                if v>.78:
                    curl=max(0,(v-.78)/.26)
                    p-=radial*(4+4*back)*curl*curl
                fullness=max(.01,sin(pi*t)**.55)
                # Three-quarter silhouette reveals an arched root, a convex
                # upper plane, a thin edge and a returning lower lip on each lock.
                crest=sin(pi*u)**.81
                relief=(5.9+.58*flare*back)*fullness*crest-2.3+2.4*sin(1.7*pi*t+j*.63)+1.0*cross
                if temple:relief+=5*sin(pi*t)**1.6
                coords.append(panel(i,p.x/c['k'],c['floor']-p.z/c['k'],back>.35))
                p+=radial*relief
                p.z+=1.8*(1-t)**3
                row.append((p,radial*(1.1+6.7*fullness*crest)))
            rows.append(row);maps.append(coords)
        first=len(g.verts)
        plate(g,rows,'Head',maps if back>.78 else None,.9+.05*sin(j))
        # Roots stay on the scalp. Ends trail the side bones during turns,
        # landings and changes of speed, also on rivals with short styles.
        if temple or abs(sin(anchor))>.55:
            bone='Lock.L' if side>0 else 'Lock.R'
            if i in (1,4):strength=.30
            else:strength=.76
            g.feather(first,len(g.verts),len(rows),bone,strength)
    # The short cheek lock curls *inward* in front of the tiny ear.
    # It separates the skin volume from the larger scallops on the nape.
    for sign in (-1,1):
        sections=[]; maps=[]
        for a in range(17):
            t=a/16
            angle=sign*(.99+.20*sin(pi*t)-.35*t*t)
            v=.24+(.74 if i==0 else .69)*t
            p=Vector(hair_profile(c,angle,v))
            radial=Vector((sin(angle),-cos(angle),.16*(1-t))).normalized()
            tangent=Vector((cos(angle),sin(angle),0))
            p+=radial*(3.2+5.6*sin(pi*t))
            p.z-=2.4*sin(pi*t)
            width=(14.6 if i==0 else 10.6)*max(.015,sin(pi*t)**.65)
            ring=[]; coords=[]
            for k in range(8):
                u=k/7
                ridge=sin(pi*u)*sin(pi*t)**.55
                pt=p+tangent*(2*u-1)*width+radial*3.9*ridge
                coords.append(panel(i,pt.x/c['k'],c['floor']-pt.z/c['k']))
                ring.append((pt,radial*(1+4*ridge)))
            sections.append(ring);maps.append(coords)
        first=len(g.verts)
        plate(g,sections,'Head')
        g.feather(first,len(g.verts),len(sections),'Lock.L' if sign>0 else 'Lock.R',.71)
    if i==0:
        # A broad temple section turns away from the eye, curls in front
        # of the earlobe and thins beside the cheek like the turnaround.
        for sign in (-1,1):
            rows=[];maps=[]
            left=(Vector((44,70)),Vector((59,100)),Vector((73,138)),Vector((48,169)))
            right=(Vector((44,70)),Vector((85,95)),Vector((91,162)),Vector((54,181)))
            for j in range(19):
                t=j/18
                inside,outside=cubic(left,t),cubic(right,t)
                row=[];coords=[]
                for k in range(9):
                    u=k/8
                    pos=inside.lerp(outside,u)
                    end=max(0,(t-.72)/.28)**1.7
                    pos=pos.lerp(inside.lerp(outside,.46),.975*end)
                    pos.x-=2.8*end
                    p,normal=frontal_point(c,sign*pos.x,pos.y)
                    crest=sin(pi*u)**.76*sin(pi*t)**.53
                    p+=normal*(1.3+6.9*crest)
                    row.append((p,normal*(1+5.3*crest)))
                    coords.append(tile(.1+.8*u,.13+.83*t))
                rows.append(row);maps.append(coords)
            first=len(g.verts)
            plate(g,rows,'Head',maps)
            g.feather(first,len(g.verts),len(rows),'Lock.L' if sign>0 else 'Lock.R',.68)
    bangs(g,i)
    if i in (0,1,3,5):
        # A pair of free, tapering outer strands leaves slivers of sky between
        # the moving ends and the bob, as in the airborne and profile sheets.
        for sign in (-1,1):
            side='L' if sign>0 else 'R'
            rows=[]
            for a in range(19):
                t=a/18
                angle=sign*(1.48+.43*sin(pi*t)-.25*t)
                v=.105+.858*t
                p=Vector(hair_profile(c,angle,v))
                radial=Vector((sin(angle),-cos(angle),.07))
                tangent=Vector((cos(angle),sin(angle),0))
                p+=radial*((13 if i==0 else 10)*sin(pi*t)**1.1+4.4*sin(2*pi*t))
                p.z+=4*sin(pi*t)
                radius=max(.018,sin(pi*t)**.57)
                row=[]
                for k in range(7):
                    u=k/6
                    crest=sin(pi*u)
                    row.append((p+tangent*(2*u-1)*4.85*radius+radial*3.8*radius*crest,radial*(.3+3.9*radius*crest)))
                rows.append(row)
            first=len(g.verts)
            plate(g,rows,'Head',None,.88)
            g.feather(first,len(g.verts),len(rows),'Lock.'+side,.86)
