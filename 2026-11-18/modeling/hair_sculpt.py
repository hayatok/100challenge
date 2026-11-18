"""Individual swept styles for the five rivals in design-sheet coordinates."""
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
    None,
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
    radius = station_width(c,sy)
    angle = asin(max(-.988,min(.988,x/max(1,radius))))
    xx,y,z = hair_profile(c,angle,v)
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
                p,n=frontal_point(c,*point)
                coords.append(panel(i,*point))
                crown=sin(pi*u)**.8 * sin(pi*(.015+.97*t))**.51
                # Drawn left/right contours sometimes run around the end. Ridge
                # stays a few millimetres proud of each overlapping neighbour.
                relief=(4.5+1.25*index)*sin(pi*t)**.6+(.85+9*crown)
                p+=n*relief
                row.append((p, n*(1+7.5*crown)))
            rows.append(row);maps.append(coords)
        plate(g,rows,'Head',None if i==3 or (i==2 and index==3) else maps,.83+.04*(index%3))


def cap_and_locks(g, i):
    c=CAST[i]
    n=72
    def cap_end(a):
        side=min(1,abs(a)/1.47)
        # The centre lies under the illustrated fringe rather than ending
        # as a horizontal strip of bare forehead. Side layers frame the eye.
        fringe_row=(0,142,141,141,147,137)[i]
        top,bottom=c['stations'][0][0],c['stations'][-1][0]
        front=(fringe_row-top)/(bottom-top)
        return front+(.905-front+.013*cos(7*a+.6))*side*side*(3-2*side)
    rows=[]
    for j in range(24):
        t=j/23;row=[]
        for k in range(n):
            a=-pi+2*pi*k/n
            p=Vector(hair_profile(c,a,t*cap_end(a)))
            nrm=Vector((sin(a),-cos(a),.58*(1-t)))
            p-=nrm*(1.3+4.5*t)
            p.z+=2.6*(1-t)**2
            if j==0:
                p.x*=.11
                p.y=15+(p.y-15)*.11
                p.z+=.8
            row.append(p)
        rows.append(row)
    def crown_uv(angle, v):
        return (.501+.498*max(0,min(1,(angle+pi)/(2*pi))),1-(2+315*max(0,min(1,v)))/1024)
    def scalp_quad(a,b):
        return [crown_uv(-pi+2*pi*col/n,(row/23)*cap_end(-pi+2*pi*col/n))
                for row,col in ((a,b),(a,b+1),(a+1,b+1),(a+1,b))]
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
                if v>.78:
                    curl=max(0,(v-.78)/.26)
                    p-=radial*(4+4*back)*curl*curl
                fullness=max(.01,sin(pi*t)**.55)
                # Three-quarter silhouette reveals an arched root, a convex
                # upper plane, a thin edge and a returning lower lip on each lock.
                crest=sin(pi*u)**.81
                relief=(5.9+.58*flare*back)*fullness*crest-2.3+2.4*sin(1.7*pi*t+j*.63)+1.0*cross
                root=max(0,1-t/.52)
                relief-=6.2*root*root
                if temple:relief+=3*sin(pi*t)**1.6
                # Each lock stays on one side of the cylindrical seam.
                theta=angle-2*pi if anchor>pi else angle
                coords.append(crown_uv(theta,v))
                p+=radial*relief
                p.z+=1.8*(1-t)**3
                row.append((p,radial*(1.1+6.7*fullness*crest)))
            rows.append(row);maps.append(coords)
        first=len(g.verts)
        plate(g,rows,'Head',maps)
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
            v=.24+.69*t
            p=Vector(hair_profile(c,angle,v))
            radial=Vector((sin(angle),-cos(angle),.16*(1-t))).normalized()
            tangent=Vector((cos(angle),sin(angle),0))
            p+=radial*(3.2+5.6*sin(pi*t))
            p.z-=2.4*sin(pi*t)
            width=10.6*max(.015,sin(pi*t)**.65)
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
    bangs(g,i)
    if i in (1,3,5):
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
                p+=radial*(6.5*sin(pi*t)**1.1+2.4*sin(2*pi*t))
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
